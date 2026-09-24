import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'country_picker.dart';
import 'digits.dart';
import 'phone_country.dart';
import 'phone_editor.dart';
import 'phone_type.dart';
import 'phone_value.dart';
import 'strings.dart';

/// Where the dropdown arrow sits in the country button.
enum IconPosition {
  /// Before the flag.
  leading,

  /// After the dial code.
  trailing,
}

/// A phone number field: a country button (flag and dial code) in front of
/// a [TextFormField] that formats the national number as it is typed.
///
/// * Pasting or typing `+213 555 12 34 56` or `00213...` switches the
///   country and keeps the national part.
/// * Shared dial codes (+1, +7, +44, ...) are told apart by their leading
///   digits.
/// * Validation uses libphonenumber lengths and patterns.
/// * Arabic-Indic and Persian digits are accepted.
/// * In a right-to-left context the layout mirrors, while the number
///   itself stays left-to-right.
class IntlPhoneInput extends StatefulWidget {
  /// Creates a phone field.
  const IntlPhoneInput({
    super.key,
    this.initialCountryCode,
    this.initialValue,
    this.onChanged,
    this.onCountryChanged,
    this.onSaved,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.invalidNumberMessage,
    this.allowedTypes,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.countries,
    this.favorites = const [],
    this.decoration = const InputDecoration(),
    this.style,
    this.textAlign = TextAlign.start,
    this.dropdownIconPosition = IconPosition.leading,
    this.dropdownIcon = const Icon(Icons.arrow_drop_down),
    this.showDropdownIcon = true,
    this.dropdownTextStyle,
    this.disableLengthCheck = false,
    this.showCountryFlag = true,
    this.flagsButtonPadding = EdgeInsets.zero,
    this.flagsButtonMargin = EdgeInsets.zero,
    this.pickerDialogStyle,
    this.pickerMode = CountryPickerMode.dialog,
    this.strings,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.autofillHints = const [AutofillHints.telephoneNumber],
    this.textInputAction,
    this.keyboardType = TextInputType.phone,
    this.inputFormatters,
    this.cursorColor,
  });

  /// ISO code (`DZ`) or dial code (`+213`) of the starting country.
  /// Ignored when [initialValue] is an international number. Defaults to
  /// `US`, or the first allowed country.
  final String? initialCountryCode;

  /// Starting number: E.164 (`+213555123456`), `00` international, or
  /// national (`0555 12 34 56`) in [initialCountryCode]. Ignored when
  /// [controller] already has text.
  final String? initialValue;

  /// Called with the new value after each edit and country change.
  final ValueChanged<PhoneValue>? onChanged;

  /// Called when the country changes, from the picker or from the input.
  final ValueChanged<PhoneCountry>? onCountryChanged;

  /// Called by `FormState.save`.
  final ValueChanged<PhoneValue>? onSaved;

  /// Called when the user submits from the keyboard.
  final ValueChanged<String>? onSubmitted;

  /// Called when the text field is tapped.
  final VoidCallback? onTap;

  /// Extra validation, run after the built-in number check passes (or
  /// always, with [disableLengthCheck]). Receives the parsed value, also
  /// when empty, so it can report a required field.
  final String? Function(PhoneValue value)? validator;

  /// Error shown for an invalid number; localized by default.
  final String? invalidNumberMessage;

  /// Number types accepted by the built-in check, such as
  /// `{PhoneType.mobile}`. Any type when null.
  final Set<PhoneType>? allowedTypes;

  /// When the field validates itself.
  final AutovalidateMode autovalidateMode;

  /// Allowed countries as ISO codes; all when null. Unknown codes are
  /// ignored.
  final List<String>? countries;

  /// ISO codes pinned at the top of the picker.
  final List<String> favorites;

  /// Decoration of the field. Its `prefixIcon` is replaced by the country
  /// button.
  final InputDecoration decoration;

  /// Text style of the number.
  final TextStyle? style;

  /// Alignment of the number, resolved left-to-right.
  final TextAlign textAlign;

  /// Where the dropdown arrow sits.
  final IconPosition dropdownIconPosition;

  /// The dropdown arrow.
  final Widget dropdownIcon;

  /// Whether to show the dropdown arrow.
  final bool showDropdownIcon;

  /// Style of the dial code in the button.
  final TextStyle? dropdownTextStyle;

  /// Disables the maximum length and the built-in validity check.
  final bool disableLengthCheck;

