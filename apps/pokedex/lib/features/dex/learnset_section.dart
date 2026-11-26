import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/move_row.dart';
import 'detail_sections.dart';

/// Learnable moves of a form in the selected game, grouped by method.
class LearnsetSection extends ConsumerWidget {
  const LearnsetSection({super.key, required this.form});

  final FormId form;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ctx = ref.watch(gameContextProvider);
    final details = ref.watch(catalogDetailsProvider);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final entries = details.learnset(form, ctx.versionGroupId);
    if (entries.isEmpty) return Text(l10n.noLearnset);

    // Groups in a fixed order; special methods separated by source key.
    final groups = <String, List<LearnsetEntry>>{};
    for (final method in LearnMethod.values) {
      for (final e in entries.where((e) => e.method == method)) {
        final key = method == LearnMethod.other
            ? 'other:${e.methodDetail ?? ''}'
            : method.key;
        groups.putIfAbsent(key, () => []).add(e);
      }
    }
    String title(String key) => switch (key) {
      'level-up' => l10n.learnLevelUp,
      'machine' => l10n.learnMachine,
      'egg' => l10n.learnEgg,
      'tutor' => l10n.learnTutor,
      _ => l10n.learnOtherMethod(key.substring(6).replaceAll('-', '_')),
    };
    String? leading(LearnsetEntry e) => switch (e.method) {
      LearnMethod.levelUp =>
        e.level == 0 ? l10n.learnLevelEvolve : l10n.learnLevel(e.level!),
      LearnMethod.machine => e.machine?.value.toUpperCase(),
      _ => null,
    };
    groups['machine']?.sort(
      (a, b) => (a.machine?.value ?? '').compareTo(b.machine?.value ?? ''),
    );
    int byName(LearnsetEntry a, LearnsetEntry b) =>
        (catalog.moves[a.move]?.name(lang) ?? a.move.value).compareTo(
          catalog.moves[b.move]?.name(lang) ?? b.move.value,
        );
    for (final e in groups.entries) {
      if (e.key != 'level-up' && e.key != 'machine') e.value.sort(byName);
    }
    // Moves of pre-evolutions are kept on evolution.
    final own = {for (final e in entries) e.move};
    final inherited = <MoveId, FormId>{};
    // From the same game as the form's own moves (International Pokédex).
    final group = learnsetGroupOf(form, ctx, details);
    for (final pre in preEvolutionsOf(catalog, form, ctx.versionGroupId)) {
      for (final e in details.learnset(pre, group)) {
        if (!own.contains(e.move)) inherited.putIfAbsent(e.move, () => pre);
      }
    }
    final inheritedSorted = inherited.entries.toList()
      ..sort(
        (a, b) => (catalog.moves[a.key]?.name(lang) ?? a.key.value).compareTo(
          catalog.moves[b.key]?.name(lang) ?? b.key.value,
        ),
      );
    final first = groups.keys.first;
    final source = NationalDex.isNational(ctx.versionId)
        ? details.newestLearnsetGroups()[form]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (source != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: InfoPill(
              icon: Icons.history_rounded,
              text: l10n.learnsetAsOf(
                catalog.versionGroups[source]?.name(lang) ?? source.value,
              ),
            ),
          ),
        for (final MapEntry(key: key, value: list) in groups.entries)
          ExpansionTile(
            key: PageStorageKey('learnset-$key'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: key == first,
            title: Text('${title(key)} (${list.length})'),
            children: [
              for (final e in list)
                MoveRow(
                  leading: leading(e),
                  name: catalog.moves[e.move]?.name(lang) ?? e.move.value,
                  profile: details.moveProfile(e.move, ctx.versionGroupId),
                  onTap: () => context.push(
                    '/dex/move/${Uri.encodeComponent(e.move.value)}',
                  ),
                ),
            ],
          ),
        if (inheritedSorted.isNotEmpty)
          ExpansionTile(
            key: const PageStorageKey('learnset-pre-evolution'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${l10n.learnPreEvolution} (${inheritedSorted.length})',
            ),
            children: [
              for (final MapEntry(key: move, value: source) in inheritedSorted)
                MoveRow(
                  leading: catalog.displayName(catalog.forms[source]!)(lang),
                  name: catalog.moves[move]?.name(lang) ?? move.value,
                  profile: details.moveProfile(move, ctx.versionGroupId),
                  onTap: () => context.push(
                    '/dex/move/${Uri.encodeComponent(move.value)}',
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
