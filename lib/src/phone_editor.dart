import 'package:flutter/services.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

import 'digits.dart';
import 'phone_country.dart';
import 'phone_value.dart';

/// The outcome of [PhoneEditor.apply].
class PhoneEditResult {
  /// Creates a result.
  const PhoneEditResult({
    required this.value,
    required this.country,
    required this.countryDetected,
  });

  /// The text and selection to show.
  final TextEditingValue value;

  /// The country after the edit.
  final PhoneCountry country;

  /// Whether the country was taken from the typed or pasted input (a `+`
  /// or `00` number, or a refined shared dial code).
  final bool countryDetected;
}

/// Pure editing logic behind the phone field: as-you-type formatting,
/// cursor placement, length limits and paste detection.
///
/// The field shows the national number only; the dial code lives in the
/// country button. The editor is independent from widgets so it can be
/// unit tested.
class PhoneEditor {
  /// Creates an editor.
  ///
  /// [allowed] restricts which countries a pasted number may switch to
  /// (all when null). With [enforceMaxLength], digits beyond the longest
  /// national number of the country (plus its trunk prefix) are refused.
  PhoneEditor({Iterable<PhoneCountry>? allowed, this.enforceMaxLength = true})
      : allowed = allowed?.toSet();

  /// Countries the input may switch to, or null for all.
  final Set<PhoneCountry>? allowed;

  /// Whether to refuse digits beyond the country's maximum length.
  final bool enforceMaxLength;

  bool _isAllowed(PhoneCountry c) => allowed == null || allowed!.contains(c);

  /// Applies the edit from [oldValue] to [newValue] for [country].
  ///
  /// With [refineSharedDialCode], a country that shares its dial code
  /// (+1, +7, +44, ...) is replaced by the sibling that the leading digits
  /// point to, when there is one.
  PhoneEditResult apply(
    PhoneCountry country,
    TextEditingValue oldValue,
    TextEditingValue newValue, {
    bool refineSharedDialCode = false,
  }) {
    final newText = normalizeDigits(newValue.text);
    final compact = newText.replaceAll(RegExp(r'[^0-9+]'), '');
    if (compact.startsWith('+') || compact.startsWith('00')) {
      final intl =
          digitsOnly(compact.startsWith('+') ? compact : compact.substring(2));
      return _international(country, oldValue, compact, intl);
    }

    var cursor = newValue.selection.baseOffset;
    if (cursor < 0 || cursor > newText.length) cursor = newText.length;
    var digits = digitsOnly(newText);
    var before = digitsOnly(newText.substring(0, cursor)).length;
    final oldDigits = digitsOnly(oldValue.text);

    // Backspace or delete over a separator: remove the digit before it.
    if (digits == oldDigits &&
        newText.length < oldValue.text.length &&
        newValue.selection.isCollapsed &&
        before > 0) {
      digits = digits.substring(0, before - 1) + digits.substring(before);
      before--;
    }

    if (enforceMaxLength && digits.length > maxDigits(country, digits)) {
      final dial = country.dialCode;
      final rest = digits.startsWith(dial) ? digits.substring(dial.length) : '';
      final nsn = PhoneValue.nationalSignificantNumber(country, rest);
      if (rest.isNotEmpty &&
          PhoneValue(country: country, nationalNumber: nsn).isValid) {
        digits = rest;
        before = rest.length;
      } else {
        return PhoneEditResult(
          value: oldValue,
          country: country,
          countryDetected: false,
        );
      }
    }

    var target = country;
    var detected = false;
    if (refineSharedDialCode && digits.isNotEmpty) {
      final siblings = PhoneCountries.byDialCode(country.dialCode);
      if (siblings.length > 1) {
        final nsn = PhoneValue.nationalSignificantNumber(country, digits);
        final parsed = PhoneValue.parseInternational(country.dialCode + nsn);
        if (parsed != null &&
            parsed.country != country &&
            parsed.isValid &&
            _isAllowed(parsed.country)) {
          target = parsed.country;
          detected = true;
        }
      }
    }

    final display = formatDigits(target, digits);
    return PhoneEditResult(
      value: TextEditingValue(
        text: display,
        selection:
            TextSelection.collapsed(offset: offsetAfterDigits(display, before)),
      ),
      country: target,
      countryDetected: detected,
    );
  }

  PhoneEditResult _international(PhoneCountry country,
      TextEditingValue oldValue, String compact, String digits) {
    PhoneEditResult raw() => PhoneEditResult(
          value: TextEditingValue(
            text: compact,
            selection: TextSelection.collapsed(offset: compact.length),
          ),
          country: country,
          countryDetected: false,
        );

    String? code;
    for (var len = 1; len <= 3 && len <= digits.length; len++) {
      final candidate = digits.substring(0, len);
      if (PhoneCountries.byDialCode(candidate).isNotEmpty) {
        code = candidate;
        break;
      }
    }
    if (code == null) return raw();

    final candidates =
        PhoneCountries.byDialCode(code).where(_isAllowed).toList();
    if (candidates.isEmpty) return raw();
    PhoneCountry target;
    if (candidates.length == 1) {
      target = candidates.single;
    } else {
      final parsed = PhoneValue.parseInternational(digits);
      if (parsed != null && candidates.contains(parsed.country)) {
        target = parsed.country;
      } else if (candidates.contains(country)) {
        target = country;
      } else {
        target = candidates.firstWhere((c) => c.isMainForDialCode,
            orElse: () => candidates.first);
      }
    }

    var national = digits.substring(code.length);
    if (enforceMaxLength) {
      final max = maxDigits(target, national);
      if (national.length > max) national = national.substring(0, max);
    }
    final display = formatDigits(target, national);
    return PhoneEditResult(
      value: TextEditingValue(
        text: display,
        selection: TextSelection.collapsed(offset: display.length),
      ),
      country: target,
      countryDetected: true,
    );
  }

  /// The most national digits [country] accepts, counting a typed trunk
  /// prefix at the start of [digits].
  int maxDigits(PhoneCountry country, String digits) {
    final np = country.nationalPrefix;
    final extra = np != null && digits.startsWith(np) ? np.length : 0;
    return country.maxLength + extra;
  }

  /// Formats national [digits] (possibly starting with a trunk prefix) for
  /// display in the field. The result always holds exactly [digits].
  String formatDigits(PhoneCountry country, String digits) {
    if (digits.isEmpty) return '';
    if (PhoneValue(country: country, nationalNumber: digits).isValid) {
      return _formatNsn(country, digits);
    }
    final np = country.nationalPrefix;
    if (np != null && digits.startsWith(np) && digits.length > np.length) {
      final rest = _formatNsn(country, digits.substring(np.length));
      final joined =
          RegExp(r'^[0-9]').hasMatch(rest) ? '$np$rest' : '$np $rest';
      return digitsOnly(joined) == digits ? joined : digits;
    }
    return _formatNsn(country, digits);
  }

  String _formatNsn(PhoneCountry country, String nsn) {
    try {
      final f =
          pnp.PhoneNumber(isoCode: country.parserIsoCode, nsn: nsn).formatNsn();
      return digitsOnly(f) == nsn ? f : nsn;
    } on Object {
      return nsn;
    }
  }

  /// The offset in [text] right after its [count]-th digit.
  static int offsetAfterDigits(String text, int count) {
    if (count <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      final u = text.codeUnitAt(i);
      if (u >= 0x30 && u <= 0x39) {
        seen++;
        if (seen == count) return i + 1;
      }
    }
    return text.length;
  }
}
