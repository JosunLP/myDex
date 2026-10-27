import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/type_badge.dart';

/// A move in the selected game, its history and who learns it.
class MovePage extends ConsumerWidget {
  const MovePage({super.key, required this.moveId});

  final MoveId moveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final details = ref.watch(catalogDetailsProvider);
    final ctx = ref.watch(gameContextProvider);
    final lang = dataLanguageOf(context, ref);
    final move = catalog.moves[moveId];
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    final gameName = ctx.version.name(lang);

    if (move == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noResults(moveId.value))),
      );
    }
    final profile = details.moveProfile(moveId, ctx.versionGroupId);
    final history = _collapse(details.moveHistory(moveId));
    final learners = details.learnersOf(moveId, ctx.versionGroupId)
      ..sort((a, b) {
        final fa = catalog.forms[a.form]!, fb = catalog.forms[b.form]!;
        final na = catalog.species[fa.speciesId]!.nationalNumber;
        final nb = catalog.species[fb.speciesId]!.nationalNumber;
        return na != nb
            ? na.compareTo(nb)
            : a.form.value.compareTo(b.form.value);
      });
    String num(int? v) => v?.toString() ?? l10n.valueNone;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: textTheme.titleMedium),
          ),
          const SizedBox(height: Space.s),
          child,
        ],
      ),
    );

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
            child: Text(move.name(lang), style: textTheme.headlineMedium),
          ),
          const SizedBox(height: Space.m),
          if (profile == null)
            Text(l10n.moveNotInGame(gameName))
          else
            Wrap(
              spacing: Space.xl,
              runSpacing: Space.m,
              children: [
                _Fact(l10n.moveType, TypeBadge(profile.type)),
                _Fact(
                  l10n.moveCategory,
                  Text(l10n.damageClass(profile.damageClass.name)),
                ),
                _Fact(l10n.movePower, Text(num(profile.power))),
                _Fact(l10n.moveAccuracy, Text(num(profile.accuracy))),
                _Fact(l10n.movePp, Text(num(profile.pp))),
                _Fact(l10n.movePriority, Text('${profile.priority}')),
              ],
            ),
          if (history.length > 1)
            section(
              l10n.moveHistory,
              Column(
                children: [
                  for (final (from, to, p) in history)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        from == to
                            ? catalog.versionGroups[from]!.name(lang)
                            : '${catalog.versionGroups[from]!.name(lang)} – ${catalog.versionGroups[to]!.name(lang)}',
                      ),
                      subtitle: Text(
                        '${l10n.typeName(p.type.key)} · ${l10n.damageClass(p.damageClass.name)} · '
                        '${l10n.movePower} ${num(p.power)} · ${l10n.moveAccuracy} ${num(p.accuracy)} · '
                        '${l10n.movePp} ${num(p.pp)}',
                      ),
                    ),
                ],
              ),
            ),
          section(
            l10n.moveLearners(gameName),
            learners.isEmpty
                ? Text(l10n.noLearners)
                : Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      for (final learner in learners)
                        ActionChip(
                          label: Text(
                            catalog.displayName(catalog.forms[learner.form]!)(
                              lang,
                            ),
                          ),
                          onPressed: () =>
                              openPokemon(context, learner.form, wide: wide),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Merges consecutive version groups with equal data.
  static List<(VersionGroupId, VersionGroupId, MoveGameProfile)> _collapse(
    List<(VersionGroupId, MoveGameProfile)> history,
  ) {
    final result = <(VersionGroupId, VersionGroupId, MoveGameProfile)>[];
    for (final (group, profile) in history) {
      if (result.isNotEmpty && result.last.$3.sameValuesAs(profile)) {
        result[result.length - 1] = (result.last.$1, group, result.last.$3);
      } else {
        result.add((group, group, profile));
      }
    }
    return result;
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: Space.xs),
      DefaultTextStyle.merge(
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontFeatures: tabularFigures),
        child: value,
      ),
    ],
  );
}
