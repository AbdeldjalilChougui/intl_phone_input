import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

import 'digits.dart';
import 'metadata_bridge.dart';
import 'phone_country.dart';
import 'phone_type.dart';

/// A phone number: a [country] and its [nationalNumber].
///
/// Validation and formatting use the libphonenumber metadata shipped in
/// `phone_numbers_parser`.
class PhoneValue {
  /// Creates a value from a country and a national significant number
  /// (digits only, without trunk prefix).
  const PhoneValue({required this.country, required this.nationalNumber});

  /// Parses [input].
  ///
  /// An input that starts with `+` or `00` is read as international, and
  /// its country comes from the dial code (shared codes such as +1 and +7
  /// are told apart by their leading digits). Any other input is read as a
  /// national number of [country] (an ISO code or a dial code; `US` when
  /// null or unknown), with an optional trunk prefix. Arabic-Indic and
  /// Persian digits are accepted.
  factory PhoneValue.parse(String input, {String? country}) {
    final fallback =
        (country == null ? null : PhoneCountries.resolve(country)) ??
            PhoneCountries.byIso('US')!;
    final normalized = normalizeDigits(input).trim();
    final digits = digitsOnly(normalized);
    if (digits.isEmpty) {
      return PhoneValue(country: fallback, nationalNumber: '');
    }
    final international = normalized.startsWith('+')
        ? digits
        : digits.startsWith('00')
            ? digits.substring(2)
            : null;
    if (international != null) {
      final parsed = parseInternational(international);
      if (parsed != null) return parsed;
      return PhoneValue(country: fallback, nationalNumber: digits);
    }
    return PhoneValue(
      country: fallback,
      nationalNumber: nationalSignificantNumber(fallback, digits),
    );
  }

  /// Reads [digits] (dial code followed by the national number, no `+`),
  /// or returns null when no dial code matches.
  static PhoneValue? parseInternational(String digits) {
    try {
      final p = pnp.PhoneNumber.parse('+$digits');
      final country = PhoneCountries.byIso(p.isoCode.name)!;
      if (!digits.startsWith(country.dialCode)) return null;
      return PhoneValue(
        country: country,
        nationalNumber: digits.substring(country.dialCode.length),
      );
    } on pnp.PhoneNumberException {
      return null;
    }
  }

  /// Strips the trunk prefix from national [digits] of [country] when the
  /// metadata says so.
  static String nationalSignificantNumber(PhoneCountry country, String digits) {
    if (digits.isEmpty) return digits;
    try {
      final p = pnp.PhoneNumber.parse(
        digits,
        callerCountry: country.parserIsoCode,
        destinationCountry: country.parserIsoCode,
      );
      if (p.isValid()) return p.nsn;
    } on pnp.PhoneNumberException {
      // Fall through to the trunk prefix rule.
    }
    final np = country.nationalPrefix;
    if (np != null && digits.startsWith(np)) {
      return digits.substring(np.length);
    }
    return digits;
  }

  /// The country the number belongs to.
  final PhoneCountry country;

  /// National significant number: digits only, no trunk prefix.
  final String nationalNumber;

  pnp.PhoneNumber get _parser =>
      pnp.PhoneNumber(isoCode: country.parserIsoCode, nsn: nationalNumber);

  /// Whether there is no national number.
  bool get isEmpty => nationalNumber.isEmpty;

  /// E.164 form, such as `+213555123456`, or an empty string when empty.
  String get e164 => isEmpty ? '' : '+${country.dialCode}$nationalNumber';

  /// Whether the number has a valid length and matches a number pattern of
  /// its country.
  bool get isValid => !isEmpty && _parser.isValid();

  /// Whether the length is possible for the country, any type.
  bool get isValidLength => !isEmpty && _parser.isValidLength();

  /// Whether the number is valid as [type]. [PhoneType.fixedLineOrMobile]
  /// accepts either.
  bool isValidFor(PhoneType type) {
    if (isEmpty) return false;
    if (type == PhoneType.fixedLineOrMobile) {
      return isValidFor(PhoneType.mobile) || isValidFor(PhoneType.fixedLine);
    }
    return _parser.isValid(type: type.parserType);
  }

  /// The number's type, or null when the number is not valid.
  PhoneType? get numberType {
    if (!isValid) return null;
    final mobile = isValidFor(PhoneType.mobile);
    final fixed = isValidFor(PhoneType.fixedLine);
    if (mobile && fixed) return PhoneType.fixedLineOrMobile;
    if (mobile) return PhoneType.mobile;
    if (fixed) return PhoneType.fixedLine;
    for (final t in PhoneType.values) {
      if (t.parserType != null && isValidFor(t)) return t;
    }
    return null;
  }

  /// National format, with the trunk prefix where the country uses one in
  /// writing, such as `0555 12 34 56`. Incomplete numbers are formatted as
  /// far as possible, without trunk prefix.
  String formatNational() {
    if (isEmpty) return '';
    final rule = _matchingRule();
    if (rule == null) return _parser.formatNsn();
    final match = RegExp('^(?:${rule.pattern})\$').firstMatch(nationalNumber)!;
    var firstGroup = match.group(1) ?? '';
    final np = country.nationalPrefix;
    final npRule = rule.nationalPrefixFormattingRule;
    if (npRule != null) {
      firstGroup =
          npRule.replaceAll(r'$NP', np ?? '').replaceAll(r'$FG', firstGroup);
    }
    return _applyFormat(rule.format, match, firstGroup);
  }

  /// International format, such as `+213 555 12 34 56`.
  String formatInternational() {
    if (isEmpty) return '';
    final nsn = _parser.formatNsn(format: pnp.NsnFormat.international);
    return '+${country.dialCode} $nsn';
  }

  FormatRule? _matchingRule() {
    for (final rule in formatRules(country.parserIsoCode)) {
      if (rule.leadingDigits.isNotEmpty &&
          RegExp(rule.leadingDigits.last).matchAsPrefix(nationalNumber) ==
              null) {
        continue;
      }
      if (RegExp('^(?:${rule.pattern})\$').hasMatch(nationalNumber)) {
        return rule;
      }
    }
    return null;
  }

  static String _applyFormat(String format, Match match, String firstGroup) {
    return format.replaceAllMapped(RegExp(r'\$(\d)'), (m) {
      final i = int.parse(m.group(1)!);
      if (i == 1) return firstGroup;
      return i <= match.groupCount ? (match.group(i) ?? '') : '';
    });
  }

  @override
  bool operator ==(Object other) =>
      other is PhoneValue &&
      other.country == country &&
      other.nationalNumber == nationalNumber;

  @override
  int get hashCode => Object.hash(country, nationalNumber);

  @override
  String toString() => 'PhoneValue(${country.isoCode}, '
      '${isEmpty ? '<empty>' : e164})';
}
