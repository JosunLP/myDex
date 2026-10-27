import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Festgehaltener Quellstand (reproduzierbarer Snapshot, keine Live-API).
const pokeApiRepository = 'https://github.com/PokeAPI/pokeapi';
const pokeApiCommit = '2bf639e5572812a67d2b94903fdcb9d095f5aeb2';

/// Commit-Zeit des Quellstands (Unix-Sekunden). Bestimmt mit der
/// Schemaversion die Reihenfolge der Katalogpakete; beim Wechsel des
/// Quellstands mit aktualisieren (`git log -1 --format=%ct <commit>`).
const pokeApiCommitTime = 1792500364;

/// Benötigte CSV-Tabellen aus `data/v2/csv`.
const requiredTables = [
  'abilities',
  'ability_names',
  'egg_groups',
  'encounter_condition_value_map',
  'encounter_condition_value_prose',
  'encounter_condition_values',
  'encounter_method_prose',
  'encounter_methods',
  'encounter_slots',
  'encounters',
  'evolution_triggers',
  'item_categories',
  'item_game_indices',
  'item_names',
  'item_pockets',
  'items',
  'languages',
  'location_area_prose',
  'location_areas',
  'location_names',
  'locations',
  'machines',
  'move_changelog',
  'move_names',
  'moves',
  'nature_names',
  'natures',
  'pokemon',
  'pokemon_abilities',
  'pokemon_abilities_past',
  'pokemon_egg_groups',
  'pokemon_evolution',
  'pokemon_form_names',
  'pokemon_forms',
  'pokemon_move_methods',
  'pokemon_moves',
  'pokemon_species',
  'pokemon_species_names',
  'pokemon_stats',
  'pokemon_stats_past',
  'pokemon_types',
  'pokemon_types_past',
  'region_names',
  'regions',
  'stats',
  'types',
  'version_group_regions',
  'version_groups',
  'version_names',
  'versions',
];

Uri tableUrl(String table) => Uri.parse(
  'https://raw.githubusercontent.com/PokeAPI/pokeapi/$pokeApiCommit/data/v2/csv/$table.csv',
);

/// Lädt fehlende Tabellen in [cache] und prüft sie gegen das Quellmanifest.
/// Ohne Manifest-Eintrag wird der Hash nur gemeldet (`--update-manifest`).
Future<Map<String, String>> fetchSource(
  Directory cache, {
  Map<String, String> expectedHashes = const {},
  void Function(String)? log,
}) async {
  await cache.create(recursive: true);
  final client = HttpClient();
  final hashes = <String, String>{};
  try {
    for (final table in requiredTables) {
      final file = File('${cache.path}/$table.csv');
      if (!await file.exists()) {
        log?.call('lade $table.csv');
        final request = await client.getUrl(tableUrl(table));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode} für $table.csv');
        }
        final tmp = File('${file.path}.part');
        await response.pipe(tmp.openWrite());
        await tmp.rename(file.path);
      }
      final hash = sha256.convert(await file.readAsBytes()).toString();
      final expected = expectedHashes[table];
      if (expected != null && expected != hash) {
        throw StateError(
          '$table.csv weicht vom Quellmanifest ab (erwartet $expected, erhalten $hash)',
        );
      }
      hashes[table] = hash;
    }
  } finally {
    client.close();
  }
  return hashes;
}

/// Quellmanifest unter `data/source_manifests/pokeapi.json`.
Map<String, String> readSourceManifest(File file) {
  if (!file.existsSync()) return const {};
  final j = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  if (j['commit'] != pokeApiCommit) return const {};
  return (j['files']! as Map<String, Object?>).cast<String, String>();
}

void writeSourceManifest(File file, Map<String, String> hashes) {
  final sorted = Map.fromEntries(
    hashes.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'source': pokeApiRepository, 'commit': pokeApiCommit, 'license': 'BSD-3-Clause (Code/Datenbank); Marken bei den Inhabern', 'files': sorted})}\n',
  );
}
