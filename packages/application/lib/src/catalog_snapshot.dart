import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Unveränderlicher, vollständig geladener Katalogstand.
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
    required this.itemNames,
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
       abilities = {for (final a in abilities) a.id: a};

  static int _groupOrder(List<VersionGroup> groups, VersionGroupId id) =>
      groups.firstWhere((g) => g.id == id).order;

  final String revision;
  final int schemaVersion;
  final Map<RulesetId, Ruleset> rulesets;
  final Map<VersionGroupId, VersionGroup> versionGroups;

  /// Chronologisch sortiert.
  final List<GameVersion> versions;
  final Map<SpeciesId, Species> species;
  final Map<FormId, PokemonForm> forms;
  final Map<AbilityId, Ability> abilities;
  final Map<ItemId, LocalizedText> itemNames;
  final List<EvolutionEdge> evolutions;

  GameContext contextFor(GameVersionId id) {
    final version = versions.firstWhere(
      (v) => v.id == id,
      orElse: () => throw ArgumentError('Unbekannte Spielversion: ${id.value}'),
    );
    final group = versionGroups[version.versionGroupId]!;
    return GameContext(
      version: version,
      versionGroup: group,
      ruleset: rulesets[group.rulesetId]!,
      contentRevision: revision,
    );
  }

  /// Neueste Spielversion als Standardkontext.
  GameContext get defaultContext => contextFor(versions.last.id);

  LocalizedText displayName(PokemonForm form) =>
      form.name ?? species[form.speciesId]!.name;
}
