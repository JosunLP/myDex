import 'package:meta/meta.dart';

import 'ids.dart';
import 'localized_text.dart';

/// Historische Typentabellen. Die Generation allein reicht nicht für alle
/// Regeln, aber für die Typentabelle ist die Ära eindeutig.
enum TypeChartEra {
  /// Gen 1: 15 Typen, u. a. Geist → Psycho ×0.
  gen1('gen1'),

  /// Gen 2–5: Unlicht und Stahl; Stahl resistiert Geist und Unlicht.
  gen2to5('gen2_5'),

  /// Ab Gen 6: Fee; Stahl resistiert Geist und Unlicht nicht mehr.
  gen6plus('gen6plus');

  const TypeChartEra(this.key);

  final String key;

  static TypeChartEra parse(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw FormatException('Unbekannte Typentabellen-Ära: $key'),
  );
}

enum StatFormula {
  /// Gen 1–2: DVs (0–15) und Status-EP.
  gen1to2('gen1_2'),

  /// Ab Gen 3: IVs (0–31), EVs und Wesen.
  modern('modern');

  const StatFormula(this.key);

  final String key;

  static StatFormula parse(String key) => values.firstWhere(
    (e) => e.key == key,
    orElse: () => throw FormatException('Unbekannte Statusformel: $key'),
  );
}

/// Mechanische Regeln eines Spiels oder Formats.
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

  /// Gen 1 kennt nur einen gemeinsamen Spezial-Wert.
  final bool unifiedSpecial;

  /// Ob Pokémon in diesem Spiel aus Eiern gezüchtet werden können.
  final bool hasBreeding;
}

/// Gruppe verwandter Editionen mit gemeinsamen Daten (z. B. Rot/Blau).
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

  /// Chronologische Reihenfolge.
  final int order;

  /// Ob der Katalog für diese Spielgruppe Kerndaten (z. B. Erlernbarkeit) enthält.
  /// Wird in der Spielauswahl als „keine Daten“ gekennzeichnet.
  final bool hasData;
}

/// Einzelne Edition (z. B. Rot).
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
