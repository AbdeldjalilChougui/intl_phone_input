import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

import 'helpers.dart';

Finder tile(String iso) => find.byKey(ValueKey<String>('country-$iso'));

void main() {
  group('typing', () {
    testWidgets('formats the number key by key', (tester) async {
      final values = <PhoneValue>[];
      await pumpApp(
          tester,
          IntlPhoneInput(
            initialCountryCode: 'DZ',
            onChanged: values.add,
          ));
      await typeKeys(tester, '555123456');
      final c = editable(tester).controller;
      expect(c.text, '555 12 34 56');
      expect(c.selection.baseOffset, c.text.length);
      expect(values.last.e164, '+213555123456');
      expect(values.last.isValid, isTrue);
      expect(values.map((v) => v.nationalNumber).take(3), ['5', '55', '555']);
    });

    testWidgets('US grouping', (tester) async {
      await pumpApp(tester, const IntlPhoneInput(initialCountryCode: 'US'));
      await typeKeys(tester, '2015550123');
      expect(editable(tester).controller.text, '(201) 555-0123');
    });

    testWidgets('no cursor jump when inserting in the middle', (tester) async {
      await pumpApp(
          tester,
          const IntlPhoneInput(
              initialCountryCode: 'DZ', initialValue: '5551234'));
      final c = editable(tester).controller;
      expect(c.text, '555 12 34');
      // Put the cursor after "555 1" and type 9.
      c.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      await typeKeys(tester, '9');
      expect(c.text, '555 19 23 4');
      expect(c.text.substring(0, c.selection.baseOffset), '555 19');
      await typeKeys(tester, '8');
      expect(c.text.substring(0, c.selection.baseOffset), '555 19 8');
    });

    testWidgets('refuses digits beyond the metadata max length',
        (tester) async {
      await pumpApp(tester, const IntlPhoneInput(initialCountryCode: 'DZ'));
      await typeKeys(tester, '5551234567');
      expect(editable(tester).controller.text, '555 12 34 56');
    });

    testWidgets('disableLengthCheck lifts the limit', (tester) async {
      await pumpApp(
          tester,
          const IntlPhoneInput(
              initialCountryCode: 'DZ', disableLengthCheck: true));
      await typeKeys(tester, '5551234567');
      expect(editable(tester).controller.text.replaceAll(RegExp(r'\D'), ''),
          '5551234567');
    });

    testWidgets('accepts Arabic-Indic digits', (tester) async {
      PhoneValue? last;
      await pumpApp(tester,
          IntlPhoneInput(initialCountryCode: 'DZ', onChanged: (v) => last = v));
      await typeKeys(tester, '٠٥٥٥١٢٣٤٥٦');
      expect(editable(tester).controller.text, '0555 12 34 56');
      expect(last!.e164, '+213555123456');
    });

    testWidgets('field uses phone keyboard and autofill hint', (tester) async {
      await pumpApp(tester, const IntlPhoneInput());
      final e = editable(tester);
      expect(e.keyboardType, TextInputType.phone);
      expect(e.autofillHints, [AutofillHints.telephoneNumber]);
    });
  });

  group('paste detection', () {
    testWidgets('+213 switches to Algeria', (tester) async {
      PhoneCountry? changed;
      await pumpApp(
          tester,
          IntlPhoneInput(
            initialCountryCode: 'US',
            onCountryChanged: (c) => changed = c,
          ));
      await paste(tester, '+213 555 12 34 56');
      expect(changed?.isoCode, 'DZ');
      expect(find.text('+213'), findsOneWidget);
      expect(editable(tester).controller.text, '555 12 34 56');
    });

    testWidgets('00 prefix', (tester) async {
      await pumpApp(tester, const IntlPhoneInput(initialCountryCode: 'FR'));
      await paste(tester, '0044 7400 123456');
      expect(find.text('+44'), findsOneWidget);
      expect(editable(tester).controller.text, '7400 123456');
    });

    testWidgets('+7 pasted Kazakh number picks KZ', (tester) async {
      PhoneCountry? changed;
      await pumpApp(
          tester,
          IntlPhoneInput(
              initialCountryCode: 'FR', onCountryChanged: (c) => changed = c));
      await paste(tester, '+7 701 234 5678');
      expect(changed?.isoCode, 'KZ');
      expect(find.text('🇰🇿'), findsOneWidget);
    });

    testWidgets('typing a +1 number refines US to Canada', (tester) async {
      PhoneCountry? changed;
      await pumpApp(
          tester,
          IntlPhoneInput(
              initialCountryCode: 'FR', onCountryChanged: (c) => changed = c));
      await typeKeys(tester, '+12042345678');
      expect(changed?.isoCode, 'CA');
      expect(find.text('🇨🇦'), findsOneWidget);
      expect(editable(tester).controller.text, '(204) 234-5678');
    });
  });

  group('initialValue', () {
    Future<(String, String)> start(WidgetTester tester,
        {String? value, String? country, TextEditingController? c}) async {
      await pumpApp(
          tester,
          IntlPhoneInput(
              initialValue: value, initialCountryCode: country, controller: c));
      final button = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.startsWith('+'));
      return (button, editable(tester).controller.text);
    }

    testWidgets('E.164 without initialCountryCode', (tester) async {
      expect(await start(tester, value: '+213555123456'),
          ('+213', '555 12 34 56'));
    });

    testWidgets('E.164 wins over initialCountryCode', (tester) async {
      expect(await start(tester, value: '+33612345678', country: 'DZ'),
          ('+33', '6 12 34 56 78'));
    });

    testWidgets('leading 00', (tester) async {
      expect(await start(tester, value: '00213555123456'),
          ('+213', '555 12 34 56'));
    });

    testWidgets('national with trunk prefix', (tester) async {
      expect(await start(tester, value: '0555 12 34 56', country: 'DZ'),
          ('+213', '555 12 34 56'));
    });

    testWidgets('national digits equal to the dial code are kept',
        (tester) async {
      expect(await start(tester, value: '+6060123456'), ('+60', '60123456'));
    });

    testWidgets('initialCountryCode as a dial code', (tester) async {
      expect(await start(tester, country: '+91'), ('+91', ''));
    });

    testWidgets('from a controller', (tester) async {
      final c = TextEditingController(text: '+447400123456');
      addTearDown(c.dispose);
      expect(await start(tester, c: c), ('+44', '7400 123456'));
      expect(c.text, '7400 123456');
    });
  });

  group('countries and favorites', () {
    testWidgets('initial country outside the allow-list does not crash',
        (tester) async {
      await pumpApp(
          tester,
          const IntlPhoneInput(
              initialCountryCode: 'US', countries: ['FR', 'DZ']));
      expect(tester.takeException(), isNull);
      expect(find.text('+33'), findsOneWidget);
    });

    testWidgets('picker lists allowed countries, favorites first',
        (tester) async {
      await pumpApp(
          tester,
          const IntlPhoneInput(
            initialCountryCode: 'FR',
            countries: ['FR', 'DZ', 'MA', 'TN'],
            favorites: ['TN', 'DZ'],
          ));
      await tester.tap(find.text('+33'));
      await tester.pumpAndSettle();
      final y = {
        for (final iso in ['TN', 'DZ', 'FR', 'MA'])
          iso: tester.getTopLeft(tile(iso)).dy,
      };
      expect(y['TN']! < y['DZ']!, isTrue);
      expect(y['DZ']! < y['FR']!, isTrue);
      expect(y['FR']! < y['MA']!, isTrue);
      expect(tile('US'), findsNothing);
    });
  });

  group('picker search', () {
    Future<void> open(WidgetTester tester,
        {Locale locale = const Locale('en'),
        CountryPickerMode mode = CountryPickerMode.dialog}) async {
      await pumpApp(
          tester, IntlPhoneInput(initialCountryCode: 'US', pickerMode: mode),
          locale: locale);
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
    }

    Future<void> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField).last, q);
      await tester.pumpAndSettle();
    }

    testWidgets('English, French and Arabic names', (tester) async {
      await open(tester);
      await search(tester, 'Algeria');
      expect(tile('DZ'), findsOneWidget);
      await search(tester, 'algerie');
      expect(tile('DZ'), findsOneWidget);
      await search(tester, 'Allemagne');
      expect(tile('DE'), findsOneWidget);
      expect(tile('DZ'), findsNothing);
      await search(tester, 'الجزائر');
      expect(tile('DZ'), findsOneWidget);
      await search(tester, 'ألمانيا');
      expect(tile('DE'), findsOneWidget);
      await search(tester, '+213');
      expect(tile('DZ'), findsOneWidget);
      await search(tester, 'zzzz');
      expect(find.text('No country found'), findsOneWidget);
    });

    testWidgets('selecting a country updates the button', (tester) async {
      PhoneCountry? changed;
      await pumpApp(
          tester,
          IntlPhoneInput(
              initialCountryCode: 'US', onCountryChanged: (c) => changed = c));
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'alg');
      await tester.pumpAndSettle();
      await tester.tap(tile('DZ'));
      await tester.pumpAndSettle();
      expect(changed?.isoCode, 'DZ');
      expect(find.text('+213'), findsOneWidget);
    });

    testWidgets('French UI shows French names and hint', (tester) async {
      await open(tester, locale: const Locale('fr'));
      expect(find.text('Rechercher un pays ou un indicatif'), findsOneWidget);
      await search(tester, 'Algeria');
      expect(find.text('Algérie'), findsOneWidget);
    });

    testWidgets('Arabic UI shows Arabic names and hint', (tester) async {
      await open(tester, locale: const Locale('ar'));
      expect(find.text('ابحث عن دولة أو رمز الاتصال'), findsOneWidget);
      await search(tester, 'algerie');
      expect(find.text('الجزائر'), findsOneWidget);
    });

    testWidgets('bottom sheet mode', (tester) async {
      await open(tester, mode: CountryPickerMode.bottomSheet);
      expect(find.byType(BottomSheet), findsOneWidget);
      await search(tester, 'Algérie');
      await tester.tap(tile('DZ'));
      await tester.pumpAndSettle();
      expect(find.text('+213'), findsOneWidget);
    });

    testWidgets('readOnly does not open the picker', (tester) async {
      await pumpApp(tester,
          const IntlPhoneInput(initialCountryCode: 'US', readOnly: true));
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('validation', () {
    testWidgets('country change re-validates', (tester) async {
      await pumpApp(
          tester,
          const IntlPhoneInput(
            initialCountryCode: 'US',
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ));
      await typeKeys(tester, '2015550123');
      await tester.pump();
      expect(find.text('Invalid phone number'), findsNothing);

      // Switch to France: a 10-digit US number is not a French number.
      await tester.tap(find.text('+1'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'France');
      await tester.pumpAndSettle();
      await tester.tap(tile('FR'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid phone number'), findsOneWidget);

      // And back: the error goes away without typing.
      await tester.tap(find.text('+33'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'United States');
      await tester.pumpAndSettle();
      await tester.tap(tile('US'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid phone number'), findsNothing);
    });

    testWidgets('form validate() runs without prior interaction',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      PhoneValue? seen;
      PhoneValue? saved;
      await pumpApp(
          tester,
          Form(
            key: formKey,
            child: IntlPhoneInput(
              initialCountryCode: 'DZ',
              validator: (v) {
                seen = v;
                return v.isEmpty ? 'Required' : null;
              },
              onSaved: (v) => saved = v,
            ),
          ));
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(seen!.isEmpty, isTrue);
      expect(find.text('Required'), findsOneWidget);

      await typeKeys(tester, '55512');
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Invalid phone number'), findsOneWidget);

      await typeKeys(tester, '3456');
      expect(formKey.currentState!.validate(), isTrue);
      formKey.currentState!.save();
      expect(saved!.e164, '+213555123456');
    });

    testWidgets('custom invalidNumberMessage and allowedTypes', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpApp(
          tester,
          Form(
            key: formKey,
            child: const IntlPhoneInput(
              initialCountryCode: 'DZ',
              initialValue: '021123456',
              invalidNumberMessage: 'Mobile only',
              allowedTypes: {PhoneType.mobile},
            ),
          ));
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Mobile only'), findsOneWidget);
    });

    testWidgets('localized error message', (tester) async {
      final formKey = GlobalKey<FormState>();
      await pumpApp(
          tester,
          Form(
            key: formKey,
            child: const IntlPhoneInput(
                initialCountryCode: 'DZ', initialValue: '555'),
          ),
          locale: const Locale('fr'));
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Numéro de téléphone invalide'), findsOneWidget);
    });
  });

  group('RTL', () {
    testWidgets('mirrors the layout but keeps the number LTR', (tester) async {
      await pumpApp(
          tester,
          const IntlPhoneInput(
              initialCountryCode: 'DZ', initialValue: '555123456'),
          locale: const Locale('ar'));
      expect(editable(tester).textDirection, TextDirection.ltr);
      final button = tester.getCenter(find.text('+213'));
      final number = tester.getCenter(find.byType(EditableText));
      expect(button.dx, greaterThan(number.dx),
          reason: 'country button sits on the right in RTL');
      final dial = tester.widget<Text>(find.text('+213'));
      expect(dial.textDirection, TextDirection.ltr);
    });

    testWidgets('LTR puts the button on the left', (tester) async {
      await pumpApp(tester, const IntlPhoneInput(initialCountryCode: 'DZ'));
      final button = tester.getCenter(find.text('+213'));
      final number = tester.getCenter(find.byType(EditableText));
      expect(button.dx, lessThan(number.dx));
    });

    testWidgets('dropdownIconPosition trailing', (tester) async {
      await pumpApp(
          tester,
          const IntlPhoneInput(
              initialCountryCode: 'DZ',
              dropdownIconPosition: IconPosition.trailing));
      final icon = tester.getCenter(find.byIcon(Icons.arrow_drop_down));
      final dial = tester.getCenter(find.text('+213'));
      expect(icon.dx, greaterThan(dial.dx));
    });
  });

  group('semantics', () {
    testWidgets('country button and picker rows are labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const IntlPhoneInput(initialCountryCode: 'DZ'));
      expect(find.bySemanticsLabel('Change country. Current: Algeria +213'),
          findsOneWidget);
      await tester.tap(find.text('+213'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'France');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('France +33'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('Arabic label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const IntlPhoneInput(initialCountryCode: 'DZ'),
          locale: const Locale('ar'));
      expect(find.bySemanticsLabel('تغيير الدولة. الحالية: الجزائر +213'),
          findsOneWidget);
      handle.dispose();
    });
  });
}
