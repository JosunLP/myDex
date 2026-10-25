import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/encounter_tile.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/type_badge.dart';

/// Ein Ort: welche Pokémon dort in der gewählten Version vorkommen.
class LocationPage extends ConsumerWidget {
  const LocationPage({super.key, required this.locationId});

  final LocationId locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final details = ref.watch(catalogDetailsProvider);
    final lang = dataLanguageOf(context, ref);
    final location = catalog.locations[locationId];
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    if (location == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noResults(locationId.value))),
      );
    }
    final gameName = ctx.version.name(lang);
    final encounters = details.encountersAt(locationId, ctx.versionId);
    final byArea = <LocationAreaId, List<Encounter>>{};
    for (final e in encounters) {
      byArea.putIfAbsent(e.area, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        actions: const [
          GameContextSelector(),
          SizedBox(width: Space.s),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.l),
        children: [
          Semantics(
            header: true,
            child: Text(location.name(lang), style: textTheme.headlineMedium),
          ),
          if (location.region case final region?)
            Text(
              catalog.regionNames[region]?.call(lang) ?? region.value,
              style: textTheme.bodyMedium,
            ),
          const SizedBox(height: Space.l),
          if (!details.hasEncounterData(ctx.versionId))
            Text(l10n.noLocationData(gameName))
          else if (encounters.isEmpty)
            Text(l10n.noEncountersHere(gameName))
          else
            for (final MapEntry(key: area, value: list) in byArea.entries) ...[
              if (byArea.length > 1)
                Padding(
                  padding: const EdgeInsets.only(
                    top: Space.l,
                    bottom: Space.xs,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      catalog.locationAreas[area]?.name(lang) ?? area.value,
                      style: textTheme.titleMedium,
                    ),
                  ),
                ),
              for (final e in list)
                if (catalog.forms[e.form] case final form?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => openPokemon(context, form.id, wide: wide),
                    title: Wrap(
                      spacing: Space.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(catalog.displayName(form)(lang)),
                        TypeBadges(
                          form.profileFor(ctx.versionGroupId).types,
                          dense: true,
                        ),
                      ],
                    ),
                    subtitle: EncounterDetails(encounter: e),
                  ),
            ],
        ],
      ),
    );
  }
}
