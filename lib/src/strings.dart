import 'package:flutter/widgets.dart';

/// The built-in texts of the phone field and the country picker.
///
/// English, French and Arabic are bundled and picked from the ambient
/// [Locale]; other languages get English. Pass your own instance to
/// `IntlPhoneInput.strings` to translate or reword them.
class PhoneInputStrings {
  /// Creates a set of strings.
  const PhoneInputStrings({
    required this.languageCode,
    required this.searchHint,
    required this.invalidNumber,
    required this.noResults,
    required this.pickerTitle,
    required this.changeCountryLabel,
  });

  /// Language used for country names (`en`, `fr` or `ar`).
  final String languageCode;

  /// Hint of the picker search field.
  final String searchHint;

  /// Default validation error.
  final String invalidNumber;

  /// Shown when the search matches no country.
  final String noResults;

  /// Title of the picker.
  final String pickerTitle;

  /// Semantics label of the country button. `{country}` and `{dialCode}`
  /// are replaced.
  final String changeCountryLabel;

  /// English.
  static const en = PhoneInputStrings(
    languageCode: 'en',
    searchHint: 'Search country or dial code',
    invalidNumber: 'Invalid phone number',
    noResults: 'No country found',
    pickerTitle: 'Select a country',
    changeCountryLabel: 'Change country. Current: {country} {dialCode}',
  );

  /// French.
  static const fr = PhoneInputStrings(
    languageCode: 'fr',
    searchHint: 'Rechercher un pays ou un indicatif',
    invalidNumber: 'Numéro de téléphone invalide',
    noResults: 'Aucun pays trouvé',
    pickerTitle: 'Choisir un pays',
    changeCountryLabel: 'Changer de pays. Actuel : {country} {dialCode}',
  );

  /// Arabic.
  static const ar = PhoneInputStrings(
    languageCode: 'ar',
    searchHint: 'ابحث عن دولة أو رمز الاتصال',
    invalidNumber: 'رقم الهاتف غير صالح',
    noResults: 'لم يتم العثور على أي دولة',
    pickerTitle: 'اختر دولة',
    changeCountryLabel: 'تغيير الدولة. الحالية: {country} {dialCode}',
  );

  /// The bundled strings for [locale], English when not bundled.
  static PhoneInputStrings forLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'fr' => fr,
        'ar' => ar,
        _ => en,
      };

  /// The bundled strings for the ambient locale.
  static PhoneInputStrings of(BuildContext context) =>
      forLocale(Localizations.maybeLocaleOf(context));

  /// [changeCountryLabel] filled in.
  String changeCountry(String country, String dialCode) => changeCountryLabel
      .replaceAll('{country}', country)
      .replaceAll('{dialCode}', '+$dialCode');
}
