import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../l10n/generated/app_localizations.dart';

/// Globale Spielauswahl – der Spielkontext ist immer sichtbar.
class GameContextSelector extends ConsumerWidget {
  const GameContextSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final ctx = ref.watch(gameContextProvider);
    final lang = dataLanguageOf(context, ref);
    final items = <PopupMenuEntry<String>>[];
    int? lastGen;
    // Neueste Spiele zuerst, nach Generation gruppiert.
    for (final v in catalog.versions.reversed) {
      final group = catalog.versionGroups[v.versionGroupId]!;
      if (group.generation != lastGen) {
        if (lastGen != null) items.add(const PopupMenuDivider());
        items.add(
          PopupMenuItem<String>(
            enabled: false,
            height: 32,
            child: Text(
              l10n.generationLabel(group.generation),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        );
        lastGen = group.generation;
      }
      items.add(
        PopupMenuItem(
          value: v.id.value,
          child: Text(
            group.hasData
                ? v.name(lang)
                : '${v.name(lang)} (${l10n.noGameData})',
          ),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: l10n.selectGame,
      initialValue: ctx.versionId.value,
      onSelected: (id) => ref
          .read(settingsProvider.notifier)
          .setGameVersion(
            catalog.versions.firstWhere((v) => v.id.value == id).id,
          ),
      itemBuilder: (_) => items,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videogame_asset_outlined, size: 20),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Semantics(
                label: l10n.selectGame,
                child: Text(
                  ctx.version.name(lang),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
