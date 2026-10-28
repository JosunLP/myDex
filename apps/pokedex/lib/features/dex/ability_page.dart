import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/game_context_selector.dart';

/// An ability and the Pokémon that have it in the selected game.
class AbilityPage extends ConsumerWidget {
  const AbilityPage({super.key, required this.abilityId});

  final AbilityId abilityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final ctx = ref.watch(gameContextProvider);
    final lang = dataLanguageOf(context, ref);
    final ability = catalog.abilities[abilityId];
    final textTheme = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    if (ability == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noResults(abilityId.value))),
      );
    }
    final holders = ref
        .watch(queriesProvider)
        .list(ctx)
        .map(
          (i) => (
            i,
            i.profile.abilities
                .where((a) => a.abilityId == abilityId)
                .firstOrNull,
          ),
        )
        .where((e) => e.$2 != null)
        .toList();

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
            child: Text(ability.name(lang), style: textTheme.headlineMedium),
          ),
          const SizedBox(height: Space.xl),
          Semantics(
            header: true,
            child: Text(
              l10n.abilityHolders(ctx.version.name(lang)),
              style: textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: Space.s),
          if (!ctx.ruleset.hasAbilities)
            Text(l10n.abilitiesNotApplicable)
          else if (holders.isEmpty)
            Text(l10n.noHolders)
          else
            for (final (item, slot) in holders)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(catalog.displayName(item.form)(lang)),
                subtitle: slot!.hidden ? Text(l10n.abilityHidden) : null,
                leading: Text(
                  '#${item.species.nationalNumber.toString().padLeft(4, '0')}',
                  style: textTheme.labelMedium?.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
                onTap: () => openPokemon(context, item.form.id, wide: wide),
              ),
        ],
      ),
    );
  }
}
