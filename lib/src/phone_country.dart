import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

import 'digits.dart';
import 'generated/country_names.dart';
import 'metadata_bridge.dart';
import 'phone_type.dart';

/// A region that has its own phone numbering metadata.
///
/// ISO code, dial code, trunk prefix and lengths come from the
/// libphonenumber metadata shipped in `phone_numbers_parser`. Names come
/// from the Unicode CLDR (English, French and Arabic).
class PhoneCountry {
  PhoneCountry._(this.parserIsoCode)
      : isoCode = parserIsoCode.name,
        _meta = regionMetadata(parserIsoCode);

  /// The ISO code as used by `phone_numbers_parser`.
  final pnp.IsoCode parserIsoCode;

  /// ISO 3166-1 alpha-2 code, such as `DZ`.
  final String isoCode;

  final RegionMetadata _meta;

  /// Dial code without the `+`, such as `213`.
  String get dialCode => _meta.dialCode;

  /// Trunk (national) prefix dialled before a national number, such as
  /// `0` in Algeria or `8` in Russia, or null when there is none.
  String? get nationalPrefix => _meta.nationalPrefix;

  /// Whether this region is the main one when several share [dialCode]
  /// (for example `US` for +1).
  bool get isMainForDialCode => _meta.isMainCountryForDialCode;

  /// Flag emoji built from the ISO code's regional indicator symbols.
  String get flag => String.fromCharCodes(
        isoCode.codeUnits.map((u) => 0x1F1E6 + u - 0x41),
      );

  /// English name.
  String get name => nameFor('en');

  /// Name in [languageCode] (`en`, `fr` or `ar`); other languages get the
  /// English name.
  String nameFor(String languageCode) {
    final names = cldrCountryNames[languageCode] ?? cldrCountryNames['en']!;
    return (names[isoCode] ?? cldrCountryNames['en']![isoCode] ?? [isoCode])
        .first;
  }

  /// Every bundled name and alternative name, in all languages.
  Iterable<String> get allNames sync* {
    for (final names in cldrCountryNames.values) {
      yield* names[isoCode] ?? const <String>[];
    }
  }

  final Map<PhoneType?, List<int>> _lengths = {};

  /// Possible national number lengths for [type], or for any type when
  /// [type] is null. Empty when the region has no numbers of that type.
  List<int> possibleLengths([PhoneType? type]) {
    return _lengths.putIfAbsent(type, () {
      if (type == PhoneType.fixedLineOrMobile) {
        return {
          ...possibleLengths(PhoneType.mobile),
          ...possibleLengths(PhoneType.fixedLine),
        }.toList()
          ..sort();
      }
      return [
        for (var n = 1; n <= 17; n++)
          if (pnp.PhoneNumber(isoCode: parserIsoCode, nsn: '0' * n)
              .isValidLength(type: type?.parserType))
            n,
      ];
    });
  }

  /// Shortest valid national number length, any type.
  int get minLength => possibleLengths().first;

  /// Longest valid national number length, any type.
  int get maxLength => possibleLengths().last;

  @override
  bool operator ==(Object other) =>
      other is PhoneCountry && other.isoCode == isoCode;

  @override
  int get hashCode => isoCode.hashCode;

  @override
  String toString() => 'PhoneCountry($isoCode, +$dialCode)';
}

/// Lookup of every [PhoneCountry].
abstract final class PhoneCountries {
  static final List<PhoneCountry> _all = [
    for (final iso in pnp.IsoCode.values) PhoneCountry._(iso),
  ];

  static final Map<String, PhoneCountry> _byIso = {
    for (final c in _all) c.isoCode: c,
  };

  /// Every region, sorted by ISO code.
  static List<PhoneCountry> get all => List.unmodifiable(_all);

  /// The region with ISO code [isoCode] (any case), or null.
  static PhoneCountry? byIso(String isoCode) =>
      _byIso[isoCode.trim().toUpperCase()];

  /// Regions that use [dialCode] (with or without `+`).
  static List<PhoneCountry> byDialCode(String dialCode) {
    final code = digitsOnly(dialCode);
    return [
      for (final c in _all)
        if (c.dialCode == code) c,
    ];
  }

  /// The main region for [dialCode], or the only one, or null.
  static PhoneCountry? mainForDialCode(String dialCode) {
    final list = byDialCode(dialCode);
    if (list.isEmpty) return null;
    return list.firstWhere((c) => c.isMainForDialCode,
        orElse: () => list.first);
  }

  /// Resolves an ISO code (`IN`) or a dial code (`+91` or `91`).
  static PhoneCountry? resolve(String code) {
    final trimmed = normalizeDigits(code.trim());
    if (RegExp(r'^\+?[0-9]{1,4}$').hasMatch(trimmed)) {
      return mainForDialCode(trimmed);
    }
    return byIso(trimmed);
  }
}
