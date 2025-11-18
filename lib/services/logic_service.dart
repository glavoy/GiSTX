// lib/services/logic_service.dart
import 'package:flutter/foundation.dart';
import '../models/question.dart';

class LogicService {
  /// Evaluates the logic check expression for a given question.
  /// Returns an error message if the expression evaluates to true, otherwise null.
  static String? evaluateLogicChecks(Question question, AnswerMap answers) {
    final expression = question.logicCheck;
    if (expression == null || expression.isEmpty) {
      return null;
    }

    try {
      // 1. Normalize whitespace (collapse newlines, tabs, multiple spaces into single spaces)
      final normalizedExpression = expression.replaceAll(RegExp(r'\s+'), ' ').trim();

      // 2. Parse the main string into expression and message
      final parts = normalizedExpression.split(';');
      if (parts.length != 2) {
        throw FormatException(
            'Logic check must be in the format "expression; \'message\'"');
      }
      final String conditionStr = parts[0].trim();
      final String message = parts[1].trim().replaceAll("'", "");

      // 2. Evaluate the expression
      final bool result = _evaluateExpression(conditionStr, answers);

      debugPrint(
          '[LogicService] Evaluating logic for ${question.fieldName}: "$conditionStr" --> $result');

      // 3. If the expression is true, the check has failed, so return the message
      if (result) {
        return message;
      }
    } catch (e) {
      debugPrint(
          '[LogicService] Error evaluating expression: "$expression". Error: $e');
      // Return error message to be visible in UI for debugging
      return 'Error in logic check expression: $e';
    }

    return null;
  }

  /// Evaluates a boolean expression string with AND and OR clauses.
  static bool _evaluateExpression(String expression, AnswerMap answers) {
    // Handle OR clauses by splitting the expression and checking if any are true
    final orClauses =
        expression.split(RegExp(r'\s+or\s+', caseSensitive: false));
    for (var orClause in orClauses) {
      orClause = orClause.trim();

      // Remove outer parentheses from the OR clause if present
      if (orClause.startsWith('(') && orClause.endsWith(')')) {
        orClause = orClause.substring(1, orClause.length - 1).trim();
      }

      // Handle AND clauses within each OR clause
      final andClauses =
          orClause.split(RegExp(r'\s+and\s+', caseSensitive: false));
      bool isAndClauseTrue = true;
      for (final andClause in andClauses) {
        // If any AND condition is false, the whole AND clause is false
        if (!_evaluateSingleCondition(andClause.trim(), answers)) {
          isAndClauseTrue = false;
          break;
        }
      }
      // If any AND clause is true, the whole OR expression is true
      if (isAndClauseTrue) {
        return true;
      }
    }
    return false;
  }

  /// Evaluates a single condition like "field = 'value'" or "field1 <> field2"
  static bool _evaluateSingleCondition(String condition, AnswerMap answers) {
    // Remove outer parentheses if present
    condition = condition.trim();
    if (condition.startsWith('(') && condition.endsWith(')')) {
      condition = condition.substring(1, condition.length - 1).trim();
    }

    // Regex to capture: (field_name) (operator) (value)
    // The value can be a quoted string or another field name.
    // Handles operators like =, <>, <=, >=, <, >
    final regex = RegExp(r"^\s*([\w_]+)\s*([<>=!]+)\s*('[\w_]+'|[\w_]+)\s*$");
    final match = regex.firstMatch(condition);

    if (match == null) {
      throw FormatException('Invalid condition format: "$condition"');
    }

    final String fieldName = match.group(1)!.trim();
    final String operator =
        match.group(2)!.trim().replaceAll('!', '<'); // Normalize != to <>
    String valueOrField = match.group(3)!.trim();

    // Get the actual value of the left-hand side operand from the answers map
    final dynamic leftValue = answers[fieldName];

    // Determine the right-hand side value
    dynamic rightValue;
    if (valueOrField.startsWith("'") && valueOrField.endsWith("'")) {
      // It's a literal string value
      rightValue = valueOrField.substring(1, valueOrField.length - 1);
    } else {
      // It's a dynamic value from another field
      rightValue = answers[valueOrField];
    }

    // If either value is null, the condition cannot be met
    if (leftValue == null || rightValue == null) {
      debugPrint(
          '[LogicService]   - Comparing "$leftValue" vs "$rightValue". One is null, returning false.');
      return false;
    }

    return _compare(leftValue.toString(), rightValue.toString(), operator);
  }

  /// Performs a comparison between two string values based on the operator.
  static bool _compare(String val1, String val2, String operator) {
    final num1 = double.tryParse(val1);
    final num2 = double.tryParse(val2);

    if (num1 != null && num2 != null) {
      // Numeric comparison
      switch (operator) {
        case '=':
          return num1 == num2;
        case '<>':
          return num1 != num2;
        case '>':
          return num1 > num2;
        case '<':
          return num1 < num2;
        case '>=':
          return num1 >= num2;
        case '<=':
          return num1 <= num2;
        default:
          return false;
      }
    } else {
      // String comparison
      switch (operator) {
        case '=':
          return val1 == val2;
        case '<>':
          return val1 != val2;
        default:
          return false;
      }
    }
  }
}
