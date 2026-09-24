import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

List<String> isoOf(Iterable<PhoneCountry> list) =>
    list.map((c) => c.isoCode).toList();

void main() {
  final all = PhoneCountries.all;

  group('foldForSearch', () {
    test('removes Latin accents and case', () {
      expect(foldForSearch('Algérie'), 'algerie');
      expect(foldForSearch('Côte d’Ivoire'), "cote d'ivoire");
      expect(foldForSearch('ÅLAND'), 'aland');
      expect(foldForSearch('Œ ß'), 'oe ss');
    });

    test('removes Arabic harakat and folds letter forms', () {
      expect(foldForSearch('الجَزَائِر'), 'الجزاير');
      expect(foldForSearch('إسبانيا'), 'اسبانيا');
      expect(foldForSearch('مصرـــ'), 'مصر');
    });
  });

  group('searchCountries', () {
    test('English name', () {
      expect(isoOf(searchCountries(all, 'alger')), contains('DZ'));
    });

    test('French name, with or without accents', () {
      expect(isoOf(searchCountries(all, 'Algérie')), contains('DZ'));
      expect(isoOf(searchCountries(all, 'algerie')), contains('DZ'));
      expect(isoOf(searchCountries(all, 'Allemagne')), ['DE']);
    });

    test('Arabic name, with or without harakat', () {
      expect(isoOf(searchCountries(all, 'الجزائر')), contains('DZ'));
      expect(isoOf(searchCountries(all, 'الجَزائِر')), contains('DZ'));
      expect(isoOf(searchCountries(all, 'ألمانيا')), ['DE']);
    });

    test('dial code with or without plus', () {
      expect(isoOf(searchCountries(all, '+213')), ['DZ']);
      expect(isoOf(searchCountries(all, '213')), ['DZ']);
      expect(isoOf(searchCountries(all, '+٢١٣')), ['DZ']);
      expect(isoOf(searchCountries(all, '+7')), unorderedEquals(['RU', 'KZ']));
    });

    test('ISO code', () {
      expect(isoOf(searchCountries(all, 'dz')), contains('DZ'));
    });

    test('CLDR alternative names', () {
      expect(isoOf(searchCountries(all, 'Ivory Coast')), ['CI']);
      expect(isoOf(searchCountries(all, 'Czech Republic')), ['CZ']);
    });

    test('empty query returns everything', () {
      expect(searchCountries(all, '  '), hasLength(all.length));
    });

    test('prefix matches rank first', () {
      final r = isoOf(searchCountries(all, 'ger'));
      expect(r.first, 'DE');
      expect(r, contains('DZ'));
    });
  });
}
