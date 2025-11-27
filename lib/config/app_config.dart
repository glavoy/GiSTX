// lib/config/app_config.dart
/// Application configuration
///
/// This file contains all configurable application-level settings.
/// Survey-specific settings are now stored in survey manifest files.

import 'dart:io';

class AppConfig {
  // Software version - displayed in the app and saved with each interview
  static const String softwareVersion = 'GiSTX 0.0.1';

  // Logging configuration
  static const bool enableDebugLogging = true;
  static const bool enableErrorDialogs = true;

  // Default survey folder path
  static const String surveysAssetPath = 'assets/surveys';

  // Database folder path
  static const String databaseFolderPath = 'assets/database';

  // TODO: Remove these deprecated database settings after refactoring db_service.dart
  // These are temporary compatibility shims until db_service is updated to use survey manifests

  /// @deprecated Use survey manifest databaseName instead
  static String? get customDatabasePath {
    if (Platform.isWindows) {
      return 'C:\\gistx\\database\\fake_household_survey.sqlite';
    }
    return null; // Use default internal storage for mobile
  }

  /// @deprecated Use survey manifest databaseName instead
  static const String databaseFilename = 'fake_household_survey.sqlite';
}
