import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/catalog_update.dart';
import '../../app/providers.dart';
import '../../app/sync_controller.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';

/// Origin of the data and coverage per game (data quality as a feature).
class DataPage extends ConsumerWidget {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final details = ref.watch(catalogDetailsProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final source = details.source;
    final coverage = details.coverage().reversed.toList();
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataSources)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        children: [
          ListTile(
            leading: const Icon(Icons.dataset_outlined),
            title: Text(l10n.aboutCatalog(source.revision)),
            subtitle: SelectableText(
              l10n.dataSourceLine(source.source, source.sourceRevision),
            ),
          ),
          if (ref.watch(syncSupportedProvider)) const _CatalogUpdateTile(),
          Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Text(l10n.coverageExplanation, style: textTheme.bodySmall),
          ),
          for (final row in coverage)
            ListTile(
              title: Text(catalog.versionGroups[row.versionGroup]!.name(lang)),
              subtitle: Text(
                '${l10n.coverageRow(row.formsConfirmed, row.formsUnavailable, row.formsGaps)}\n'
                '${l10n.coverageLearnsets(row.learnsetEntries)} · '
                '${row.encounterEntries == 0 ? l10n.coverageNoEncounters : l10n.coverageEncounters(row.encounterEntries)}',
              ),
              isThreeLine: true,
              leading: Icon(
                row.formsGaps == 0
                    ? Icons.check_circle_outline
                    : Icons.construction_outlined,
                color: row.formsGaps == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.tertiary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Signed catalog updates via your own sync server (ADR 0015).
class _CatalogUpdateTile extends ConsumerWidget {
  const _CatalogUpdateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(catalogUpdateProvider);
    return ListTile(
      leading: const Icon(Icons.system_update_alt),
      title: Text(l10n.catalogUpdateTitle),
      subtitle: Text(
        status.result == null
            ? l10n.catalogUpdateHint
            : l10n.catalogUpdateResult(status.result!, status.revision ?? ''),
      ),
      isThreeLine: true,
      trailing: status.busy
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () => ref.read(catalogUpdateProvider.notifier).check(),
              child: Text(l10n.catalogUpdateCheck),
            ),
    );
  }
}
