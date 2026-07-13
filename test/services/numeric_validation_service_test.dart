import 'package:flutter_test/flutter_test.dart';
import 'package:GiSTX/services/numeric_validation_service.dart';

void main() {
  group('NumericValidationService.hasTrailingDecimalSeparator', () {
    test('rejects values ending with a decimal separator', () {
      expect(
        NumericValidationService.hasTrailingDecimalSeparator('120.'),
        isTrue,
      );
      expect(
        NumericValidationService.hasTrailingDecimalSeparator('120. '),
        isTrue,
      );
    });

    test('allows whole numbers and completed decimals', () {
      expect(
        NumericValidationService.hasTrailingDecimalSeparator('120'),
        isFalse,
      );
      expect(
        NumericValidationService.hasTrailingDecimalSeparator('120.0'),
        isFalse,
      );
      expect(
        NumericValidationService.hasTrailingDecimalSeparator('120.5'),
        isFalse,
      );
    });
  });
}
