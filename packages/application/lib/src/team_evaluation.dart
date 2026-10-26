import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';

import 'catalog_details.dart';
import 'catalog_snapshot.dart';
import 'pokemon_queries.dart';

/// Ergebnis einer Prüfung. Reihenfolge = Schwere (höchste zuletzt).
enum CheckStatus {
  /// Alle erfassten Regeln sind erfüllt.
  valid,

  /// Etwas ist nur außerhalb der erfassten Wege möglich (z. B. Event/Transfer).
  partial,

  /// Für eine Aussage fehlen Daten.
  insufficientData,

  /// Verstößt gegen eine erfasste Regel.
  invalid;

  CheckStatus worst(CheckStatus other) => index >= other.index ? this : other;
}

enum IssueKind {
  formNotInGame,
  formDataGap,
  levelOutOfRange,
  abilityNotApplicable,
  abilityNotAvailable,
  abilityDataGap,
  heldItemsNotApplicable,
  itemNotHoldable,
  itemDataGap,
  naturesNotApplicable,
  tooManyMoves,
  duplicateMove,
  moveNotInGame,
  moveNotInLearnset,
  learnsetDataGap,
  statValuesInvalid,
  teamTooLarge,
}

@immutable
class CheckIssue {
  const CheckIssue(this.kind, this.status, {this.subject});

  final IssueKind kind;
  final CheckStatus status;

  /// Betroffene Attacke, Fähigkeit oder Item (ID).
  final String? subject;
}

@immutable
class MemberCheck {
  const MemberCheck(this.issues);
  final List<CheckIssue> issues;

  CheckStatus get status =>
      issues.fold(CheckStatus.valid, (s, i) => s.worst(i.status));
}

@immutable
class TeamCheck {
  const TeamCheck(this.members, this.teamIssues);
  final List<MemberCheck> members;
  final List<CheckIssue> teamIssues;

  CheckStatus get status => [
    ...teamIssues.map((i) => i.status),
    ...members.map((m) => m.status),
  ].fold(CheckStatus.valid, (s, i) => s.worst(i));
}

/// Vorschlag: eine im Spiel erlernbare Attacke schließt eine Abdeckungslücke.
@immutable
class MoveSuggestion {
  const MoveSuggestion(this.memberIndex, this.move, this.covers);
  final int memberIndex;
  final MoveId move;
  final PokemonType covers;
}

@immutable
class TeamInsights {
  const TeamInsights(this.analysis, this.suggestions);
  final TeamAnalysis analysis;
  final List<MoveSuggestion> suggestions;
}

/// Prüfung, Werte und Analyse eines Teams im Kontext seines Spiels.
/// Geprüft werden nur die erfassten Wege (Level, Maschine, Zucht, Lehrer, …);
/// Events, Transfers und Kombinationsbeschränkungen sind nicht modelliert.
class TeamEvaluator {
  TeamEvaluator(this.catalog, this.details, this.context);

  final CatalogSnapshot catalog;
  final CatalogDetails details;
  final GameContext context;

  late final TypeChart chart = TypeChart.forEra(context.ruleset.typeChartEra);

  /// Erlernbare Attacken inkl. Vorentwicklungen; Wert = Quelle (die Form selbst
  /// oder die Vorentwicklung, über die die Attacke kommt).
  Map<MoveId, FormId> learnable(FormId form) {
    final result = <MoveId, FormId>{};
    for (final source in [
      form,
      ...preEvolutionsOf(catalog, form, context.versionGroupId),
    ]) {
      for (final e in details.learnset(source, context.versionGroupId)) {
        result.putIfAbsent(e.move, () => source);
      }
    }
    return result;
  }

  FormGameProfile profileOf(TeamMember m) =>
      catalog.forms[m.form]?.profileFor(context.versionGroupId) ??
      FormGameProfile.notResearched;

  TeamCheck check(Team team) => TeamCheck(
    [for (final m in team.members) checkMember(m)],
    [
      if (team.members.length > context.ruleset.partySize)
        const CheckIssue(IssueKind.teamTooLarge, CheckStatus.invalid),
    ],
  );

