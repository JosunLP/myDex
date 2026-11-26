import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../brand/brand_mark.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/game_context_selector.dart';
import '../../widgets/motion.dart';
import 'team_widgets.dart';

/// Team list. New teams are created for the currently selected Pokédex or
/// game.
class TeamsPage extends ConsumerWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final teams = ref.watch(teamsProvider).value ?? const [];

    Future<void> create() async {
      final ctx = ref.read(gameContextProvider);
      final team = await ref
          .read(teamsProvider.notifier)
          .create(l10n.defaultTeamName(teams.length + 1), ctx.versionId);
      if (context.mounted) context.go('/teams/${team.id}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.teamsTitle),
        actions: const [
          Flexible(child: GameContextSelector()),
          SizedBox(width: Space.s),
        ],
      ),
      floatingActionButton: teams.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: Text(l10n.newTeam),
              onPressed: create,
            ),
      body: teams.isEmpty
          ? _EmptyTeams(onCreate: create)
          : EntranceScope(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  Space.l,
                  Space.s,
                  Space.l,
                  96,
                ),
                itemCount: teams.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.m),
                itemBuilder: (context, i) => Entrance(
                  index: i,
                  child: _TeamCard(team: teams[i]),
                ),
              ),
            ),
    );
  }
}

class _EmptyTeams extends StatelessWidget {
  const _EmptyTeams({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.all(Space.xs),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: i == 1
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(Radii.m),
                        ),
                        child: i == 1
                            ? const Center(child: BrandMark(size: 36))
                            : Icon(Icons.add, color: scheme.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Space.xl),
              Text(
                l10n.teamsEmptyTitle,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: Space.s),
              Text(
                l10n.teamsEmpty,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.xl),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(l10n.newTeam),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamCard extends ConsumerWidget {
  const _TeamCard({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final evaluator = evaluatorFor(ref, team);
    final status = evaluator.check(team).status;
    final version = catalog.versionById(team.version);
    final party = evaluator.context.ruleset.partySize;
    final names = [
      for (final m in team.members)
        if (catalog.forms[m.form] case final f?) catalog.displayName(f)(lang),
    ];
    return PressScale(
      child: Card(
        child: InkWell(
          onTap: () => context.go('/teams/${team.id}'),
          child: Padding(
            padding: const EdgeInsets.all(Space.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(team.name, style: textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            NationalDex.isNational(team.version)
                                ? l10n.teamNational(
                                    version?.name(lang) ?? team.version.value,
                                  )
                                : l10n.teamGame(
                                    version?.name(lang) ?? team.version.value,
                                  ),
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CheckStatusIcon(status),
                  ],
                ),
                const SizedBox(height: Space.m),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final m in team.members)
                      DexThumb(m.form, size: 48, shiny: m.shiny),
                    for (var i = team.members.length; i < party; i++)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(48 * 0.28),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                      ),
                  ],
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: Space.m),
                  Text(
                    names.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
