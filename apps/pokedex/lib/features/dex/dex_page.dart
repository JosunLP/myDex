import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/motion.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/settings.dart';
import '../../app/theme.dart';
import '../../brand/brand_mark.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/availability_notice.dart';
import '../../widgets/collection_toggles.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/form_artwork.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/motion.dart';
import '../../widgets/search_field.dart';
import '../../widgets/type_badge.dart';
import 'filter_sheet.dart';
import 'pokemon_detail_page.dart';

class DexQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

/// Search text of the Dex list; kept across selection and navigation.
final dexQueryProvider = NotifierProvider<DexQuery, String>(DexQuery.new);

/// Moves and abilities for the search query (full-text index in the catalog).
final entityResultsProvider = Provider<List<EntityHit>>((ref) {
  final query = ref.watch(dexQueryProvider).trim();
  if (query.isEmpty) return const [];
  return [
    for (final hit
        in ref.watch(catalogDetailsProvider).searchEntities(query, limit: 20))
      if (hit.kind != EntityKind.item) hit,
  ];
});

/// Result list in the current game context, filtered by the search.
final dexResultsProvider = Provider<List<PokemonListItem>>((ref) {
  final ctx = ref.watch(gameContextProvider);
  final filter = ref.watch(dexFilterProvider);
  final items = applyDexFilter(
    ref.watch(queriesProvider).list(ctx),
    filter,
    collection: filter.collection == CollectionFilter.all
        ? const {}
        : ref.watch(collectionProvider).value ?? const {},
    scope: collectionScopeOf(ctx),
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

  void _setQuery(String value) {
    ref.read(dexQueryProvider.notifier).set(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final browser = _DexBrowser(
      controller: _controller,
      focusNode: _searchFocus,
      onQuery: _setQuery,
      selected: wide ? widget.selected : null,
      wide: wide,
      onOpen: (id) => openPokemon(context, id, wide: wide),
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
          body: wide
              ? Row(
                  children: [
                    SizedBox(width: 400, child: browser),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: FadeThroughSwitcher(
                        child: widget.selected == null
                            ? _EmptyDetail(
                                key: const ValueKey('empty'),
                                text: l10n.detailEmpty,
                              )
                            : PokemonDetailView(
                                key: ValueKey(widget.selected),
                                formId: widget.selected!,
                              ),
                      ),
                    ),
                  ],
                )
              : browser,
        ),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Opacity(opacity: 0.9, child: BrandMark(size: 96)),
        const SizedBox(height: Space.l),
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

/// Search, context and results as one scrolling surface.
class _DexBrowser extends ConsumerWidget {
  const _DexBrowser({
    required this.controller,
    required this.focusNode,
    required this.onQuery,
    required this.selected,
    required this.wide,
    required this.onOpen,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onQuery;
  final FormId? selected;
  final bool wide;
  final ValueChanged<FormId> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.medium;
    final items = ref.watch(dexResultsProvider);
    final entities = ref.watch(entityResultsProvider);
    final query = ref.watch(dexQueryProvider);
    final ctx = ref.watch(gameContextProvider);
    final filter = ref.watch(dexFilterProvider);
    final layout = wide
        ? DexLayout.list
        : ref.watch(settingsProvider.select((s) => s.dexLayout));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final layoutToggle = wide
        ? null
        : IconButton(
            tooltip: layout == DexLayout.list
                ? l10n.layoutGrid
                : l10n.layoutList,
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .setDexLayout(
                  layout == DexLayout.list ? DexLayout.grid : DexLayout.list,
                ),
            icon: AnimatedSwitcher(
              duration: Motion.of(context, Motion.short),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween(begin: -0.25, end: 0.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                layout == DexLayout.list
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_outlined,
                key: ValueKey(layout),
              ),
            ),
          );

    final results = _results(context, ref, items, entities, query, layout);

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverAppBar(
          pinned: !phone,
          floating: phone,
          snap: phone,
          titleSpacing: Space.l,
          toolbarHeight: 64,
          title: phone ? const BrandLogo(size: 24) : Text(l10n.navDex),
          actions: [
            ?layoutToggle,
            const SizedBox(width: Space.s),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.s),
            child: Row(
              children: [
                const Flexible(child: GameContextSelector()),
                const SizedBox(width: Space.m),
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.short),
                  child: Text(
                    l10n.pokemonCount(items.length),
                    key: ValueKey(items.length),
                    style: textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SearchHeader(
            // Grows with the system text size so the field is never clipped.
            extent:
                Space.s +
                math.max(
                  56,
                  36 + MediaQuery.textScalerOf(context).scale(16) * 1.5,
                ),
            child: Container(
              color: scheme.surface,
              alignment: Alignment.center,
              padding: const EdgeInsets.fromLTRB(
                Space.l,
                Space.xs,
                Space.l,
                Space.xs,
              ),
              child: SearchField(
                controller: controller,
                focusNode: focusNode,
                hintText: l10n.searchHint,
                trailing: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).deleteButtonTooltip,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          onQuery('');
                        },
                      ),
                onChanged: onQuery,
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: FilterBar()),
        // A new context, filter or layout replays the staggered entrance.
        SliverEntranceScope(
          key: ValueKey((ctx.versionId, filter, layout)),
          sliver: results,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
      ],
    );
  }

  Widget _results(
    BuildContext context,
    WidgetRef ref,
    List<PokemonListItem> items,
    List<EntityHit> entities,
    String query,
    DexLayout layout,
  ) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (items.isEmpty && entities.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: Space.m),
              Text(
                l10n.noResults(query),
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.l, Space.l, Space.xs),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
    final moves = entities.where((e) => e.kind == EntityKind.move).toList();
    final abilities = entities
        .where((e) => e.kind == EntityKind.ability)
        .toList();
    final showHeaders = entities.isNotEmpty;

    final pokemon = layout == DexLayout.grid
        ? SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: Space.m,
                crossAxisSpacing: Space.m,
                childAspectRatio: 0.78,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => Entrance(
                index: i,
                child: _PokemonCard(
                  item: items[i],
                  hero: !wide,
                  onOpen: onOpen,
                ),
              ),
            ),
          )
        : SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => Entrance(
              index: i,
              child: _PokemonRow(
                item: items[i],
                selected: items[i].form.id == selected,
                hero: !wide,
                onOpen: onOpen,
              ),
            ),
          );

    Widget entityTile(IconData icon, String title, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.s),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(Radii.s),
              ),
              child: Icon(icon, color: scheme.onSecondaryContainer, size: 20),
            ),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );

    return SliverMainAxisGroup(
      slivers: [
        if (showHeaders && items.isNotEmpty)
          SliverToBoxAdapter(child: header(l10n.searchPokemon)),
        pokemon,
        if (moves.isNotEmpty) ...[
          SliverToBoxAdapter(child: header(l10n.searchMoves)),
          SliverList.list(
            children: [
              for (final m in moves)
                entityTile(
                  Icons.flash_on_outlined,
                  catalog.moves[MoveId(m.id)]?.name(lang) ?? m.id,
                  () => context.push('/dex/move/${Uri.encodeComponent(m.id)}'),
                ),
            ],
          ),
        ],
        if (abilities.isNotEmpty) ...[
          SliverToBoxAdapter(child: header(l10n.searchAbilities)),
          SliverList.list(
            children: [
              for (final a in abilities)
                entityTile(
                  Icons.bolt,
                  catalog.abilities[AbilityId(a.id)]?.name(lang) ?? a.id,
                  () =>
                      context.push('/dex/ability/${Uri.encodeComponent(a.id)}'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Starts a staggered entrance for the items of a sliver.
class SliverEntranceScope extends StatelessWidget {
  const SliverEntranceScope({super.key, required this.sliver});

  final Widget sliver;

  @override
  Widget build(BuildContext context) => EntranceScope(child: sliver);
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  const _SearchHeader({required this.extent, required this.child});

  final double extent;

  final Widget child;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrink, bool overlaps) =>
      SizedBox(height: extent, child: child);

  @override
  bool shouldRebuild(_SearchHeader old) =>
      old.child != child || old.extent != extent;
}

/// A Pokémon in the list: thumbnail, number, name and types.
class _PokemonRow extends ConsumerWidget {
  const _PokemonRow({
    required this.item,
    required this.selected,
    required this.hero,
    required this.onOpen,
  });

  final PokemonListItem item;
  final bool selected;
  final bool hero;
  final ValueChanged<FormId> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final name = catalog.displayName(item.form).resolve(lang);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 1),
      child: ListTile(
        selected: selected,
        onTap: () => onOpen(item.form.id),
        contentPadding: const EdgeInsets.only(left: Space.s, right: Space.xs),
        minVerticalPadding: Space.s,
        leading: DexThumb(item.form.id, size: 56, hero: hero),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name.text,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.onPrimaryContainer : null,
                ),
              ),
            ),
            const SizedBox(width: Space.s),
            Text(
              DexNumber.format(item.species.nationalNumber),
              style: textTheme.labelMedium?.copyWith(
                fontFamily: AppFonts.mono,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: Space.xs),
          child: item.profile.types.isEmpty
              ? const Align(
                  alignment: Alignment.centerLeft,
                  child: DataGapChip(),
                )
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
      ),
    );
  }
}

/// A Pokémon as a card in the grid: artwork on its own colour.
class _PokemonCard extends ConsumerWidget {
  const _PokemonCard({
    required this.item,
    required this.hero,
    required this.onOpen,
  });

  final PokemonListItem item;
  final bool hero;
  final ValueChanged<FormId> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tint = pokemonTint(ref, item.form.id, item.profile.types, scheme);
    final name = catalog.displayName(item.form)(lang);
    Widget art = FormArtwork(item.form.id, size: 112);
    if (hero) art = Hero(tag: pokemonHeroTag(item.form.id), child: art);
    return PressScale(
      child: Semantics(
        button: true,
        label: name,
        child: TintBackdrop(
          tint: tint,
          borderRadius: BorderRadius.circular(Radii.l),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => onOpen(item.form.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.m,
                  Space.s,
                  Space.xs,
                  Space.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DexNumber(item.species.nationalNumber, dense: true),
                        const Spacer(),
                        CaughtButton(form: item.form.id),
                      ],
                    ),
                    Expanded(child: Center(child: art)),
                    const SizedBox(height: Space.xs),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    TypeBadges(item.profile.types, dense: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
