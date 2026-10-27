import 'dart:convert';
import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:sqlite3/sqlite3.dart';

import 'csv.dart';
import 'source.dart';

/// Quell-Sprach-ID → Sprachcode im Katalog.
const languageCodes = {
  1: 'ja-Hrkt',
  11: 'ja',
  3: 'ko',
  4: 'zh-Hant',
  12: 'zh-Hans',
  5: 'fr',
  6: 'de',
  7: 'es',
  8: 'it',
  9: 'en',
  13: 'pt',
};

/// Damage-Class-IDs der Quelle.
const _damageClasses = {
  1: DamageClass.status,
  2: DamageClass.physical,
  3: DamageClass.special,
};

/// Bis Gen 3 bestimmte der Typ die Schadensklasse.
const _physicalTypesGen1to3 = {
  PokemonType.normal,
  PokemonType.fighting,
  PokemonType.flying,
  PokemonType.poison,
  PokemonType.ground,
  PokemonType.rock,
  PokemonType.bug,
  PokemonType.ghost,
  PokemonType.steel,
};

class BuildOptions {
  const BuildOptions({required this.revision, this.speciesFilter});

  final String revision;

  /// Nur diese Arten (nationale Nummern) – für kleine Testkataloge.
  final Set<int>? speciesFilter;
}

class BuildReport {
  final problems = <String>[];
  final _warnings = <String>{};
  List<String> get warnings => _warnings.toList();
  void warn(String w) => _warnings.add(w);
  final counts = <String, int>{};

  @override
  String toString() => [
    for (final e in counts.entries) '${e.key}: ${e.value}',
    'Warnungen: ${warnings.length}',
    for (final w in warnings.take(30)) '  ⚠ $w',
    if (warnings.length > 30) '  … ${warnings.length - 30} weitere',
    'Probleme: ${problems.length}',
    for (final p in problems.take(50)) '  ✗ $p',
  ].join('\n');
}

class _Group {
  _Group(this.rid, this.id, this.generation, this.order, this.ruleset);
  final int rid;
  final String id;
  final int generation;
  final int order;
  final _Ruleset ruleset;
  final regions = <int>{};
  bool hasData = false;
}

class _Ruleset {
  const _Ruleset(
    this.id,
    this.generation,
    this.era,
    this.formula, {
    required this.abilities,
    required this.heldItems,
    required this.natures,
    this.breeding = false,
  });
  final String id;
  final int generation;
  final TypeChartEra era;
  final StatFormula formula;
  final bool abilities;
  final bool heldItems;
  final bool natures;
  final bool breeding;
  bool get unifiedSpecial => generation == 1;
}

_Ruleset _rulesetFor(String group, int gen) {
  // Bekannte Sonderregeln einzelner Spiele.
  if (group == 'lets-go-pikachu-lets-go-eevee') {
    return const _Ruleset(
      'lgpe',
      7,
      TypeChartEra.gen6plus,
      StatFormula.modern,
      abilities: false,
      heldItems: false,
      natures: true,
    );
  }
  if (group == 'legends-arceus') {
    return const _Ruleset(
      'pla',
      8,
      TypeChartEra.gen6plus,
      StatFormula.modern,
      abilities: false,
      heldItems: false,
      natures: true,
    );
  }
  final era = gen == 1
      ? TypeChartEra.gen1
      : (gen <= 5 ? TypeChartEra.gen2to5 : TypeChartEra.gen6plus);
  // Spiele ohne Pension/Zucht erhalten ein eigenes Regelwerk.
  final noBreeding = switch (group) {
    'colosseum' || 'xd' => 'orre',
    'legends-za' || 'mega-dimension' => 'lza',
    'champions' => 'champions',
    _ => null,
  };
  return _Ruleset(
    noBreeding ?? 'gen$gen',
    gen,
    era,
    gen <= 2 ? StatFormula.gen1to2 : StatFormula.modern,
    abilities: gen >= 3,
    heldItems: gen >= 2,
    natures: gen >= 3,
    breeding: noBreeding == null && gen >= 2,
  );
}

/// Baut den Katalog aus den Quelltabellen.
class CatalogBuilder {
  CatalogBuilder(this.t, this.options);

  final SourceTables t;
  final BuildOptions options;
  final report = BuildReport();

  late final Database _db;
  final _groups = <int, _Group>{}; // Quell-VG-ID → Gruppe
  final _typeKeys = <int, PokemonType>{};
  final _speciesGen = <int, int>{};
  final _speciesIdent = <int, String>{};
  final _formSpecies = <int, int>{};
  final _formIdent = <int, String>{};
  final _formIntroducedOrder = <int, int>{};
  final _defaultForm = <int, int>{}; // Art → Standardform
  final _pokemonFormToPokemon = <int, int>{};
  final _moveGen = <int, int>{};
  final _abilityGen = <int, int>{};
  final _availability = <(int, int), DataAvailability>{}; // (Form, VG)
  final _learnsetForms = <int, Set<int>>{}; // VG → Formen mit Erlernbarkeit
  final _usedMoves = <int, Set<int>>{}; // VG → Attacken
  final _items = <int, String>{};
  final _locations = <int, (String, int)>{}; // ID → (Bezeichner, Region)
  final _encounterForms = <int, Set<int>>{}; // VG → Formen mit Begegnungen
  final _encounterEntries = <int, int>{}; // VG → Anzahl
  final _regions = <int, String>{};

