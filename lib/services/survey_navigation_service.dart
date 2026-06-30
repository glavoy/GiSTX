import 'package:flutter/foundation.dart';

import '../models/question.dart';
import 'skip_service.dart';

typedef AutomaticQuestionProcessor = Future<void> Function(Question question);

/// Resolves forward survey navigation while keeping skipped answers consistent.
class SurveyNavigationService {
  static const Set<String> protectedAutomaticFields = {
    'starttime',
    'startdate',
    'uniqueid',
    'swver',
    'survey_id',
    'lastmod',
    'stoptime',
  };

  /// Advances from a displayed question, applying its postskip before traversing
  /// automatic questions and preskips.
  static Future<int> advanceFromQuestion({
    required List<Question> questions,
    required int currentIndex,
    required AnswerMap answers,
    required AutomaticQuestionProcessor processAutomaticQuestion,
    Iterable<String> primaryKeyFields = const [],
    bool isEditMode = false,
  }) async {
    var startIndex = currentIndex + 1;
    final postSkipTarget =
        SkipService.evaluateSkips(questions[currentIndex].postSkips, answers);

    if (postSkipTarget != null) {
      final targetIndex = _findQuestionByFieldName(questions, postSkipTarget);
      if (targetIndex > currentIndex) {
        clearAnswersInRange(
          questions: questions,
          answers: answers,
          startIndex: currentIndex + 1,
          endIndex: targetIndex,
          primaryKeyFields: primaryKeyFields,
        );
        startIndex = targetIndex;
      }
    }

    return findNextDisplayedQuestion(
      questions: questions,
      startIndex: startIndex,
      answers: answers,
      processAutomaticQuestion: processAutomaticQuestion,
      primaryKeyFields: primaryKeyFields,
      isEditMode: isEditMode,
    );
  }

  /// Finds the next displayed question. Preskips are evaluated before any
  /// automatic or hidden-primary-key processing.
  static Future<int> findNextDisplayedQuestion({
    required List<Question> questions,
    required int startIndex,
    required AnswerMap answers,
    required AutomaticQuestionProcessor processAutomaticQuestion,
    Iterable<String> primaryKeyFields = const [],
    bool isEditMode = false,
  }) async {
    var index = startIndex;
    final primaryKeys =
        primaryKeyFields.map((field) => field.toLowerCase()).toSet();

    while (index < questions.length) {
      final question = questions[index];
      final preSkipTarget =
          SkipService.evaluateSkips(question.preSkips, answers);

      if (preSkipTarget != null) {
        final targetIndex = _findQuestionByFieldName(questions, preSkipTarget);
        if (targetIndex > index) {
          clearAnswersInRange(
            questions: questions,
            answers: answers,
            startIndex: index,
            endIndex: targetIndex,
            primaryKeyFields: primaryKeys,
          );
          index = targetIndex;
          continue;
        }
      }

      final isHiddenPrimaryKey =
          isEditMode && primaryKeys.contains(question.fieldName.toLowerCase());
      if (question.type == QuestionType.automatic || isHiddenPrimaryKey) {
        await processAutomaticQuestion(question);
        index++;
        continue;
      }

      return index;
    }

    return questions.isEmpty ? 0 : questions.length - 1;
  }

  /// Clears [startIndex] (inclusive) through [endIndex] (exclusive).
  ///
  /// Calculated automatic fields are route-derived and must be invalidated.
  /// Protected system fields and primary keys are never cleared by navigation.
  static void clearAnswersInRange({
    required List<Question> questions,
    required AnswerMap answers,
    required int startIndex,
    required int endIndex,
    Iterable<String> primaryKeyFields = const [],
  }) {
    final primaryKeys =
        primaryKeyFields.map((field) => field.toLowerCase()).toSet();
    final clearedFields = <String>[];
    final boundedStart = startIndex < 0 ? 0 : startIndex;

    for (var index = boundedStart;
        index < endIndex && index < questions.length;
        index++) {
      final question = questions[index];
      final fieldName = question.fieldName;
      final normalizedFieldName = fieldName.toLowerCase();

      if (primaryKeys.contains(normalizedFieldName) ||
          protectedAutomaticFields.contains(normalizedFieldName) ||
          question.type == QuestionType.information) {
        continue;
      }

      if (question.type == QuestionType.automatic &&
          question.calculation == null) {
        continue;
      }

      if (answers[fieldName] != null) {
        clearedFields.add(fieldName);
      }
      answers[fieldName] = null;
    }

    if (clearedFields.isNotEmpty) {
      debugPrint(
        'Cleared ${clearedFields.length} skipped answers: '
        '${clearedFields.join(", ")}',
      );
    }
  }

  static int _findQuestionByFieldName(
    List<Question> questions,
    String fieldName,
  ) {
    return questions.indexWhere((question) => question.fieldName == fieldName);
  }
}
