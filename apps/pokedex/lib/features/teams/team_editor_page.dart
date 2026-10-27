import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/dex_decor.dart';
import '../../widgets/search_picker.dart';
import '../../widgets/type_badge.dart';
import 'team_widgets.dart';

/// Team bearbeiten: Mitglieder, Prüfergebnis und Typanalyse im Spiel des Teams.
class TeamEditorPage extends ConsumerStatefulWidget {
  const TeamEditorPage({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamEditorPage> createState() => _TeamEditorPageState();
}

class _TeamEditorPageState extends ConsumerState<TeamEditorPage> {
  final _name = TextEditingController();
  Timer? _debounce;
  bool _initialized = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  void _rename(Team team, String name) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref
          .read(teamsProvider.notifier)
          .save(team.copyWith(name: name, updatedAt: DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final team = ref.watch(
      teamsProvider.select(
        (s) => s.value?.where((t) => t.id == widget.teamId).firstOrNull,
      ),
    );
    if (team == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noResults(widget.teamId))),
      );
    }
    if (!_initialized) {
      _name.text = team.name;
      _initialized = true;
    }
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final evaluator = evaluatorFor(ref, team);
    final ctx = evaluator.context;
    final check = evaluator.check(team);
    final textTheme = Theme.of(context).textTheme;
    String subjectName(String id) =>
        catalog.moves[MoveId(id)]?.name(lang) ??
        catalog.abilities[AbilityId(id)]?.name(lang) ??
        catalog.items[ItemId(id)]?.name(lang) ??
        id;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.s),
      child: Semantics(
        header: true,
        child: Text(text, style: textTheme.titleMedium),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: l10n.deleteTeam,
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  content: Text(l10n.deleteTeamConfirm(team.name)),
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
              if (confirmed ?? false) {
                await ref.read(teamsProvider.notifier).delete(team.id);
                if (context.mounted) context.go('/teams');
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.l),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l10n.teamName),
            onChanged: (v) => _rename(team, v),
          ),
          const SizedBox(height: Space.s),
          Text(l10n.teamGame(ctx.version.name(lang))),
          const SizedBox(height: Space.m),
          CheckStatusIcon(check.status, showLabel: true),
          for (final issue in check.teamIssues)
            Text(
              describeIssue(issue, l10n, subjectName),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: Space.xs),
          Text(l10n.checkScope, style: textTheme.bodySmall),
          heading(
            l10n.teamMembersCount(team.members.length, ctx.ruleset.partySize),
          ),
          for (final (i, member) in team.members.indexed)
            _MemberCard(
              team: team,
              index: i,
              member: member,
              check: check.members[i],
              evaluator: evaluator,
              subjectName: subjectName,
            ),
          if (team.members.length < ctx.ruleset.partySize)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addMember),
                onPressed: () => _addMember(team, evaluator),
              ),
            ),
          if (team.members.isNotEmpty) ...[
            heading(l10n.analysisTitle),
            Text(l10n.analysisBasicNote, style: textTheme.bodySmall),
            _AnalysisView(team: team, evaluator: evaluator),
          ],
        ],
      ),
    );
  }

  Future<void> _addMember(Team team, TeamEvaluator evaluator) async {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.read(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final items = ref.read(queriesProvider).list(evaluator.context);
    final picked = await showSearchPicker<FormId>(
      context,
      title: l10n.choosePokemon,
      searchHint: l10n.searchHint,
      options: [
        for (final item in items)
          PickerOption(
            item.form.id,
            catalog.displayName(item.form)(lang),
            subtitle:
                '#${item.species.nationalNumber.toString().padLeft(4, '0')}',
            searchText:
                '${item.species.nationalNumber} ${catalog.displayName(item.form).allValues.join(' ')}',
          ),
      ],
    );
    final form = picked?.value;
    if (form == null) return;
    final member = defaultMember(
      form,
      evaluator,
      ref.read(catalogDetailsProvider),
    );
    await ref
        .read(teamsProvider.notifier)
        .save(
          team.copyWith(
            members: [...team.members, member],
            updatedAt: DateTime.now(),
          ),
        );
  }
}

