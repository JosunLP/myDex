import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/text_input_dialog.dart';

/// Bar with the filter button and saved presets.
class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(dexFilterProvider);
    final presets = ref.watch(presetsProvider).value ?? const [];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.l),
        children: [
          Center(
            child: FilterChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: Text(
                filter.isEmpty
                    ? l10n.filters
                    : l10n.filtersActive(filter.activeCount),
              ),
              selected: !filter.isEmpty,
              onSelected: (_) => showFilterSheet(context),
            ),
          ),
          for (final preset in presets)
            Padding(
              padding: const EdgeInsets.only(left: Space.s),
              child: Center(
                child: GestureDetector(
                  onLongPress: () => _confirmDelete(context, ref, preset),
                  child: ChoiceChip(
                    label: Text(preset.name),
                    selected: preset.filter == filter,
                    onSelected: (selected) => ref
                        .read(dexFilterProvider.notifier)
                        .set(selected ? preset.filter : const DexFilter()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FilterPreset preset,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePreset),
        content: Text(preset.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(presetsProvider.notifier).remove(preset.id);
  }
}

Future<void> showFilterSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FilterSheet(),
    );

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late DexFilter _filter = ref.read(dexFilterProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final generations = {for (final s in catalog.species.values) s.generation}
      ..remove(0);
    final textTheme = Theme.of(context).textTheme;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.l, bottom: Space.s),
      child: Semantics(
        header: true,
        child: Text(text, style: textTheme.titleSmall),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Space.l, 0, Space.l, Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.filters, style: textTheme.titleLarge),
              heading(l10n.filterTypes),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final t in PokemonType.values)
                    FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: typeColor(t),
                        radius: 6,
                      ),
                      label: Text(l10n.typeName(t.key)),
                      selected: _filter.types.contains(t),
                      onSelected: (on) => setState(() {
                        _filter = _filter.copyWith(
                          types: on
                              ? {..._filter.types, t}
                              : ({..._filter.types}..remove(t)),
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: Space.s),
              SegmentedButton<TypeMatch>(
                segments: [
                  ButtonSegment(
                    value: TypeMatch.any,
                    label: Text(l10n.typeMatchAny),
                  ),
                  ButtonSegment(
                    value: TypeMatch.all,
                    label: Text(l10n.typeMatchAll),
                  ),
                ],
                selected: {_filter.typeMatch},
                onSelectionChanged: (s) => setState(
                  () => _filter = _filter.copyWith(typeMatch: s.single),
                ),
              ),
              heading(l10n.filterGenerations),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final g in generations.toList()..sort())
                    FilterChip(
                      label: Text('$g'),
                      selected: _filter.generations.contains(g),
                      onSelected: (on) => setState(() {
                        _filter = _filter.copyWith(
                          generations: on
                              ? {..._filter.generations, g}
                              : ({..._filter.generations}..remove(g)),
                        );
                      }),
                    ),
                ],
              ),
              heading(l10n.filterCollection),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (final (value, label) in [
                    (CollectionFilter.all, l10n.collectionFilterAll),
                    (CollectionFilter.caught, l10n.collectionFilterCaught),
                    (CollectionFilter.missing, l10n.collectionFilterMissing),
                    (
                      CollectionFilter.shinyMissing,
                      l10n.collectionFilterShinyMissing,
                    ),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter.collection == value,
                      onSelected: (_) => setState(
                        () => _filter = _filter.copyWith(collection: value),
                      ),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.defaultFormsOnly),
                value: _filter.defaultFormsOnly,
                onChanged: (v) => setState(
                  () => _filter = _filter.copyWith(defaultFormsOnly: v),
                ),
              ),
              const SizedBox(height: Space.l),
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        setState(() => _filter = const DexFilter()),
                    child: Text(l10n.resetFilters),
                  ),
                  OutlinedButton(
                    onPressed: _filter.isEmpty ? null : _savePreset,
                    child: Text(l10n.savePreset),
                  ),
                  FilledButton(
                    onPressed: () {
                      ref.read(dexFilterProvider.notifier).set(_filter);
                      Navigator.pop(context);
                    },
                    child: Text(l10n.apply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePreset() async {
    final l10n = AppLocalizations.of(context);
    final name = await showTextInputDialog(
      context,
      title: l10n.savePreset,
      label: l10n.presetName,
      confirm: l10n.save,
      cancel: l10n.cancel,
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(presetsProvider.notifier).add(name.trim(), _filter);
    ref.read(dexFilterProvider.notifier).set(_filter);
    if (mounted) Navigator.pop(context);
  }
}
