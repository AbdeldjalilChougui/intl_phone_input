// Reads the libphonenumber metadata bundled in phone_numbers_parser.
//
// The package only exports parsing, formatting and validation. The trunk
// prefix, the "main country" flag of shared dial codes and the national
// prefix formatting rules live in its generated metadata, which is not
// exported. This file is the only place that reaches into it, so a layout
// change in the dependency breaks one file, and test/unit/country_test.dart
// catches it. The dependency is pinned to a minor version for that reason.
// ignore_for_file: implementation_imports

import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:phone_numbers_parser/src/metadata/generated/metadata_by_iso_code.dart';
import 'package:phone_numbers_parser/src/metadata/generated/metadata_formats_by_iso_code.dart';
import 'package:phone_numbers_parser/src/metadata/models/phone_metadata_formats.dart';

/// Raw metadata for one region.
class RegionMetadata {
  /// Creates the record.
  const RegionMetadata({
    required this.dialCode,
    required this.nationalPrefix,
    required this.isMainCountryForDialCode,
  });

  /// Dial code without `+`.
  final String dialCode;

  /// Trunk prefix, such as `0` or `8`, or null.
  final String? nationalPrefix;

  /// Whether this region is the main one of a shared dial code.
  final bool isMainCountryForDialCode;
}

/// One number format rule.
class FormatRule {
  /// Creates the rule.
  const FormatRule({
    required this.pattern,
    required this.leadingDigits,
    required this.format,
    required this.intlFormat,
    required this.nationalPrefixFormattingRule,
  });

  /// Pattern the whole national number must match.
  final String pattern;

  /// Leading-digit patterns; the last one is the most specific.
  final List<String> leadingDigits;

  /// National format, such as `$1 $2 $3`.
  final String format;

  /// International format, or null to use [format].
  final String? intlFormat;

  /// Rule such as `$NP$FG` for the first group in national format.
  final String? nationalPrefixFormattingRule;
}

/// Returns the metadata for [iso].
RegionMetadata regionMetadata(IsoCode iso) {
  final m = metadataByIsoCode[iso]!;
  return RegionMetadata(
    dialCode: m.countryCode,
    nationalPrefix: m.nationalPrefix,
    isMainCountryForDialCode: m.isMainCountryForDialCode,
  );
}

/// Returns the format rules for [iso], following references.
List<FormatRule> formatRules(IsoCode iso) {
  var def = metadataFormatsByIsoCode[iso];
  if (def is PhoneMetadataFormatReferenceDefinition) {
    def = metadataFormatsByIsoCode[def.referenceIsoCode];
  }
  if (def is! PhoneMetadataFormatListDefinition) return const [];
  return [
    for (final f in def.formats)
      FormatRule(
        pattern: f.pattern,
        leadingDigits: f.leadingDigits,
        format: f.format,
        intlFormat: f.intlFormat,
        nationalPrefixFormattingRule: f.nationalPrefixFormattingRule,
      ),
  ];
}
