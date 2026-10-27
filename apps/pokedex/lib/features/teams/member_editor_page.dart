import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mydex_domain/mydex_domain.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/search_picker.dart';
import '../../widgets/type_badge.dart';
import 'team_widgets.dart';

/// Edit a team member. The fields follow the team's ruleset.
class MemberEditorPage extends ConsumerWidget {
  const MemberEditorPage({
    super.key,
    required this.teamId,
    required this.index,
  });

  final String teamId;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final team = ref.watch(
      teamsProvider.select(
        (s) => s.value?.where((t) => t.id == teamId).firstOrNull,
      ),
    );
    if (team == null || index >= team.members.length) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l10n.noResults('$teamId/$index'))),
      );
    }
    final member = team.members[index];
    final catalog = ref.watch(readyCatalogProvider);
    final details = ref.watch(catalogDetailsProvider);
    final lang = dataLanguageOf(context, ref);
    final evaluator = evaluatorFor(ref, team);
    final ctx = evaluator.context;
    final rules = ctx.ruleset;
    final profile = evaluator.profileOf(member);
    final check = evaluator.checkMember(member);
    final stats = evaluator.stats(member);
    final form = catalog.forms[member.form];
    final textTheme = Theme.of(context).textTheme;
    final modern = rules.statFormula == StatFormula.modern;

    Future<void> update(TeamMember next) => ref
        .read(teamsProvider.notifier)
        .save(
          team.copyWith(
            members: [
              for (final (i, m) in team.members.indexed) i == index ? next : m,
            ],
            updatedAt: DateTime.now(),
          ),
        );
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
        title: Text(
          form == null ? member.form.value : catalog.displayName(form)(lang),
        ),
        actions: [
          IconButton(
            tooltip: l10n.removeMember,
            icon: const Icon(Icons.person_remove_outlined),
            onPressed: () async {
              await ref
                  .read(teamsProvider.notifier)
                  .save(
                    team.copyWith(
                      members: [
                        for (final (i, m) in team.members.indexed)
                          if (i != index) m,
                      ],
                      updatedAt: DateTime.now(),
                    ),
                  );
              if (context.mounted) context.go('/teams/${team.id}');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.l),
        children: [
          TypeBadges(profile.types),
          const SizedBox(height: Space.m),
          CheckStatusIcon(check.status, showLabel: true),
          for (final issue in check.issues)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(describeIssue(issue, l10n, subjectName)),
            ),
          const SizedBox(height: Space.l),
          TextFormField(
            initialValue: member.nickname,
            decoration: InputDecoration(labelText: l10n.nickname),
            onChanged: (v) =>
                update(member.copyWith(nickname: v.isEmpty ? null : v)),
          ),
          const SizedBox(height: Space.m),
          _NumberField(
            label: l10n.level,
            value: member.level,
            min: 1,
            max: 100,
            onChanged: (v) => update(member.copyWith(level: v)),
          ),
          if (rules.hasAbilities) ...[
            const SizedBox(height: Space.m),
            DropdownButtonFormField<AbilityId?>(
              isExpanded: true,
              initialValue: member.ability,
              decoration: InputDecoration(labelText: l10n.ability),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.none)),
                for (final slot in profile.abilities)
                  DropdownMenuItem(
                    value: slot.abilityId,
                    child: Text(
                      '${catalog.abilities[slot.abilityId]?.name(lang) ?? slot.abilityId.value}'
                      '${slot.hidden ? ' (${l10n.abilityHidden})' : ''}',
                    ),
                  ),
                // Keep an already set ability visible even if it is invalid here.
                if (member.ability != null &&
                    !profile.abilities.any(
                      (a) => a.abilityId == member.ability,
                    ))
                  DropdownMenuItem(
                    value: member.ability,
                    child: Text(
                      catalog.abilities[member.ability]?.name(lang) ??
                          member.ability!.value,
                    ),
                  ),
              ],
              onChanged: (v) => update(member.copyWith(ability: v)),
            ),
          ],
          if (rules.hasNatures) ...[
            const SizedBox(height: Space.m),
            DropdownButtonFormField<NatureId?>(
              isExpanded: true,
              initialValue: member.nature,
              decoration: InputDecoration(labelText: l10n.nature),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.none)),
                for (final n
                    in catalog.natures.values.toList()
                      ..sort((a, b) => a.name(lang).compareTo(b.name(lang))))
                  DropdownMenuItem(
                    value: n.id,
                    child: Text(
                      n.isNeutral
                          ? n.name(lang)
                          : '${n.name(lang)} (+${_statLabel(l10n, n.increased!)} −${_statLabel(l10n, n.decreased!)})',
                    ),
                  ),
              ],
              onChanged: (v) => update(member.copyWith(nature: v)),
            ),
          ],
          if (rules.hasHeldItems) ...[
            const SizedBox(height: Space.m),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.heldItem),
              subtitle: Text(
                member.item == null
                    ? l10n.none
                    : catalog.items[member.item]?.name(lang) ??
                          member.item!.value,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final result = await showSearchPicker<ItemId>(
                  context,
                  title: l10n.chooseItem,
                  searchHint: l10n.chooseItem,
                  clearLabel: l10n.none,
                  options: [
                    for (final item
                        in catalog.items.values
                            .where((i) => i.holdableIn(ctx.generation))
                            .toList()
                          ..sort(
                            (a, b) => a.name(lang).compareTo(b.name(lang)),
                          ))
                      PickerOption(
                        item.id,
                        item.name(lang),
                        searchText: item.name.allValues.join(' '),
                      ),
                  ],
                );
                if (result == null) return;
                await update(
                  member.copyWith(item: result.cleared ? null : result.value),
                );
              },
            ),
          ],
          heading(l10n.movesLabel),
          for (var slot = 0; slot < 4; slot++)
            Builder(
              builder: (context) {
                final move = slot < member.moves.length
                    ? member.moves[slot]
                    : null;
                final p = move == null
                    ? null
                    : details.moveProfile(move, ctx.versionGroupId);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    move == null
                        ? l10n.emptyMoveSlot
                        : catalog.moves[move]?.name(lang) ?? move.value,
                  ),
                  subtitle: p == null
                      ? null
                      : Text(
                          '${l10n.damageClass(p.damageClass.name)} · ${l10n.movePower} ${p.power ?? l10n.valueNone}',
                        ),
                  leading: p == null
                      ? const Icon(Icons.add)
                      : TypeBadge(p.type, dense: true),
                  onTap: () async {
                    final result = await showSearchPicker<MoveId>(
                      context,
                      title: l10n.chooseMove,
                      searchHint: l10n.chooseMove,
                      clearLabel: move == null ? null : l10n.none,
                      options: [
                        for (final MapEntry(key: m, value: source)
                            in evaluator.learnable(member.form).entries)
                          PickerOption(
                            m,
                            catalog.moves[m]?.name(lang) ?? m.value,
                            subtitle: source == member.form
                                ? null
                                : l10n.viaForm(
                                    catalog.displayName(catalog.forms[source]!)(
                                      lang,
                                    ),
                                  ),
                            searchText: catalog.moves[m]?.name.allValues.join(
                              ' ',
                            ),
                            trailing: switch (details.moveProfile(
                              m,
                              ctx.versionGroupId,
                            )) {
                              final p? => TypeBadge(p.type, dense: true),
                              null => null,
                            },
                          ),
                      ]..sort((a, b) => a.label.compareTo(b.label)),
                    );
                    if (result == null) return;
                    final moves = [...member.moves];
                    if (result.cleared) {
                      if (slot < moves.length) moves.removeAt(slot);
                    } else if (slot < moves.length) {
                      moves[slot] = result.value!;
                    } else {
                      moves.add(result.value!);
                    }
                    await update(member.copyWith(moves: moves));
                  },
                );
              },
            ),
          heading(l10n.calculatedStats),
          if (rules.id.value == 'lgpe' || rules.id.value == 'pla')
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: Text(l10n.statFormulaNote, style: textTheme.bodySmall),
            ),
          if (stats != null)
            _StatsTable(stats: stats, unifiedSpecial: rules.unifiedSpecial),
          heading(modern ? l10n.ivs : l10n.dvs),
          if (!modern) Text(l10n.hpDvDerived, style: textTheme.bodySmall),
          _StatInputs(
            stats: _editableStats(modern, rules.unifiedSpecial, forIvs: true),
            values: member.ivs,
            max: modern ? 31 : 15,
            defaultValue: modern ? 31 : 15,
            labels: (s) => _statLabel(l10n, s, unified: !modern),
            onChanged: (s, v) => update(
              member.copyWith(
                ivs: _withLinkedSpecial(member.ivs, s, v, !modern),
              ),
            ),
          ),
          heading(modern ? l10n.evs : l10n.statExp),
          if (modern)
            Text(
              l10n.evTotal(member.evs.values.fold(0, (a, b) => a + b)),
              style: textTheme.bodySmall,
            ),
          _StatInputs(
            stats: _editableStats(modern, rules.unifiedSpecial, forIvs: false),
            values: member.evs,
            max: modern ? 252 : 65535,
            defaultValue: 0,
            labels: (s) => _statLabel(l10n, s, unified: !modern),
            onChanged: (s, v) => update(
              member.copyWith(
                evs: _withLinkedSpecial(member.evs, s, v, !modern),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gen 1–2: one shared Special DV or Special stat exp; HP DV derived.
  static List<Stat> _editableStats(
    bool modern,
    bool unified, {
    required bool forIvs,
  }) => [
    if (modern || !forIvs) Stat.hp,
    Stat.attack,
    Stat.defense,
    Stat.specialAttack,
    if (modern) Stat.specialDefense,
    Stat.speed,
  ];

  static Map<Stat, int> _withLinkedSpecial(
    Map<Stat, int> values,
    Stat stat,
    int value,
    bool linked,
  ) => {
    ...values,
    stat: value,
    if (linked && stat == Stat.specialAttack) Stat.specialDefense: value,
  };

  static String _statLabel(
    AppLocalizations l10n,
    Stat s, {
    bool unified = false,
  }) => switch (s) {
    Stat.hp => l10n.statHp,
    Stat.attack => l10n.statAttack,
    Stat.defense => l10n.statDefense,
    Stat.specialAttack => unified ? l10n.statSpecial : l10n.statSpAtk,
    Stat.specialDefense => l10n.statSpDef,
    Stat.speed => l10n.statSpeed,
  };
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.stats, required this.unifiedSpecial});

  final Map<Stat, int> stats;
  final bool unifiedSpecial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: Space.xl,
      runSpacing: Space.s,
      children: [
        for (final s in Stat.values)
          if (!(unifiedSpecial && s == Stat.specialDefense))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MemberEditorPage._statLabel(l10n, s, unified: unifiedSpecial),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  '${stats[s]}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

class _StatInputs extends StatelessWidget {
  const _StatInputs({
    required this.stats,
    required this.values,
    required this.max,
    required this.defaultValue,
    required this.labels,
    required this.onChanged,
  });

  final List<Stat> stats;
  final Map<Stat, int> values;
  final int max;
  final int defaultValue;
  final String Function(Stat) labels;
  final void Function(Stat, int) onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.m,
    runSpacing: Space.m,
    children: [
      for (final s in stats)
        SizedBox(
          width: 104,
          child: _NumberField(
            key: ValueKey('stat-${s.name}-$max'),
            label: labels(s),
            value: values[s] ?? defaultValue,
            min: 0,
            max: max,
            onChanged: (v) => onChanged(s, v),
          ),
        ),
    ],
  );
}

/// Number field with range check; invalid input is not applied.
class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: '$value',
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, helperText: '$min–$max'),
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: (v) {
      final n = int.tryParse(v ?? '');
      return n == null || n < min || n > max ? '$min–$max' : null;
    },
    onChanged: (v) {
      final n = int.tryParse(v);
      if (n != null && n >= min && n <= max) onChanged(n);
    },
  );
}
