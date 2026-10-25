import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';

const _manifestAsset = 'assets/catalog/catalog.manifest.json';
const _packAsset = 'assets/catalog/catalog.sqlite.gz';

/// Installiert das mitgelieferte Katalogpaket beim ersten Start (und nach
/// App-Updates mit neuem Katalog) und lädt es. Funktioniert vollständig offline.
class BundledCatalogRepository implements CatalogRepository {
  BundledCatalogRepository(this.directory, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final Directory directory;
  final AssetBundle _bundle;

  /// Gesetzt, wenn ein neues Paket verworfen und die Vorversion genutzt wurde.
  Object? installError;

  @override
  Future<LoadedCatalog> load() async {
    final manifest = CatalogPackManifest.fromJson(
      jsonDecode(await _bundle.loadString(_manifestAsset))
          as Map<String, Object?>,
    );
    final current = await CatalogInstaller(directory).current();
    if (current != null && current.revision == manifest.revision) {
      return openInstalledCatalog(current.path);
    }
    final pack = (await _bundle.load(_packAsset)).buffer.asUint8List();
    final dir = directory;
    // Entpacken und Prüfen blockieren nicht die Oberfläche.
    final installed = await Isolate.run(
      () => CatalogInstaller(dir).ensureInstalled(manifest, () => pack),
    );
    installError = installed.installError;
    if (installError != null) {
      debugPrint('Katalog-Update verworfen: $installError');
    }
    return openInstalledCatalog(installed.path);
  }
}

/// Lädt den Snapshot im Hintergrund und öffnet die Detailverbindung.
Future<LoadedCatalog> openInstalledCatalog(String path) async {
  final snapshot = await Isolate.run(() => loadCatalogSnapshot(path));
  return LoadedCatalog(snapshot, SqliteCatalogDetails.open(path));
}
