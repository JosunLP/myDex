import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_details.dart';
import 'catalog_snapshot.dart';
import 'national_dex.dart';

/// Answers detail queries for the International Pokédex (ADR 0016) and
/// passes everything else to the game data.
///
/// - Learnsets: the newest game with a learnset for the form.
/// - Moves: the newest known values.
/// - Locations: locations are game-specific; the International Pokédex
///   lists all of them, encounters are read per game
///   ([encounterVersionsOf], [encounterVersionsAt]).
class NationalCatalogDetails implements CatalogDetails {
  NationalCatalogDetails(this.inner, this.catalog);

  final CatalogDetails inner;
  final CatalogSnapshot catalog;

  static bool _isNationalGroup(VersionGroupId g) =>
      g == NationalDex.versionGroupId;

  Map<FormId, VersionGroupId>? _newestLearnsets;
  final _newestMoves = <MoveId, MoveGameProfile?>{};
  List<LocationId>? _allLocations;
  bool? _anyEncounters;

  @override
  CatalogSourceInfo get source => inner.source;

  /// Version group the International Pokédex takes the learnset of [form]
  /// from; `null` if no game has one.
  VersionGroupId? learnsetSource(FormId form) => newestLearnsetGroups()[form];

  @override
  Map<FormId, VersionGroupId> newestLearnsetGroups() =>
      _newestLearnsets ??= inner.newestLearnsetGroups();

  @override
  List<LearnsetEntry> learnset(FormId form, VersionGroupId group) {
    if (!_isNationalGroup(group)) return inner.learnset(form, group);
    final source = learnsetSource(form);
    return source == null ? const [] : inner.learnset(form, source);
  }

  @override
  MoveGameProfile? moveProfile(MoveId move, VersionGroupId group) {
    if (!_isNationalGroup(group)) return inner.moveProfile(move, group);
    return _newestMoves.putIfAbsent(
      move,
      () => inner.moveHistory(move).lastOrNull?.$2,
    );
  }

  @override
  List<(VersionGroupId, MoveGameProfile)> moveHistory(MoveId move) =>
      inner.moveHistory(move);

  @override
  List<MoveLearner> learnersOf(MoveId move, VersionGroupId group) {
    if (!_isNationalGroup(group)) return inner.learnersOf(move, group);
    final newest = newestLearnsetGroups();
    return [
      for (final MapEntry(key: g, value: learners) in learnersByGroup(
        move,
      ).entries)
        for (final l in learners)
          if (newest[l.form] == g) l,
    ];
  }

  @override
  Map<VersionGroupId, List<MoveLearner>> learnersByGroup(MoveId move) =>
      inner.learnersByGroup(move);

  @override
  List<Encounter> encountersOf(FormId form, GameVersionId version) =>
      NationalDex.isNational(version)
      ? const []
      : inner.encountersOf(form, version);

  @override
  List<Encounter> encountersAt(LocationId location, GameVersionId version) =>
      NationalDex.isNational(version)
      ? const []
      : inner.encountersAt(location, version);

  @override
  List<LocationId> locationsWithEncounters(GameVersionId version) {
    if (!NationalDex.isNational(version)) {
      return inner.locationsWithEncounters(version);
    }
    return _allLocations ??= {
      for (final v in catalog.versions) ...inner.locationsWithEncounters(v.id),
    }.toList();
  }

  @override
  bool hasEncounterData(GameVersionId version) {
    if (!NationalDex.isNational(version)) {
      return inner.hasEncounterData(version);
    }
    return _anyEncounters ??= catalog.versions.any(
      (v) => inner.hasEncounterData(v.id),
    );
  }

  @override
  List<GameVersionId> encounterVersionsOf(FormId form) =>
      _chronological(inner.encounterVersionsOf(form));

  @override
  List<GameVersionId> encounterVersionsAt(LocationId location) =>
      _chronological(inner.encounterVersionsAt(location));

  /// In the order of the game picker (the snapshot's chronology).
  List<GameVersionId> _chronological(List<GameVersionId> versions) {
    final index = _versionIndex ??= {
      for (final (i, v) in catalog.versions.indexed) v.id: i,
    };
    return [...versions]
      ..sort((a, b) => (index[a] ?? -1).compareTo(index[b] ?? -1));
  }

  Map<GameVersionId, int>? _versionIndex;

  @override
  List<EntityHit> searchEntities(String query, {int limit = 30}) =>
      inner.searchEntities(query, limit: limit);

  @override
  List<CoverageRow> coverage() => inner.coverage();

  @override
  void close() => inner.close();
}
