import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/move_row.dart';

/// Erlernbare Attacken einer Form im gewählten Spiel, nach Methode gruppiert.
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

    // Gruppen in fester Reihenfolge; Sondermethoden je Quellschlüssel getrennt.
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
    final first = groups.keys.first;

    return Column(
      children: [
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
      ],
    );
  }
}
