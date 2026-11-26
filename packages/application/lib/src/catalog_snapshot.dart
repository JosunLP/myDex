import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'national_dex.dart';

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

  /// The International Pokédex derived from this catalog (ADR 0016).
  late final NationalDex national = NationalDex.derive(this);

  /// Context of a game version or of the International Pokédex.
  GameContext contextFor(GameVersionId id) {
    if (NationalDex.isNational(id)) return nationalContext;
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

  /// Version-independent context with the newest data of every form.
  late final GameContext nationalContext = GameContext(
    version: national.version,
    versionGroup: national.versionGroup,
    ruleset: national.ruleset,
    contentRevision: revision,
  );

  /// The International Pokédex is the default context: it shows every
  /// Pokémon with its newest data, independent of a single game.
  GameContext get defaultContext => nationalContext;

  /// Whether [id] names a game version or the International Pokédex.
  bool hasVersion(GameVersionId id) =>
      NationalDex.isNational(id) || versions.any((v) => v.id == id);

  /// A game version or the International Pokédex; `null` if unknown.
  GameVersion? versionById(GameVersionId id) => NationalDex.isNational(id)
      ? national.version
      : versions.where((v) => v.id == id).firstOrNull;

  /// Profile of [form] in a version group, including the International
  /// Pokédex. Use this instead of [PokemonForm.profileFor] for contexts.
  FormGameProfile profileOf(PokemonForm form, VersionGroupId group) =>
      group == NationalDex.versionGroupId
      ? national.profileOf(form.id)
      : form.profileFor(group);

  /// Evolutions valid in a version group (or the International Pokédex).
  List<EvolutionEdge> evolutionsIn(VersionGroupId group) =>
      group == NationalDex.versionGroupId
      ? national.evolutions
      : (_evolutionsByGroup[group] ??= [
          for (final e in evolutions)
            if (e.versionGroups.contains(group)) e,
        ]);

  final Map<VersionGroupId, List<EvolutionEdge>> _evolutionsByGroup = {};

  LocalizedText displayName(PokemonForm form) =>
      form.name ?? species[form.speciesId]!.name;
}
