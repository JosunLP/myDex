import 'dart:convert';
import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

/// Opens a catalog file read-only.
///
/// Elsewhere the file is opened as a `file:` URI with `immutable=1`, which
/// prevents lock and journal files next to the catalog. On Windows such URIs
/// fail for some paths (drive letters, user profiles with special characters:
/// `SqliteException(14)`), so the plain path is used there; the catalog is
/// never written, so read-only mode is enough.
Database openCatalogDatabase(String path) {
  final absolute = File(path).absolute.path;
  if (Platform.isWindows) {
    return sqlite3.open(absolute, mode: OpenMode.readOnly);
  }
  final uri = Uri.file(absolute).replace(queryParameters: {'immutable': '1'});
  try {
    return sqlite3.open(uri.toString(), mode: OpenMode.readOnly, uri: true);
  } on SqliteException {
    // Fallback for SQLite builds or file systems that reject the URI form.
    return sqlite3.open(absolute, mode: OpenMode.readOnly);
  }
}

/// Reads the metadata and checks the schema version.
Map<String, String> readCatalogMeta(Database db) {
  final meta = {
    for (final r in db.select('SELECT key, value FROM meta'))
      r['key'] as String: r['value'] as String,
  };
  final schema = int.tryParse(meta['schemaVersion'] ?? '');
  if (schema != catalogSchemaVersion) {
    throw FormatException('Unsupported catalog schema version: $schema');
  }
  return meta;
}

/// Loads the core data completely into memory. Can run in a background
/// isolate; the result is immutable and transferable.
CatalogSnapshot loadCatalogSnapshot(String path) {
  final db = openCatalogDatabase(path);
  try {
    return _SnapshotLoader(db).load();
  } finally {
    db.close();
  }
}

class _SnapshotLoader {
  _SnapshotLoader(this.db);

  final Database db;
  final _names = <String, Map<int, Map<String, String>>>{};

  // Equal values share one instance (many version groups are identical).
  final _typeLists = <String, List<PokemonType>>{};
  final _stats = <String, BaseStats>{};
  final _abilityLists = <String, List<AbilitySlot>>{};

  LocalizedText _name(String kind, int ref) =>
      LocalizedText(_names[kind]?[ref] ?? const {});