  /// Whether to show the flag in the button and the picker.
  final bool showCountryFlag;

  /// Padding inside the country button.
  final EdgeInsetsGeometry flagsButtonPadding;

  /// Margin around the country button.
  final EdgeInsetsGeometry flagsButtonMargin;

  /// Styling of the picker.
  final PickerDialogStyle? pickerDialogStyle;

  /// Whether the picker is a dialog or a bottom sheet.
  final CountryPickerMode pickerMode;

  /// Built-in texts; bundled English, French or Arabic by locale.
  final PhoneInputStrings? strings;

  /// Controller of the national number text. Its text is replaced by the
  /// formatted number.
  final TextEditingController? controller;

  /// Focus node of the text field.
  final FocusNode? focusNode;

  /// Whether the field and the country button accept input.
  final bool enabled;

  /// Whether the text and the country are read-only.
  final bool readOnly;

  /// Whether to focus the field when first built.
  final bool autofocus;

  /// Autofill hints; `telephoneNumber` by default.
  final Iterable<String>? autofillHints;

  /// Keyboard action button.
  final TextInputAction? textInputAction;

  /// Keyboard type; phone by default.
  final TextInputType keyboardType;

  /// Extra formatters, run before the phone formatter.
  final List<TextInputFormatter>? inputFormatters;

  /// Cursor colour.
  final Color? cursorColor;

  @override
  State<IntlPhoneInput> createState() => _IntlPhoneInputState();
}

