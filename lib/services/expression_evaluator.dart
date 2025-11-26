// lib/services/expression_evaluator.dart
import '../models/question.dart'; // For AnswerMap

/// A utility class for parsing and evaluating boolean expressions.
class ExpressionEvaluator {
  /// Evaluates a boolean expression string with AND and OR clauses.
  /// Returns true if the expression evaluates to true, otherwise false.
  static bool evaluate(String expression, AnswerMap answers) {
    // Handle OR clauses by splitting the expression and checking if any are true
    final Pattern orPattern = RegExp(r'\s+or\s+', caseSensitive: false);
    final orClauses = expression.split(orPattern);
    for (final orClause in orClauses) {
      // Handle AND clauses within each OR clause
      final Pattern andPattern = RegExp(r'\s+and\s+', caseSensitive: false);
      final andClauses = orClause.split(andPattern);
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
    // Regex to capture: (field_name) (operator) (value)
    // The value can be a quoted string or another field name.
    // Handles operators like =, <>, <=, >=, <, >, contains, does not contain
    final Pattern pattern = RegExp(
        r"^\s*\(?([\w_]+)\s*(==|!=|<>|<=|>=|<|>|contains|does not contain)\s*([\w_'\s]+)\)?\s*$");
    final matches = pattern.allMatches(condition);
    final match = matches.isEmpty ? null : matches.first;

    if (match == null) {
      throw FormatException('Invalid condition format: "$condition"');
    }

    final String fieldName = match.group(1)!.trim();
    final String operator = match.group(2)!.trim();
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
      return false;
    }

    // Handle List values for 'contains' and 'does not contain' operators
    String leftValueStr;
    if (leftValue is List) {
      leftValueStr = leftValue.join(',');
    } else {
      leftValueStr = leftValue.toString();
    }

    return _compare(leftValueStr, rightValue.toString(), operator);
  }

  /// Performs a comparison between two string values based on the operator.
  static bool _compare(String val1, String val2, String operator) {
    // Handle 'contains' and 'does not contain' for comma-separated strings
    if (operator == 'contains') {
      final list = val1.split(',').map((s) => s.trim()).toList();
      return list.contains(val2);
    }
    if (operator == 'does not contain') {
      final list = val1.split(',').map((s) => s.trim()).toList();
      return !list.contains(val2);
    }

    // Try to parse values as numbers for numeric comparison
    final num1 = double.tryParse(val1);
    final num2 = double.tryParse(val2);

    if (num1 != null && num2 != null) {
      // Numeric comparison
      switch (operator) {
        case '=':
        case '==':
          return num1 == num2;
        case '<>':
        case '!=':
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
        case '==':
          return val1 == val2;
        case '<>':
        case '!=':
          return val1 != val2;
        default:
          // For non-numeric types, only equality checks are supported
          return false;
      }
    }
  }
}
