// Generates lib/src/generated/country_names.dart from the Unicode CLDR data.
//
// Source: https://github.com/unicode-org/cldr-json (package
// cldr-localenames-full, file main/<locale>/territories.json).
// License: Unicode License v3, reproduced in the generated file.
//
// Run from the package root:
//
//   dart run tool/generate_country_names.dart
//
// The set of regions comes from the phone metadata (phone_numbers_parser's
// IsoCode enum), so every region that has a dial code gets a name.
import 'dart:convert';
import 'dart:io';

import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// The cldr-json release tag the names are taken from.
const cldrTag = '48.2.2';

/// The locales bundled with the package.
const locales = ['en', 'fr', 'ar'];

Future<Map<String, String>> _fetch(HttpClient client, String locale) async {
  final uri = Uri.parse(
    'https://raw.githubusercontent.com/unicode-org/cldr-json/$cldrTag/'
    'cldr-json/cldr-localenames-full/main/$locale/territories.json',
  );
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != 200) {
    throw HttpException('HTTP ${response.statusCode}', uri: uri);
  }
  final body = await response.transform(utf8.decoder).join();
  final json = jsonDecode(body) as Map<String, dynamic>;
  final main = json['main'] as Map<String, dynamic>;
  final loc = main[locale] as Map<String, dynamic>;
  final names = loc['localeDisplayNames'] as Map<String, dynamic>;
  final territories = names['territories'] as Map<String, dynamic>;
  return territories.map((k, v) => MapEntry(k, v as String));
}

String _quote(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

Future<void> main() async {
  final client = HttpClient();
  final data = <String, Map<String, String>>{};
  try {
    for (final locale in locales) {
      data[locale] = await _fetch(client, locale);
    }
  } finally {
    client.close();
  }
  final license = await _fetchLicense();

  final regions = IsoCode.values.map((c) => c.name).toList()..sort();
  final out = StringBuffer()
    ..writeln('// GENERATED FILE, DO NOT EDIT BY HAND.')
    ..writeln('// Regenerate with: dart run tool/generate_country_names.dart')
    ..writeln('//')
    ..writeln('// Country and territory names from the Unicode CLDR, cldr-json')
    ..writeln('// release $cldrTag, cldr-localenames-full/main/<locale>/')
    ..writeln('// territories.json: https://github.com/unicode-org/cldr-json')
    ..writeln('//');
  for (final line in const LineSplitter().convert(license)) {
    out.writeln(line.isEmpty ? '//' : '// $line');
  }
  out
    ..writeln()
    ..writeln('/// Country names by locale, then by ISO 3166-1 alpha-2 code.')
    ..writeln('///')
    ..writeln('/// The first name is the CLDR display name. Any further names')
    ..writeln(
        '/// are CLDR alternative forms (short or variant), used only for')
    ..writeln('/// search.')
    ..writeln(
        'const Map<String, Map<String, List<String>>> cldrCountryNames = {');
  for (final locale in locales) {
    final names = data[locale]!;
    out.writeln("  '$locale': {");
    for (final region in regions) {
      final main = names[region];
      if (main == null) {
        stderr.writeln('warning: no $locale name for $region');
        continue;
      }
      final alts = names.entries
          .where((e) => e.key.startsWith('$region-alt-'))
          .map((e) => e.value)
          .where((v) => v != main)
          .toSet();
      final all = [main, ...alts].map(_quote).join(', ');
      out.writeln("    '$region': [$all],");
    }
    out.writeln('  },');
  }
  out.writeln('};');

  final file = File('lib/src/generated/country_names.dart');
  await file.parent.create(recursive: true);
  await file.writeAsString(out.toString());
  stdout.writeln('Wrote ${file.path} (${regions.length} regions).');
}

Future<String> _fetchLicense() async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(
      'https://raw.githubusercontent.com/unicode-org/cldr-json/$cldrTag/LICENSE',
    );
    final response = await (await client.getUrl(uri)).close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: uri);
    }
    return (await response.transform(utf8.decoder).join()).trim();
  } finally {
    client.close();
  }
}
