import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Immutable, fully loaded catalog state.
@immutable
class CatalogSnapshot {
  CatalogSnapshot({
    required this.revision,
    required this.schemaVersion,
    required List<Ruleset> rulesets,
    required List<VersionGroup> versionGroups,
    required List<GameVersion> versions,
    required List<Species> species,
    required List<PokemonForm> forms,
    required List<Ability> abilities,
    List<Move> moves = const [],
    required this.itemNames,
    this.locationNames = const {},
    this.locations = const {},
    this.locationAreas = const {},
    this.encounterMethods = const {},
    this.encounterConditionNames = const {},
    this.regionNames = const {},
    this.natures = const {},
    this.items = const {},
    required this.evolutions,
  }) : rulesets = {for (final r in rulesets) r.id: r},
       versionGroups = {for (final g in versionGroups) g.id: g},
       versions = List.unmodifiable(
         <GameVersion>[...versions]..sort(
           (a, b) => _groupOrder(
             versionGroups,
             a.versionGroupId,
           ).compareTo(_groupOrder(versionGroups, b.versionGroupId)),
         ),
       ),
       species = {for (final s in species) s.id: s},
       forms = {for (final f in forms) f.id: f},
       abilities = {for (final a in abilities) a.id: a},
       moves = {for (final m in moves) m.id: m};

  static int _groupOrder(List<VersionGroup> groups, VersionGroupId id) =>
      groups.firstWhere((g) => g.id == id).order;

  final String revision;
  final int schemaVersion;
  final Map<RulesetId, Ruleset> rulesets;
  final Map<VersionGroupId, VersionGroup> versionGroups;

  /// Sorted chronologically.
  final List<GameVersion> versions;
  final Map<SpeciesId, Species> species;
  final Map<FormId, PokemonForm> forms;
  final Map<AbilityId, Ability> abilities;
  final Map<MoveId, Move> moves;
  final Map<ItemId, LocalizedText> itemNames;
  final Map<LocationId, LocalizedText> locationNames;
  final Map<LocationId, Location> locations;
  final Map<LocationAreaId, LocationArea> locationAreas;
  final Map<EncounterMethodId, EncounterMethod> encounterMethods;
  final Map<EncounterConditionId, LocalizedText> encounterConditionNames;
  final Map<RegionId, LocalizedText> regionNames;
  final Map<NatureId, Nature> natures;
  final Map<ItemId, ItemInfo> items;
  final List<EvolutionEdge> evolutions;

  GameContext contextFor(GameVersionId id) {
    final version = versions.firstWhere(
      (v) => v.id == id,
      orElse: () => throw ArgumentError('Unknown game version: ${id.value}'),
    );
    final group = versionGroups[version.versionGroupId]!;
    return GameContext(
      version: version,
      versionGroup: group,
      ruleset: rulesets[group.rulesetId]!,
      contentRevision: revision,
    );
  }

  /// The chronologically newest game is always the default context – even
  /// if data is still missing for it (gaps are shown then).
  GameContext get defaultContext => contextFor(versions.last.id);

  LocalizedText displayName(PokemonForm form) =>
      form.name ?? species[form.speciesId]!.name;
}
