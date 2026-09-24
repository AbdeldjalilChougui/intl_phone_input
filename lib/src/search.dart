import 'digits.dart';
import 'phone_country.dart';

const _latinFrom =
    'ÀÁÂÃÄÅĀĂĄàáâãäåāăąÇĆĈĊČçćĉċčÐĎĐðďđÈÉÊËĒĔĖĘĚèéêëēĕėęěĜĞĠĢĝğġģĤĦĥħ'
    'ÌÍÎÏĨĪĬĮİìíîïĩīĭįıĴĵĶķĹĻĽĿŁĺļľŀłÑŃŅŇñńņňÒÓÔÕÖØŌŎŐòóôõöøōŏőŔŖŘŕŗř'
    'ŚŜŞŠȘśŝşšșŢŤŦȚţťŧțÙÚÛÜŨŪŬŮŰŲùúûüũūŭůűųŴŵÝŸŶýÿŷŹŻŽźżž';
const _latinTo =
    'AAAAAAAAAaaaaaaaaaCCCCCcccccDDDdddEEEEEEEEEeeeeeeeeeGGGGggggHHhh'
    'IIIIIIIIIiiiiiiiiiJjKkLLLLLlllllNNNNnnnnOOOOOOOOOoooooooooRRRrrr'
    'SSSSSsssssTTTTttttUUUUUUUUUUuuuuuuuuuuWwYYYyyyZZZzzz';

final Map<int, String> _fold = () {
  final from = _latinFrom.runes.toList();
  final to = _latinTo.runes.toList();
  assert(from.length == to.length, 'fold tables differ in length');
  final map = <int, String>{
    for (var i = 0; i < from.length; i++) from[i]: String.fromCharCode(to[i]),
  };
  map.addAll({
    'Æ'.runes.first: 'ae', 'æ'.runes.first: 'ae', //
    'Œ'.runes.first: 'oe', 'œ'.runes.first: 'oe',
    'ß'.runes.first: 'ss', 'Þ'.runes.first: 'th', 'þ'.runes.first: 'th',
    // Apostrophes and dashes.
    0x2019: "'", 0x2018: "'", 0x02BC: "'", 0x2010: '-', 0x2011: '-',
    0x2013: '-', 0x2014: '-',
    // Arabic letter forms.
    0x0623: 'ا', 0x0625: 'ا', 0x0622: 'ا', 0x0671: 'ا', 0x0672: 'ا',
    0x0673: 'ا', 0x0649: 'ي', 0x0626: 'ي', 0x0624: 'و', 0x0629: 'ه',
    0x06CC: 'ي', 0x06A9: 'ك',
  });
  return map;
}();

bool _isArabicMark(int r) =>
    (r >= 0x0610 && r <= 0x061A) ||
    (r >= 0x064B && r <= 0x065F) ||
    r == 0x0670 ||
    r == 0x0640 || // tatweel
    (r >= 0x06D6 && r <= 0x06ED) ||
    (r >= 0x0300 && r <= 0x036F); // combining Latin accents

/// Folds [input] for accent- and case-insensitive search: removes Latin
/// accents, Arabic harakat and tatweel, unifies Arabic alef, yeh, waw and
/// teh marbuta forms, converts Arabic-Indic digits, lower-cases and
/// collapses white space.
String foldForSearch(String input) {
  final out = StringBuffer();
  for (final r in normalizeDigits(input).runes) {
    if (_isArabicMark(r)) continue;
    out.write(_fold[r] ?? String.fromCharCode(r));
  }
  return out.toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

final Map<PhoneCountry, List<String>> _index = {};

List<String> _keysOf(PhoneCountry c) =>
    _index.putIfAbsent(c, () => c.allNames.map(foldForSearch).toList());

/// Filters [countries] by [query].
///
/// A query of digits (with or without `+`) matches dial codes by prefix.
/// Any other query matches the English, French and Arabic names (and their
/// CLDR alternative names) ignoring case and diacritics, and the ISO code.
/// Names that start with the query come first; the input order is kept
/// otherwise.
List<PhoneCountry> searchCountries(
    Iterable<PhoneCountry> countries, String query) {
  final q = foldForSearch(query);
  if (q.isEmpty) return countries.toList();
  if (RegExp(r'^\+?[0-9 ]+$').hasMatch(q)) {
    final code = q.replaceAll(RegExp(r'[^0-9]'), '');
    return [
      for (final c in countries)
        if (c.dialCode.startsWith(code)) c,
    ];
  }
  final starts = <PhoneCountry>[];
  final contains = <PhoneCountry>[];
  for (final c in countries) {
    final keys = _keysOf(c);
    if (c.isoCode.toLowerCase() == q ||
        keys.any((k) => k.startsWith(q) || k.contains(' $q'))) {
      starts.add(c);
    } else if (keys.any((k) => k.contains(q))) {
      contains.add(c);
    }
  }
  return [...starts, ...contains];
}