  CatalogSnapshot load() {
    final meta = readCatalogMeta(db);
    for (final r in db.select('SELECT kind, ref, lang, text FROM name')) {
      _names
              .putIfAbsent(r['kind'] as String, () => {})
              .putIfAbsent(r['ref'] as int, () => {})[r['lang'] as String] =
          r['text'] as String;
    }

    final rulesets = [
      for (final r in db.select('SELECT * FROM ruleset'))
        Ruleset(
          id: RulesetId(r['id'] as String),
          generation: r['generation'] as int,
          typeChartEra: TypeChartEra.parse(r['type_chart_era'] as String),
          statFormula: StatFormula.parse(r['stat_formula'] as String),
          partySize: r['party_size'] as int,
          hasAbilities: r['has_abilities'] == 1,
          hasHeldItems: r['has_held_items'] == 1,
          hasNatures: r['has_natures'] == 1,
          unifiedSpecial: r['unified_special'] == 1,
          hasBreeding: r['has_breeding'] == 1,
        ),
    ];

    final groupIds = <int, VersionGroupId>{};
    final groups = [
      for (final r in db.select('SELECT * FROM version_group'))
        VersionGroup(
          id: groupIds[r['rid'] as int] = VersionGroupId(r['id'] as String),
          generation: r['generation'] as int,
          rulesetId: RulesetId(r['ruleset'] as String),
          name: _name('version_group', r['rid'] as int),
          order: r['sort'] as int,
          hasData: r['has_data'] == 1,
        ),
    ];

    final versions = [
      for (final r in db.select('SELECT * FROM version ORDER BY rid'))
        GameVersion(
          id: GameVersionId(r['id'] as String),
          versionGroupId: groupIds[r['version_group'] as int]!,
          name: _name('version', r['rid'] as int),
        ),
    ];

    final speciesIds = <int, SpeciesId>{};
    final species = [
      for (final r in db.select('SELECT * FROM species'))
        Species(
          id: speciesIds[r['rid'] as int] = SpeciesId(r['id'] as String),
          nationalNumber: r['national'] as int,
          name: _name('species', r['rid'] as int),
          hatchable: r['hatchable'] == 1,
          generation: r['generation'] as int,
          mythical: r['mythical'] == 1,
        ),
    ];

    final abilityIds = <int, AbilityId>{};
    final abilities = [
      for (final r in db.select('SELECT rid, id FROM ability'))
        Ability(
          id: abilityIds[r['rid'] as int] = AbilityId(r['id'] as String),
          name: _name('ability', r['rid'] as int),
        ),
    ];

    final moves = [
      for (final r in db.select('SELECT rid, id, generation FROM move'))
        Move(
          id: MoveId(r['id'] as String),
          name: _name('move', r['rid'] as int),
          generation: r['generation'] as int,
        ),
    ];

    final items = {
      for (final r in db.select(
        'SELECT rid, id, pocket, generations FROM item',
      ))
        ItemId(r['id'] as String): ItemInfo(
          id: ItemId(r['id'] as String),
          name: _name('item', r['rid'] as int),
          pocket: r['pocket'] as String?,
          generations: {
            for (var g = 1; g < 31; g++)
              if (((r['generations'] as int) >> g) & 1 == 1) g,
          },
        ),
    };
    final itemNames = {for (final i in items.values) i.id: i.name};
    final natures = {
      for (final r in db.select(
        'SELECT rid, id, increased, decreased FROM nature',
      ))
        NatureId(r['id'] as String): Nature(
          id: NatureId(r['id'] as String),
          name: _name('nature', r['rid'] as int),
          increased: r['increased'] == null
              ? null
              : Stat.values.byName(r['increased'] as String),
          decreased: r['decreased'] == null
              ? null
              : Stat.values.byName(r['decreased'] as String),
        ),
    };

    final regionIds = <int, RegionId>{};
    final regionNames = {
      for (final r in db.select('SELECT rid, id FROM region'))
        regionIds[r['rid'] as int] = RegionId(r['id'] as String): _name(
          'region',
          r['rid'] as int,
        ),
    };
    final locationIds = <int, LocationId>{};
    final locations = <LocationId, Location>{};
    for (final r in db.select('SELECT rid, id, region FROM location')) {
      final id = locationIds[r['rid'] as int] = LocationId(r['id'] as String);
      locations[id] = Location(
        id: id,
        name: _name('location', r['rid'] as int),
        region: regionIds[r['region'] as int?],
      );
    }
    final locationNames = {for (final l in locations.values) l.id: l.name};
    final locationAreas = {
      for (final r in db.select('SELECT rid, id, location FROM location_area'))
        LocationAreaId(r['id'] as String): LocationArea(
          id: LocationAreaId(r['id'] as String),
          location: locationIds[r['location'] as int]!,
          name: _name('location_area', r['rid'] as int),
        ),
    };
    final encounterMethods = {
      for (final r in db.select('SELECT rid, id, sort FROM encounter_method'))
        EncounterMethodId(r['id'] as String): EncounterMethod(
          id: EncounterMethodId(r['id'] as String),
          name: _name('encounter_method', r['rid'] as int),
          order: r['sort'] as int,
        ),
    };
    final encounterConditionNames = {
      for (final r in db.select('SELECT rid, id FROM encounter_condition'))
        EncounterConditionId(r['id'] as String): _name(
          'encounter_condition',
          r['rid'] as int,
        ),
    };

    final profiles = <int, Map<VersionGroupId, FormGameProfile>>{};
    for (final r in db.select('SELECT * FROM form_profile')) {
      profiles.putIfAbsent(
        r['form'] as int,
        () => {},
      )[groupIds[r['version_group'] as int]!] = _profile(
        r,
        abilityIds,
      );
    }

    final formIds = <int, FormId>{};
    final forms = [
      for (final r in db.select('SELECT * FROM form ORDER BY sort'))
        PokemonForm(
          id: formIds[r['rid'] as int] = FormId(r['id'] as String),
          speciesId: speciesIds[r['species'] as int]!,
          isDefault: r['is_default'] == 1,
          name: r['own_name'] == 1 ? _name('form', r['rid'] as int) : null,
          profiles: profiles[r['rid'] as int] ?? const {},
        ),
    ];

    final evolutions = [
      for (final r in db.select('SELECT * FROM evolution'))
        EvolutionEdge(
          from: formIds[r['from_form'] as int]!,
          to: formIds[r['to_form'] as int]!,
          condition: EvolutionCondition.fromJson(
            _decodeJsonObject(r['condition'] as String),
          ),
          versionGroups: {
            for (final g in (r['version_groups'] as String).split(','))
              if (g.isNotEmpty) VersionGroupId(g),
          },
        ),
    ];

    return CatalogSnapshot(
      revision: meta['revision']!,
      schemaVersion: catalogSchemaVersion,
      rulesets: rulesets,
      versionGroups: groups,
      versions: versions,
      species: species,
      forms: forms,
      abilities: abilities,
      moves: moves,
      itemNames: itemNames,
      locationNames: locationNames,
      locations: locations,
      locationAreas: locationAreas,
      encounterMethods: encounterMethods,
      encounterConditionNames: encounterConditionNames,
      regionNames: regionNames,
      natures: natures,
      items: items,
      evolutions: evolutions,
    );
  }

