import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/availability_notice.dart';
import '../../widgets/collection_toggles.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/type_badge.dart';
import 'pokemon_detail_page.dart';

class DexQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Suchtext der Dex-Liste; bleibt bei Auswahl und Navigation erhalten.
final dexQueryProvider = NotifierProvider<DexQuery, String>(DexQuery.new);

/// Ergebnisliste im aktuellen Spielkontext, gefiltert durch die Suche.
final dexResultsProvider = Provider<List<PokemonListItem>>((ref) {
  final ctx = ref.watch(gameContextProvider);
  final items = ref.watch(queriesProvider).list(ctx);
  final query = ref.watch(dexQueryProvider).trim();
  if (query.isEmpty) return items;
  final byId = {for (final i in items) i.form.id: i};
  return [
    for (final hit in ref.watch(searchIndexProvider).search(query))
      ?byId[hit.form],
  ];
});

class DexPage extends ConsumerStatefulWidget {
  const DexPage({super.key, this.selected});

  final FormId? selected;

  @override
  ConsumerState<DexPage> createState() => _DexPageState();
}

class _DexPageState extends ConsumerState<DexPage> {
  late final _controller = TextEditingController(
    text: ref.read(dexQueryProvider),
  );
  final _searchFocus = FocusNode(debugLabel: 'dex-search');

  @override
  void dispose() {
    _controller.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final list = _DexList(
      selected: wide ? widget.selected : null,
      onOpen: (id) => openPokemon(context, id, wide: wide),
    );

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.l,
            Space.s,
            Space.l,
            Space.s,
          ),
          child: SearchBar(
            controller: _controller,
            focusNode: _searchFocus,
            hintText: l10n.searchHint,
            leading: const Icon(Icons.search),
            trailing: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    ref.read(dexQueryProvider.notifier).set('');
                    setState(() {});
                  },
                ),
            ],
            onChanged: (v) {
              ref.read(dexQueryProvider.notifier).set(v);
              setState(() {});
            },
            elevation: const WidgetStatePropertyAll(0),
          ),
        ),
        Expanded(child: list),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.slash): () {
          if (!_searchFocus.hasFocus) _searchFocus.requestFocus();
        },
      },
      child: Focus(
        autofocus: wide,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.navDex),
            actions: const [
              GameContextSelector(),
              SizedBox(width: Space.s),
            ],
          ),
          body: wide
              ? Row(
                  children: [
                    SizedBox(width: 380, child: body),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: widget.selected == null
                          ? Center(child: Text(l10n.detailEmpty))
                          : PokemonDetailView(
                              key: ValueKey(widget.selected),
                              formId: widget.selected!,
                            ),
                    ),
                  ],
                )
              : body,
        ),
      ),
    );
  }
}

class _DexList extends ConsumerWidget {
  const _DexList({required this.selected, required this.onOpen});

  final FormId? selected;
  final ValueChanged<FormId> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(dexResultsProvider);
    final query = ref.watch(dexQueryProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    if (items.isEmpty) {
      return Center(child: Text(l10n.noResults(query)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final name = catalog.displayName(item.form).resolve(lang);
        return ListTile(
          selected: item.form.id == selected,
          onTap: () => onOpen(item.form.id),
          leading: SizedBox(
            width: 52,
            child: Text(
              '#${item.species.nationalNumber.toString().padLeft(4, '0')}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontFeatures: tabularFigures),
            ),
          ),
          title: Text(name.text),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: item.profile.availability.isGap
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: DataGapChip(),
                  )
                : TypeBadges(item.profile.types, dense: true),
          ),
          trailing: CaughtButton(form: item.form.id),
        );
      },
    );
  }
}
