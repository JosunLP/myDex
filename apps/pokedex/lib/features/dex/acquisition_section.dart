import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/encounter_tile.dart';
import '../../widgets/game_context_selector.dart';

/// Locations and further ways of acquisition in the selected game.
/// Missing data is marked as a gap, never as "not catchable".
class AcquisitionSection extends ConsumerWidget {
  const AcquisitionSection({super.key, required this.form});

  final FormId form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final details = ref.watch(catalogDetailsProvider);
    final lang = dataLanguageOf(context, ref);
    final gameName = ctx.version.name(lang);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final national = NationalDex.isNational(ctx.versionId);
    final hasData = details.hasEncounterData(ctx.versionId);
    final encounters = hasData && !national
        ? details.encountersOf(form, ctx.versionId)
        : const <Encounter>[];
    final byLocation = <LocationId, List<Encounter>>{};
    for (final e in encounters) {
      final location = catalog.locationAreas[e.area]?.location;
      if (location != null) byLocation.putIfAbsent(location, () => []).add(e);
    }

    // Further ways: evolution and breeding.
    final detail = ref.watch(queriesProvider).detail(form, ctx);
    final from = detail.evolutions
        .where((e) => e.to.id == form)
        .map((e) => e.from)
        .toList();
    final root = detail.evolutions.isEmpty
        ? detail.form
        : detail.evolutions.first.from;
    final rootSpecies = catalog.species[root.speciesId]!;
    final canBreed =
        ctx.ruleset.hasBreeding &&
        detail.form.isDefault &&
        root.isDefault &&
        rootSpecies.hatchable &&
        detail.profile.availability == DataAvailability.confirmedAvailable;

    // Trades from other games (only if no locations are known here) and
    // event distributions for mythical Pokémon.
    final acquisition = AcquisitionQueries(catalog, details);
    final tradeFrom = byLocation.isEmpty && !national
        ? acquisition.tradeSources(form, ctx)
        : const <GameVersion>[];
    final eventOnly = acquisition.isEventOnly(form, ctx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (national)
          _EncounterGames(form: form)
        else ...[
          if (eventOnly)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: _Notice(
                icon: Icons.card_giftcard,
                text: l10n.acquireByEvent,
                color: scheme.primary,
              ),
            ),
          if (!hasData && !eventOnly)
            _Notice(
              icon: Icons.construction_outlined,
              text: l10n.noEncounterData(gameName),
              color: scheme.tertiary,
            )
          else if (byLocation.isEmpty && !eventOnly)
            Text(l10n.noEncountersForForm(gameName))
          else
            for (final MapEntry(key: location, value: list)
                in byLocation.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: Card.outlined(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(
                      '/dex/location/${Uri.encodeComponent(location.value)}',
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 18),
                              const SizedBox(width: Space.s),
                              Expanded(
                                child: Text(
                                  catalog.locations[location]?.displayName(
                                        lang,
                                      ) ??
                                      location.value,
                                  style: textTheme.titleSmall,
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          for (final e in list)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.s),
                              child: EncounterDetails(
                                encounter: e,
                                showArea:
                                    catalog.locationAreas[e.area]?.displayName(
                                      lang,
                                    ) !=
                                    catalog.locations[location]?.displayName(
                                      lang,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
        ],
        if (national && eventOnly)
          Padding(
            padding: const EdgeInsets.only(top: Space.s),
            child: _Notice(
              icon: Icons.card_giftcard,
              text: l10n.acquireByEvent,
              color: scheme.primary,
            ),
          ),
        if (tradeFrom.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.swap_horiz),
            title: Text(
              l10n.acquireByTrade(
                tradeFrom.map((v) => v.name(lang)).toSet().join(', '),
              ),
            ),
          ),
        for (final f in from)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.trending_up),
            title: Text(l10n.acquireByEvolution(catalog.displayName(f)(lang))),
          ),
        if (canBreed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.egg_outlined),
            title: Text(
              root.id == form
                  ? l10n.acquireByHatching
                  : l10n.acquireByBreedingFamily(
                      catalog.displayName(root)(lang),
                    ),
            ),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color),
      const SizedBox(width: Space.m),
      Expanded(child: Text(text)),
    ],
  );
}

/// International Pokédex: the games in which the Pokémon can be found.
/// Tapping one switches to that game (with undo), where the locations show.
class _EncounterGames extends ConsumerWidget {
  const _EncounterGames({required this.form});

  final FormId form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final details = ref.watch(catalogDetailsProvider);
    final lang = dataLanguageOf(context, ref);
    final versions = [
      for (final id in details.encounterVersionsOf(form).reversed)
        ?catalog.versionById(id),
    ];
    if (versions.isEmpty) return Text(l10n.noEncounterGames);

    void open(GameVersion v) {
      final settings = ref.read(settingsProvider.notifier);
      // Undo restores the game and the recently used games.
      final previous = ref.read(settingsProvider);
      settings.setGameVersion(v.id);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.switchedToGame(v.name(lang))),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => settings.restoreGame(previous),
            ),
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.encounterGames),
        const SizedBox(height: Space.m),
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            for (final v in versions)
              ActionChip(
                avatar: CircleAvatar(
                  radius: 6,
                  backgroundColor: generationColor(
                    catalog.versionGroups[v.versionGroupId]!.generation,
                  ),
                ),
                label: Text(v.name(lang)),
                onPressed: () => open(v),
              ),
          ],
        ),
      ],
    );
  }
}
