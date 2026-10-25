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
    return PopupMenuButton<String>(
      tooltip: l10n.selectGame,
      initialValue: ctx.versionId.value,
      onSelected: (id) => ref
          .read(settingsProvider.notifier)
          .setGameVersion(
            catalog.versions.firstWhere((v) => v.id.value == id).id,
          ),
      itemBuilder: (_) => [
        for (final v in catalog.versions)
          PopupMenuItem(
            value: v.id.value,
            child: Text(
              '${v.name(lang)}  ·  Gen ${catalog.versionGroups[v.versionGroupId]!.generation}',
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videogame_asset_outlined, size: 20),
            const SizedBox(width: 6),
            Semantics(
              label: l10n.selectGame,
              child: Text(ctx.version.name(lang)),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
