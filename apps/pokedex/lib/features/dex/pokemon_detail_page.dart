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
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/availability_notice.dart';
import '../../widgets/collection_toggles.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/form_artwork.dart';
import '../../widgets/form_sprite.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/motion.dart';
import '../../widgets/stat_bars.dart';
import '../../widgets/type_badge.dart';
import 'acquisition_section.dart';
import 'detail_sections.dart';
import 'dex_page.dart';
import 'gallery_section.dart';
import 'learnset_section.dart';
import 'pokemon_speech.dart';

/// Standalone detail page for narrow windows. Swipe sideways to browse the
/// current Dex results.
class PokemonDetailPage extends ConsumerStatefulWidget {
  const PokemonDetailPage({super.key, required this.formId});

  final FormId formId;

  @override
  ConsumerState<PokemonDetailPage> createState() => _PokemonDetailPageState();
}

class _PokemonDetailPageState extends ConsumerState<PokemonDetailPage> {
  /// The results at the time the page opened: browsing stays stable even
  /// if the list changes in the background.
  late final List<FormId> _ids = () {
    final ids = [for (final i in ref.read(dexResultsProvider)) i.form.id];
    return ids.contains(widget.formId) ? ids : [widget.formId];
  }();
  late int _index = _ids.indexOf(widget.formId);
  late final _pages = PageController(initialPage: _index);
  bool _scrolled = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > 220;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final scheme = Theme.of(context).colorScheme;
    final form = catalog.forms[_ids[_index]];
    final title = form == null ? '' : catalog.displayName(form)(lang);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _scrolled
            ? scheme.surfaceContainer
            : Colors.transparent,
        title: AnimatedOpacity(
          opacity: _scrolled ? 1 : 0,
          duration: Motion.of(context, Motion.short),
          child: Text(title, overflow: TextOverflow.ellipsis),
        ),
        actions: const [
          Flexible(child: GameContextSelector()),
          SizedBox(width: Space.s),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _pages,
          itemCount: _ids.length,
          onPageChanged: (i) {
            HapticFeedback.selectionClick();
            setState(() {
              _index = i;
              _scrolled = false;
            });
          },
          itemBuilder: (context, i) =>
              PokemonDetailView(formId: _ids[i], standalone: true),
        ),
      ),
    );
  }
}

/// Detail content, exclusively with data of the selected game context.
class PokemonDetailView extends ConsumerWidget {
  const PokemonDetailView({
    super.key,
    required this.formId,
    this.standalone = false,
  });

  final FormId formId;

  /// On its own page (under a transparent app bar) instead of next to the
  /// list.
  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    if (!catalog.forms.containsKey(formId)) {
      return Center(child: Text(l10n.noResults(formId.value)));
    }
    final d = ref.watch(queriesProvider).detail(formId, ctx);
    final name = catalog.displayName(d.form).resolve(lang);
    final gameName = ctx.version.name(lang);
    final profile = d.profile;

    var i = 0;
    final sections = <Widget>[
      if (profile.availability != DataAvailability.confirmedAvailable)
        Padding(
          padding: const EdgeInsets.only(top: Space.m),
          child: AvailabilityNotice(
            availability: profile.availability,
            pokemonName: name.text,
            gameName: gameName,
          ),
        ),
      if (profile.baseStats != null)
        DetailSection(
          index: i++,
          title: l10n.sectionStats,
          icon: Icons.bar_chart_rounded,
          child: StatBars(
            stats: profile.baseStats!,
            unifiedSpecial: ctx.ruleset.unifiedSpecial,
          ),
        ),
      if (profile.types.isNotEmpty)
        DetailSection(
          index: i++,
          title: l10n.sectionMatchups,
          subtitle: l10n.matchupHint,
          icon: Icons.shield_outlined,
          child: TypeMatchups(
            types: profile.types,
            era: ctx.ruleset.typeChartEra,
          ),
        ),
      if (profile.availability == DataAvailability.confirmedAvailable)
        DetailSection(
          index: i++,
          title: l10n.sectionAbilities,
          icon: Icons.bolt,
          child: !d.abilitiesApplicable
              ? Text(l10n.abilitiesNotApplicable)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in d.abilities)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Space.xs,
                        ),
                        onTap: () => context.push(
                          '/dex/ability/${Uri.encodeComponent(a.ability.id.value)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        leading: Icon(
                          a.hidden ? Icons.visibility_off_outlined : Icons.bolt,
                        ),
                        title: Text(a.ability.name(lang)),
                        subtitle: a.hidden ? Text(l10n.abilityHidden) : null,
                      ),
                  ],
                ),
        ),
      DetailSection(
        index: i++,
        title: l10n.sectionEvolution,
        icon: Icons.auto_graph_rounded,
        child: d.evolutions.isEmpty
            ? Text(l10n.noEvolution)
            : EvolutionChain(evolutions: d.evolutions, current: d.form.id),
      ),
      if (d.otherForms.isNotEmpty)
        DetailSection(
          index: i++,
          title: l10n.sectionForms,
          icon: Icons.style_outlined,
          child: OtherForms(forms: d.otherForms, current: d.form.id),
        ),
      if (profile.availability != DataAvailability.confirmedUnavailable) ...[
        DetailSection(
          index: i++,
          title: l10n.sectionAcquisition,
          icon: Icons.place_outlined,
          child: AcquisitionSection(form: d.form.id),
        ),
        DetailSection(
          index: i++,
          title: l10n.sectionMoves,
          icon: Icons.flash_on_outlined,
          child: LearnsetSection(form: d.form.id),
        ),
      ],
      DetailSection(
        index: i++,
        title: l10n.sectionGallery,
        icon: Icons.photo_library_outlined,
        child: GallerySection(form: d.form.id, name: name.text),
      ),
    ];

    // Switching the game keeps the scroll position; values glide instead.
    return EntranceScope(
      key: ValueKey(formId),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(detail: d, standalone: standalone),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final side = math.max(
                Space.l,
                (constraints.crossAxisExtent - 760) / 2,
              );
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 0, side, Space.xxxl),
                sliver: SliverList.list(children: sections),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Coloured header with artwork, number, name, types and collection status.
