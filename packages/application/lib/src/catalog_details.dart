import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Origin and state of a catalog pack.
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

  /// E.g. `PokéAPI`.
  final String source;

  /// Pinned source snapshot (e.g. commit hash).
  final String sourceRevision;
}

/// Data coverage per version group – missing data is visible (ADR 0005).
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

  /// 0 = no location data is available for this version group.
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

/// Who learns a move in a version group.
@immutable
class MoveLearner {
  const MoveLearner(this.form, this.methods);
  final FormId form;
  final Set<LearnMethod> methods;
}

/// On-demand queries against the catalog (large tables such as learnsets),
/// complementing the fully loaded [CatalogSnapshot].
abstract interface class CatalogDetails {
  CatalogSourceInfo get source;

  List<LearnsetEntry> learnset(FormId form, VersionGroupId group);

  /// `null` if the move does not exist in this version group.
  MoveGameProfile? moveProfile(MoveId move, VersionGroupId group);

  /// Data per version group in chronological order.
  List<(VersionGroupId, MoveGameProfile)> moveHistory(MoveId move);

  List<MoveLearner> learnersOf(MoveId move, VersionGroupId group);

  /// Encounters of a form in a game version.
  List<Encounter> encountersOf(FormId form, GameVersionId version);

  /// All encounters at a location in a game version.
  List<Encounter> encountersAt(LocationId location, GameVersionId version);

  /// Locations with encounter data in a game version.
  List<LocationId> locationsWithEncounters(GameVersionId version);

  /// Whether there is any location data for this game version.
  bool hasEncounterData(GameVersionId version);

  /// Full-text search over moves, abilities and items.
  List<EntityHit> searchEntities(String query, {int limit = 30});

  List<CoverageRow> coverage();

  void close();
}
