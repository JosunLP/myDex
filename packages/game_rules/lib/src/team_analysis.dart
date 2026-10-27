import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'type_chart.dart';

/// Input for the base type analysis. Abilities, items and weather belong to
/// the context-dependent analysis and are deliberately left out here.
@immutable
class TeamMemberTyping {
  const TeamMemberTyping({
    required this.label,
    required this.types,
    this.attackTypes = const [],
  });

  final String label;
  final List<PokemonType> types;

  /// Types of this member's damaging moves.
  final List<PokemonType> attackTypes;
}

@immutable
class DefensiveRow {
  const DefensiveRow(this.attackType, this.multipliers);

  final PokemonType attackType;

  /// Multiplier per team member (same order as the input).
  final List<double> multipliers;

  int get weak => multipliers.where((m) => m > 1).length;
  int get resistant => multipliers.where((m) => m > 0 && m < 1).length;
  int get immune => multipliers.where((m) => m == 0).length;
}

@immutable
class OffensiveRow {
  const OffensiveRow(this.defendingType, this.best);

  final PokemonType defendingType;

  /// Best achievable multiplier; `null` if the team has no moves.
  final double? best;

  bool get superEffective => (best ?? 0) > 1;
}

/// Explainable, deterministic hints – no AI.
@immutable
sealed class TeamFinding {
  const TeamFinding();
}

/// Several members are weak, none resists.
final class SharedWeakness extends TeamFinding {
  const SharedWeakness(this.attackType, this.weakCount);
  final PokemonType attackType;
  final int weakCount;
}

/// No member hits this type super-effectively.
final class CoverageGap extends TeamFinding {
  const CoverageGap(this.defendingType);
  final PokemonType defendingType;
}

@immutable
class TeamAnalysis {
  const TeamAnalysis({
    required this.defensive,
    required this.offensive,
    required this.findings,
  });

  final List<DefensiveRow> defensive;
  final List<OffensiveRow> offensive;
  final List<TeamFinding> findings;
}

class TeamAnalyzer {
  const TeamAnalyzer(this.chart, {this.sharedWeaknessThreshold = 3});

  final TypeChart chart;
  final int sharedWeaknessThreshold;

  TeamAnalysis analyze(List<TeamMemberTyping> team) {
    final defensive = [
      for (final atk in chart.types)
        DefensiveRow(atk, [for (final m in team) chart.against(atk, m.types)]),
    ];
    final attackTypes = {for (final m in team) ...m.attackTypes};
    final offensive = [
      for (final def in chart.types)
        OffensiveRow(
          def,
          attackTypes.isEmpty
              ? null
              : attackTypes
                    .map((a) => chart.single(a, def))
                    .reduce((a, b) => a > b ? a : b),
        ),
    ];
    final findings = <TeamFinding>[
      for (final row in defensive)
        if (row.weak >= sharedWeaknessThreshold &&
            row.resistant == 0 &&
            row.immune == 0)
          SharedWeakness(row.attackType, row.weak),
      if (attackTypes.isNotEmpty)
        for (final row in offensive)
          if (!row.superEffective) CoverageGap(row.defendingType),
    ];
    return TeamAnalysis(
      defensive: defensive,
      offensive: offensive,
      findings: findings,
    );
  }
}
