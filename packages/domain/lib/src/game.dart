import 'package:meta/meta.dart';

import 'ids.dart';
import 'localized_text.dart';

/// Historical type charts. The generation alone is not enough for all rules,
/// but for the type chart the era is unambiguous.
enum TypeChartEra {
  /// Gen 1: 15 Typen, u. a. Geist → Psycho ×0.
  gen1('gen1'),

  /// Gen 2–5: Dark and Steel; Steel resists Ghost and Dark.
  gen2to5('gen2_5'),

  /// From Gen 6: Fairy; Steel no longer resists Ghost and Dark.
  gen6plus('gen6plus');

  const TypeChartEra(this.key);

  final String key;

  static TypeChartEra parse(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw FormatException('Unknown type chart era: $key'),
  );
}

enum StatFormula {
  /// Gen 1–2: DVs (0–15) and stat experience.
  gen1to2('gen1_2'),

  /// From Gen 3: IVs (0–31), EVs and natures.
  modern('modern');

  const StatFormula(this.key);

  final String key;

  static StatFormula parse(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw FormatException('Unknown stat formula: $key'),
  );
}

/// Mechanical rules of a game or format.
@immutable
class Ruleset {
  const Ruleset({
    required this.id,
    required this.generation,
    required this.typeChartEra,
    required this.statFormula,
    required this.partySize,
    required this.hasAbilities,
    required this.hasHeldItems,
    required this.hasNatures,
    required this.unifiedSpecial,
    this.hasBreeding = false,
  });

  factory Ruleset.fromJson(Map<String, Object?> j) => Ruleset(
    id: RulesetId(j['id']! as String),
    generation: j['generation']! as int,
    typeChartEra: TypeChartEra.parse(j['typeChartEra']! as String),
    statFormula: StatFormula.parse(j['statFormula']! as String),
    partySize: j['partySize']! as int,
    hasAbilities: j['hasAbilities']! as bool,
    hasHeldItems: j['hasHeldItems']! as bool,
    hasNatures: j['hasNatures']! as bool,
    unifiedSpecial: j['unifiedSpecial']! as bool,
    hasBreeding: (j['hasBreeding'] as bool?) ?? false,
  );

  final RulesetId id;
  final int generation;
  final TypeChartEra typeChartEra;
  final StatFormula statFormula;
  final int partySize;
  final bool hasAbilities;
  final bool hasHeldItems;
  final bool hasNatures;

  /// Gen 1 only has a single shared Special stat.
  final bool unifiedSpecial;

  /// Whether Pokémon can be bred from eggs in this game.
  final bool hasBreeding;
}

/// Group of related editions with shared data (e.g. Red/Blue).
@immutable
class VersionGroup {
  const VersionGroup({
    required this.id,
    required this.generation,
    required this.rulesetId,
    required this.name,
    required this.order,
    this.hasData = true,
  });

  factory VersionGroup.fromJson(Map<String, Object?> j) => VersionGroup(
    id: VersionGroupId(j['id']! as String),
    generation: j['generation']! as int,
    rulesetId: RulesetId(j['ruleset']! as String),
    name: LocalizedText.fromJson(j['name']! as Map<String, Object?>),
    order: j['order']! as int,
    hasData: (j['hasData'] as bool?) ?? true,
  );

  final VersionGroupId id;
  final int generation;
  final RulesetId rulesetId;
  final LocalizedText name;

  /// Chronological order.
  final int order;

  /// Whether the catalog contains core data (e.g. learnsets) for this group.
  /// Marked as "no data" in the game picker.
  final bool hasData;
}

/// A single edition (e.g. Red).
@immutable
class GameVersion {
  const GameVersion({
    required this.id,
    required this.versionGroupId,
    required this.name,
  });

  factory GameVersion.fromJson(Map<String, Object?> j) => GameVersion(
    id: GameVersionId(j['id']! as String),
    versionGroupId: VersionGroupId(j['versionGroup']! as String),
    name: LocalizedText.fromJson(j['name']! as Map<String, Object?>),
  );

  final GameVersionId id;
  final VersionGroupId versionGroupId;
  final LocalizedText name;
}
