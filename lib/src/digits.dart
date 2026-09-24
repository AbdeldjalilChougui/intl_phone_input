/// Converts Arabic-Indic (`٠`-`٩`), Extended Arabic-Indic (`۰`-`۹`) and
/// full-width (`０`-`９`) digits to ASCII `0`-`9`, and a full-width plus
/// (`＋`) to `+`. Every other character is kept as it is.
String normalizeDigits(String input) {
  final out = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + rune - 0x06F0);
    } else if (rune >= 0xFF10 && rune <= 0xFF19) {
      out.writeCharCode(0x30 + rune - 0xFF10);
    } else if (rune == 0xFF0B) {
      out.write('+');
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

/// Returns only the ASCII digits of [input], after [normalizeDigits].
String digitsOnly(String input) =>
    normalizeDigits(input).replaceAll(RegExp(r'[^0-9]'), '');