  FormGameProfile _profile(Row r, Map<int, AbilityId> abilityIds) {
    final availability = DataAvailability.parse(r['availability'] as String);
    final t1 = r['type1'] as String?;
    final t2 = r['type2'] as String?;
    final types = _typeLists.putIfAbsent('$t1|$t2', () {
      return List.unmodifiable([
        if (t1 != null) PokemonType.parse(t1),
        if (t2 != null) PokemonType.parse(t2),
      ]);
    });
    BaseStats? stats;
    if (r['hp'] != null) {
      final key = [
        for (final c in ['hp', 'atk', 'def', 'spa', 'spd', 'spe', 'special'])
          r[c],
      ].join(',');
      stats = _stats.putIfAbsent(key, () {
        final special = r['special'] as int?;
        return special != null
            ? BaseStats.gen1(
                hp: r['hp'] as int,
                attack: r['atk'] as int,
                defense: r['def'] as int,
                special: special,
                speed: r['spe'] as int,
              )
            : BaseStats(
                hp: r['hp'] as int,
                attack: r['atk'] as int,
                defense: r['def'] as int,
                specialAttack: r['spa'] as int,
                specialDefense: r['spd'] as int,
                speed: r['spe'] as int,
              );
      });
    }
    final a1 = r['ability1'] as int?;
    final a2 = r['ability2'] as int?;
    final ah = r['ability_hidden'] as int?;
    final abilities = _abilityLists.putIfAbsent('$a1|$a2|$ah', () {
      return List.unmodifiable([
        if (a1 != null) AbilitySlot(abilityIds[a1]!),
        if (a2 != null) AbilitySlot(abilityIds[a2]!),
        if (ah != null) AbilitySlot(abilityIds[ah]!, hidden: true),
      ]);
    });
    return FormGameProfile(
      availability: availability,
      types: types,
      baseStats: stats,
      abilities: abilities,
    );
  }
}

Map<String, Object?> _decodeJsonObject(String s) {
  final decoded = jsonDecode(s);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Condition must be a JSON object');
  }
  return decoded;
}

/// On-demand queries. One connection per isolate.
class SqliteCatalogDetails implements CatalogDetails {
  SqliteCatalogDetails._(this._db, this.source) {
    for (final r in _db.select('SELECT rid, id FROM form')) {
      _formRid[r['id'] as String] = r['rid'] as int;
      _formId[r['rid'] as int] = r['id'] as String;
    }
    for (final r in _db.select(
      'SELECT rid, id, sort FROM version_group ORDER BY sort',
    )) {
      _groupRid[r['id'] as String] = r['rid'] as int;
      _groupId[r['rid'] as int] = r['id'] as String;
    }
    for (final r in _db.select('SELECT rid, id FROM move')) {
      _moveRid[r['id'] as String] = r['rid'] as int;
    }
    for (final r in _db.select('SELECT rid, id FROM version')) {
      _versionRid[r['id'] as String] = r['rid'] as int;
    }
    for (final r in _db.select('SELECT rid, id FROM location')) {
      _locationRid[r['id'] as String] = r['rid'] as int;
      _locationId[r['rid'] as int] = r['id'] as String;
    }
    for (final r in _db.select('SELECT rid, id FROM location_area')) {
      _areaId[r['rid'] as int] = r['id'] as String;
    }
    for (final r in _db.select('SELECT rid, id FROM encounter_method')) {
      _methodId[r['rid'] as int] = r['id'] as String;
    }
  }

