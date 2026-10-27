import 'package:flutter/material.dart';
import 'package:mydex_application/mydex_application.dart';

import '../app/theme.dart';
import 'search_field.dart';

@immutable
class PickerOption<T> {
  const PickerOption(
    this.value,
    this.label, {
    this.trailing,
    this.subtitle,
    this.searchText,
  });

  final T value;
  final String label;
  final Widget? trailing;
  final String? subtitle;

  /// Zusätzlicher Suchtext (z. B. Namen in anderen Sprachen).
  final String? searchText;
}

/// Ergebnis eines Pickers: [cleared] = bewusst „keins“ gewählt.
@immutable
class PickerResult<T> {
  const PickerResult(this.value) : cleared = false;
  const PickerResult.cleared() : value = null, cleared = true;

  final T? value;
  final bool cleared;
}

/// Vollbild-Auswahl mit Suche, für lange Listen (Pokémon, Attacken, Items).
Future<PickerResult<T>?> showSearchPicker<T>(
  BuildContext context, {
  required String title,
  required String searchHint,
  required List<PickerOption<T>> options,
  String? clearLabel,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _SearchPicker<T>(
      title: title,
      searchHint: searchHint,
      options: options,
      clearLabel: clearLabel,
    ),
  ),
);

class _SearchPicker<T> extends StatefulWidget {
  const _SearchPicker({
    required this.title,
    required this.searchHint,
    required this.options,
    this.clearLabel,
  });

  final String title;
  final String searchHint;
  final List<PickerOption<T>> options;
  final String? clearLabel;

  @override
  State<_SearchPicker<T>> createState() => _SearchPickerState<T>();
}

class _SearchPickerState<T> extends State<_SearchPicker<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = normalizeSearchText(_query);
    final visible = [
      for (final o in widget.options)
        if (q.isEmpty ||
            normalizeSearchText('${o.label} ${o.searchText ?? ''}').contains(q))
          o,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.l,
              Space.s,
              Space.l,
              Space.s,
            ),
            child: SearchField(
              autofocus: true,
              hintText: widget.searchHint,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: visible.length + (widget.clearLabel != null ? 1 : 0),
              itemBuilder: (context, i) {
                if (widget.clearLabel != null) {
                  if (i == 0) {
                    return ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(widget.clearLabel!),
                      onTap: () =>
                          Navigator.pop(context, PickerResult<T>.cleared()),
                    );
                  }
                  i--;
                }
                final o = visible[i];
                return ListTile(
                  title: Text(o.label),
                  subtitle: o.subtitle == null ? null : Text(o.subtitle!),
                  trailing: o.trailing,
                  onTap: () => Navigator.pop(context, PickerResult<T>(o.value)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
