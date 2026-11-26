import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_snapshot.dart';

/// The International Pokédex: a version-independent view of every form in
/// the catalog with the newest known data (ADR 0016).
///
/// It is derived from the game data instead of being stored, so a catalog
/// update automatically moves it to the newest state. Every value comes from
/// a real game; [profileSource] names which one (for learnsets:
/// `NationalCatalogDetails.learnsetSource`).
@immutable
class NationalDex {
  NationalDex._({
    required this.version,
    required this.versionGroup,
    required this.ruleset,
    required Map<FormId, FormGameProfile> profiles,
    required Map<FormId, VersionGroupId> profileSources,
    required this.evolutions,
  }) : _profiles = profiles,
       _profileSources = profileSources;

  /// Stable ID of the International Pokédex as a "game version". It is
  /// stored in settings and teams, so it must never change.
  static const versionId = GameVersionId('national');
  static const versionGroupId = VersionGroupId('national');
  static const rulesetId = RulesetId('national');

  /// Names in the catalog languages. Ja/ko/zh use the established term of
  /// the games for the complete, region-independent Pokédex.
  static const name = LocalizedText({
    'de': 'Internationaler Pokédex',
    'en': 'International Pokédex',
    'es': 'Pokédex Internacional',
    'fr': 'Pokédex International',
    'it': 'Pokédex Internazionale',
    'pt': 'Pokédex Internacional',
    'ja': '全国図鑑',
    'ja-Hrkt': 'ぜんこくずかん',
    'ko': '전국도감',
    'zh-Hans': '全国图鉴',
    'zh-Hant': '全國圖鑑',
  });

  final GameVersion version;
  final VersionGroup versionGroup;
  final Ruleset ruleset;
  final Map<FormId, FormGameProfile> _profiles;
  final Map<FormId, VersionGroupId> _profileSources;

  /// Evolutions in their newest known form, valid in [versionGroupId].
  final List<EvolutionEdge> evolutions;

  static bool isNational(GameVersionId id) => id == versionId;

  /// Newest known profile of a form. Every form of the catalog exists in the
  /// franchise, so it is available; only forms without any type or base stat
  /// data are marked as a data gap.
  FormGameProfile profileOf(FormId form) =>
      _profiles[form] ?? FormGameProfile.notResearched;

  /// Version group the types and base stats of [form] come from.
  VersionGroupId? profileSource(FormId form) => _profileSources[form];

  /// Derives the International Pokédex from the game data of [catalog].
  factory NationalDex.derive(CatalogSnapshot catalog) {
    final groups = catalog.versionGroups.values.toList()
      ..sort((a, b) => b.order.compareTo(a.order)); // newest first
    final newest = groups.isEmpty ? null : groups.first;
    final generation = groups.fold(
      0,
      (g, v) => v.generation > g ? v.generation : g,
    );
    final ruleset = Ruleset(
      id: rulesetId,
      generation: generation,
      // The newest era of all rulesets: the current type chart.
      typeChartEra: catalog.rulesets.values.fold(
        TypeChartEra.gen1,
        (e, r) => r.typeChartEra.index > e.index ? r.typeChartEra : e,
      ),
      statFormula: StatFormula.modern,
      partySize: 6,
      hasAbilities: true,
      hasHeldItems: true,
      hasNatures: true,
      unifiedSpecial: false,
      hasBreeding: true,
    );
    final group = VersionGroup(
      id: versionGroupId,
      generation: generation,
      rulesetId: rulesetId,
      name: name,
      order: (newest?.order ?? 0) + 1,
    );
    const version = GameVersion(
      id: versionId,
      versionGroupId: versionGroupId,
      name: name,
    );

    final profiles = <FormId, FormGameProfile>{};
    final sources = <FormId, VersionGroupId>{};
    // Preference per value, best first: a game with its own data that
    // confirms the form, any game that confirms it, a game with its own
    // data, any game. Expansions without own data ("no data" in the picker)
    // only repeat their base game, so they are not cited as the source.
    int rank(VersionGroup g, FormGameProfile p) =>
        (p.availability == DataAvailability.confirmedAvailable ? 0 : 2) +
        (g.hasData ? 0 : 1);
    for (final form in catalog.forms.values) {
      (int, VersionGroup, FormGameProfile)? core;
      (int, List<AbilitySlot>)? abilities;
      for (final g in groups) {
        final p = form.profiles[g.id];
        if (p == null) continue;
        final r = rank(g, p);
        // Types and base stats belong together: take them from one game.
        if (p.types.isNotEmpty &&
            p.baseStats != null &&
            (core == null || r < core.$1)) {
          core = (r, g, p);
        }
        final hasAbilities =
            catalog.rulesets[g.rulesetId]?.hasAbilities ?? false;
        if (hasAbilities &&
            p.abilities.isNotEmpty &&
            (abilities == null || r < abilities.$1)) {
          abilities = (r, p.abilities);
        }
        if (core?.$1 == 0 && abilities?.$1 == 0) break;
      }
      if (core == null) continue; // data gap: not researched
      final (_, sourceGroup, profile) = core;
      sources[form.id] = sourceGroup.id;
      profiles[form.id] = FormGameProfile(
        availability: DataAvailability.confirmedAvailable,
        types: profile.types,
        baseStats: profile.baseStats,
        abilities: abilities?.$2 ?? const [],
      );
    }

    return NationalDex._(
      version: version,
      versionGroup: group,
      ruleset: ruleset,
      profiles: profiles,
      profileSources: sources,
      evolutions: _newestEvolutions(catalog),
    );
  }

  /// Per evolution (from → to) the edges of the newest game that has it:
  /// conditions change over time (e.g. Leafeon: Moss Rock → Leaf Stone).
  static List<EvolutionEdge> _newestEvolutions(CatalogSnapshot catalog) {
    int order(VersionGroupId g) => catalog.versionGroups[g]?.order ?? -1;
    int newestOf(EvolutionEdge e) =>
        e.versionGroups.fold(-1, (m, g) => order(g) > m ? order(g) : m);
    final newestPerPair = <(FormId, FormId), int>{};
    for (final e in catalog.evolutions) {
      final key = (e.from, e.to);
      final n = newestOf(e);
      if (n > (newestPerPair[key] ?? -2)) newestPerPair[key] = n;
    }
    return [
      for (final e in catalog.evolutions)
        if (newestOf(e) == newestPerPair[(e.from, e.to)])
          EvolutionEdge(
            from: e.from,
            to: e.to,
            condition: e.condition,
            versionGroups: {versionGroupId},
          ),
    ];
  }
}
