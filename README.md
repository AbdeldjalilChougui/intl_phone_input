# intl_phone_input

A phone number field for Flutter with a country picker. It formats the number
as the user types, detects pasted international numbers, and validates against
libphonenumber metadata. A maintained replacement for `intl_phone_field`.

[![pub package](https://img.shields.io/pub/v/intl_phone_input.svg)](https://pub.dev/packages/intl_phone_input)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- **`IntlPhoneInput`** wraps a `TextFormField`, so it works in a `Form`, with
  `validate()`, `save()`, a `controller`, a `focusNode` and autofill
  (`AutofillHints.telephoneNumber`).
- **Formats as you type** (`555 12 34 56`, `(201) 555-0123`,
  `7400 123456`). After every insert, delete or paste the cursor stays next
  to the same digit. A backspace over a separator deletes the digit before
  it.
- **Paste detection**. Pasting `+213 555 12 34 56` or `00213555123456`
  switches the country to Algeria and keeps `555 12 34 56`. Typing `+213`
  key by key does the same.
- **Shared dial codes**. `+1` (US, CA, PR, JM, ...), `+7` (RU, KZ), `+44`
  (GB, GG, JE, IM) and the others are told apart by their leading digits.
- **Real lengths and patterns**. The field refuses digits beyond the
  country's longest number, and the validator checks the number against the
  libphonenumber length and pattern for each type. You can accept only some
  types, for example mobile numbers.
- **`PhoneValue`** holds the country, the national number, `e164`,
  `isValid`, `numberType` (`mobile`, `fixedLine`, `fixedLineOrMobile`,
  `tollFree`, ...), `formatNational()` (`0555 12 34 56`) and
  `formatInternational()` (`+213 555 12 34 56`).
- **Searchable country picker**, as a dialog or a bottom sheet. Search
  matches English, French and Arabic names, ignoring case, accents and
  harakat, and also matches CLDR alternative names (`Ivory Coast`, `Czech
  Republic`), ISO codes and dial codes (`+213`, `213`, `+٢١٣`). You can pin
  favorites at the top and restrict the list with an allow-list.
- **Arabic-Indic and Persian digits** (`٠٥٥٥`, `۰۵۵۵`) are accepted and
  converted to ASCII.
- **RTL**. In a right-to-left app the country button moves to the right,
  while the number itself stays left-to-right.
- **Localized** built-in texts and country names in English, French and
  Arabic, picked from the app locale. You can pass your own
  `PhoneInputStrings` to change them.
- **Semantics labels** on the country button ("Change country. Current:
  Algeria +213"), the picker rows ("France +33") and the picker route.

## Install

```yaml
dependencies:
  intl_phone_input: ^0.1.0
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          IntlPhoneInput(
            initialCountryCode: 'DZ',
            favorites: const ['DZ', 'FR', 'MA', 'TN'],
            decoration: const InputDecoration(labelText: 'Phone'),
            allowedTypes: const {PhoneType.mobile},
            validator: (value) => value.isEmpty ? 'Required' : null,
            onChanged: (value) => debugPrint(value.e164),
            onSaved: (value) => debugPrint('saved ${value.e164}'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
```

Without a widget:

```dart
final value = PhoneValue.parse('+213 555 12 34 56');
value.country.isoCode;       // 'DZ'
value.nationalNumber;        // '555123456'
value.e164;                  // '+213555123456'
value.isValid;               // true
value.numberType;            // PhoneType.mobile
value.formatNational();      // '0555 12 34 56'
value.formatInternational(); // '+213 555 12 34 56'

PhoneValue.parse('06 12 34 56 78', country: 'FR').e164; // '+33612345678'
PhoneValue.parse('+7 701 234 5678').country.isoCode;     // 'KZ'
```

To open the picker yourself, call `showCountryPickerDialog` or
`showCountryPickerSheet`. You can also embed `CountryPickerList`.

The built-in texts follow `Localizations.localeOf(context)`. To use the French
and Arabic texts, add `flutter_localizations` and list the locales in your
`MaterialApp`, as the example app does.

## Migrating from intl_phone_field

Most code only needs new names:

| intl_phone_field | intl_phone_input | Notes |
| --- | --- | --- |
| `IntlPhoneField(...)` | `IntlPhoneInput(...)` | |
| `PhoneNumber` | `PhoneValue` | `completeNumber` becomes `e164`, `number` becomes `nationalNumber` (digits only, no trunk prefix), `countryISOCode` becomes `country.isoCode`, `countryCode` becomes `'+${country.dialCode}'`. |
| `phone.isValidNumber()` (throws) | `value.isValid` (bool) | Also `isValidLength`, `isValidFor(PhoneType.mobile)` and `numberType`. |
| `PhoneNumber.fromCompleteNumber(completeNumber: s)` | `PhoneValue.parse(s)` | Also accepts `00` numbers and national numbers with `country:`. |
| `Country` | `PhoneCountry` | `code` becomes `isoCode`, and `dialCode` is the same. `name` is the English CLDR name, and `nameFor('fr')` gives the French one. `minLength`/`maxLength` now come from libphonenumber. |
| `countries: [Country, ...]` | `countries: ['DZ', 'FR']` | ISO codes. A new `favorites` list pins countries at the top. |
| `initialCountryCode: 'IN'` or `'+91'` | same | Dial codes now work (issue #412). |
| `initialValue` | same | `+`, `00` and national forms are all parsed. |
| `validator: (PhoneNumber?) => FutureOr<String?>` | `validator: (PhoneValue) => String?` | Synchronous. It runs on `Form.validate()` and receives empty values too, so it can report a required field. |
| `invalidNumberMessage` | same | Localized by default (en, fr, ar). |
| `disableLengthCheck` | same | Also disables the built-in validity check, as before. |
| `languageCode: 'fr'` | removed | The picker follows the app locale. You can also pass `strings: PhoneInputStrings.fr`. |
| `searchText` | `pickerDialogStyle.searchFieldInputDecoration.hintText` or `strings` | |
| `pickerDialogStyle: PickerDialogStyle(...)` | same | Adds `searchFieldTextStyle` (issue #378). |
| `dropdownIconPosition: IconPosition.leading` | same | |
| `dropdownIcon`, `showDropdownIcon`, `dropdownTextStyle`, `showCountryFlag`, `flagsButtonPadding`, `flagsButtonMargin` | same | |
| `controller`, `focusNode`, `enabled`, `readOnly`, `autofocus`, `textInputAction`, `keyboardType`, `inputFormatters`, `cursorColor`, `textAlign`, `autovalidateMode`, `onSaved`, `onSubmitted`, `onTap` | same | |
| `disableAutoFillHints: true` | `autofillHints: null` | The default hint is `telephoneNumber`. |
| `dropdownDecoration`, `obscureText`, `cursorHeight`, `cursorRadius`, `cursorWidth`, `showCursor`, `keyboardAppearance`, `textAlignVertical` | not supported | Wrap in a `Theme` or open an issue. |
| no equivalent | `pickerMode: CountryPickerMode.bottomSheet` | Opens the picker as a bottom sheet (issue #373). |
| no equivalent | `allowedTypes: {PhoneType.mobile}` | Accepts only these number types. |

Behaviour changes to check:

- The text field shows the **formatted** national number (`555 12 34 56`).
  If you read `controller.text`, use `PhoneValue` or `digitsOnly()` instead.
- `onChanged` also fires when the country changes, because the value
  changed.
- A trunk prefix the user types stays visible (`0555 12 34 56`) and is
  removed in `PhoneValue.nationalNumber`.

### Issues addressed

These open intl_phone_field issues each have a test:

- Wrong dial codes and lengths (Italy +39 #297, Djibouti #323, Madagascar
  #382). Dial codes and lengths now come from libphonenumber instead of a
  hand-written table.
- The UK number was validated as Guernsey (#424). `+44` numbers now resolve by
  leading digits, and a number is validated against the selected country.
- Cursor jumps while editing. The cursor is placed by digit count after each
  edit.
- `initialValue` with a leading `+` was not parsed when `initialCountryCode`
  was set. The international number now wins.
- A national number that starts with the same digits as the dial code was cut
  short (#420, `+60 60123456`).
- The validator did not run on submit (#328, #356, #401) or when the field was
  empty (#435), and it did not re-run after a country change. It is now a
  plain `FormField` validator, and it re-runs when the country changes.
- A crash when `countries` did not include the initial country. The first
  allowed country is used instead.
- `readOnly` still opened the picker (#442).
- `initialCountryCode: '+91'` was ignored (#412, #377, #393).

## Limitations

- The dependency is pinned to `phone_numbers_parser` `>=9.0.26 <9.1.0`. That
  package only exports parsing, formatting and validation. The trunk prefix
  and the national formatting rules are read from its generated metadata,
  which lives in one file, `lib/src/metadata_bridge.dart`.
- Formatting while typing uses the metadata's format rules on the digits typed
  so far. It is close to libphonenumber's `AsYouTypeFormatter`, but it is not
  a port of it, so a few countries may group incomplete numbers differently.
- A number is taken as international only when it starts with `+` or `00`.
  Other exit codes, such as `011` from North America, are read as national
  digits.
- `formatNational()` adds the trunk prefix only when the metadata has a
  national prefix formatting rule for that number's format. Otherwise it
  returns the grouped national number without a prefix.
- Flags are emoji (regional indicator symbols). Windows desktop and some web
  fonts show them as two letters.
- Bundled country names and strings are in English, French and Arabic. Other
  locales get English names unless you pass your own `PhoneInputStrings`.

## Data sources

- **Phone metadata** (regions, dial codes, trunk prefixes, lengths, patterns,
  formats) comes from Google's
  [libphonenumber](https://github.com/google/libphonenumber) (Apache 2.0), as
  packaged in [`phone_numbers_parser`](https://pub.dev/packages/phone_numbers_parser)
  (MIT). It is a runtime dependency, not a copy.
- **Country names** in English, French and Arabic, and their alternative forms,
  come from the [Unicode CLDR](https://cldr.unicode.org/) data in
  [unicode-org/cldr-json](https://github.com/unicode-org/cldr-json), release
  48.2.2, `cldr-localenames-full/main/{en,fr,ar}/territories.json`. The license
  is the Unicode License v3, and its full text is at the top of
  `lib/src/generated/country_names.dart`. That file is generated by
  `dart run tool/generate_country_names.dart`.

## License

MIT. See [LICENSE](LICENSE). The bundled CLDR data is under the Unicode
License v3, as described above.

Made by [Abdeldjalil Chougui](https://abdeldjalilchougui.biz/).
