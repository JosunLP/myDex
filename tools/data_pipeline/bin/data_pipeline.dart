import 'dart:io';

import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_data_pipeline/mydex_data_pipeline.dart';

/// Arten des kleinen Testkatalogs (u. a. Piepi Normal→Fee, Alola-Raichu, Evoli,
/// Rettan/Sandan als Versionsexklusive, Pichu für Zucht).
const testSubset = {
  1, 2, 3, 4, 5, 6, 7, 8, 9, 23, 25, 26, 27, 35, 36, 39, 81, 82, 133, 134, //
  135, 136, 172, 462,
};

const usage = '''
Verwendung: dart run mydex_data_pipeline <befehl> [optionen]

  fetch [--update-manifest]   Quelltabellen laden und gegen das Manifest prüfen
  build                       Vollständigen Katalog und Testkatalog erzeugen

Optionen:
  --cache <dir>   Quell-Cache (Standard: .dart_tool/pokeapi/<commit>)
  --root <dir>    Repository-Wurzel (Standard: aktuelles Verzeichnis)
''';

Future<void> main(List<String> args) async {
  String? option(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final root = Directory(option('--root') ?? Directory.current.path);
  final cache = Directory(
    option('--cache') ?? '${root.path}/.dart_tool/pokeapi/$pokeApiCommit',
  );
  final manifestFile = File('${root.path}/data/source_manifests/pokeapi.json');
  final command = args.isEmpty ? '' : args.first;

  switch (command) {
    case 'fetch':
      final update = args.contains('--update-manifest');
      final hashes = await fetchSource(
        cache,
        expectedHashes: update ? const {} : readSourceManifest(manifestFile),
        log: stdout.writeln,
      );
      if (update) {
        manifestFile.parent.createSync(recursive: true);
        writeSourceManifest(manifestFile, hashes);
        stdout.writeln('Quellmanifest aktualisiert: ${manifestFile.path}');
      }
      stdout.writeln('${hashes.length} Tabellen bereit in ${cache.path}');
    case 'build':
      await fetchSource(
        cache,
        expectedHashes: readSourceManifest(manifestFile),
      );
      final tables = await SourceTables.load(cache, requiredTables);
      final revision =
          'pokeapi-${pokeApiCommit.substring(0, 7)}-s$catalogSchemaVersion';
      final outDir = Directory('${root.path}/build/catalog')
        ..createSync(recursive: true);

      final ok = _build(
        tables,
        BuildOptions(revision: revision),
        File('${outDir.path}/catalog.sqlite'),
      );
      final testDb = File('${outDir.path}/catalog_test.sqlite');
      final okSubset = _build(
        tables,
        BuildOptions(revision: '$revision-test', speciesFilter: testSubset),
        testDb,
      );
      if (!ok || !okSubset) exit(1);

      // Kleiner Testkatalog für Paket- und App-Tests (ohne Netz nutzbar).
      packCatalog(
        database: testDb,
        packOut: File('${root.path}/data/fixtures/catalog_test.sqlite.gz'),
        manifestOut: File(
          '${root.path}/data/fixtures/catalog_test.manifest.json',
        ),
        revision: '$revision-test',
        source: 'PokéAPI',
        sourceRevision: pokeApiCommit,
      );

      final manifest = packCatalog(
        database: File('${outDir.path}/catalog.sqlite'),
        packOut: File(
          '${root.path}/apps/pokedex/assets/catalog/catalog.sqlite.gz',
        ),
        manifestOut: File(
          '${root.path}/apps/pokedex/assets/catalog/catalog.manifest.json',
        ),
        revision: revision,
        source: 'PokéAPI',
        sourceRevision: pokeApiCommit,
      );
      stdout.writeln(
        'Paket ${manifest.revision}: ${manifest.size} Bytes, sha256 ${manifest.sha256}',
      );
    default:
      stdout.write(usage);
      exit(command.isEmpty ? 0 : 64);
  }
}

bool _build(SourceTables tables, BuildOptions options, File out) {
  final sw = Stopwatch()..start();
  final report = CatalogBuilder(tables, options).build(out);
  stdout.writeln(
    '== ${out.path} (${sw.elapsedMilliseconds} ms, ${out.lengthSync()} Bytes)',
  );
  stdout.writeln(report);
  return report.problems.isEmpty;
}
