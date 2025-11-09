import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/survey_loader.dart';
import '../widgets/question_views.dart';
import '../services/db_service.dart';
import '../config/app_config.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final AnswerMap _answers = {};
  int _index = 0;
  late Future<List<Question>> _futureSurvey = _loadSurvey();

  Future<List<Question>> _loadSurvey() async {
    try {
      // 1) init DB
      await DbService.init();

      // 2) load questions for UI from the survey XML
      // The database tables are pre-created by another app, so we just load the XML
      return SurveyLoader.loadFromAsset(AppConfig.surveyAssetPath);
    } catch (e) {
      // If database initialization fails, still allow viewing the survey
      // but warn the user
      debugPrint('Warning: Database initialization failed: $e');
      debugPrint('Survey will load but data cannot be saved.');
      return SurveyLoader.loadFromAsset(AppConfig.surveyAssetPath);
    }
  }

  void _next(List<Question> qs) {
    if (_index < qs.length - 1) {
      setState(() => _index++);
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Question>>(
      future: _futureSurvey,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snap.error}')));
        }

        final questions = snap.data!;
        final q = questions[_index];
        final isFirst = _index == 0;
        final isLast = _index == questions.length - 1;
        final progress = (_index + 1) / questions.length;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 120,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/branding/gistx.png',
                    width: 100,
                    height: 100,
                  ),
                ),
                const SizedBox(width: 10),
                // const Text("Geoff's Dart Questionnaire"), // or your new name
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: FilledButton.tonal(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Cancel Interview'),
                        content: const Text(
                            'Are you sure you want to cancel the interview? \n\nAll data will be lost!'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // Close dialog
                              Navigator.of(context)
                                  .pop(); // Return to main screen
                            },
                            child: const Text('Yes'),
                          ),
                        ],
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel Interview'),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with progress
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Text(
                                      'Step ${_index + 1} of ${questions.length}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const Spacer(),
                                  Text('${(progress * 100).round()}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                    value: progress, minHeight: 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Animated question card
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: Card(
                            key: ValueKey(
                                q.fieldName), // forces fresh state per question
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: SingleChildScrollView(
                                child: QuestionView(
                                  key: ValueKey('view_${q.fieldName}'),
                                  question: q,
                                  answers: _answers,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Nav bar
                      Row(
                        children: [
                          if (!isFirst)
                            OutlinedButton.icon(
                              onPressed: _prev,
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Previous'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          if (!isFirst) const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => isLast
                                  ? _showDone(context)
                                  : _next(questions),
                              icon: Icon(
                                  isLast ? Icons.check : Icons.arrow_forward),
                              label: Text(isLast ? 'Finish' : 'Next'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDone(BuildContext context) async {
    final questions = await _futureSurvey; // already loaded
    final surveyFilename = await DbService.firstSurveyId();
    if (surveyFilename == null) return;

    bool saveSuccessful = false;
    String? errorMessage;

    try {
      await DbService.saveInterview(
        surveyFilename: surveyFilename,
        answers: _answers,
        questions: questions,
      );
      saveSuccessful = true;
    } catch (e) {
      // Capture the error to show in dialog
      errorMessage = e.toString();
      debugPrint('Save failed: $e');
    }

    if (!mounted) return;

    if (saveSuccessful) {
      // Success dialog
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('All done!'),
          content: Text(
              'Thanks! Answers saved successfully.\n\nInterview ID: ${_answers['uniqueid']}\nDatabase: ${DbService.databasePath ?? 'Unknown'}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to main screen
              },
              child: const Text('OK'),
            )
          ],
        ),
      );
    } else {
      // Error dialog
      if (AppConfig.enableErrorDialogs) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text('Save Failed'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Failed to save the interview data to the database.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Error details:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      errorMessage ?? 'Unknown error',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please check:\n'
                    '• Database file exists at the configured path\n'
                    '• Table name matches the survey filename\n'
                    '• All required columns exist in the table',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to main screen
                },
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
  }
}