class _IntlPhoneInputState extends State<IntlPhoneInput> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  late List<PhoneCountry> _allowed;
  late PhoneEditor _editor;
  late PhoneCountry _country;
  TextEditingController? _ownController;
  bool _refine = false;

  TextEditingController get _controller => widget.controller ?? _ownController!;

  @override
  void initState() {
    super.initState();
    _configure();
    if (widget.controller == null) _ownController = TextEditingController();
    final existing = _controller.text;
    _country = _initialCountry();
    _setInitial(existing.isNotEmpty ? existing : widget.initialValue);
  }

  void _configure() {
    final list = widget.countries
            ?.map(PhoneCountries.byIso)
            .whereType<PhoneCountry>()
            .toList() ??
        const <PhoneCountry>[];
    _allowed = list.isEmpty ? PhoneCountries.all : list;
    _editor = PhoneEditor(
      allowed: widget.countries == null ? null : _allowed,
      enforceMaxLength: !widget.disableLengthCheck,
    );
  }

  PhoneCountry _initialCountry() {
    final code = widget.initialCountryCode;
    final wanted = code == null ? null : PhoneCountries.resolve(code);
    if (wanted != null && _allowed.contains(wanted)) return wanted;
    final us = PhoneCountries.byIso('US')!;
    return _allowed.contains(us) ? us : _allowed.first;
  }

  void _setInitial(String? input) {
    if (input == null || input.trim().isEmpty) {
      _controller.text = '';
      return;
    }
    final value = PhoneValue.parse(input, country: _country.isoCode);
    if (!_allowed.contains(value.country)) {
      _controller.text =
          normalizeDigits(input).replaceAll(RegExp(r'[^0-9+]'), '');
      return;
    }
    _country = value.country;
    _controller.text = _editor.formatDigits(_country, value.nationalNumber);
  }

  @override
  void didUpdateWidget(IntlPhoneInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final text = oldWidget.controller?.text ?? _ownController?.text ?? '';
      if (widget.controller == null) {
        _ownController ??= TextEditingController(text: text);
      } else {
        _ownController?.dispose();
        _ownController = null;
      }
    }
    if (oldWidget.countries != widget.countries ||
        oldWidget.disableLengthCheck != widget.disableLengthCheck) {
      _configure();
      if (!_allowed.contains(_country)) _country = _initialCountry();
    }
  }

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  PhoneValue _valueOf(String text) {
    final compact = normalizeDigits(text).replaceAll(RegExp(r'[^0-9+]'), '');
    if (compact.startsWith('+') || compact.startsWith('00')) {
      return PhoneValue.parse(compact, country: _country.isoCode);
    }
    final digits = digitsOnly(text);
    return PhoneValue(
      country: _country,
      nationalNumber: PhoneValue.nationalSignificantNumber(_country, digits),
    );
  }

  bool _isRawInternational(String text) {
    final compact = normalizeDigits(text).replaceAll(RegExp(r'[^0-9+]'), '');
    return compact.startsWith('+') || compact.startsWith('00');
  }

  bool _acceptable(PhoneValue value, String text) {
    if (_isRawInternational(text)) return false;
    final types = widget.allowedTypes;
    if (types == null || types.isEmpty) return value.isValid;
    return types.any(value.isValidFor);
  }

  String? _validate(String? text) {
    final t = text ?? '';
    final value = _valueOf(t);
    if (!widget.disableLengthCheck &&
        (t.trim().isNotEmpty) &&
        !_acceptable(value, t)) {
      return widget.invalidNumberMessage ?? _strings.invalidNumber;
    }
    return widget.validator?.call(value);
  }

  PhoneInputStrings get _strings =>
      widget.strings ?? PhoneInputStrings.of(context);

  TextEditingValue _format(TextEditingValue oldValue, TextEditingValue next) {
    final result =
        _editor.apply(_country, oldValue, next, refineSharedDialCode: _refine);
    if (result.country != _country) {
      setState(() => _country = result.country);
      widget.onCountryChanged?.call(result.country);
    }
    if (result.countryDetected) {
      _refine = PhoneCountries.byDialCode(result.country.dialCode).length > 1;
    }
    return result.value;
  }

  bool get _canPick => widget.enabled && !widget.readOnly;

  Future<void> _pick() async {
    if (!_canPick) return;
    final favorites = widget.favorites
        .map(PhoneCountries.byIso)
        .whereType<PhoneCountry>()
        .where(_allowed.contains)
        .toList();
    final show = widget.pickerMode == CountryPickerMode.dialog
        ? showCountryPickerDialog
        : showCountryPickerSheet;
    final picked = await show(
      context,
      countries: _allowed,
      favorites: favorites,
      selected: _country,
      style: widget.pickerDialogStyle,
      strings: widget.strings,
      showFlags: widget.showCountryFlag,
    );
    if (!mounted || picked == null || picked == _country) return;
    _changeCountry(picked);
  }

  void _changeCountry(PhoneCountry country) {
    final digits = digitsOnly(_controller.text);
    final text = _isRawInternational(_controller.text)
        ? _controller.text
        : _editor.formatDigits(country, digits);
    setState(() {
      _country = country;
      _refine = false;
    });
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    widget.onCountryChanged?.call(country);
    widget.onChanged?.call(_valueOf(text));
    final field = _fieldKey.currentState;
    if (field != null &&
        widget.autovalidateMode != AutovalidateMode.disabled &&
        (field.hasError || text.isNotEmpty)) {
      field.didChange(text);
      field.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: _fieldKey,
      controller: _controller,
      focusNode: widget.focusNode,
      decoration: widget.decoration.copyWith(prefixIcon: _button(context)),
      style: widget.style,
      textAlign: widget.textAlign,
      textDirection: TextDirection.ltr,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      cursorColor: widget.cursorColor,
      autovalidateMode: widget.autovalidateMode,
      inputFormatters: [
        ...?widget.inputFormatters,
        TextInputFormatter.withFunction(_format),
      ],
      onChanged: (text) => widget.onChanged?.call(_valueOf(text)),
      onFieldSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      onSaved: (text) => widget.onSaved?.call(_valueOf(text ?? '')),
      validator: _validate,
    );
  }

  Widget _button(BuildContext context) {
    final strings = _strings;
    final name = _country.nameFor(strings.languageCode);
    final showIcon = widget.showDropdownIcon && _canPick;
    return Padding(
      padding: widget.flagsButtonMargin,
      child: Semantics(
        button: true,
        enabled: _canPick,
        label: strings.changeCountry(name, _country.dialCode),
        excludeSemantics: true,
        onTap: _canPick ? _pick : null,
        child: InkWell(
          onTap: _canPick ? _pick : null,
          child: Padding(
            padding: widget.flagsButtonPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 4),
                if (showIcon &&
                    widget.dropdownIconPosition == IconPosition.leading) ...[
                  widget.dropdownIcon,
                  const SizedBox(width: 4),
                ],
                if (widget.showCountryFlag) ...[
                  Text(_country.flag, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                ],
                Text(
                  '+${_country.dialCode}',
                  textDirection: TextDirection.ltr,
                  style: widget.dropdownTextStyle,
                ),
                if (showIcon &&
                    widget.dropdownIconPosition == IconPosition.trailing) ...[
                  const SizedBox(width: 4),
                  widget.dropdownIcon,
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
