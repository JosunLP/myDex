import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/game_context_selector.dart';

enum _View { game, global, allGames }

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  _View _view = _View.game;
  bool _shiny = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final entries = ref.watch(collectionProvider).value ?? const {};
    final storage = ref.watch(appStorageProvider).collection;
    final quarantined = storage is FileCollectionRepository
        ? storage.quarantinedPath
        : null;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final dateFormat = DateFormat.yMd(
      Localizations.localeOf(context).toLanguageTag(),
    );

    final header = <Widget>[
      if (quarantined != null)
        Padding(
          padding: const EdgeInsets.all(Space.l),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.warning_amber),
              title: Text(l10n.storageRecovered(quarantined)),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        child: Wrap(
          spacing: Space.l,
          runSpacing: Space.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<_View>(
              segments: [
                ButtonSegment(
                  value: _View.game,
                  label: Text(l10n.scopeThisGame),
                ),
                ButtonSegment(
                  value: _View.global,
                  label: Text(l10n.scopeGlobal),
                ),
                ButtonSegment(
                  value: _View.allGames,
                  label: Text(l10n.scopeAllGames),
                ),
              ],
              selected: {_view},
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
    ];

    Widget progress(int caught, int total) => Padding(
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.collectionProgress(caught, total),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Space.s),
          LinearProgressIndicator(value: total == 0 ? 0 : caught / total),
        ],
      ),
    );

    Widget numberButton(PokemonForm form) => TextButton(
      onPressed: () => openPokemon(context, form.id, wide: wide),
      child: Text(
        '#${catalog.species[form.speciesId]!.nationalNumber.toString().padLeft(4, '0')}',
        style: const TextStyle(fontFeatures: tabularFigures),
      ),
    );

    final List<Widget> body;
    if (_view == _View.allGames) {
      // Globale Checkliste: Markierungen aller Spiele zusammengefasst (nur lesend).
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
      body = [
        progress(forms.where((f) => done(f.id)).length, forms.length),
        for (final form in forms)
          Builder(
            builder: (context) {
              final status = overview[form.id];
              final games = _shiny ? status?.shinyCaughtIn : status?.caughtIn;
              return ListTile(
                leading: Icon(
                  done(form.id)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: done(form.id)
                      ? Theme.of(context).colorScheme.primary
                      : null,
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
              );
            },
          ),
      ];
    } else {
      final items = ref.watch(queriesProvider).list(ctx);
      final scope = _view == _View.global
          ? const GlobalScope()
          : GameScope(ctx.versionId);
      CollectionKey keyFor(FormId f) =>
          CollectionKey(scope: scope, form: f, shiny: _shiny);
      final controller = ref.read(collectionProvider.notifier);
      final caught = items
          .where((i) => entries[keyFor(i.form.id)]?.caught ?? false)
          .length;
      body = [
        progress(caught, items.length),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.l),
          child: Text(
            l10n.collectionSeen(
              items
                  .where((i) => entries[keyFor(i.form.id)]?.seen ?? false)
                  .length,
            ),
          ),
        ),
        for (final item in items)
          Builder(
            builder: (context) {
              final entry = entries[keyFor(item.form.id)];
              return CheckboxListTile(
                value: entry?.caught ?? false,
                onChanged: (v) =>
                    controller.setCaught(keyFor(item.form.id), v ?? false),
                title: Text(catalog.displayName(item.form)(lang)),
                subtitle: entry?.caughtAt == null
                    ? null
                    : Text(
                        l10n.caughtOn(
                          dateFormat.format(entry!.caughtAt!.toLocal()),
                        ),
                      ),
                secondary: numberButton(item.form),
              );
            },
          ),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navCollection),
        actions: const [
          GameContextSelector(),
          SizedBox(width: Space.s),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        children: [...header, ...body],
      ),
    );
  }
}
