// lib/services/db_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/question.dart';
import '../config/app_config.dart';

class DbService {
  static Database? _db;
  static String? _dbPath;

  /// Call once at app start
  static Future<void> init() async {
    try {
      // Windows / desktop via FFI
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      // Determine database path
      if (AppConfig.customDatabasePath != null) {
        _dbPath = AppConfig.customDatabasePath;
        _log('Using custom database path: $_dbPath');
      } else {
        final dir = await getApplicationSupportDirectory();
        _dbPath = p.join(dir.path, AppConfig.databaseFilename);
        _log('Using default database path: $_dbPath');
      }

      // Check if database file exists
      final dbFile = File(_dbPath!);
      if (!dbFile.existsSync()) {
        final errorMsg =
            'Database file not found at: $_dbPath\n\nThe database must be created by your external application before running surveys.';
        _logError(errorMsg);
        throw DatabaseException(errorMsg);
      }

      // Open the database
      _db = await openDatabase(_dbPath!, version: 1);
      _log('Database opened successfully: $_dbPath');
    } catch (e) {
      _logError('Failed to initialize database: $e');
      rethrow;
    }
  }

  /// Get the current database path
  static String? get databasePath => _dbPath;

  /// Save one completed interview's answers to the survey-specific table.
  /// The table name is derived from the survey XML filename (without .xml extension).
  /// Each table has columns matching the fieldnames from the XML (except 'information' type fields).
  ///
  /// - `surveyFilename`: the XML filename (e.g., 'survey.xml')
  /// - `answers`: your in-memory AnswerMap (fieldname -> value)
  /// - `questions`: the parsed questions (to know which fields to save and their types)
  static Future<void> saveInterview({
    required String surveyFilename,
    required AnswerMap answers,
    required List<Question> questions,
  }) async {
    if (_db == null) {
      throw DatabaseException(
          'Database not initialized. Call DbService.init() first.');
    }

    final db = _db!;

    // Derive table name from filename: remove .xml extension
    final tableName = surveyFilename.toLowerCase().replaceAll('.xml', '');

    try {
      // Check if table exists first
      final tableExists = await _tableExists(tableName);
      if (!tableExists) {
        final errorMsg =
            'Table "$tableName" does not exist in database.\n\nExpected table name: $tableName\nDatabase path: $_dbPath\n\nPlease create this table using your external application before conducting surveys.';
        _logError(errorMsg);
        throw DatabaseException(errorMsg);
      }

      // Build the column:value map, excluding information type questions
      final Map<String, dynamic> rowData = {};

      for (final q in questions) {
        // Skip information questions - they don't get stored in the database
        if (q.type == QuestionType.information) continue;

        final val = answers[q.fieldName];
        if (val == null) continue;

        // Store the value based on the question type
        switch (q.type) {
          case QuestionType.checkbox:
            // Store checkbox as comma-separated values
            final list = (val is List)
                ? val.map((e) => e.toString()).toList()
                : <String>[];
            rowData[q.fieldName] = list.join(',');
            break;

          case QuestionType.date:
            // Store date as ISO8601 string (YYYY-MM-DD)
            if (val is DateTime) {
              rowData[q.fieldName] = val.toIso8601String().split('T')[0];
            } else {
              rowData[q.fieldName] = val.toString();
            }
            break;

          case QuestionType.datetime:
          case QuestionType.automatic:
            // Store datetime/timestamp as ISO8601 string
            if (val is DateTime) {
              rowData[q.fieldName] = val.toIso8601String();
            } else {
              rowData[q.fieldName] = val.toString();
            }
            break;

          default:
            // For text, radio, combobox, etc., store as string
            rowData[q.fieldName] = val.toString();
            break;
        }
      }

      // Get the uniqueid to use as primary key
      final uniqueId = rowData['uniqueid']?.toString();
      if (uniqueId == null || uniqueId.isEmpty) {
        throw DatabaseException('uniqueid is required for interview saving.');
      }

      _log(
          'Saving interview to table "$tableName" with uniqueid: $uniqueId');
      _log('Row data: ${rowData.keys.join(', ')}');

      // Insert or replace the row
      await db.insert(
        tableName,
        rowData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _log('Interview saved successfully to table "$tableName"');
    } catch (e) {
      final errorMsg =
          'Failed to save interview to table "$tableName": $e\n\nDatabase: $_dbPath';
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

  /// Public method to check if a table exists
  static Future<bool> tableExists(String tableName) => _tableExists(tableName);

  /// Get the list of all tables in the database
  static Future<List<String>> getTables() async {
    if (_db == null) {
      throw DatabaseException('Database not initialized.');
    }

    try {
      final result = await _db!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      _logError('Error getting table list: $e');
      return [];
    }
  }

  /// Get the column names for a specific table
  static Future<List<String>> getTableColumns(String tableName) async {
    if (_db == null) {
      throw DatabaseException('Database not initialized.');
    }

    try {
      final result = await _db!.rawQuery('PRAGMA table_info($tableName)');
      return result.map((row) => row['name'] as String).toList();
    } catch (e) {
      _logError('Error getting columns for table $tableName: $e');
      return [];
    }
  }

  /// Convenience: return the first survey filename
  static Future<String?> firstSurveyId() async {
    return AppConfig.surveyFilename;
  }

  /// Close the database connection
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _log('Database closed');
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
