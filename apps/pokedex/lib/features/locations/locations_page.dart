import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/search_field.dart';
import '../../widgets/game_context_selector.dart';

/// Locations with encounters in the selected game, grouped by region.
class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final details = ref.watch(catalogDetailsProvider);
    final lang = dataLanguageOf(context, ref);
    final gameName = ctx.version.name(lang);
    final q = normalizeSearchText(_query);

    final locations = [
      for (final id in details.locationsWithEncounters(ctx.versionId))
        if (catalog.locations[id] case final location?)
          if (q.isEmpty ||
              normalizeSearchText(location.displayName(lang)).contains(q))
            location,
    ];
    final byRegion = <RegionId?, List<Location>>{};
    for (final l in locations) {
      byRegion.putIfAbsent(l.region, () => []).add(l);
    }
    for (final list in byRegion.values) {
      list.sort((a, b) => a.displayName(lang).compareTo(b.displayName(lang)));
    }
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navLocations),
        actions: const [
          Flexible(child: GameContextSelector()),
          SizedBox(width: Space.s),
        ],
      ),
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
              hintText: l10n.locationSearchHint,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: !details.hasEncounterData(ctx.versionId)
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xl),
                      child: Text(
                        l10n.noLocationData(gameName),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : locations.isEmpty
                ? Center(child: Text(l10n.noResults(_query)))
                : ListView(
                    children: [
                      for (final MapEntry(key: region, value: list)
                          in byRegion.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            Space.l,
                            Space.l,
                            Space.l,
                            Space.xs,
                          ),
                          child: Semantics(
                            header: true,
                            child: Text(
                              region == null
                                  ? l10n.otherRegion
                                  : catalog.regionNames[region]?.call(lang) ??
                                        region.value,
                              style: textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                        for (final location in list)
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: Space.l,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(Radii.s),
                              ),
                              child: Icon(
                                Icons.place_outlined,
                                size: 20,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(location.displayName(lang)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.go(
                              '/locations/${Uri.encodeComponent(location.id.value)}',
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
