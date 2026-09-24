import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside a localized MaterialApp.
Future<void> pumpApp(WidgetTester tester, Widget child,
    {Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child)),
  ));
  await tester.pumpAndSettle();
}

/// The phone number EditableText.
EditableText editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).first);

/// Types [chars] one key at a time at the current cursor.
Future<void> typeKeys(WidgetTester tester, String chars) async {
  await tester.showKeyboard(find.byType(EditableText).first);
  for (final ch in chars.split('')) {
    final value = editable(tester).controller.value;
    final at = value.selection.baseOffset < 0
        ? value.text.length
        : value.selection.baseOffset;
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: value.text.substring(0, at) + ch + value.text.substring(at),
      selection: TextSelection.collapsed(offset: at + 1),
    ));
    await tester.pump();
  }
}

/// Replaces the whole text, as a paste over a selection would.
Future<void> paste(WidgetTester tester, String text) async {
  await tester.showKeyboard(find.byType(EditableText).first);
  tester.testTextInput.updateEditingValue(TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  ));
  await tester.pumpAndSettle();
}
