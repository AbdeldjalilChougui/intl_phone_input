import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

PhoneCountry c(String iso) => PhoneCountries.byIso(iso)!;

TextEditingValue v(String text, [int? cursor]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );

/// Types [chars] one by one at the end, as a keyboard would.
PhoneEditResult typeAll(PhoneEditor editor, PhoneCountry country, String chars,
    {String start = ''}) {
  var value = v(start);
  var current = country;
  late PhoneEditResult result;
  for (final ch in chars.split('')) {
    final text = value.text;
    final at = value.selection.baseOffset;
    final next = v(text.substring(0, at) + ch + text.substring(at), at + 1);
    result = editor.apply(current, value, next);
    value = result.value;
    current = result.country;
  }
  return result;
}

void main() {
  final editor = PhoneEditor();

  group('as-you-type formatting', () {
    test('DZ mobile', () {
      final r = typeAll(editor, c('DZ'), '555123456');
      expect(r.value.text, '555 12 34 56');
      expect(r.value.selection.baseOffset, r.value.text.length);
      expect(r.country.isoCode, 'DZ');
    });

    test('DZ with trunk prefix keeps the 0 visible', () {
      final r = typeAll(editor, c('DZ'), '0555123456');
      expect(r.value.text, '0555 12 34 56');
    });

    test('FR', () {
      expect(typeAll(editor, c('FR'), '612345678').value.text, '6 12 34 56 78');
      expect(
          typeAll(editor, c('FR'), '0612345678').value.text, '06 12 34 56 78');
    });

    test('US', () {
      expect(
          typeAll(editor, c('US'), '2015550123').value.text, '(201) 555-0123');
    });

    test('GB', () {
      expect(typeAll(editor, c('GB'), '7400123456').value.text, '7400 123456');
    });

    test('RU', () {
      expect(
          typeAll(editor, c('RU'), '9123456789').value.text, '912 345-67-89');
    });

    test('non-digits are dropped', () {
      final r = editor.apply(c('DZ'), v(''), v('5a5-5'));
      expect(r.value.text, '555');
    });
  });

  group('cursor position', () {
    test('inserting in the middle keeps the cursor after the new digit', () {
      // "555 12 34 5" with the cursor after "555 1" (offset 5), type 9.
      const old = '555 12 34 5';
      final next = v('555 192 34 5', 6);
      final r = editor.apply(c('DZ'), v(old, 5), next);
      expect(r.value.text, '555 19 23 45');
      // Cursor sits right after the inserted 9.
      expect(r.value.text.substring(0, r.value.selection.baseOffset), '555 19');
    });

    test('deleting a digit in the middle keeps the cursor in place', () {
      const old = '555 12 34 56';
      // Delete the "1" at offset 4.
      final r = editor.apply(c('DZ'), v(old, 5), v('555 2 34 56', 4));
      expect(r.value.text, '555 23 45 6');
      // Right after the third digit.
      expect(r.value.selection.baseOffset, 3);
    });

    test('backspace over a separator deletes the digit before it', () {
      const old = '555 12';
      // Cursor after the space (offset 4); backspace removes the space.
      final r = editor.apply(c('DZ'), v(old, 4), v('55512', 3));
      expect(r.value.text, '551 2');
      expect(r.value.selection.baseOffset, 2);
    });

    test('US: typing after a closing parenthesis', () {
      final r = typeAll(editor, c('US'), '2015');
      expect(r.value.text, '(201) 5');
      expect(r.value.selection.baseOffset, r.value.text.length);
    });
  });

  group('max length from metadata', () {
    test('DZ rejects a 10th national digit', () {
      final r = typeAll(editor, c('DZ'), '5551234567');
      expect(r.value.text, '555 12 34 56');
    });

    test('DZ with trunk prefix allows 10 digits', () {
      final r = typeAll(editor, c('DZ'), '05551234567');
      expect(r.value.text, '0555 12 34 56');
    });

    test('DJ allows 8 digits', () {
      expect(
          typeAll(editor, c('DJ'), '77831001')
              .value
              .text
              .replaceAll(RegExp(r'\D'), ''),
          '77831001');
    });

    test('limit can be switched off', () {
      final r =
          typeAll(PhoneEditor(enforceMaxLength: false), c('DZ'), '5551234567');
      expect(r.value.text.replaceAll(RegExp(r'\D'), ''), '5551234567');
    });

    test('an overlong paste starting with the dial code drops it', () {
      final r = editor.apply(c('DZ'), v(''), v('213555123456'));
      expect(r.value.text, '555 12 34 56');
      expect(r.country.isoCode, 'DZ');
    });
  });

  group('paste detection', () {
    test('+213 switches to DZ', () {
      final r = editor.apply(c('US'), v(''), v('+213 555 12 34 56'));
      expect(r.country.isoCode, 'DZ');
      expect(r.countryDetected, isTrue);
      expect(r.value.text, '555 12 34 56');
      expect(r.value.selection.baseOffset, r.value.text.length);
    });

    test('leading 00 switches too', () {
      final r = editor.apply(c('US'), v(''), v('00213555123456'));
      expect(r.country.isoCode, 'DZ');
      expect(r.value.text, '555 12 34 56');
    });

    test('paste replaces an existing number', () {
      final r = editor.apply(c('FR'), v('6 12'), v('+44 7400 123456'));
      expect(r.country.isoCode, 'GB');
      expect(r.value.text, '7400 123456');
    });

    test('+1 disambiguates US and CA', () {
      expect(editor.apply(c('FR'), v(''), v('+1 204 234 5678')).country.isoCode,
          'CA');
      expect(editor.apply(c('FR'), v(''), v('+1 201 555 0123')).country.isoCode,
          'US');
    });

    test('+7 disambiguates RU and KZ', () {
      expect(editor.apply(c('FR'), v(''), v('+7 701 234 5678')).country.isoCode,
          'KZ');
      expect(editor.apply(c('FR'), v(''), v('+7 912 345 6789')).country.isoCode,
          'RU');
    });

    test('Arabic-Indic paste', () {
      final r = editor.apply(c('US'), v(''), v('+٢١٣ ٥٥٥ ١٢ ٣٤ ٥٦'));
      expect(r.country.isoCode, 'DZ');
      expect(r.value.text, '555 12 34 56');
    });

    test('typing +213 key by key switches once the code is complete', () {
      var r = editor.apply(c('US'), v(''), v('+'));
      expect(r.value.text, '+');
      expect(r.country.isoCode, 'US');
      r = editor.apply(r.country, r.value, v('+2'));
      expect(r.value.text, '+2');
      r = editor.apply(r.country, r.value, v('+21'));
      expect(r.value.text, '+21');
      r = editor.apply(r.country, r.value, v('+213'));
      expect(r.country.isoCode, 'DZ');
      expect(r.countryDetected, isTrue);
      expect(r.value.text, '');
    });

    test('a detected country outside the allow-list is not applied', () {
      final e = PhoneEditor(allowed: [c('FR'), c('US')]);
      final r = e.apply(c('FR'), v(''), v('+213 555 12 34 56'));
      expect(r.country.isoCode, 'FR');
      expect(r.countryDetected, isFalse);
    });

    test('shared dial code picks an allowed country', () {
      final e = PhoneEditor(allowed: [c('CA'), c('FR')]);
      final r = e.apply(c('FR'), v(''), v('+1 201 555 0123'));
      expect(r.country.isoCode, 'CA');
    });
  });

  group('shared dial code refinement', () {
    test('US becomes CA once a Canadian number is complete', () {
      final r = editor.apply(c('US'), v('204 234 567'), v('2042345678'),
          refineSharedDialCode: true);
      expect(r.country.isoCode, 'CA');
      expect(r.countryDetected, isTrue);
      expect(r.value.text, '(204) 234-5678');
    });

    test('RU becomes KZ', () {
      final r = editor.apply(c('RU'), v(''), v('7012345678'),
          refineSharedDialCode: true);
      expect(r.country.isoCode, 'KZ');
    });

    test('no refinement unless asked', () {
      final r = editor.apply(c('US'), v(''), v('2042345678'));
      expect(r.country.isoCode, 'US');
      expect(r.countryDetected, isFalse);
    });
  });

  group('Arabic-Indic typing', () {
    test('digits are converted as they are typed', () {
      final r = typeAll(editor, c('DZ'), '٥٥٥١٢٣٤٥٦');
      expect(r.value.text, '555 12 34 56');
    });

    test('Persian digits too', () {
      final r = typeAll(editor, c('DZ'), '۰۵۵۵');
      expect(r.value.text, '0555');
    });
  });

  group('formatDigits', () {
    test('reformats digits for another country', () {
      expect(editor.formatDigits(c('FR'), '612345678'), '6 12 34 56 78');
      expect(editor.formatDigits(c('DZ'), ''), '');
    });
  });
}
