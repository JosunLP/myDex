import 'dart:convert';
import 'dart:io';

import 'package:mydex_catalog_store/mydex_catalog_store.dart';

/// Testkatalog aus `data/fixtures` (von der Pipeline erzeugt).
final fixtureManifest = CatalogPackManifest.fromJson(
  jsonDecode(
        File(
          '../../data/fixtures/catalog_test.manifest.json',
        ).readAsStringSync(),
      )
      as Map<String, Object?>,
);

List<int> fixturePack() =>
    File('../../data/fixtures/catalog_test.sqlite.gz').readAsBytesSync();

/// Installiert den Testkatalog in ein temporäres Verzeichnis.
Future<String> installFixture(Directory dir) async =>
    (await CatalogInstaller(dir).install(fixtureManifest, fixturePack())).path;
