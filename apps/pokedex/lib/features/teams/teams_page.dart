import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/game_context_selector.dart';
import 'team_widgets.dart';

/// Teamliste. Neue Teams werden für das aktuell gewählte Spiel angelegt.
class TeamsPage extends ConsumerWidget {
  const TeamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final teams = ref.watch(teamsProvider).value ?? const [];
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.teamsTitle),
        actions: const [
          GameContextSelector(),
          SizedBox(width: Space.s),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newTeam),
        onPressed: () async {
          final ctx = ref.read(gameContextProvider);
          final team = await ref
              .read(teamsProvider.notifier)
              .create(l10n.defaultTeamName(teams.length + 1), ctx.versionId);
          if (context.mounted) context.go('/teams/${team.id}');
        },
      ),
      body: teams.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text(l10n.teamsEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final team in teams)
                  Builder(
                    builder: (context) {
                      final evaluator = evaluatorFor(ref, team);
                      final status = evaluator.check(team).status;
                      final version = catalog.versions
                          .where((v) => v.id == team.version)
                          .firstOrNull;
                      return ListTile(
                        title: Text(team.name),
                        subtitle: Text(
                          [
                            l10n.teamGame(
                              version?.name(lang) ?? team.version.value,
                            ),
                            for (final m in team.members)
                              if (catalog.forms[m.form] case final f?)
                                catalog.displayName(f)(lang),
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: CheckStatusIcon(status),
                        onTap: () => context.go('/teams/${team.id}'),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}
