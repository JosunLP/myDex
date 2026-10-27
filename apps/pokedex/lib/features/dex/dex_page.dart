import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/availability_notice.dart';
import '../../widgets/collection_toggles.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/search_field.dart';
import '../../widgets/type_badge.dart';
import 'filter_sheet.dart';
import 'pokemon_detail_page.dart';

class DexQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Suchtext der Dex-Liste; bleibt bei Auswahl und Navigation erhalten.
final dexQueryProvider = NotifierProvider<DexQuery, String>(DexQuery.new);

/// Attacken und Fähigkeiten zur Suchanfrage (Volltextindex im Katalog).
final entityResultsProvider = Provider<List<EntityHit>>((ref) {
  final query = ref.watch(dexQueryProvider).trim();
  if (query.isEmpty) return const [];
  return [
    for (final hit
        in ref.watch(catalogDetailsProvider).searchEntities(query, limit: 20))
      if (hit.kind != EntityKind.item) hit,
  ];
});

/// Ergebnisliste im aktuellen Spielkontext, gefiltert durch die Suche.
final dexResultsProvider = Provider<List<PokemonListItem>>((ref) {
  final ctx = ref.watch(gameContextProvider);
  final filter = ref.watch(dexFilterProvider);
  final items = applyDexFilter(
    ref.watch(queriesProvider).list(ctx),
    filter,
    collection: filter.collection == CollectionFilter.all
        ? const {}
        : ref.watch(collectionProvider).value ?? const {},
    scope: GameScope(ctx.versionId),
  );
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
          child: SearchField(
            controller: _controller,
            focusNode: _searchFocus,
            hintText: l10n.searchHint,
            trailing: _controller.text.isEmpty
                ? null
                : IconButton(
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
            onChanged: (v) {
              ref.read(dexQueryProvider.notifier).set(v);
              setState(() {});
            },
          ),
        ),
        const FilterBar(),
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
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (MediaQuery.sizeOf(context).width < Breakpoints.medium) ...[
                  const PokedexLens(size: 30),
                  const SizedBox(width: Space.m),
                ],
                Text(l10n.navDex),
              ],
            ),
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
    final entities = ref.watch(entityResultsProvider);
    final query = ref.watch(dexQueryProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    if (items.isEmpty && entities.isEmpty) {
      return Center(child: Text(l10n.noResults(query)));
    }
    final textTheme = Theme.of(context).textTheme;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.l, Space.l, Space.l, Space.xs),
      child: Semantics(
        header: true,
        child: Text(text, style: textTheme.titleSmall),
      ),
    );
    final moves = entities.where((e) => e.kind == EntityKind.move).toList();
    final abilities = entities
        .where((e) => e.kind == EntityKind.ability)
        .toList();
    final showHeaders = entities.isNotEmpty;

    // Flache Liste aus Zeilenbauern: Pokémon, dann Attacken, dann Fähigkeiten.
    final rows = <Widget Function()>[
      if (showHeaders && items.isNotEmpty) () => header(l10n.searchPokemon),
      for (final item in items)
        () => _pokemonTile(context, item, catalog, lang),
      if (moves.isNotEmpty) () => header(l10n.searchMoves),
      for (final m in moves)
        () => ListTile(
          leading: const Icon(Icons.flash_on_outlined),
          title: Text(catalog.moves[MoveId(m.id)]?.name(lang) ?? m.id),
          onTap: () => context.push('/dex/move/${Uri.encodeComponent(m.id)}'),
        ),
      if (abilities.isNotEmpty) () => header(l10n.searchAbilities),
      for (final a in abilities)
        () => ListTile(
          leading: const Icon(Icons.bolt),
          title: Text(catalog.abilities[AbilityId(a.id)]?.name(lang) ?? a.id),
          onTap: () =>
              context.push('/dex/ability/${Uri.encodeComponent(a.id)}'),
        ),
    ];
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) => rows[i](),
    );
  }

  Widget _pokemonTile(
    BuildContext context,
    PokemonListItem item,
    CatalogSnapshot catalog,
    String lang,
  ) {
    final name = catalog.displayName(item.form).resolve(lang);
    return ListTile(
      selected: item.form.id == selected,
      onTap: () => onOpen(item.form.id),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DexNumber(item.species.nationalNumber, dense: true),
          const SizedBox(width: Space.xs),
          DexThumb(item.form.id),
        ],
      ),
      title: Text(name.text),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Space.xs),
        child: item.profile.types.isEmpty
            ? const Align(alignment: Alignment.centerLeft, child: DataGapChip())
            : Wrap(
                spacing: Space.s,
                runSpacing: Space.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TypeBadges(item.profile.types, dense: true),
                  if (item.profile.availability.isGap) const DataGapChip(),
                ],
              ),
      ),
      trailing: CaughtButton(form: item.form.id),
    );
  }
}