  BuildReport build(File out) {
    if (out.existsSync()) out.deleteSync();
    _db = sqlite3.open(out.path);
    try {
      _db.execute(
        'PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF; PRAGMA page_size = 4096;',
      );
      _db.execute('BEGIN');
      for (final sql in catalogSchemaSql) {
        _db.execute(sql);
      }
      _meta();
      _games();
      _species();
      _forms();
      _abilities();
      _items_();
      _moves();
      _learnsets();
      _locationsTable();
      _encounters();
      _formProfiles();
      _moveProfiles();
      _machines();
      _evolutions();
      _coverage();
      _searchIndex();
      _db.execute('COMMIT');
      _db.execute('VACUUM');
    } finally {
      _db.close();
    }
    if (report.problems.isEmpty) {
      final snapshot = loadCatalogSnapshot(out.path);
      report.problems.addAll(validateCatalog(snapshot));
    }
    return report;
  }

  bool _speciesIncluded(int species) =>
      options.speciesFilter == null || options.speciesFilter!.contains(species);

  void _insert(String table, List<Object?> values) {
    final placeholders = List.filled(values.length, '?').join(',');
    _db.execute('INSERT INTO $table VALUES ($placeholders)', values);
  }

  void _names(
    String kind,
    String table,
    String idColumn, {
    String nameColumn = 'name',
    Set<int>? only,
  }) {
    final stmt = _db.prepare('INSERT OR REPLACE INTO name VALUES (?, ?, ?, ?)');
    final rows =
        t[table]
            .where(
              (r) =>
                  languageCodes.containsKey(int.parse(r['local_language_id']!)),
            )
            .toList()
          ..sort((a, b) {
            final c = int.parse(
              a[idColumn]!,
            ).compareTo(int.parse(b[idColumn]!));
            return c != 0
                ? c
                : int.parse(
                    a['local_language_id']!,
                  ).compareTo(int.parse(b['local_language_id']!));
          });
    for (final r in rows) {
      final ref = r.integer(idColumn);
      final text = r[nameColumn] ?? '';
      if (text.isEmpty || (only != null && !only.contains(ref))) continue;
      stmt.execute([
        kind,
        ref,
        languageCodes[r.integer('local_language_id')],
        text,
      ]);
    }
    stmt.close();
  }

  void _meta() {
    for (final e in {
      'schemaVersion': '$catalogSchemaVersion',
      'revision': options.revision,
      'source': 'PokéAPI',
      'sourceRepository': pokeApiRepository,
      'sourceRevision': pokeApiCommit,
      'languages': languageCodes.values.join(','),
      'subset': options.speciesFilter == null ? 'false' : 'true',
    }.entries) {
      _insert('meta', [e.key, e.value]);
    }
  }

  void _games() {
    for (final r in t['types']) {
      final id = r.integer('id');
      // Nur die 18 Kampftypen; Sondertypen wie „stellar“ (Tera) bleiben außen vor.
      final type = PokemonType.values
          .where((t) => t.key == r['identifier'])
          .firstOrNull;
      if (id < 10000 && type != null) _typeKeys[id] = type;
    }
    for (final r in t['regions']) {
      _regions[r.integer('id')] = r['identifier']!;
    }
    final rulesets = <String, _Ruleset>{};
    for (final r
        in t['version_groups']
          ..sort((a, b) => a.integer('order').compareTo(b.integer('order')))) {
      final ruleset = _rulesetFor(r['identifier']!, r.integer('generation_id'));
      rulesets[ruleset.id] = ruleset;
      _groups[r.integer('id')] = _Group(
        r.integer('id'),
        r['identifier']!,
        r.integer('generation_id'),
        r.integer('order'),
        ruleset,
      );
    }
    for (final r in t['version_group_regions']) {
      _groups[r.integer('version_group_id')]?.regions.add(
        r.integer('region_id'),
      );
    }
    for (final rs
        in rulesets.values.toList()..sort((a, b) => a.id.compareTo(b.id))) {
      _insert('ruleset', [
        rs.id,
        rs.generation,
        rs.era.key,
        rs.formula.key,
        6,
        rs.abilities ? 1 : 0,
        rs.heldItems ? 1 : 0,
        rs.natures ? 1 : 0,
        rs.unifiedSpecial ? 1 : 0,
        rs.breeding ? 1 : 0,
      ]);
    }
    // Spielgruppen werden in _coverage mit has_data ergänzt; hier nur anlegen.
    final versions = [...t['versions']]
      ..sort((a, b) {
        final g = _groups[a.integer('version_group_id')]!.order.compareTo(
          _groups[b.integer('version_group_id')]!.order,
        );
        return g != 0 ? g : a.integer('id').compareTo(b.integer('id'));
      });
    for (final v in versions) {
      _insert('version', [
        v.integer('id'),
        v['identifier'],
        v.integer('version_group_id'),
      ]);
    }
    _names('version', 'version_names', 'version_id');
    // Namen der Spielgruppen: Versionsnamen mit „ / “ verbunden.
    final versionNames = <int, Map<String, String>>{};
    for (final r in t['version_names']) {
      final lang = languageCodes[r.integer('local_language_id')];
      if (lang != null) {
        versionNames.putIfAbsent(r.integer('version_id'), () => {})[lang] =
            r['name']!;
      }
    }
    for (final g in _groups.values) {
      final members = versions
          .where((v) => v.integer('version_group_id') == g.rid)
          .map((v) => v.integer('id'));
      for (final lang in languageCodes.values) {
        final parts = [for (final m in members) ?versionNames[m]?[lang]];
        if (parts.length == members.length && parts.isNotEmpty) {
          _insert('name', ['version_group', g.rid, lang, parts.join(' / ')]);
        }
      }
    }
  }

