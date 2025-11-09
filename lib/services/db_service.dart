// lib/services/db_service.dart
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/question.dart';
import '../config/app_config.dart';

class DbService {
  static Database? _db;

  /// Call once at app start
  static Future<void> init() async {
    try {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // Set database path
      final dbPath = AppConfig.customDatabasePath ??
          p.join((await getApplicationSupportDirectory()).path,
              AppConfig.databaseFilename);
      _log('Using database path: $dbPath');

      // Open the database (will fail if file doesn't exist)
      _db = await openDatabase(dbPath);
    } catch (e) {
      _logError('Failed to initialize database: $e');
      rethrow;
    }
  }

  /// Get the current database path
  static String? get databasePath => _db?.path;

  /// Save one completed interview's answers to the survey-specific table.
  /// The table name is derived from the survey XML filename (without .xml extension).
  ///
  /// - `surveyFilename`: the XML filename (e.g., 'survey.xml')
  /// - `answers`: in-memory AnswerMap (fieldname -> value)
  static Future<void> saveInterview({
    required String surveyFilename,
    required AnswerMap answers,
  }) async {
    final db = _db!;

    // Derive table name from filename: remove .xml extension
    final tableName = surveyFilename.toLowerCase().replaceAll('.xml', '');

    try {
      // Check if table exists first
      final tableExists = await _tableExists(tableName);
      if (!tableExists) {
        final errorMsg =
            'Table "$tableName" does not exist in database.\n\nExpected table name: $tableName\nDatabase path: ${databasePath}\n\nPlease create this table using your external application before conducting surveys.';
        _logError(errorMsg);
        throw DatabaseException(errorMsg);
      }

      // Build the column:value map from answers
      // Convert special types to database-friendly formats
      final Map<String, dynamic> rowData = {};

      for (final entry in answers.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val == null) continue;

        // Store the value based on its runtime type
        if (val is List) {
          // Checkbox values - store as comma-separated
          rowData[key] = val.map((e) => e.toString()).join(',');
        } else if (val is DateTime) {
          // DateTime values - store as ISO8601 string
          rowData[key] = val.toIso8601String();
        } else {
          // Everything else (String, int, etc.) - store as-is
          rowData[key] = val;
        }
      }

      // Insert or replace the row
      await db.insert(
        tableName,
        rowData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      final errorMsg =
          'Failed to save interview to table "$tableName": $e\n\nDatabase: ${databasePath}';
      _logError(errorMsg);
      throw DatabaseException(errorMsg);
    }
  }

  /// Check if a table exists in the database
  static Future<bool> _tableExists(String tableName) async {
    if (_db == null) return false;

    try {
      final result = await _db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      return result.isNotEmpty;
    } catch (e) {
      _logError('Error checking if table exists: $e');
      return false;
    }
  }

  // Logging helpers
  static void _log(String message) {
    if (AppConfig.enableDebugLogging) {
      debugPrint('[DbService] $message');
    }
  }

  static void _logError(String message) {
    debugPrint('[DbService ERROR] $message');
  }
}

/// Custom exception for database errors
class DatabaseException implements Exception {
  final String message;

  DatabaseException(this.message);

  @override
  String toString() => message;
}
