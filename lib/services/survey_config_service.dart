// lib/services/survey_config_service.dart
/// Service for loading and managing survey configurations
///
/// Reads survey manifests and provides helper methods for accessing
/// survey-specific resources like XML files and metadata.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'settings_service.dart';

class SurveyConfigService {
  static final SurveyConfigService _instance = SurveyConfigService._internal();
  factory SurveyConfigService() => _instance;
  SurveyConfigService._internal();

  final _settingsService = SettingsService();

  // Cache for loaded survey manifests
  final Map<String, Map<String, dynamic>> _manifestCache = {};

  /// Get the survey ID from the survey name stored in settings
  /// Returns null if no survey is selected or if survey not found
  Future<String?> getActiveSurveyId() async {
    final surveyName = await _settingsService.activeSurvey;
    debugPrint('[SurveyConfig] Getting survey ID for survey name: $surveyName');

    if (surveyName == null) {
      debugPrint('[SurveyConfig] No survey name found in settings');
      return null;
    }

    // List of known survey folders to check
    const surveyFolders = [
      'fake_household_survey',
      'fake_clinical_trial',
    ];

    debugPrint('[SurveyConfig] Checking ${surveyFolders.length} survey folders...');

    // Check each survey folder for a matching survey name
    for (final folder in surveyFolders) {
      try {
        final manifestPath = 'assets/surveys/$folder/survey_manifest.json';
        debugPrint('[SurveyConfig] Loading manifest from: $manifestPath');
        final manifest = await _loadManifest(manifestPath);
        final manifestSurveyName = manifest['surveyName'] as String?;
        debugPrint('[SurveyConfig] Manifest survey name: $manifestSurveyName');

        if (manifestSurveyName == surveyName) {
          final surveyId = manifest['surveyId'] as String?;
          debugPrint('[SurveyConfig] ✓ Match found! Survey ID: $surveyId');
          return surveyId;
        }
      } catch (e) {
        debugPrint('[SurveyConfig] Failed to load manifest from $folder: $e');
        // Skip folders that don't have a valid manifest
        continue;
      }
    }

    debugPrint('[SurveyConfig] ✗ No matching survey found for name: $surveyName');
    return null;
  }

  /// Load a survey manifest from the given path
  Future<Map<String, dynamic>> _loadManifest(String manifestPath) async {
    if (_manifestCache.containsKey(manifestPath)) {
      return _manifestCache[manifestPath]!;
    }

    final manifestJson = await rootBundle.loadString(manifestPath);
    final manifest = json.decode(manifestJson) as Map<String, dynamic>;
    _manifestCache[manifestPath] = manifest;
    return manifest;
  }

  /// Get the full asset path for a questionnaire XML file
  /// Returns the path like: 'assets/surveys/fake_household_survey/household.xml'
  /// Returns null if no survey is active
  Future<String?> getQuestionnaireAssetPath(String filename) async {
    final surveyId = await getActiveSurveyId();
    if (surveyId == null) return null;

    return 'assets/surveys/$surveyId/$filename';
  }

  /// Get the active survey's manifest
  /// Returns null if no survey is selected
  Future<Map<String, dynamic>?> getActiveSurveyManifest() async {
    final surveyId = await getActiveSurveyId();
    if (surveyId == null) return null;

    try {
      final manifestPath = 'assets/surveys/$surveyId/survey_manifest.json';
      return await _loadManifest(manifestPath);
    } catch (e) {
      return null;
    }
  }

  /// Check if a survey is currently configured in settings
  Future<bool> isSurveyConfigured() async {
    final surveyId = await getActiveSurveyId();
    return surveyId != null;
  }

  /// Get the surveyor ID from settings
  Future<String?> getSurveyorId() async {
    return await _settingsService.surveyorId;
  }

  /// Check if all required settings are configured
  /// (surveyor ID and active survey)
  Future<bool> areSettingsConfigured() async {
    final surveyorId = await _settingsService.surveyorId;
    final activeSurvey = await _settingsService.activeSurvey;

    return surveyorId != null &&
           surveyorId.isNotEmpty &&
           activeSurvey != null &&
           activeSurvey.isNotEmpty;
  }

  /// Clear the manifest cache (useful for testing or after updates)
  void clearCache() {
    _manifestCache.clear();
  }
}