  void _species() {
    final eggGroups = {
      for (final r in t['egg_groups']) r.integer('id'): r['identifier']!,
    };
    final groupsOf = <int, Set<String>>{};
    for (final r in t['pokemon_egg_groups']) {
      groupsOf
          .putIfAbsent(r.integer('species_id'), () => {})
          .add(eggGroups[r.integer('egg_group_id')]!);
    }
    final familyBreeds = <int?, bool>{};
    for (final r in t['pokemon_species']) {
      final groups = groupsOf[r.integer('id')] ?? const <String>{};
      final breeds = groups.any((g) => g != 'no-eggs' && g != 'ditto');
      final chain = r.optInt('evolution_chain_id');
      familyBreeds[chain] = (familyBreeds[chain] ?? false) || breeds;
    }
    for (final r in t['pokemon_species']) {
      final id = r.integer('id');
      _speciesGen[id] = r.integer('generation_id');
      _speciesIdent[id] = r['identifier']!;
      if (!_speciesIncluded(id)) continue;
      // Schlüpfbar, wenn ein Mitglied der Entwicklungsfamilie Eier legen kann
      // (Babys wie Pichu sind selbst „unbekannt“, schlüpfen aber aus Eiern).
      final hatchable = familyBreeds[r.optInt('evolution_chain_id')] ?? false;
      _insert('species', [
        id,
        r['identifier'],
        id,
        r.integer('generation_id'),
        hatchable ? 1 : 0,
        // Mysteriöse Pokémon gibt es in der Regel nur über Events.
        r.flag('is_mythical') ? 1 : 0,
      ]);
    }
    _names(
      'species',
      'pokemon_species_names',
      'pokemon_species_id',
      only: {
        for (final r in t['pokemon_species'])
          if (_speciesIncluded(r.integer('id'))) r.integer('id'),
      },
    );
  }

  void _forms() {
    final defaultPokemonForm = <int, Map<String, String>>{};
    for (final f in t['pokemon_forms']) {
      _pokemonFormToPokemon[f.integer('id')] = f.integer('pokemon_id');
      if (f.flag('is_default')) defaultPokemonForm[f.integer('pokemon_id')] = f;
    }
    final ownNames = <int, Map<String, String>>{};
    final formToPokemon = {
      for (final e in defaultPokemonForm.entries) e.value.integer('id'): e.key,
    };
    for (final r in t['pokemon_form_names']) {
      final pokemon = formToPokemon[r.integer('pokemon_form_id')];
      final lang = languageCodes[r.integer('local_language_id')];
      final name = r['pokemon_name'] ?? '';
      if (pokemon != null && lang != null && name.isNotEmpty) {
        ownNames.putIfAbsent(pokemon, () => {})[lang] = name;
      }
    }
    final pokemon = [...t['pokemon']]
      ..sort((a, b) {
        final s = a.integer('species_id').compareTo(b.integer('species_id'));
        if (s != 0) return s;
        if (a.flag('is_default') != b.flag('is_default')) {
          return a.flag('is_default') ? -1 : 1;
        }
        return a.integer('id').compareTo(b.integer('id'));
      });
    var sort = 0;
    for (final r in pokemon) {
      final id = r.integer('id');
      final species = r.integer('species_id');
      _formSpecies[id] = species;
      _formIdent[id] = r['identifier']!;
      final pf = defaultPokemonForm[id];
      final introduced = pf?.optInt('introduced_in_version_group_id');
      _formIntroducedOrder[id] = introduced == null
          ? 0
          : _groups[introduced]!.order;
      if (r.flag('is_default')) _defaultForm[species] = id;
      if (!_speciesIncluded(species)) continue;
      final names = ownNames[id];
      _insert('form', [
        id,
        r['identifier'],
        species,
        r.flag('is_default') ? 1 : 0,
        names == null ? 0 : 1,
        (pf?.flag('is_battle_only') ?? false) ? 1 : 0,
        sort++,
      ]);
      for (final e in (names ?? const <String, String>{}).entries) {
        _insert('name', ['form', id, e.key, e.value]);
      }
    }
  }

  void _abilities() {
    final ids = <int>{};
    for (final r in t['abilities']) {
      if (!r.flag('is_main_series')) continue;
      final id = r.integer('id');
      ids.add(id);
      _abilityGen[id] = r.integer('generation_id');
      _insert('ability', [id, r['identifier'], r.integer('generation_id')]);
    }
    _names('ability', 'ability_names', 'ability_id', only: ids);
  }