  factory SqliteCatalogDetails.open(String path) {
    final db = openCatalogDatabase(path);
    try {
      final meta = readCatalogMeta(db);
      return SqliteCatalogDetails._(
        db,
        CatalogSourceInfo(
          revision: meta['revision']!,
          schemaVersion: catalogSchemaVersion,
          source: meta['source'] ?? '?',
          sourceRevision: meta['sourceRevision'] ?? '?',
        ),
      );
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  final Database _db;
  @override
  final CatalogSourceInfo source;

  final _formRid = <String, int>{};
  final _formId = <int, String>{};
  final _groupRid = <String, int>{};
  final _groupId = <int, String>{};
  final _moveRid = <String, int>{};
  final _versionRid = <String, int>{};
  final _locationRid = <String, int>{};
  final _locationId = <int, String>{};
  final _areaId = <int, String>{};
  final _methodId = <int, String>{};

  @override
  List<LearnsetEntry> learnset(FormId form, VersionGroupId group) {
    final f = _formRid[form.value];
    final g = _groupRid[group.value];
    if (f == null || g == null) return const [];
    final rows = _db.select(
      '''
      SELECT l.method, m.id AS move, l.level, l.method_key,
        (SELECT i.id FROM machine mc JOIN item i ON i.rid = mc.item
          WHERE mc.version_group = l.version_group AND mc.move = l.move
          ORDER BY i.id LIMIT 1) AS machine
      FROM learnset l JOIN move m ON m.rid = l.move
      WHERE l.form = ? AND l.version_group = ?
      ORDER BY l.method, l.level, m.id''',
      [f, g],
    );
    return [
      for (final r in rows)
        LearnsetEntry(
          move: MoveId(r['move'] as String),
          method: _method(r['method'] as int),
          level: r['method'] == LearnMethodCode.levelUp
              ? r['level'] as int
              : null,
          machine:
              r['method'] == LearnMethodCode.machine && r['machine'] != null
              ? ItemId(r['machine'] as String)
              : null,
          methodDetail: r['method_key'] as String?,
        ),
    ];
  }

  static LearnMethod _method(int code) => switch (code) {
    LearnMethodCode.levelUp => LearnMethod.levelUp,
    LearnMethodCode.egg => LearnMethod.egg,
    LearnMethodCode.tutor => LearnMethod.tutor,
    LearnMethodCode.machine => LearnMethod.machine,
    _ => LearnMethod.other,
  };

  static MoveGameProfile _moveProfile(Row r) => MoveGameProfile(
    availability: DataAvailability.parse(r['availability'] as String),
    type: PokemonType.parse(r['type'] as String),
    damageClass: DamageClass.parse(r['damage_class'] as String),
    power: r['power'] as int?,
    accuracy: r['accuracy'] as int?,
    pp: r['pp'] as int?,
    priority: r['priority'] as int,
  );

  @override
  MoveGameProfile? moveProfile(MoveId move, VersionGroupId group) {
    final m = _moveRid[move.value];
    final g = _groupRid[group.value];
    if (m == null || g == null) return null;
    final rows = _db.select(
      'SELECT * FROM move_profile WHERE move = ? AND version_group = ?',
      [m, g],
    );
    return rows.isEmpty ? null : _moveProfile(rows.first);
  }

  @override
  List<(VersionGroupId, MoveGameProfile)> moveHistory(MoveId move) {
    final m = _moveRid[move.value];
    if (m == null) return const [];
    return [
      for (final r in _db.select(
        '''SELECT p.* FROM move_profile p JOIN version_group g ON g.rid = p.version_group
           WHERE p.move = ? ORDER BY g.sort''',
        [m],
      ))
        (VersionGroupId(_groupId[r['version_group'] as int]!), _moveProfile(r)),
    ];
  }

  @override
  List<MoveLearner> learnersOf(MoveId move, VersionGroupId group) {
    final m = _moveRid[move.value];
    final g = _groupRid[group.value];
    if (m == null || g == null) return const [];
    final byForm = <int, Set<LearnMethod>>{};
    for (final r in _db.select(
      'SELECT form, method FROM learnset WHERE move = ? AND version_group = ?',
      [m, g],
    )) {
      byForm
          .putIfAbsent(r['form'] as int, () => {})
          .add(_method(r['method'] as int));
    }
    return [
      for (final e in byForm.entries)
        MoveLearner(FormId(_formId[e.key]!), e.value),
    ];
  }

  Encounter _encounter(Row r) => Encounter(
    form: FormId(_formId[r['form'] as int]!),
    area: LocationAreaId(_areaId[r['area'] as int]!),
    method: EncounterMethodId(_methodId[r['method'] as int]!),
    minLevel: r['min_level'] as int,
    maxLevel: r['max_level'] as int,
    chance: r['chance'] as int,
    conditions: [
      for (final c in (r['conditions'] as String).split(','))
        if (c.isNotEmpty) EncounterConditionId(c),
    ],
  );

  @override
  List<Encounter> encountersOf(FormId form, GameVersionId version) {
    final f = _formRid[form.value];
    final v = _versionRid[version.value];
    if (f == null || v == null) return const [];
    return [
      for (final r in _db.select(
        '''SELECT e.* FROM encounter e JOIN encounter_method m ON m.rid = e.method
           WHERE e.form = ? AND e.version = ? ORDER BY e.area, m.sort, e.conditions''',
        [f, v],
      ))
        _encounter(r),
    ];
  }

  @override
  List<Encounter> encountersAt(LocationId location, GameVersionId version) {
    final l = _locationRid[location.value];
    final v = _versionRid[version.value];
    if (l == null || v == null) return const [];
    return [
      for (final r in _db.select(
        '''SELECT e.* FROM encounter e
           JOIN location_area a ON a.rid = e.area
           JOIN encounter_method m ON m.rid = e.method
           WHERE e.version = ? AND a.location = ?
           ORDER BY e.area, m.sort, e.chance DESC, e.form''',
        [v, l],
      ))
        _encounter(r),
    ];
  }

  @override
  List<LocationId> locationsWithEncounters(GameVersionId version) {
    final v = _versionRid[version.value];
    if (v == null) return const [];
    return [
      for (final r in _db.select(
        '''SELECT DISTINCT a.location FROM encounter e
           JOIN location_area a ON a.rid = e.area WHERE e.version = ?''',
        [v],
      ))
        LocationId(_locationId[r['location'] as int]!),
    ];
  }

  @override
  bool hasEncounterData(GameVersionId version) {
    final v = _versionRid[version.value];
    if (v == null) return false;
    return _db.select('SELECT 1 FROM encounter WHERE version = ? LIMIT 1', [
      v,
    ]).isNotEmpty;
  }

  @override
  List<EntityHit> searchEntities(String query, {int limit = 30}) {
    final normalized = normalizeSearchText(query).replaceAll('"', '');
    final tokens = normalized.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];
    final match = tokens.map((t) => '"$t"*').join(' ');
    final rows = _db.select(
      '''
      SELECT s.kind, s.ref, max(s.text = ?) AS exact, min(s.rank) AS score
      FROM search s WHERE search MATCH ?
      GROUP BY s.kind, s.ref ORDER BY exact DESC, score LIMIT ?''',
      [normalized, match, limit],
    );
    final hits = <EntityHit>[];
    for (final r in rows) {
      final kind = EntityKind.values.byName(r['kind'] as String);
      final table = switch (kind) {
        EntityKind.move => 'move',
        EntityKind.ability => 'ability',
        EntityKind.item => 'item',
      };
      final id = _db.select('SELECT id FROM $table WHERE rid = ?', [r['ref']]);
      if (id.isNotEmpty) hits.add(EntityHit(kind, id.first['id'] as String));
    }
    return hits;
  }

  @override
  List<CoverageRow> coverage() => [
    for (final r in _db.select('''SELECT c.*, g.id AS gid FROM coverage c
         JOIN version_group g ON g.rid = c.version_group ORDER BY g.sort'''))
      CoverageRow(
        versionGroup: VersionGroupId(r['gid'] as String),
        formsConfirmed: r['forms_confirmed'] as int,
        formsUnavailable: r['forms_unavailable'] as int,
        formsGaps: r['forms_gaps'] as int,
        learnsetEntries: r['learnset_entries'] as int,
        encounterEntries: r['encounter_entries'] as int,
      ),
  ];

  @override
  void close() => _db.close();
}

/// Loads the snapshot and the details connection together (synchronously, e.g. for tests).
LoadedCatalog openLoadedCatalog(String path) =>
    LoadedCatalog(loadCatalogSnapshot(path), SqliteCatalogDetails.open(path));
