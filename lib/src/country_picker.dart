import 'package:flutter/material.dart';

import 'phone_country.dart';
import 'search.dart';
import 'strings.dart';

/// How the country picker opens.
enum CountryPickerMode {
  /// A centred dialog.
  dialog,

  /// A modal bottom sheet.
  bottomSheet,
}

/// Styling for the country picker, named as in `intl_phone_field`.
class PickerDialogStyle {
  /// Creates a style.
  const PickerDialogStyle({
    this.backgroundColor,
    this.countryCodeStyle,
    this.countryNameStyle,
    this.listTileDivider,
    this.listTilePadding,
    this.padding,
    this.searchFieldCursorColor,
    this.searchFieldInputDecoration,
    this.searchFieldPadding,
    this.searchFieldTextStyle,
    this.width,
  });

  /// Background of the dialog or sheet.
  final Color? backgroundColor;

  /// Style of the dial code in each row.
  final TextStyle? countryCodeStyle;

  /// Style of the country name in each row.
  final TextStyle? countryNameStyle;

  /// Widget between rows; none by default.
  final Widget? listTileDivider;

  /// Padding of each row.
  final EdgeInsets? listTilePadding;

  /// Padding around the picker content.
  final EdgeInsets? padding;

  /// Cursor colour of the search field.
  final Color? searchFieldCursorColor;

  /// Decoration of the search field. Its hint defaults to the localized
  /// search hint.
  final InputDecoration? searchFieldInputDecoration;

  /// Padding around the search field.
  final EdgeInsets? searchFieldPadding;

  /// Text style of the search field.
  final TextStyle? searchFieldTextStyle;

  /// Width of the dialog.
  final double? width;
}

/// A searchable list of countries: a search field above a list, with
/// [favorites] pinned at the top.
///
/// Search matches English, French and Arabic names ignoring diacritics,
/// the ISO code, and the dial code. Each row has the key
/// `ValueKey<String>('country-<ISO>')`.
class CountryPickerList extends StatefulWidget {
  /// Creates the list.
  const CountryPickerList({
    super.key,
    required this.countries,
    required this.onSelected,
    this.favorites = const [],
    this.selected,
    this.style,
    this.strings,
    this.showFlags = true,
  });

  /// Countries to list.
  final List<PhoneCountry> countries;

  /// Countries pinned at the top, in this order.
  final List<PhoneCountry> favorites;

  /// The current country, shown as selected.
  final PhoneCountry? selected;

  /// Called with the tapped country.
  final ValueChanged<PhoneCountry> onSelected;

  /// Styling.
  final PickerDialogStyle? style;

  /// Texts; the ambient locale's by default.
  final PhoneInputStrings? strings;

  /// Whether to show flag emojis.
  final bool showFlags;

  @override
  State<CountryPickerList> createState() => _CountryPickerListState();
}

class _CountryPickerListState extends State<CountryPickerList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings ?? PhoneInputStrings.of(context);
    final style = widget.style;
    final favorites =
        widget.favorites.where(widget.countries.contains).toList();
    final rest = widget.countries.where((c) => !favorites.contains(c)).toList();
    final shownFavorites = searchCountries(favorites, _query);
    final shownRest = searchCountries(rest, _query);
    final rows = <Widget>[
      for (final c in shownFavorites) _row(c, strings),
      if (shownFavorites.isNotEmpty && shownRest.isNotEmpty)
        const Divider(key: ValueKey<String>('favorites-divider')),
      for (final c in shownRest) _row(c, strings),
    ];
    final title = strings.pickerTitle;
    final decoration =
        (style?.searchFieldInputDecoration ?? const InputDecoration()).copyWith(
      hintText:
          style?.searchFieldInputDecoration?.hintText ?? strings.searchHint,
      prefixIcon: style?.searchFieldInputDecoration?.prefixIcon ??
          const Icon(Icons.search),
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Padding(
        padding: style?.padding ?? EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: style?.searchFieldPadding ?? const EdgeInsets.all(8),
              child: TextField(
                cursorColor: style?.searchFieldCursorColor,
                style: style?.searchFieldTextStyle,
                decoration: decoration,
                textInputAction: TextInputAction.search,
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            Flexible(
              child: rows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(strings.noResults),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (_, i) => rows[i],
                      separatorBuilder: (_, __) =>
                          style?.listTileDivider ?? const SizedBox.shrink(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(PhoneCountry c, PhoneInputStrings strings) {
    final style = widget.style;
    final name = c.nameFor(strings.languageCode);
    return Semantics(
      key: ValueKey<String>('country-${c.isoCode}'),
      label: '$name +${c.dialCode}',
      button: true,
      selected: c == widget.selected,
      excludeSemantics: true,
      onTap: () => widget.onSelected(c),
      child: ListTile(
        contentPadding: style?.listTilePadding,
        selected: c == widget.selected,
        leading: widget.showFlags
            ? Text(c.flag, style: const TextStyle(fontSize: 24))
            : null,
        title: Text(name, style: style?.countryNameStyle),
        trailing: Text(
          '+${c.dialCode}',
          textDirection: TextDirection.ltr,
          style: style?.countryCodeStyle,
        ),
        onTap: () => widget.onSelected(c),
      ),
    );
  }
}

/// Shows the country picker as a dialog and returns the chosen country,
/// or null when dismissed.
Future<PhoneCountry?> showCountryPickerDialog(
  BuildContext context, {
  List<PhoneCountry>? countries,
  List<PhoneCountry> favorites = const [],
  PhoneCountry? selected,
  PickerDialogStyle? style,
  PhoneInputStrings? strings,
  bool showFlags = true,
}) {
  return showDialog<PhoneCountry>(
    context: context,
    builder: (context) {
      final size = MediaQuery.sizeOf(context);
      return Dialog(
        backgroundColor: style?.backgroundColor,
        child: SizedBox(
          width: style?.width ?? 400,
          height: size.height * 0.7,
          child: CountryPickerList(
            countries: countries ?? PhoneCountries.all,
            favorites: favorites,
            selected: selected,
            style: style,
            strings: strings,
            showFlags: showFlags,
            onSelected: (c) => Navigator.of(context).pop(c),
          ),
        ),
      );
    },
  );
}

/// Shows the country picker as a modal bottom sheet and returns the chosen
/// country, or null when dismissed.
Future<PhoneCountry?> showCountryPickerSheet(
  BuildContext context, {
  List<PhoneCountry>? countries,
  List<PhoneCountry> favorites = const [],
  PhoneCountry? selected,
  PickerDialogStyle? style,
  PhoneInputStrings? strings,
  bool showFlags = true,
}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: style?.backgroundColor,
    builder: (context) {
      final media = MediaQuery.of(context);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: media.size.height * 0.85,
          child: CountryPickerList(
            countries: countries ?? PhoneCountries.all,
            favorites: favorites,
            selected: selected,
            style: style,
            strings: strings,
            showFlags: showFlags,
            onSelected: (c) => Navigator.of(context).pop(c),
          ),
        ),
      );
    },
  );
}