  void _items_() {
    final pockets = {
      for (final r in t['item_pockets']) r.integer('id'): r['identifier']!,
    };
    final categoryPocket = {
      for (final r in t['item_categories'])
        r.integer('id'): pockets[r.integer('pocket_id')],
    };
    final generations = <int, int>{};
    for (final r in t['item_game_indices']) {
      final id = r.integer('item_id');
      generations[id] =
          (generations[id] ?? 0) | (1 << r.integer('generation_id'));
    }
    final seen = <String>{};
    for (final r in [
      ...t['items'],
    ]..sort((a, b) => a.integer('id').compareTo(b.integer('id')))) {
      var ident = r['identifier']!;
      if (!seen.add(ident)) {
        // Die Quelle enthält doppelte Bezeichner; die stabile ID erhält die Quell-ID.
        report.warn('Item-Bezeichner $ident doppelt (Quell-ID ${r['id']})');
        ident = '$ident--${r['id']}';
      }
      _items[r.integer('id')] = ident;
      _insert('item', [
        r.integer('id'),
        ident,
        categoryPocket[r.optInt('category_id')],
        generations[r.integer('id')] ?? 0,
      ]);
    }
    _names('item', 'item_names', 'item_id');
    const statKeys = {
      2: 'attack',
      3: 'defense',
      4: 'specialAttack',
      5: 'specialDefense',
      6: 'speed',
    };
    for (final r in [
      ...t['natures'],
    ]..sort((a, b) => a.integer('id').compareTo(b.integer('id')))) {
      final up = r.integer('increased_stat_id');
      final down = r.integer('decreased_stat_id');
      // Neutrale Wesen erhöhen und senken denselben Wert – also keinen.
      _insert('nature', [
        r.integer('id'),
        r['identifier'],
        up == down ? null : statKeys[up],
        up == down ? null : statKeys[down],
      ]);
    }
    _names('nature', 'nature_names', 'nature_id');
  }

  void _moves() {
    final ids = <int>{};
    for (final r in t['moves']) {
      final id = r.integer('id');
      if (id >= 10000) {
        continue; // Schatten-Attacken (Colosseum/XD) folgen gesondert
      }
      ids.add(id);
      _moveGen[id] = r.integer('generation_id');
      _insert('move', [id, r['identifier'], r.integer('generation_id')]);
    }
    _names('move', 'move_names', 'move_id', only: ids);
  }

  void _learnsets() {
    final methodKeys = {
      for (final r in t['pokemon_move_methods'])
        r.integer('id'): r['identifier']!,
    };
    final stmt = _db.prepare(
      'INSERT OR IGNORE INTO learnset VALUES (?, ?, ?, ?, ?, ?)',
    );
    final rows = t['pokemon_moves'];
    for (final r in rows) {
      final form = r.integer('pokemon_id');
      final move = r.integer('move_id');
      final group = r.integer('version_group_id');
      final species = _formSpecies[form];
      if (species == null ||
          !_moveGen.containsKey(move) ||
          !_groups.containsKey(group)) {
        continue;
      }
      _learnsetForms.putIfAbsent(group, () => {}).add(form);
      _usedMoves.putIfAbsent(group, () => {}).add(move);
      if (!_speciesIncluded(species)) continue;
      final method = r.integer('pokemon_move_method_id');
      final code = method <= 4 ? method : 100 + method;
      stmt.execute([
        form,
        group,
        code,
        move,
        method == LearnMethodCode.levelUp ? (r.optInt('level') ?? 0) : 0,
        method <= 4 ? null : methodKeys[method],
      ]);
    }
    stmt.close();
    for (final r in t['machines']) {
      final move = r.integer('move_id');
      if (_moveGen.containsKey(move)) {
        _usedMoves
            .putIfAbsent(r.integer('version_group_id'), () => {})
            .add(move);
      }
    }
  }

  /// Wert aus „Vergangenheits“-Zeilen: gültig bis einschließlich deren Generation.
  static T? _past<T>(Iterable<(int, T)> rows, int generation) {
    (int, T)? best;
    for (final row in rows) {
      if (row.$1 >= generation && (best == null || row.$1 < best.$1)) {
        best = row;
      }
    }
    return best?.$2;
  }

