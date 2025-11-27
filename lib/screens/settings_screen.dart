// lib/screens/settings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();

  // Controllers for text fields
  final _surveyorIdController = TextEditingController();
  final _ftpHostController = TextEditingController();
  final _ftpUsernameController = TextEditingController();
  final _ftpPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _obscurePassword = true;

  // Available surveys - will be populated by scanning assets/surveys folder
  final List<String> _availableSurveys = [];
  String? _selectedSurvey;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Load surveys first, then settings
    await _loadAvailableSurveys();
    await _loadSettings();
  }

  @override
  void dispose() {
    _surveyorIdController.dispose();
    _ftpHostController.dispose();
    _ftpUsernameController.dispose();
    _ftpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final surveyorId = await _settingsService.surveyorId;
    final ftpHost = await _settingsService.ftpHost;
    final ftpUsername = await _settingsService.ftpUsername;
    final ftpPassword = await _settingsService.ftpPassword;
    final activeSurvey = await _settingsService.activeSurvey;

    if (mounted) {
      setState(() {
        _surveyorIdController.text = surveyorId ?? '';
        _ftpHostController.text = ftpHost ?? '';
        _ftpUsernameController.text = ftpUsername ?? '';
        _ftpPasswordController.text = ftpPassword ?? '';
        _selectedSurvey = activeSurvey;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAvailableSurveys() async {
    try {
      // List of known survey folders to check
      const surveyFolders = [
        'fake_household_survey',
        'fake_clinical_trial',
      ];

      debugPrint('Scanning for survey manifests in ${surveyFolders.length} folders...');

      for (final folder in surveyFolders) {
        final manifestPath = 'assets/surveys/$folder/survey_manifest.json';

        try {
          debugPrint('Attempting to load: $manifestPath');
          final manifestJson = await rootBundle.loadString(manifestPath);
          final surveyData = json.decode(manifestJson);
          final surveyName = surveyData['surveyName'] as String?;

          debugPrint('Found survey: $surveyName');

          if (surveyName != null && !_availableSurveys.contains(surveyName)) {
            if (mounted) {
              setState(() {
                _availableSurveys.add(surveyName);
              });
            }
            debugPrint('Added survey to list: $surveyName');
          }
        } catch (e) {
          debugPrint('Could not load manifest from $manifestPath: $e');
          // Continue to next folder
        }
      }

      debugPrint('Final available surveys (${_availableSurveys.length}): $_availableSurveys');

      if (_availableSurveys.isEmpty) {
        debugPrint('WARNING: No surveys found - please ensure flutter run was executed with a full rebuild');
        debugPrint('Try: flutter clean && flutter run');
      }
    } catch (e) {
      debugPrint('Error scanning for surveys: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _settingsService.saveAllSettings(
          surveyorId: _surveyorIdController.text.trim(),
          ftpHost: _ftpHostController.text.trim(),
          ftpUsername: _ftpUsernameController.text.trim(),
          ftpPassword: _ftpPasswordController.text,
          activeSurvey: _selectedSurvey,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Settings saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving settings: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: FilledButton.tonal(
              onPressed: _saveSettings,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'User Settings',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _surveyorIdController,
                      decoration: const InputDecoration(
                        labelText: 'Surveyor ID',
                        hintText: 'Enter your surveyor ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Surveyor ID is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'Survey Selection',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Survey dropdown with current value display
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Active Survey',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.poll),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _availableSurveys.contains(_selectedSurvey)
                              ? _selectedSurvey
                              : null,
                          items: _availableSurveys.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    enabled: false,
                                    child: Text('No surveys available - rebuild app'),
                                  )
                                ]
                              : _availableSurveys.map((survey) {
                                  return DropdownMenuItem(
                                    value: survey,
                                    child: Text(survey),
                                  );
                                }).toList(),
                          onChanged: _availableSurveys.isEmpty
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedSurvey = value;
                                  });
                                },
                          hint: Text(_availableSurveys.isEmpty
                              ? 'No surveys found'
                              : 'Select a survey'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      'FTP Settings (Optional)',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These settings will be used for downloading surveys and uploading data in the future.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ftpHostController,
                      decoration: const InputDecoration(
                        labelText: 'FTP Host',
                        hintText: 'ftp.example.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cloud),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ftpUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'FTP Username',
                        hintText: 'Enter FTP username',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_circle),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ftpPasswordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'FTP Password',
                        hintText: 'Enter FTP password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
