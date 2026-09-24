import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

void main() => runApp(const ExampleApp());

/// Demo app: switch the language to see French and Arabic (RTL).
class ExampleApp extends StatefulWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  Locale _locale = const Locale('en');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'intl_phone_input',
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: DemoPage(
        locale: _locale,
        onLocale: (l) => setState(() => _locale = l),
      ),
    );
  }
}

/// The demo form.
class DemoPage extends StatefulWidget {
  /// Creates the page.
  const DemoPage({super.key, required this.locale, required this.onLocale});

  /// Current locale.
  final Locale locale;

  /// Called to switch locale.
  final ValueChanged<Locale> onLocale;

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _formKey = GlobalKey<FormState>();
  PhoneValue? _value;
  String _saved = '';

  @override
  Widget build(BuildContext context) {
    final v = _value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('intl_phone_input'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('EN')),
              ButtonSegment(value: 'fr', label: Text('FR')),
              ButtonSegment(value: 'ar', label: Text('AR')),
            ],
            selected: {widget.locale.languageCode},
            onSelectionChanged: (s) => widget.onLocale(Locale(s.first)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Try pasting +213 555 12 34 56 or 0044 7400 123456.'),
            const SizedBox(height: 16),
            IntlPhoneInput(
              initialCountryCode: 'DZ',
              favorites: const ['DZ', 'FR', 'MA', 'TN'],
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              validator: (v) => v.isEmpty ? 'Required' : null,
              onChanged: (v) => setState(() => _value = v),
              onSaved: (v) => setState(() => _saved = v.e164),
            ),
            const SizedBox(height: 16),
            IntlPhoneInput(
              initialValue: '+14155550123',
              pickerMode: CountryPickerMode.bottomSheet,
              dropdownIconPosition: IconPosition.trailing,
              allowedTypes: const {PhoneType.mobile},
              invalidNumberMessage: 'Enter a mobile number',
              decoration: const InputDecoration(
                labelText: 'Mobile (bottom sheet picker)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                }
              },
              child: const Text('Validate and save'),
            ),
            const SizedBox(height: 16),
            if (v != null) ...[
              Text('Country: ${v.country.isoCode} (+${v.country.dialCode})'),
              Text('E.164: ${v.e164}'),
              Text('National: ${v.formatNational()}'),
              Text('International: ${v.formatInternational()}'),
              Text('Valid: ${v.isValid}, type: ${v.numberType?.name}'),
            ],
            if (_saved.isNotEmpty) Text('Saved: $_saved'),
          ],
        ),
      ),
    );
  }
}
