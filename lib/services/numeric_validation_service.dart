class NumericValidationService {
  /// Returns true when a decimal separator is the final non-space character.
  ///
  /// This catches incomplete decimal entries such as "120." while allowing
  /// whole numbers ("120") and completed decimals ("120.0", "120.5").
  static bool hasTrailingDecimalSeparator(String value) {
    return value.trimRight().endsWith('.');
  }
}
