import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

void main() {
  group('normalizeDigits', () {
    test('Arabic-Indic digits become ASCII', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('Extended Arabic-Indic (Persian/Urdu) digits become ASCII', () {
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('full-width digits and plus become ASCII', () {
      expect(normalizeDigits('＋２１３'), '+213');
    });

    test('other characters are kept', () {
      expect(normalizeDigits('+٢١٣ (٥٥٥) 12-34'), '+213 (555) 12-34');
    });
  });
}