  MemberCheck checkMember(TeamMember m) {
    final issues = <CheckIssue>[];
    final rules = context.ruleset;
    final profile = profileOf(m);
    switch (profile.availability) {
      case DataAvailability.confirmedUnavailable ||
          DataAvailability.notApplicable:
        issues.add(
          const CheckIssue(IssueKind.formNotInGame, CheckStatus.invalid),
        );
      case DataAvailability.unknown || DataAvailability.notResearched:
        issues.add(
          const CheckIssue(IssueKind.formDataGap, CheckStatus.insufficientData),
        );
      case DataAvailability.confirmedAvailable:
    }
    if (m.level < 1 || m.level > 100) {
      issues.add(
        const CheckIssue(IssueKind.levelOutOfRange, CheckStatus.invalid),
      );
    }

    if (m.ability case final ability?) {
      if (!rules.hasAbilities) {
        issues.add(
          const CheckIssue(IssueKind.abilityNotApplicable, CheckStatus.invalid),
        );
      } else if (profile.abilities.isEmpty) {
        issues.add(
          CheckIssue(
            IssueKind.abilityDataGap,
            CheckStatus.insufficientData,
            subject: ability.value,
          ),
        );
      } else if (!profile.abilities.any((a) => a.abilityId == ability)) {
        issues.add(
          CheckIssue(
            IssueKind.abilityNotAvailable,
            CheckStatus.invalid,
            subject: ability.value,
          ),
        );
      }
    }

    if (m.item case final item?) {
      final info = catalog.items[item];
      if (!rules.hasHeldItems) {
        issues.add(
          const CheckIssue(
            IssueKind.heldItemsNotApplicable,
            CheckStatus.invalid,
          ),
        );
      } else if (info == null || info.generations.isEmpty) {
        issues.add(
          CheckIssue(
            IssueKind.itemDataGap,
            CheckStatus.insufficientData,
            subject: item.value,
          ),
        );
      } else if (!info.holdableIn(context.generation)) {
        issues.add(
          CheckIssue(
            IssueKind.itemNotHoldable,
            CheckStatus.invalid,
            subject: item.value,
          ),
        );
      }
    }

    if (m.nature != null && !rules.hasNatures) {
      issues.add(
        const CheckIssue(IssueKind.naturesNotApplicable, CheckStatus.invalid),
      );
    }

    if (m.moves.length > 4) {
      issues.add(const CheckIssue(IssueKind.tooManyMoves, CheckStatus.invalid));
    }
    final seen = <MoveId>{};
    final learnset = learnable(m.form).keys.toSet();
    for (final move in m.moves) {
      if (!seen.add(move)) {
        issues.add(
          CheckIssue(
            IssueKind.duplicateMove,
            CheckStatus.invalid,
            subject: move.value,
          ),
        );
      } else if (details.moveProfile(move, context.versionGroupId) == null) {
        issues.add(
          CheckIssue(
            IssueKind.moveNotInGame,
            CheckStatus.invalid,
            subject: move.value,
          ),
        );
      } else if (learnset.isEmpty) {
        issues.add(
          CheckIssue(
            IssueKind.learnsetDataGap,
            CheckStatus.insufficientData,
            subject: move.value,
          ),
        );
      } else if (!learnset.contains(move)) {
        // Nicht über erfasste Wege – Events/Transfers sind nicht modelliert.
        issues.add(
          CheckIssue(
            IssueKind.moveNotInLearnset,
            CheckStatus.partial,
            subject: move.value,
          ),
        );
      }
    }

    if (profile.baseStats != null) {
      try {
        _calculate(m, profile.baseStats!);
      } on ArgumentError {
        issues.add(
          const CheckIssue(IssueKind.statValuesInvalid, CheckStatus.invalid),
        );
      }
    }
    return MemberCheck(issues);
  }

  Map<Stat, int> _calculate(TeamMember m, BaseStats base) {
    final nature = m.nature == null ? null : catalog.natures[m.nature];
    return StatCalculator(context.ruleset.statFormula).calculate(
      base,
      StatInputs(
        level: m.level,
        ivs: m.ivs,
        evs: m.evs,
        natureUp: context.ruleset.hasNatures ? nature?.increased : null,
        natureDown: context.ruleset.hasNatures ? nature?.decreased : null,
      ),
    );
  }

  /// Berechnete Werte; `null` ohne Basiswerte oder bei ungültigen Eingaben.
  Map<Stat, int>? stats(TeamMember m) {
    final base = profileOf(m).baseStats;
    if (base == null) return null;
    try {
      return _calculate(m, base);
    } on ArgumentError {
      return null;
    }
  }

  /// Basistypen-Analyse plus erklärbare Attackenvorschläge für Abdeckungslücken.
  TeamInsights insights(Team team, {int maxSuggestions = 5}) {
    final typings = [
      for (final m in team.members)
        TeamMemberTyping(
          label: m.form.value,
          types: [
            for (final t in profileOf(m).types)
              if (chart.contains(t)) t,
          ],
          attackTypes: [
            for (final move in m.moves)
              if (details.moveProfile(move, context.versionGroupId)
                  case final p?)
                if (p.damageClass != DamageClass.status &&
                    chart.contains(p.type))
                  p.type,
          ],
        ),
    ];
    final analysis = TeamAnalyzer(chart).analyze(typings);
    final suggestions = <MoveSuggestion>[];
    // Lernsets und Attackenwerte nur einmal abfragen.
    final profiles = <MoveId, MoveGameProfile?>{};
    MoveGameProfile? profile(MoveId id) => profiles.putIfAbsent(
      id,
      () => details.moveProfile(id, context.versionGroupId),
    );
    final learnsets = [for (final m in team.members) learnable(m.form).keys];
    final gaps = analysis.findings.whereType<CoverageGap>().map(
      (g) => g.defendingType,
    );
    for (final gap in gaps) {
      if (suggestions.length >= maxSuggestions) break;
      MoveSuggestion? best;
      var bestPower = -1;
      for (var i = 0; i < team.members.length; i++) {
        final member = team.members[i];
        for (final move in learnsets[i]) {
          if (member.moves.contains(move)) continue;
          final p = profile(move);
          if (p == null ||
              p.damageClass == DamageClass.status ||
              !chart.contains(p.type)) {
            continue;
          }
          if (chart.single(p.type, gap) <= 1) continue;
          final power = p.power ?? 0;
          if (power > bestPower) {
            bestPower = power;
            best = MoveSuggestion(i, move, gap);
          }
        }
      }
      if (best != null) suggestions.add(best);
    }
    return TeamInsights(analysis, suggestions);
  }
}
