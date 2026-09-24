import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_input/intl_phone_input.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' show IsoCode;

void main() {
  group('PhoneCountries', () {
    test('has one entry per region in the phone metadata', () {
      expect(PhoneCountries.all, hasLength(IsoCode.values.length));
      expect(PhoneCountries.all.map((c) => c.isoCode).toSet(),
          hasLength(IsoCode.values.length));
    });

    test('Algeria: dial code, flag, names in en/fr/ar', () {
      final dz = PhoneCountries.byIso('DZ')!;
      expect(dz.dialCode, '213');
      expect(dz.flag, '🇩🇿');
      expect(dz.name, 'Algeria');
      expect(dz.nameFor('fr'), 'Algérie');
      expect(dz.nameFor('ar'), 'الجزائر');
      expect(dz.nameFor('de'), 'Algeria', reason: 'falls back to English');
      expect(dz.nationalPrefix, '0');
    });

    test('Italy dial code is 39 (wrong in intl_phone_field)', () {
      expect(PhoneCountries.byIso('IT')!.dialCode, '39');
      expect(PhoneCountries.byIso('IT')!.nationalPrefix, isNull);
    });

    test('byIso is case-insensitive and returns null when unknown', () {
      expect(PhoneCountries.byIso('fr')!.isoCode, 'FR');
      expect(PhoneCountries.byIso('ZZ'), isNull);
    });

    test('countries sharing +1 and +7', () {
      final plusOne = PhoneCountries.byDialCode('1').map((c) => c.isoCode);
      expect(plusOne, containsAll(<String>['US', 'CA', 'PR', 'JM']));
      final plusSeven = PhoneCountries.byDialCode('+7').map((c) => c.isoCode);
      expect(plusSeven, unorderedEquals(<String>['RU', 'KZ']));
      expect(PhoneCountries.mainForDialCode('1')!.isoCode, 'US');
      expect(PhoneCountries.mainForDialCode('7')!.isoCode, 'RU');
    });

    test('resolve accepts ISO codes and dial codes', () {
      expect(PhoneCountries.resolve('IN')!.isoCode, 'IN');
      expect(PhoneCountries.resolve('in')!.isoCode, 'IN');
      expect(PhoneCountries.resolve('+91')!.isoCode, 'IN');
      expect(PhoneCountries.resolve('91')!.isoCode, 'IN');
      expect(PhoneCountries.resolve('+1')!.isoCode, 'US');
      expect(PhoneCountries.resolve('nope'), isNull);
    });
  });

  group('PhoneCountry lengths come from libphonenumber metadata', () {
    test('Algeria: mobile 9, fixed line 8 or 9', () {
      final dz = PhoneCountries.byIso('DZ')!;
      expect(dz.possibleLengths(PhoneType.mobile), [9]);
      expect(dz.possibleLengths(PhoneType.fixedLine), [8, 9]);
      expect(dz.minLength, 8);
      expect(dz.maxLength, 9);
    });

    test('Djibouti is 8 digits (intl_phone_field says 6)', () {
      final dj = PhoneCountries.byIso('DJ')!;
      expect(dj.minLength, 8);
      expect(dj.maxLength, 8);
    });

    test('United Kingdom mobiles are 10 digits', () {
      expect(
          PhoneCountries.byIso('GB')!.possibleLengths(PhoneType.mobile), [10]);
    });

    test('Madagascar is 9 digits (intl_phone_field says 10)', () {
      expect(PhoneCountries.byIso('MG')!.maxLength, 9);
    });

    test('Italy allows 6 to 12 digits', () {
      final it = PhoneCountries.byIso('IT')!;
      expect(it.minLength, 6);
      expect(it.maxLength, 12);
    });
  });
}
