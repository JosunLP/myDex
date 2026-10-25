import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/game_context_selector.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  bool _global = false;
  bool _shiny = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final items = ref.watch(queriesProvider).list(ctx);
    final entries = ref.watch(collectionProvider).value ?? const {};
    final controller = ref.read(collectionProvider.notifier);
    final scope = _global ? const GlobalScope() : GameScope(ctx.versionId);
    CollectionKey keyFor(FormId f) =>
        CollectionKey(scope: scope, form: f, shiny: _shiny);

    final caught = items
        .where((i) => entries[keyFor(i.form.id)]?.caught ?? false)
        .length;
    final seen = items
        .where((i) => entries[keyFor(i.form.id)]?.seen ?? false)
        .length;
    final storage = ref.watch(appStorageProvider).collection;
    final quarantined = storage is FileCollectionRepository
        ? storage.quarantinedPath
        : null;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;

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
        children: [
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
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(l10n.scopeThisGame),
                    ),
                    ButtonSegment(value: true, label: Text(l10n.scopeGlobal)),
                  ],
                  selected: {_global},
                  onSelectionChanged: (s) => setState(() => _global = s.single),
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
          Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.collectionProgress(caught, items.length),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l10n.collectionSeen(seen)),
                const SizedBox(height: Space.s),
                LinearProgressIndicator(
                  value: items.isEmpty ? 0 : caught / items.length,
                ),
              ],
            ),
          ),
          for (final item in items)
            CheckboxListTile(
              value: entries[keyFor(item.form.id)]?.caught ?? false,
              onChanged: (v) =>
                  controller.setCaught(keyFor(item.form.id), v ?? false),
              title: Text(catalog.displayName(item.form)(lang)),
              secondary: TextButton(
                onPressed: () => openPokemon(context, item.form.id, wide: wide),
                child: Text(
                  '#${item.species.nationalNumber.toString().padLeft(4, '0')}',
                  style: const TextStyle(fontFeatures: tabularFigures),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
