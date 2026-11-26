import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import '../../app/motion.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/motion.dart';

enum _View {
  /// The selected context: a game, or the International Pokédex.
  current,

  /// The International Pokédex's list while a game is selected.
  global,

  /// Marks of all games combined (read-only).
  allGames,
}

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  _View _view = _View.current;
  bool _shiny = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final national = ref.watch(isNationalProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final entries = ref.watch(collectionProvider).value ?? const {};
    var storage = ref.watch(appStorageProvider).collection;
    if (storage is SyncingCollectionRepository) storage = storage.inner;
    final quarantined = storage is FileCollectionRepository
        ? storage.quarantinedPath
        : null;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final dateFormat = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    // In the International Pokédex "current" already is the global list.
    final view = national && _view == _View.global ? _View.current : _view;

    Widget numberButton(PokemonForm form) => TextButton(
      onPressed: () => openPokemon(context, form.id, wide: wide),
      child: DexNumber(
        catalog.species[form.speciesId]!.nationalNumber,
        dense: true,
      ),
    );

    final int caught;
    final int total;
    final int? seen;
    final Widget list;
    if (view == _View.allGames) {
      // Global checklist: marks of all games combined (read-only).
      final overview = crossGameOverview(entries.values);
      final forms = catalog.forms.values.where((f) => f.isDefault).toList()
        ..sort(
          (a, b) => catalog.species[a.speciesId]!.nationalNumber.compareTo(
            catalog.species[b.speciesId]!.nationalNumber,
          ),
        );
      bool done(FormId f) => _shiny
          ? overview[f]?.shinyCaught ?? false
          : overview[f]?.caught ?? false;
      String gameNames(Set<GameVersionId> ids) => [
        for (final v in catalog.versions)
          if (ids.contains(v.id)) v.name(lang),
        if (ids.contains(const GameVersionId(''))) l10n.ownChecklist,
      ].join(', ');
      caught = forms.where((f) => done(f.id)).length;
      total = forms.length;
      seen = null;
      list = SliverList.builder(
        itemCount: forms.length,
        itemBuilder: (context, i) {
          final form = forms[i];
          final status = overview[form.id];
          final games = _shiny ? status?.shinyCaughtIn : status?.caughtIn;
          final isDone = done(form.id);
          return Entrance(
            index: i,
            child: ListTile(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.short),
                    child: Icon(
                      isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(isDone),
                      color: isDone
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  DexThumb(form.id, size: 44, shiny: _shiny),
                ],
              ),
              title: Text(catalog.displayName(form)(lang)),
              subtitle: games == null || games.isEmpty
                  ? null
                  : Text(
                      [
                        l10n.caughtInGames(gameNames(games)),
                        if (status?.firstCaughtAt case final at?)
                          l10n.caughtOn(dateFormat.format(at.toLocal())),
                      ].join(' · '),
                    ),
              trailing: numberButton(form),
            ),
          );
        },
      );
    } else {
      // The International list always covers every Pokémon, whichever game
      // is selected.
      final items = ref
          .watch(queriesProvider)
          .list(view == _View.global ? catalog.nationalContext : ctx);
      final scope = view == _View.global
          ? const GlobalScope()
          : collectionScopeOf(ctx);
      CollectionKey keyFor(FormId f) =>
          CollectionKey(scope: scope, form: f, shiny: _shiny);
      final controller = ref.read(collectionProvider.notifier);
      caught = items
          .where((i) => entries[keyFor(i.form.id)]?.caught ?? false)
          .length;
      total = items.length;
      seen = items
          .where((i) => entries[keyFor(i.form.id)]?.seen ?? false)
          .length;
      list = SliverList.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final entry = entries[keyFor(item.form.id)];
          return Entrance(
            index: i,
            child: CheckboxListTile(
              value: entry?.caught ?? false,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                controller.setCaught(keyFor(item.form.id), v ?? false);
              },
              title: Row(
                children: [
                  DexThumb(item.form.id, size: 44, shiny: _shiny),
                  const SizedBox(width: Space.m),
                  Expanded(child: Text(catalog.displayName(item.form)(lang))),
                ],
              ),
              subtitle: entry?.caughtAt == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 44 + Space.m),
                      child: Text(
                        l10n.caughtOn(
                          dateFormat.format(entry!.caughtAt!.toLocal()),
                        ),
                      ),
                    ),
              secondary: numberButton(item.form),
            ),
          );
        },
      );
    }

    final segments = [
      ButtonSegment(
        value: _View.current,
        label: Text(national ? l10n.scopeGlobal : l10n.scopeThisGame),
      ),
      if (!national)
        ButtonSegment(value: _View.global, label: Text(l10n.scopeGlobal)),
      ButtonSegment(value: _View.allGames, label: Text(l10n.scopeAllGames)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navCollection),
        actions: const [
          Flexible(child: GameContextSelector()),
          SizedBox(width: Space.s),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          if (quarantined != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.m),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber),
                    title: Text(l10n.storageRecovered(quarantined)),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.l),
            sliver: SliverToBoxAdapter(
              child: _ProgressCard(
                caught: caught,
                total: total,
                seen: seen,
                shiny: _shiny,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.l,
                Space.l,
                Space.l,
                Space.s,
              ),
              child: Wrap(
                spacing: Space.m,
                runSpacing: Space.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<_View>(
                    showSelectedIcon: false,
                    segments: segments,
                    selected: {view},
                    onSelectionChanged: (s) => setState(() => _view = s.single),
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.collectionShinyToggle),
                    selected: _shiny,
                    onSelected: (v) => setState(() => _shiny = v),
                  ),
                ],
              ),
            ),
          ),
          EntranceScope(
            key: ValueKey((view, _shiny, ctx.versionId)),
            child: list,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
        ],
      ),
    );
  }
}

/// Progress as an animated ring with the numbers next to it.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.caught,
    required this.total,
    required this.seen,
    required this.shiny,
  });

  final int caught;
  final int total;
  final int? seen;
  final bool shiny;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : caught / total;
    final color = shiny ? DexColors.ledYellow : scheme.primary;
    return TintBackdrop(
      tint: shiny ? DexColors.ledYellow : DexColors.red,
      strength: 0.55,
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 104,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: Motion.of(context, Motion.reveal),
                curve: Motion.enter,
                builder: (context, t, _) => CustomPaint(
                  painter: _RingPainter(
                    fraction: t,
                    color: color,
                    track: scheme.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: Text(
                      // One decimal while small, so early progress shows.
                      '${NumberFormat(t < 0.1 ? '0.0' : '0', Localizations.localeOf(context).toLanguageTag()).format((t * 1000).floor() / 10)} %',
                      style: textTheme.titleLarge?.copyWith(
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.xl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.collectionProgress(caught, total),
                    style: textTheme.titleMedium,
                  ),
                  if (seen != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      l10n.collectionSeen(seen!),
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: Space.m),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: fraction),
                      duration: Motion.of(context, Motion.reveal),
                      curve: Motion.enter,
                      builder: (context, t, _) => LinearProgressIndicator(
                        value: t,
                        minHeight: 8,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.1;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
