import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

void main() {
  group('Algeria (DZ)', () {
    test('parses E.164', () {
      final v = PhoneValue.parse('+213555123456');
      expect(v.country.isoCode, 'DZ');
      expect(v.nationalNumber, '555123456');
      expect(v.e164, '+213555123456');
      expect(v.isValid, isTrue);
      expect(v.numberType, PhoneType.mobile);
    });

    test('parses a national number with trunk prefix', () {
      final v = PhoneValue.parse('0555 12 34 56', country: 'DZ');
      expect(v.nationalNumber, '555123456');
      expect(v.isValid, isTrue);
    });

    test('formats national and international', () {
      final v = PhoneValue.parse('+213555123456');
      expect(v.formatNational(), '0555 12 34 56');
      expect(v.formatInternational(), '+213 555 12 34 56');
    });

    test('fixed line', () {
      final v = PhoneValue.parse('+21321123456');
      expect(v.isValid, isTrue);
      expect(v.numberType, PhoneType.fixedLine);
    });

    test('too short is invalid', () {
      final v = PhoneValue.parse('+21355512345');
      expect(v.isValid, isFalse);
      expect(v.numberType, isNull);
    });
  });

  group('France (FR)', () {
    test('parse and format', () {
      final v = PhoneValue.parse('06 12 34 56 78', country: 'FR');
      expect(v.nationalNumber, '612345678');
      expect(v.e164, '+33612345678');
      expect(v.formatNational(), '06 12 34 56 78');
      expect(v.formatInternational(), '+33 6 12 34 56 78');
      expect(v.numberType, PhoneType.mobile);
    });
  });

  group('United States (US)', () {
    test('parse and format', () {
      final v = PhoneValue.parse('+1 (201) 555-0123');
      expect(v.country.isoCode, 'US');
      expect(v.nationalNumber, '2015550123');
      expect(v.formatNational(), '(201) 555-0123');
      expect(v.formatInternational(), '+1 201-555-0123');
      expect(v.numberType, PhoneType.fixedLineOrMobile);
    });

    test('+1 numbers are disambiguated by leading digits', () {
      expect(PhoneValue.parse('+1 204 234 5678').country.isoCode, 'CA');
      expect(PhoneValue.parse('+1 787 234 5678').country.isoCode, 'PR');
    });
  });

  group('United Kingdom (GB)', () {
    test('parse and format', () {
      final v = PhoneValue.parse('07400 123456', country: 'GB');
      expect(v.nationalNumber, '7400123456');
      expect(v.e164, '+447400123456');
      expect(v.formatNational(), '07400 123456');
      expect(v.formatInternational(), '+44 7400 123456');
      expect(v.numberType, PhoneType.mobile);
    });

    test('a UK number is valid as GB (issue: Guernsey picked instead)', () {
      final v = PhoneValue.parse('7400123456', country: 'GB');
      expect(v.country.isoCode, 'GB');
      expect(v.isValid, isTrue);
    });

    test('Guernsey numbers resolve to GG', () {
      expect(PhoneValue.parse('+441481256789').country.isoCode, 'GG');
    });
  });

  group('+7 (Russia and Kazakhstan)', () {
    test('Kazakhstan by leading digits', () {
      final v = PhoneValue.parse('+7 701 234 5678');
      expect(v.country.isoCode, 'KZ');
      expect(v.nationalNumber, '7012345678');
      expect(v.isValid, isTrue);
      expect(v.formatInternational(), '+7 701 234 5678');
    });

    test('Russia by leading digits', () {
      final v = PhoneValue.parse('+7 495 123 45 67');
      expect(v.country.isoCode, 'RU');
      expect(v.numberType, PhoneType.fixedLine);
      expect(v.formatInternational(), '+7 495 123-45-67');
    });

    test('Russian national number with trunk prefix 8', () {
      final v = PhoneValue.parse('8 912 345 67 89', country: 'RU');
      expect(v.nationalNumber, '9123456789');
      expect(v.isValid, isTrue);
      expect(v.numberType, PhoneType.mobile);
    });
  });

  group('input forms', () {
    test('leading 00 is an international prefix', () {
      final v = PhoneValue.parse('00213555123456');
      expect(v.country.isoCode, 'DZ');
      expect(v.nationalNumber, '555123456');
    });

    test('the E.164 country wins over the fallback country', () {
      final v = PhoneValue.parse('+33612345678', country: 'DZ');
      expect(v.country.isoCode, 'FR');
    });

    test('national digits equal to the dial code are kept', () {
      // intl_phone_field stripped "60" from +60 60123456.
      final v = PhoneValue.parse('+60 12 345 6789');
      expect(v.country.isoCode, 'MY');
      expect(v.nationalNumber, '123456789');
      final w = PhoneValue.parse('+6060123456');
      expect(w.country.isoCode, 'MY');
      expect(w.nationalNumber, '60123456');
    });

    test('Arabic-Indic digits', () {
      final v = PhoneValue.parse('+٢١٣٥٥٥١٢٣٤٥٦');
      expect(v.country.isoCode, 'DZ');
      expect(v.nationalNumber, '555123456');
      final w = PhoneValue.parse('۰۵۵۵۱۲۳۴۵۶', country: 'DZ');
      expect(w.nationalNumber, '555123456');
    });

    test('empty input', () {
      final v = PhoneValue.parse('', country: 'FR');
      expect(v.country.isoCode, 'FR');
      expect(v.isEmpty, isTrue);
      expect(v.e164, '');
      expect(v.isValid, isFalse);
    });

    test('isValidFor checks per-type rules', () {
      final v = PhoneValue.parse('+21321123456');
      expect(v.isValidFor(PhoneType.fixedLine), isTrue);
      expect(v.isValidFor(PhoneType.mobile), isFalse);
      final us = PhoneValue.parse('+12015550123');
      expect(us.isValidFor(PhoneType.mobile), isTrue);
    });

    test('equality and toString', () {
      expect(PhoneValue.parse('+213555123456'),
          PhoneValue.parse('0555123456', country: 'DZ'));
      expect(PhoneValue.parse('+213555123456').toString(),
          contains('+213555123456'));
    });
  });
}