  void _formProfiles() {
    final stats = <int, Map<int, int>>{};
    for (final r in t['pokemon_stats']) {
      stats.putIfAbsent(r.integer('pokemon_id'), () => {})[r.integer(
        'stat_id',
      )] = r.integer(
        'base_stat',
      );
    }
    final pastStats = <(int, int), List<(int, int)>>{};
    for (final r in t['pokemon_stats_past']) {
      pastStats
          .putIfAbsent((
            r.integer('pokemon_id'),
            r.integer('stat_id'),
          ), () => [])
          .add((r.integer('generation_id'), r.integer('base_stat')));
    }
    final types = <int, List<(int, int)>>{};
    for (final r in t['pokemon_types']) {
      types.putIfAbsent(r.integer('pokemon_id'), () => []).add((
        r.integer('slot'),
        r.integer('type_id'),
      ));
    }
    final pastTypes = <int, Map<int, List<(int, int)>>>{};
    for (final r in t['pokemon_types_past']) {
      pastTypes
          .putIfAbsent(r.integer('pokemon_id'), () => {})
          .putIfAbsent(r.integer('generation_id'), () => [])
          .add((r.integer('slot'), r.integer('type_id')));
    }
    final abilities = <int, Map<int, int>>{};
    for (final r in t['pokemon_abilities']) {
      abilities.putIfAbsent(r.integer('pokemon_id'), () => {})[r.integer(
        'slot',
      )] = r.integer(
        'ability_id',
      );
    }
    final pastAbilities = <(int, int), List<(int, int?)>>{};
    for (final r in t['pokemon_abilities_past']) {
      pastAbilities
          .putIfAbsent((r.integer('pokemon_id'), r.integer('slot')), () => [])
          .add((r.integer('generation_id'), r.optInt('ability_id')));
    }

    final stmt = _db.prepare(
      'INSERT INTO form_profile VALUES (${List.filled(15, '?').join(',')})',
    );
    final forms =
        _formSpecies.keys
            .where((f) => _speciesIncluded(_formSpecies[f]!))
            .toList()
          ..sort();
    final groups = _groups.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final form in forms) {
      final species = _formSpecies[form]!;
      for (final g in groups) {
        final DataAvailability availability;
        if ((_learnsetForms[g.rid]?.contains(form) ?? false) ||
            (_encounterForms[g.rid]?.contains(form) ?? false)) {
          availability = DataAvailability.confirmedAvailable;
        } else if (_speciesGen[species]! > g.generation ||
            _formIntroducedOrder[form]! > g.order) {
          availability = DataAvailability.confirmedUnavailable;
        } else {
          availability = DataAvailability.notResearched;
        }
        _availability[(form, g.rid)] = availability;
        if (availability == DataAvailability.confirmedUnavailable) {
          stmt.execute([
            form,
            g.rid,
            availability.key,
            ...List.filled(12, null),
          ]);
          continue;
        }
        final gen = g.generation;
        // Typen
        final past = pastTypes[form];
        List<(int, int)>? typeRows;
        if (past != null) {
          final gens = past.keys.where((k) => k >= gen).toList()..sort();
          if (gens.isNotEmpty) typeRows = past[gens.first];
        }
        typeRows = [...(typeRows ?? types[form] ?? const [])]
          ..sort((a, b) => a.$1.compareTo(b.$1));
        final typeKeys = [for (final r in typeRows) _typeKeys[r.$2]?.key];
        // Basiswerte
        int stat(int id) =>
            _past(pastStats[(form, id)] ?? const [], gen) ??
            stats[form]?[id] ??
            -1;
        final special = g.ruleset.unifiedSpecial
            ? _past(pastStats[(form, 9)] ?? const [], 1)
            : null;
        if (g.ruleset.unifiedSpecial && special == null) {
          report.warn('${_formIdent[form]}: kein Gen-1-Spezialwert');
        }
        // Fähigkeiten
        int? ability(int slot) {
          if (!g.ruleset.abilities) return null;
          // Versteckte Fähigkeiten gibt es erst ab Gen 5.
          if (slot == 3 && gen < 5) return null;
          final pastRows = pastAbilities[(form, slot)];
          if (pastRows != null) {
            (int, int?)? best;
            for (final row in pastRows) {
              if (row.$1 >= gen && (best == null || row.$1 < best.$1)) {
                best = row;
              }
            }
            if (best != null) return best.$2;
          }
          final a = abilities[form]?[slot];
          if (a != null && (_abilityGen[a] ?? 99) > gen) {
            report.warn(
              '${_formIdent[form]} in ${g.id}: Fähigkeit $a erst ab Gen ${_abilityGen[a]}',
            );
            return null;
          }
          return a;
        }

        final hasStats = stats.containsKey(form);
        stmt.execute([
          form,
          g.rid,
          availability.key,
          typeKeys.isNotEmpty ? typeKeys[0] : null,
          typeKeys.length > 1 ? typeKeys[1] : null,
          if (hasStats) ...[
            stat(1),
            stat(2),
            stat(3),
            special ?? stat(4),
            special ?? stat(5),
            stat(6),
            special,
          ] else
            ...List.filled(7, null),
          ability(1),
          ability(2),
          ability(3),
        ]);
      }
    }
    stmt.close();
  }

  void _moveProfiles() {
    final changes = <int, List<Map<String, String>>>{};
    for (final r in t['move_changelog']) {
      changes.putIfAbsent(r.integer('move_id'), () => []).add(r);
    }
    final stmt = _db.prepare(
      'INSERT INTO move_profile VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    );
    final groups = _groups.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final moves =
        t['moves'].where((r) => _moveGen.containsKey(r.integer('id'))).toList()
          ..sort((a, b) => a.integer('id').compareTo(b.integer('id')));
    for (final m in moves) {
      final id = m.integer('id');
      for (final g in groups) {
        if (g.generation < _moveGen[id]!) continue;
        // Je Feld: der früheste Änderungseintrag nach dieser Spielgruppe gilt.
        String? field(String column) {
          Map<String, String>? best;
          for (final c in changes[id] ?? const <Map<String, String>>[]) {
            final changedIn =
                _groups[c.integer('changed_in_version_group_id')]!.order;
            if (changedIn > g.order &&
                (c[column] ?? '').isNotEmpty &&
                (best == null ||
                    changedIn <
                        _groups[best.integer('changed_in_version_group_id')]!
                            .order)) {
              best = c;
            }
          }
          return best != null ? best[column] : m[column];
        }

        int? optional(String column) {
          final v = field(column);
          return v == null || v.isEmpty ? null : int.parse(v);
        }

        final typeId = optional('type_id');
        final type = typeId == null ? null : _typeKeys[typeId];
        if (type == null) {
          report.warn('Attacke ${m['identifier']}: unbekannter Typ $typeId');
          continue;
        }
        var damageClass =
            _damageClasses[m.optInt('damage_class_id')] ?? DamageClass.status;
        if (g.generation <= 3 && damageClass != DamageClass.status) {
          damageClass = _physicalTypesGen1to3.contains(type)
              ? DamageClass.physical
              : DamageClass.special;
        }
        final available = _usedMoves[g.rid]?.contains(id) ?? false;
        stmt.execute([
          id,
          g.rid,
          (available
                  ? DataAvailability.confirmedAvailable
                  : DataAvailability.notResearched)
              .key,
          type.key,
          damageClass.name,
          optional('power'),
          optional('accuracy'),
          optional('pp'),
          optional('priority') ?? 0,
        ]);
      }
    }
    stmt.close();
  }

  void _machines() {
    final rows = [...t['machines']]
      ..sort((a, b) {
        final g = a
            .integer('version_group_id')
            .compareTo(b.integer('version_group_id'));
        return g != 0
            ? g
            : a.integer('move_id').compareTo(b.integer('move_id'));
      });
    for (final r in rows) {
      if (!_moveGen.containsKey(r.integer('move_id')) ||
          !_items.containsKey(r.integer('item_id'))) {
        continue;
      }
      _db.execute('INSERT OR IGNORE INTO machine VALUES (?, ?, ?)', [
        r.integer('version_group_id'),
        r.integer('move_id'),
        r.integer('item_id'),
      ]);
    }
  }

  EvolutionCondition? _condition(
    Map<String, String> r,
    Map<int, String> triggers,
  ) {
    final atoms = <EvolutionCondition>[];
    final trigger = triggers[r.integer('evolution_trigger_id')]!;
    switch (trigger) {
      case 'level-up':
        if (r.optInt('minimum_level') case final level?) {
          atoms.add(MinLevel(level));
        }
      case 'trade':
        atoms.add(const Trade());
      case 'use-item':
        final item = r.optInt('trigger_item_id');
        if (item != null) atoms.add(UseItem(ItemId(_items[item]!)));
      default:
        atoms.add(SpecialCondition(trigger));
    }
    if (r.optInt('held_item_id') case final item?) {
      atoms.add(HoldItem(ItemId(_items[item]!)));
    }
    switch (r['time_of_day']) {
      case 'day':
        atoms.add(const TimeOfDayCondition(TimeOfDay.day));
      case 'night':
        atoms.add(const TimeOfDayCondition(TimeOfDay.night));
      case 'dusk':
        atoms.add(const TimeOfDayCondition(TimeOfDay.dusk));
      case final String other when other.isNotEmpty:
        atoms.add(SpecialCondition('special-time', value: other));
      default:
    }
    if (r.optInt('location_id') case final loc?) {
      atoms.add(AtLocation(LocationId(_locations[loc]!.$1)));
    }
    if (r.optInt('gender_id') case final g?) {
      atoms.add(GenderCondition(g == 1 ? Gender.female : Gender.male));
    }
    if (r.optInt('known_move_id') case final m? when _moveGen.containsKey(m)) {
      atoms.add(KnowsMove(MoveId(_moveIdent[m]!)));
    }
    if (r.optInt('known_move_type_id') case final ty?) {
      atoms.add(SpecialCondition('known-move-type', value: _typeKeys[ty]?.key));
    }
    if (r.optInt('minimum_happiness') case final v?) {
      atoms.add(MinFriendship(v));
    }
    if (r.optInt('minimum_beauty') case final v?) {
      atoms.add(SpecialCondition('min-beauty', value: '$v'));
    }
    if (r.optInt('minimum_affection') case final v?) {
      atoms.add(SpecialCondition('min-affection', value: '$v'));
    }
    if (r.optInt('relative_physical_stats') case final v?) {
      atoms.add(SpecialCondition('physical-stats', value: '$v'));
    }
    if (r.optInt('party_species_id') case final s?) {
      atoms.add(SpecialCondition('party-species', value: _speciesIdent[s]));
    }
    if (r.optInt('party_type_id') case final ty?) {
      atoms.add(SpecialCondition('party-type', value: _typeKeys[ty]?.key));
    }
    if (r.optInt('trade_species_id') case final s?) {
      atoms.add(SpecialCondition('trade-species', value: _speciesIdent[s]));
    }
    if (r.flag('needs_overworld_rain')) {
      atoms.add(const SpecialCondition('overworld-rain'));
    }
    if (r.flag('turn_upside_down')) {
      atoms.add(const SpecialCondition('upside-down'));
    }
    if (r.flag('needs_multiplayer')) {
      atoms.add(const SpecialCondition('multiplayer'));
    }
    if (r.flag('near_special_rock')) {
      atoms.add(const SpecialCondition('special-rock'));
    }
    if (r.optInt('region_id') case final region?) {
      atoms.add(InRegion(_regions[region]!));
    }
    if (r.optInt('used_move_id') case final m? when _moveGen.containsKey(m)) {
      atoms.add(SpecialCondition('used-move', value: _moveIdent[m]));
    }
    if (r.optInt('minimum_move_count') case final v?) {
      atoms.add(SpecialCondition('move-count', value: '$v'));
    }
    if (r.optInt('minimum_steps') case final v?) {
      atoms.add(SpecialCondition('steps', value: '$v'));
    }
    if (r.optInt('minimum_damage_taken') case final v?) {
      atoms.add(SpecialCondition('damage-taken', value: '$v'));
    }
    if ((r['nature_bitmask'] ?? '').isNotEmpty) {
      atoms.add(const SpecialCondition('nature'));
    }
    if ((r['condition_expression'] ?? '').isNotEmpty) {
      atoms.add(const SpecialCondition('personality-value'));
    }
    if (r.optInt('percentage_chance') case final v?) {
      atoms.add(SpecialCondition('chance', value: '$v'));
    }
    if (atoms.isEmpty) return SpecialCondition(trigger);
    return atoms.length == 1 ? atoms.single : AllOf(atoms);
  }

  late final Map<int, String> _moveIdent = {
    for (final r in t['moves']) r.integer('id'): r['identifier']!,
  };

  void _evolutions() {
    final triggers = {
      for (final r in t['evolution_triggers'])
        r.integer('id'): r['identifier']!,
    };
    final evolvesFrom = {
      for (final r in t['pokemon_species'])
        r.integer('id'): ?r.optInt('evolves_from_species_id'),
    };
    final groups = _groups.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final edges =
        <
          (int, int, int, String, int?),
          Set<int>
        >{}; // (from, to, toSpecies, condJson, region) → VGs
    for (final r in t['pokemon_evolution']) {
      final toSpecies = r.integer('evolved_species_id');
      final fromSpecies = evolvesFrom[toSpecies];
      if (fromSpecies == null) continue;
      if (!_speciesIncluded(toSpecies) || !_speciesIncluded(fromSpecies)) {
        continue;
      }
      final from = r.optInt('required_pokemon_form_id') != null
          ? _pokemonFormToPokemon[r.integer('required_pokemon_form_id')]!
          : _defaultForm[fromSpecies]!;
      final to = r.optInt('evolved_pokemon_form_id') != null
          ? _pokemonFormToPokemon[r.integer('evolved_pokemon_form_id')]!
          : _defaultForm[toSpecies]!;
      final introduced = r.optInt('version_group_id');
      final minOrder = introduced == null ? 0 : _groups[introduced]!.order;
      final minGen = [
        _speciesGen[toSpecies]!,
        _speciesGen[fromSpecies]!,
      ].reduce((a, b) => a > b ? a : b);
      final location = r.optInt('location_id');
      final region = r.optInt('region_id');
      final vgs = <int>{
        for (final g in groups)
          if (g.order >= minOrder &&
              g.generation >= minGen &&
              (location == null ||
                  g.regions.contains(_locations[location]!.$2)) &&
              (region == null || g.regions.contains(region)))
            g.rid,
      };
      final condition = _condition(r, triggers)!;
      edges
          .putIfAbsent((
            from,
            to,
            toSpecies,
            jsonEncode(condition.toJson()),
            region,
          ), () => {})
          .addAll(vgs);
    }
    // Regionale Entwicklungen ersetzen die allgemeine in ihrer Region (z. B. Alola-Raichu).
    for (final e in edges.entries.where((e) => e.key.$5 == null)) {
      for (final regional in edges.entries.where(
        (o) => o.key.$5 != null && o.key.$1 == e.key.$1 && o.key.$3 == e.key.$3,
      )) {
        e.value.removeAll(regional.value);
      }
    }
    final rows = <(int, int, String, String)>[];
    for (final e in edges.entries) {
      final (from, to, _, condition, _) = e.key;
      final vgs = [
        for (final g in groups)
          if (e.value.contains(g.rid) &&
              _availability[(from, g.rid)] !=
                  DataAvailability.confirmedUnavailable &&
              _availability[(to, g.rid)] !=
                  DataAvailability.confirmedUnavailable)
            g.id,
      ];
      if (vgs.isNotEmpty) rows.add((from, to, condition, vgs.join(',')));
    }
    rows.sort((a, b) {
      final f = a.$1.compareTo(b.$1);
      if (f != 0) return f;
      final t = a.$2.compareTo(b.$2);
      return t != 0 ? t : a.$3.compareTo(b.$3);
    });
    for (final r in rows) {
      _insert('evolution', [r.$1, r.$2, r.$3, r.$4]);
    }
  }

  void _locationsTable() {
    for (final r in [
      ...t['regions'],
    ]..sort((a, b) => a.integer('id').compareTo(b.integer('id')))) {
      _insert('region', [r.integer('id'), r['identifier']]);
    }
    _names('region', 'region_names', 'region_id');
    final seen = <String>{};
    for (final r in [
      ...t['locations'],
    ]..sort((a, b) => a.integer('id').compareTo(b.integer('id')))) {
      var ident = r['identifier']!;
      if (!seen.add(ident)) {
        report.warn('Ort $ident doppelt (Quell-ID ${r['id']})');
        ident = '$ident--${r['id']}';
      }
      _locations[r.integer('id')] = (ident, r.optInt('region_id') ?? 0);
      _insert('location', [r.integer('id'), ident, r.optInt('region_id')]);
    }
    _names('location', 'location_names', 'location_id');
    final areaIds = <String>{};
    for (final r in [
      ...t['location_areas'],
    ]..sort((a, b) => a.integer('id').compareTo(b.integer('id')))) {
      final location = _locations[r.integer('location_id')];
      if (location == null) continue;
      final area = r['identifier'] ?? '';
      var ident = area.isEmpty ? location.$1 : '${location.$1}/$area';
      if (!areaIds.add(ident)) ident = '$ident--${r['id']}';
      _insert('location_area', [
        r.integer('id'),
        ident,
        r.integer('location_id'),
      ]);
    }
    _names('location_area', 'location_area_prose', 'location_area_id');
    for (final r in t['encounter_methods']) {
      _insert('encounter_method', [
        r.integer('id'),
        r['identifier'],
        r.integer('order'),
      ]);
    }
    _names('encounter_method', 'encounter_method_prose', 'encounter_method_id');
    for (final r in t['encounter_condition_values']) {
      _insert('encounter_condition', [r.integer('id'), r['identifier']]);
    }
    _names(
      'encounter_condition',
      'encounter_condition_value_prose',
      'encounter_condition_value_id',
    );
  }

  /// Begegnungen je Form, Version, Gebiet, Methode und Bedingungen.
  void _encounters() {
    final slots = {for (final r in t['encounter_slots']) r.integer('id'): r};
    final versionGroup = {
      for (final r in t['versions'])
        r.integer('id'): r.integer('version_group_id'),
    };
    final conditionIdent = {
      for (final r in t['encounter_condition_values'])
        r.integer('id'): r['identifier']!,
    };
    final conditions = <int, List<String>>{};
    for (final r in t['encounter_condition_value_map']) {
      conditions
          .putIfAbsent(r.integer('encounter_id'), () => [])
          .add(conditionIdent[r.integer('encounter_condition_value_id')]!);
    }
    final rows = <(int, int, int, int, String), List<int>>{};
    for (final r in t['encounters']) {
      final form = r.integer('pokemon_id');
      final species = _formSpecies[form];
      final slot = slots[r.integer('encounter_slot_id')];
      if (species == null || slot == null) continue;
      final version = r.integer('version_id');
      final group = versionGroup[version]!;
      _encounterForms.putIfAbsent(group, () => {}).add(form);
      _encounterEntries[group] = (_encounterEntries[group] ?? 0) + 1;
      if (!_speciesIncluded(species)) continue;
      final conds = [...?conditions[r.integer('id')]]..sort();
      final key = (
        form,
        version,
        r.integer('location_area_id'),
        slot.integer('encounter_method_id'),
        conds.join(','),
      );
      final agg = rows[key];
      final min = r.integer('min_level'), max = r.integer('max_level');
      final rarity = slot.optInt('rarity') ?? 0;
      if (agg == null) {
        rows[key] = [min, max, rarity];
      } else {
        agg[0] = min < agg[0] ? min : agg[0];
        agg[1] = max > agg[1] ? max : agg[1];
        agg[2] += rarity;
      }
    }
    final stmt = _db.prepare(
      'INSERT INTO encounter VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    );
    final keys = rows.keys.toList()
      ..sort((a, b) {
        for (final c in [
          a.$1.compareTo(b.$1),
          a.$2.compareTo(b.$2),
          a.$3.compareTo(b.$3),
          a.$4.compareTo(b.$4),
          a.$5.compareTo(b.$5),
        ]) {
          if (c != 0) return c;
        }
        return 0;
      });
    for (final k in keys) {
      final v = rows[k]!;
      // Mehrere Slots können zusammen über 100 % ergeben (z. B. Bedingungsvarianten).
      stmt.execute([
        k.$1,
        k.$2,
        k.$3,
        k.$4,
        v[0],
        v[1],
        v[2] > 100 ? 100 : v[2],
        k.$5,
      ]);
    }
    stmt.close();
  }

  void _coverage() {
    final formRids = _formSpecies.keys
        .where((f) => _speciesIncluded(_formSpecies[f]!))
        .toSet();
    for (final g
        in _groups.values.toList()
          ..sort((a, b) => a.order.compareTo(b.order))) {
      var confirmed = 0, unavailable = 0, gaps = 0;
      for (final f in formRids) {
        switch (_availability[(f, g.rid)]) {
          case DataAvailability.confirmedAvailable:
            confirmed++;
          case DataAvailability.confirmedUnavailable:
            unavailable++;
          default:
            gaps++;
        }
      }
      g.hasData = (_learnsetForms[g.rid]?.isNotEmpty ?? false);
      final entries =
          _db.select(
                'SELECT count(*) AS n FROM learnset WHERE version_group = ?',
                [g.rid],
              ).first['n']
              as int;
      _insert('version_group', [
        g.rid,
        g.id,
        g.generation,
        g.ruleset.id,
        g.order,
        g.hasData ? 1 : 0,
      ]);
      _insert('coverage', [
        g.rid,
        confirmed,
        unavailable,
        gaps,
        entries,
        _encounterEntries[g.rid] ?? 0,
      ]);
      report.counts['Formen bestätigt in ${g.id}'] = confirmed;
    }
    report.counts['Formen'] = formRids.length;
    report.counts['Erlernbarkeitseinträge'] =
        _db.select('SELECT count(*) AS n FROM learnset').first['n'] as int;
  }

  void _searchIndex() {
    final stmt = _db.prepare(
      'INSERT INTO search(text, kind, ref) VALUES (?, ?, ?)',
    );
    for (final (kind, entity) in [
      ('move', EntityKind.move),
      ('ability', EntityKind.ability),
      ('item', EntityKind.item),
    ]) {
      final rows = _db.select(
        'SELECT ref, text FROM name WHERE kind = ? ORDER BY ref, lang',
        [kind],
      );
      final seen = <(int, String)>{};
      for (final r in rows) {
        final normalized = normalizeSearchText(r['text'] as String);
        if (normalized.isEmpty || !seen.add((r['ref'] as int, normalized))) {
          continue;
        }
        stmt.execute([normalized, entity.name, r['ref']]);
      }
    }
    stmt.close();
  }
}
