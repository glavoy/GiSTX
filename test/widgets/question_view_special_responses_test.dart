import 'dart:io';

import 'package:GiSTX/models/question.dart';
import 'package:GiSTX/services/csv_data_service.dart';
import 'package:GiSTX/widgets/question_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  Future<void> setCountry(String country) async {
    SharedPreferences.setMockInitialValues({'country': country});

    if (!Platform.isMacOS && !Platform.isLinux) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
        final args = call.arguments as Map?;
        final key = args?['key'];

        switch (call.method) {
          case 'read':
            return key == 'country' ? country : null;
          case 'write':
          case 'delete':
          case 'deleteAll':
            return null;
          case 'readAll':
            return {'country': country};
          case 'containsKey':
            return key == 'country';
          default:
            return null;
        }
      });
    }
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('radio special responses are localized for Burkina Faso',
      (tester) async {
    await setCountry('Burkina Faso');
    final answers = <String, dynamic>{};

    await tester.pumpQuestionView(
      question: _specialResponseQuestion(QuestionType.radio),
      answers: answers,
    );

    expect(find.text('Ne sait pas'), findsOneWidget);
    expect(find.text('Refuse de répondre'), findsOneWidget);
    expect(find.text("Don't know"), findsNothing);
    expect(find.text('Refuse to answer'), findsNothing);

    await tester.tap(find.text('Ne sait pas'));
    await tester.pump();

    expect(answers['special_field'], '-7');
  });

  testWidgets('radio special responses stay English for Uganda',
      (tester) async {
    await setCountry('Uganda');

    await tester.pumpQuestionView(
      question: _specialResponseQuestion(QuestionType.radio),
      answers: <String, dynamic>{},
    );

    expect(find.text("Don't know"), findsOneWidget);
    expect(find.text('Refuse'), findsOneWidget);
    expect(find.text('Ne sait pas'), findsNothing);
    expect(find.text('Refuse de répondre'), findsNothing);
  });

  testWidgets('checkbox special responses are localized for Burkina Faso',
      (tester) async {
    await setCountry('Burkina Faso');
    final answers = <String, dynamic>{};

    await tester.pumpQuestionView(
      question: _specialResponseQuestion(QuestionType.checkbox),
      answers: answers,
    );

    expect(find.text('Ne sait pas'), findsOneWidget);
    expect(find.text('Refuse de répondre'), findsOneWidget);
    expect(find.text("Don't know"), findsNothing);
    expect(find.text('Refuse to answer'), findsNothing);

    await tester.tap(find.text('Refuse de répondre'));
    await tester.pump();

    expect(answers['special_field'], ['-8']);
  });
}

extension on WidgetTester {
  Future<void> pumpQuestionView({
    required Question question,
    required Map<String, dynamic> answers,
  }) async {
    await pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuestionView(
            question: question,
            answers: answers,
            csvDataService: CsvDataService(),
            surveyId: 'test-survey',
          ),
        ),
      ),
    );
    await pumpAndSettle();
  }
}

Question _specialResponseQuestion(QuestionType type) {
  return Question(
    type: type,
    fieldName: 'special_field',
    fieldType: 'text',
    text: 'Special response question',
    dontKnow: '-7',
    refuse: '-8',
    options: [
      QuestionOption(value: '1', label: 'Regular response'),
      QuestionOption(value: '-7', label: "Don't know"),
      QuestionOption(value: '-8', label: 'Refuse to answer'),
    ],
  );
}
