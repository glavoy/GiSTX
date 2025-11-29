/// Application configuration
///
/// This file contains all configurable application-level settings.

class AppConfig {
  // Software version - displayed in the app and saved with each interview
  static const String softwareVersion = 'GiSTX 0.0.1.alpha';

  // Logging configuration
  static const bool enableDebugLogging = true;
  static const bool enableErrorDialogs = true;

  // Default survey folder path
  static const String surveysAssetPath = 'assets/surveys';

  // Database folder path
  static const String databaseFolderPath = 'assets/database';
}
