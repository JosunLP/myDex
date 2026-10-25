import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_data_pipeline/mydex_data_pipeline.dart';
import 'package:test/test.dart';

void main() {
  group('CSV', () {
    test('Anführungszeichen, Kommas und Zeilenumbrüche', () {
      final rows = parseCsv(
        'a,b,c\n1,"x, y",""\r\n2,"zeile\neins","sagt ""hi"""\n',
      );
      expect(rows, [
        ['a', 'b', 'c'],
        ['1', 'x, y', ''],
        ['2', 'zeile\neins', 'sagt "hi"'],
      ]);
    });

    test('Tabelle mit Spaltennamen und Zahlen', () {
      final t = Table.parse('t', 'id,name,level\n1,bulbasaur,\n');
      expect(t.rows.single['name'], 'bulbasaur');
      expect(t.rows.single.integer('id'), 1);
      expect(t.rows.single.optInt('level'), isNull);
      expect(() => t.rows.single.integer('name'), throwsFormatException);
    });
  });

  group('Quellmanifest', () {
    final manifest = File('../../data/source_manifests/pokeapi.json');

    test('hält Commit und alle benötigten Tabellen fest', () {
      final j = jsonDecode(manifest.readAsStringSync()) as Map<String, Object?>;
      expect(j['commit'], pokeApiCommit);
      expect((j['files']! as Map).keys, containsAll(requiredTables));
    });
  });

  group('Pakete', () {
    for (final (pack, manifestPath) in [
      (
        '../../apps/pokedex/assets/catalog/catalog.sqlite.gz',
        '../../apps/pokedex/assets/catalog/catalog.manifest.json',
      ),
      (
        '../../data/fixtures/catalog_test.sqlite.gz',
        '../../data/fixtures/catalog_test.manifest.json',
      ),
    ]) {
      test('Manifest passt zum Inhalt: $pack', () {
        final manifest = CatalogPackManifest.fromJson(
          jsonDecode(File(manifestPath).readAsStringSync())
              as Map<String, Object?>,
        );
        final bytes = gzip.decode(File(pack).readAsBytesSync());
        expect(bytes.length, manifest.size);
        expect(sha256.convert(bytes).toString(), manifest.sha256);
        expect(manifest.schemaVersion, catalogSchemaVersion);
        expect(manifest.sourceRevision, pokeApiCommit);
      });
    }
  });
}
