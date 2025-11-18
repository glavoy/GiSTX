import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/db_service.dart';
import 'survey_screen.dart';
import 'record_selector_screen.dart';

/// Represents a questionnaire with its filename and display name
class QuestionnaireInfo {
  final String filename;
  final String displayName;

  QuestionnaireInfo({
    required this.filename,
    required this.displayName,
  });
}

/// Screen that displays a list of available questionnaires as buttons
/// and allows the user to select which one to complete.
class QuestionnaireSelectorScreen extends StatefulWidget {
  /// If true, navigates to record selector after selection (for modifying existing surveys)
  /// If false, navigates to new survey screen (for new surveys)
  final bool isModifyMode;

  const QuestionnaireSelectorScreen({
    super.key,
    this.isModifyMode = false,
  });

  @override
  State<QuestionnaireSelectorScreen> createState() =>
      _QuestionnaireSelectorScreenState();
}

class _QuestionnaireSelectorScreenState
    extends State<QuestionnaireSelectorScreen> {
  List<QuestionnaireInfo> _availableQuestionnaires = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAvailableQuestionnaires();
  }

  /// Loads the list of available questionnaire XML files from assets
  /// and fetches their display names from the database
  Future<void> _loadAvailableQuestionnaires() async {
    try {
      // 1. Initialize database
      await DbService.init();

      // 2. Load the asset manifest to find all XML files in surveys directory
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // 3. Get all XML filenames from assets
      final Set<String> availableXmlFiles = {};
      for (final assetPath in manifestMap.keys) {
        if (assetPath.startsWith('assets/surveys/') && assetPath.endsWith('.xml')) {
          // Extract just the filename (e.g., "baseline.xml" from "assets/surveys/baseline.xml")
          final filename = assetPath.substring('assets/surveys/'.length);
          availableXmlFiles.add(filename);
        }
      }

      // 4. Get questionnaires from the crfs table in the order they appear
      final crfsRecords = await DbService.getExistingRecords('crfs');
      final List<QuestionnaireInfo> questionnaires = [];

      for (final record in crfsRecords) {
        final tableName = record['tablename']?.toString();
        final displayName = record['displayname']?.toString();

        if (tableName != null && displayName != null) {
          // Construct the expected filename from the table name
          final filename = '$tableName.xml';

          // Only add if the XML file actually exists in assets
          if (availableXmlFiles.contains(filename)) {
            questionnaires.add(QuestionnaireInfo(
              filename: filename,
              displayName: displayName,
            ));
          }
        }
      }

      _availableQuestionnaires = questionnaires;

      // 5. If no questionnaires found, show error
      if (_availableQuestionnaires.isEmpty) {
        setState(() {
          _errorMessage = 'No questionnaire files found in assets/surveys/';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading questionnaires: $e';
        _isLoading = false;
      });
    }
  }

  /// Handles questionnaire selection
  void _onQuestionnaireSelected(QuestionnaireInfo questionnaire) {
    if (widget.isModifyMode) {
      // Navigate to record selector screen with the selected questionnaire
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecordSelectorScreen(
            questionnaireFilename: questionnaire.filename,
          ),
        ),
      );
    } else {
      // Navigate to new survey screen with the selected questionnaire
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SurveyScreen(
            questionnaireFilename: questionnaire.filename,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isModifyMode
              ? 'Select Questionnaire to Modify'
              : 'Select Questionnaire',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.isModifyMode
                            ? 'Select the questionnaire you want to modify:'
                            : 'Select the questionnaire you want to complete:',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _availableQuestionnaires.length,
                          itemBuilder: (context, index) {
                            final questionnaire = _availableQuestionnaires[index];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _onQuestionnaireSelected(questionnaire),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.assignment,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          questionnaire.displayName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
