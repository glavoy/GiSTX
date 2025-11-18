// lib/config/app_config.dart
/// Application configuration
///
/// This file contains all configurable settings for the application.
/// Modify these values to match your deployment environment.

class AppConfig {
  // Software version - displayed in the app and saved with each interview
  static const String softwareVersion = '0.0.3';

  // Database configuration
  // Set to null to use the default application support directory
  // Set to a specific path to use a custom location (e.g., 'C:\\GiSTX\\Data\\gistx.sqlite')
  static const String? customDatabasePath =
      'C:\\gistx\\database\\gistx_config.sqlite';

  // Default database filename (used if customDatabasePath is null)
  static const String databaseFilename = 'gistx.sqlite';

  // Survey configuration
  // The name of the XML file containing the survey questions
  static const String surveyFilename = 'survey.xml';

  // Asset path to the survey XML
  static const String surveyAssetPath = 'assets/surveys/survey.xml';

  // Logging configuration
  static const bool enableDebugLogging = true;
  static const bool enableErrorDialogs = true;

  // Get the full database path based on configuration
  static String getDatabasePath(String appSupportDir) {
    if (customDatabasePath != null) {
      return customDatabasePath!;
    }
    return '$appSupportDir${appSupportDir.endsWith('\\') || appSupportDir.endsWith('/') ? '' : '/'}$databaseFilename';
  }
}