/// Sinnvolle Vorgaben: Lv. 50, erste reguläre Fähigkeit, die letzten vier
/// bis Lv. 50 erlernten Level-Attacken.
TeamMember defaultMember(
  FormId form,
  TeamEvaluator evaluator,
  CatalogDetails details,
) {
  const level = 50;
  final ctx = evaluator.context;
  final profile = evaluator.catalog.forms[form]!.profileFor(ctx.versionGroupId);
  final levelMoves = <MoveId>[];
  for (final e in details.learnset(form, ctx.versionGroupId)) {
    if (e.method == LearnMethod.levelUp && (e.level ?? 0) <= level) {
      levelMoves
        ..remove(e.move)
        ..add(e.move);
    }
  }
  return TeamMember(
    form: form,
    level: level,
    ability: ctx.ruleset.hasAbilities
        ? profile.abilities.where((a) => !a.hidden).firstOrNull?.abilityId
        : null,
    moves: levelMoves.length > 4
        ? levelMoves.sublist(levelMoves.length - 4)
        : levelMoves,
  );
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.team,
    required this.index,
    required this.member,
    required this.check,
    required this.evaluator,
    required this.subjectName,
  });

  final Team team;
  final int index;
  final TeamMember member;
  final MemberCheck check;
  final TeamEvaluator evaluator;
  final String Function(String) subjectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final form = catalog.forms[member.form];
    final name = form == null
        ? member.form.value
        : catalog.displayName(form)(lang);
    final profile = evaluator.profileOf(member);
    final textTheme = Theme.of(context).textTheme;
    final details = [
      'Lv. ${member.level}',
      if (member.ability case final a?)
        catalog.abilities[a]?.name(lang) ?? a.value,
      if (member.item case final i?) catalog.items[i]?.name(lang) ?? i.value,
      if (member.nature case final n?)
        catalog.natures[n]?.name(lang) ?? n.value,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s),
      child: Card.outlined(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/teams/${team.id}/member/$index'),
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DexThumb(
                      member.form,
                      size: 48,
                      shiny: member.shiny,
                      version: team.version,
                    ),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text(
                        member.nickname?.isNotEmpty ?? false
                            ? '${member.nickname} ($name)'
                            : name,
                        style: textTheme.titleSmall,
                      ),
                    ),
                    CheckStatusIcon(check.status),
                  ],
                ),
                const SizedBox(height: Space.xs),
                TypeBadges(profile.types, dense: true),
                const SizedBox(height: Space.xs),
                Text(details, style: textTheme.bodySmall),
                if (member.moves.isNotEmpty)
                  Text(
                    member.moves
                        .map((m) => catalog.moves[m]?.name(lang) ?? m.value)
                        .join(', '),
                    style: textTheme.bodySmall,
                  ),
                for (final issue in check.issues)
                  Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Text(
                      describeIssue(issue, l10n, subjectName),
                      style: textTheme.bodySmall?.copyWith(
                        color: issue.status == CheckStatus.invalid
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysisView extends ConsumerWidget {
  const _AnalysisView({required this.team, required this.evaluator});

  final Team team;
  final TeamEvaluator evaluator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(readyCatalogProvider);
    final lang = dataLanguageOf(context, ref);
    final insights = evaluator.insights(team);
    final analysis = insights.analysis;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final shared = {
      for (final f in analysis.findings.whereType<SharedWeakness>())
        f.attackType: f,
    };
    final gaps = [
      for (final f in analysis.findings.whereType<CoverageGap>())
        f.defendingType,
    ];
    final hasAttacks = analysis.offensive.any((o) => o.best != null);
    String memberName(int i) {
      final m = team.members[i];
      final form = catalog.forms[m.form];
      return m.nickname?.isNotEmpty ?? false
          ? m.nickname!
          : form == null
          ? m.form.value
          : catalog.displayName(form)(lang);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Space.m),
        Text(l10n.defenseTitle, style: textTheme.titleSmall),
        for (final f in shared.values)
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, size: 18, color: scheme.error),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    l10n.sharedWeakness(
                      f.weakCount,
                      l10n.typeName(f.attackType.key),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Space.s),
        for (final row in analysis.defensive)
          if (row.weak + row.resistant + row.immune > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TypeBadge(row.attackType, dense: true),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.defenseRow(row.weak, row.resistant, row.immune),
                      style: textTheme.bodySmall?.copyWith(
                        fontFeatures: tabularFigures,
                        color: shared.containsKey(row.attackType)
                            ? scheme.error
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: Space.l),
        Text(l10n.offenseTitle, style: textTheme.titleSmall),
        const SizedBox(height: Space.xs),
        if (!hasAttacks)
          Text(l10n.noAttackMoves)
        else if (gaps.isEmpty)
          Text(l10n.noIssues)
        else
          Text(
            l10n.coverageGaps(gaps.map((t) => l10n.typeName(t.key)).join(', ')),
          ),
        if (insights.suggestions.isNotEmpty) ...[
          const SizedBox(height: Space.l),
          Text(l10n.suggestionsTitle, style: textTheme.titleSmall),
          for (final s in insights.suggestions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(
                l10n.suggestion(
                  memberName(s.memberIndex),
                  catalog.moves[s.move]?.name(lang) ?? s.move.value,
                  l10n.typeName(s.covers.key),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
