// The Usage example from README.md, compiled and run.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_input/intl_phone_input.dart';

import 'helpers.dart';

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

void main() {
  testWidgets('README usage example validates and saves', (tester) async {
    await pumpApp(tester, const SignUpForm());
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    await typeKeys(tester, '0555123456');
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Required'), findsNothing);
    expect(find.text('Invalid phone number'), findsNothing);
  });
}
