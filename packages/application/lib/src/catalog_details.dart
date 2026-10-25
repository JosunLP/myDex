import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Herkunft und Stand eines Katalogpakets.
@immutable
class CatalogSourceInfo {
  const CatalogSourceInfo({
    required this.revision,
    required this.schemaVersion,
    required this.source,
    required this.sourceRevision,
  });

  final String revision;
  final int schemaVersion;

  /// Z. B. `PokéAPI`.
  final String source;

  /// Festgehaltener Quellstand (z. B. Commit-Hash).
  final String sourceRevision;
}

/// Datenabdeckung je Spielgruppe – fehlende Daten sind sichtbar (ADR 0005).
@immutable
class CoverageRow {
  const CoverageRow({
    required this.versionGroup,
    required this.formsConfirmed,
    required this.formsUnavailable,
    required this.formsGaps,
    required this.learnsetEntries,
    this.encounterEntries = 0,
  });

  final VersionGroupId versionGroup;
  final int formsConfirmed;
  final int formsUnavailable;
  final int formsGaps;
  final int learnsetEntries;

  /// 0 = für diese Spielgruppe liegen keine Fundortdaten vor.
  final int encounterEntries;
}

enum EntityKind { move, ability, item }

@immutable
class EntityHit {
  const EntityHit(this.kind, this.id);
  final EntityKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is EntityHit && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);
}

/// Wer eine Attacke in einer Spielgruppe erlernt.
@immutable
class MoveLearner {
  const MoveLearner(this.form, this.methods);
  final FormId form;
  final Set<LearnMethod> methods;
}

/// Bedarfsweise Abfragen auf den Katalog (große Tabellen wie Erlernbarkeit),
/// ergänzend zum vollständig geladenen [CatalogSnapshot].
abstract interface class CatalogDetails {
  CatalogSourceInfo get source;

  List<LearnsetEntry> learnset(FormId form, VersionGroupId group);

  /// `null`, wenn die Attacke in dieser Spielgruppe nicht existiert.
  MoveGameProfile? moveProfile(MoveId move, VersionGroupId group);

  /// Werte je Spielgruppe in chronologischer Reihenfolge.
  List<(VersionGroupId, MoveGameProfile)> moveHistory(MoveId move);

  List<MoveLearner> learnersOf(MoveId move, VersionGroupId group);

  /// Begegnungen einer Form in einer Spielversion.
  List<Encounter> encountersOf(FormId form, GameVersionId version);

  /// Alle Begegnungen an einem Ort in einer Spielversion.
  List<Encounter> encountersAt(LocationId location, GameVersionId version);

  /// Orte mit Begegnungsdaten in einer Spielversion.
  List<LocationId> locationsWithEncounters(GameVersionId version);

  /// Ob für diese Spielversion überhaupt Fundortdaten vorliegen.
  bool hasEncounterData(GameVersionId version);

  /// Volltextsuche über Attacken, Fähigkeiten und Items.
  List<EntityHit> searchEntities(String query, {int limit = 30});

  List<CoverageRow> coverage();

  void close();
}
