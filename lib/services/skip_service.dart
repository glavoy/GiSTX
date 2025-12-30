// lib/services/skip_service.dart
import '../models/question.dart';

/// Service for evaluating skip conditions
class SkipService {
  /// Evaluate a skip condition and return the target field name if skip should occur
  /// Returns null if the skip condition is not met
  static String? evaluateSkip(
    SkipCondition skip,
    AnswerMap answers,
  ) {
    // Get the value to check
    final actualValue = answers[skip.fieldName];
    if (actualValue == null) return null;

    // Get the comparison value
    String compareValue;
    if (skip.responseType == 'dynamic') {
      // Dynamic: get value from another field
      compareValue = answers[skip.response]?.toString() ?? '';
    } else {
      // Fixed: use the literal value
      compareValue = skip.response;
    }

    // Convert actualValue to string for comparison, handling Lists from checkboxes
    String actualValueStr;
    if (actualValue is List) {
      actualValueStr = actualValue.join(',');
    } else {
      actualValueStr = actualValue.toString();
    }

    // Evaluate the condition
    final conditionMet = _evaluateCondition(
      actualValueStr,
      skip.condition,
      compareValue,
    );

    // If condition is met, return the skip target
    return conditionMet ? skip.skipToFieldName : null;
  }

  /// Evaluate all skip conditions for a question and return the first matching skip target
  /// Returns null if no skip conditions are met
  static String? evaluateSkips(
    List<SkipCondition> skips,
    AnswerMap answers,
  ) {
    for (final skip in skips) {
      final target = evaluateSkip(skip, answers);
      if (target != null) return target;
    }
    return null;
  }

  /// Evaluate a condition between two values
  static bool _evaluateCondition(
    String actualValue,
    String condition,
    String compareValue,
  ) {
    // Handle HTML-encoded operators from XML
    final op = condition
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');

    switch (op) {
      case '=':
      case '==':
        final aNum = double.tryParse(actualValue);
        final cNum = double.tryParse(compareValue);
        if (aNum != null && cNum != null) {
          return aNum == cNum;
        }

        final aDate = DateTime.tryParse(actualValue);
        final cDate = DateTime.tryParse(compareValue);
        if (aDate != null && cDate != null) {
          return aDate.isAtSameMomentAs(cDate);
        }

        return actualValue == compareValue;

      case '<>':
      case '!=':
        final aNum = double.tryParse(actualValue);
        final cNum = double.tryParse(compareValue);
        if (aNum != null && cNum != null) {
          return aNum != cNum;
        }

        final aDate = DateTime.tryParse(actualValue);
        final cDate = DateTime.tryParse(compareValue);
        if (aDate != null && cDate != null) {
          return !aDate.isAtSameMomentAs(cDate);
        }

        return actualValue != compareValue;

      case '<':
        return _numericCompare(actualValue, compareValue) < 0;

      case '>':
        return _numericCompare(actualValue, compareValue) > 0;

      case '<=':
        return _numericCompare(actualValue, compareValue) <= 0;

      case '>=':
        return _numericCompare(actualValue, compareValue) >= 0;

      case 'contains':
        // Check if the comma-separated list contains the value
        final list = actualValue.split(',').map((s) => s.trim()).toList();
        return list.contains(compareValue);

      case 'does not contain':
        // Check if the comma-separated list does not contain the value
        final list = actualValue.split(',').map((s) => s.trim()).toList();
        return !list.contains(compareValue);

      default:
        // Unknown operator, default to false
        return false;
    }
  }

  /// Compare two values numerically, falling back to string comparison if not numeric
  static int _numericCompare(String a, String b) {
    final aNum = double.tryParse(a);
    final bNum = double.tryParse(b);

    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }

    // Fall back to string comparison
    return a.compareTo(b);
  }
}
