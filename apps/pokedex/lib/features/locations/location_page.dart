import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/encounter_tile.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/type_badge.dart';

/// A location: which Pokémon occur there in the selected version. In the
/// International Pokédex the game is chosen on the page.
class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({super.key, required this.locationId});

  final LocationId locationId;

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  /// Game chosen on this page (International Pokédex only).
  GameVersionId? _version;

  LocationId get locationId => widget.locationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final global = ref.watch(gameContextProvider);
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
    final national = NationalDex.isNational(global.versionId);
    final versions = national
        ? [
            for (final id in details.encounterVersionsAt(locationId).reversed)
              ?catalog.versionById(id),
          ]
        : const <GameVersion>[];
    final chosen =
        versions.where((v) => v.id == _version).firstOrNull ??
        versions.firstOrNull;
    final ctx = chosen == null ? global : catalog.contextFor(chosen.id);
    final gameName = ctx.version.name(lang);
    final encounters = details.encountersAt(locationId, ctx.versionId);
    final byArea = <LocationAreaId, List<Encounter>>{};
    for (final e in encounters) {
      byArea.putIfAbsent(e.area, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(
        actions: const [
          Flexible(child: GameContextSelector()),
          SizedBox(width: Space.s),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.l),
        children: [
          Semantics(
            header: true,
            child: Text(
              location.displayName(lang),
              style: textTheme.headlineMedium,
            ),
          ),
          if (location.region case final region?)
            Text(
              catalog.regionNames[region]?.call(lang) ?? region.value,
              style: textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: Space.l),
          if (national && versions.isNotEmpty) ...[
            Text(l10n.locationNationalHint, style: textTheme.bodyMedium),
            const SizedBox(height: Space.s),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final v in versions)
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: generationColor(
                        catalog.versionGroups[v.versionGroupId]!.generation,
                      ),
                    ),
                    label: Text(v.name(lang)),
                    selected: v.id == chosen?.id,
                    onSelected: (_) => setState(() => _version = v.id),
                  ),
              ],
            ),
            const SizedBox(height: Space.l),
          ],
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Space.xs,
                    ),
                    leading: DexThumb(
                      form.id,
                      size: 48,
                      version: ctx.versionId,
                    ),
                    onTap: () => openPokemon(context, form.id, wide: wide),
                    title: Wrap(
                      spacing: Space.s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(catalog.displayName(form)(lang)),
                        TypeBadges(
                          catalog.profileOf(form, ctx.versionGroupId).types,
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