class _Header extends ConsumerWidget {
  const _Header({required this.detail, required this.standalone});

  final PokemonDetail detail;
  final bool standalone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final ctx = ref.watch(gameContextProvider);
    final national = ref.watch(isNationalProvider);
    final lang = dataLanguageOf(context, ref);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final d = detail;
    final name = catalog.displayName(d.form).resolve(lang);
    final tint = pokemonTint(ref, d.form.id, d.profile.types, scheme);
    final top = standalone
        ? MediaQuery.paddingOf(context).top + kToolbarHeight
        : Space.l;
    final source = national ? catalog.national.profileSource(d.form.id) : null;

    Widget artwork = FormArtwork(d.form.id, size: 220);
    if (standalone) {
      artwork = Hero(tag: pokemonHeroTag(d.form.id), child: artwork);
    }

    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: Motion.of(context, Motion.long),
      curve: Motion.standard,
      builder: (context, color, child) => PokemonHeader(
        tint: color ?? tint,
        borderRadius: standalone
            ? const BorderRadius.vertical(bottom: Radius.circular(Radii.xl))
            : BorderRadius.circular(Radii.xl),
        margin: standalone
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(Space.l, 0, Space.l, 0),
        child: child!,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.l, top, Space.l, Space.xl),
        child: Column(
          children: [
            Row(
              children: [
                DexNumber(d.species.nationalNumber),
                const Spacer(),
                if (!standalone) _NeighbourButtons(current: d.form.id),
              ],
            ),
            SizedBox(
              height: 232,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft shadow under the artwork.
                  Positioned(
                    bottom: 14,
                    child: Container(
                      width: 150,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: RadialGradient(
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  artwork,
                  // The selected game's sprite as a small detail.
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: FormSprite(
                      d.form.id,
                      key: const ValueKey('dexScreenSprite'),
                      size: 64,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.s),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      name.text,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                  ),
                ),
                if (name.isFallback)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.s),
                    child: Tooltip(
                      message: l10n.translationMissing(name.language),
                      child: const Icon(Icons.translate, size: 20),
                    ),
                  ),
                const SizedBox(width: Space.xs),
                SpeakButton(
                  id: 'pokemon:${d.form.id.value}:${ctx.version.id.value}',
                  text: () => pokemonSpeechText(
                    d,
                    l10n,
                    catalog,
                    Localizations.localeOf(context).languageCode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s),
            if (d.profile.types.isNotEmpty)
              Semantics(
                label: l10n.sectionTypes,
                child: FadeThroughSwitcher(
                  alignment: Alignment.center,
                  child: TypeBadges(
                    d.profile.types,
                    key: ValueKey(d.profile.types),
                  ),
                ),
              ),
            if (source != null) ...[
              const SizedBox(height: Space.m),
              InfoPill(
                icon: Icons.history_rounded,
                text: l10n.dataAsOf(catalog.versionGroups[source]!.name(lang)),
                tooltip: l10n.dataAsOfHint,
              ),
            ],
            const SizedBox(height: Space.l),
            CollectionToggles(form: d.form.id),
          ],
        ),
      ),
    );
  }
}

/// The coloured header surface of a Pokémon (artwork colour).
class PokemonHeader extends StatelessWidget {
  const PokemonHeader({
    super.key,
    required this.tint,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.margin = EdgeInsets.zero,
  });

  final Color tint;
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: TintBackdrop(tint: tint, borderRadius: borderRadius, child: child),
  );
}

/// Previous/next Pokémon of the results (list and detail side by side).
class _NeighbourButtons extends ConsumerWidget {
  const _NeighbourButtons({required this.current});

  final FormId current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(dexResultsProvider);
    final i = items.indexWhere((x) => x.form.id == current);
    void go(int index) =>
        openPokemon(context, items[index].form.id, wide: true);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: l10n.previousPokemon,
          onPressed: i > 0 ? () => go(i - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        const SizedBox(width: Space.xs),
        IconButton.filledTonal(
          tooltip: l10n.nextPokemon,
          onPressed: i >= 0 && i < items.length - 1 ? () => go(i + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
