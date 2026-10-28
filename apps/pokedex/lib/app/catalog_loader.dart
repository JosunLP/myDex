import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';

const _manifestAsset = 'assets/catalog/catalog.manifest.json';
const _packAsset = 'assets/catalog/catalog.sqlite.gz';

/// Installs the bundled catalog pack on first start (and after app updates
/// with a new catalog) and loads it. Works fully offline.
class BundledCatalogRepository implements CatalogRepository {
  BundledCatalogRepository(this.directory, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final Directory directory;
  final AssetBundle _bundle;

  /// Set when a new pack was discarded and the previous version was used.
  Object? installError;

  @override
  Future<LoadedCatalog> load() async {
    final manifest = CatalogPackManifest.fromJson(
      jsonDecode(await _bundle.loadString(_manifestAsset))
          as Map<String, Object?>,
    );
    final current = await CatalogInstaller(directory).current();
    // A newer pack installed over the network takes precedence over the
    // bundled one; a newer bundled one (app update) replaces it.
    if (current != null &&
        (current.revision == manifest.revision ||
            current.sequence > manifest.sequence)) {
      try {
        return await openInstalledCatalog(current.path);
      } on Object catch (e) {
        // e.g. schema of an older app version: use the bundled pack.
        debugPrint('Installed catalog not readable: $e');
      }
    }
    final pack = (await _bundle.load(_packAsset)).buffer.asUint8List();
    final dir = directory;
    // Unpacking and verifying do not block the UI.
    final installed = await Isolate.run(
      () => CatalogInstaller(dir).ensureInstalled(manifest, () => pack),
    );
    installError = installed.installError;
    if (installError != null) {
      debugPrint('Catalog update discarded: $installError');
    }
    return openInstalledCatalog(installed.path);
  }
}

/// Loads the snapshot in the background and opens the details connection.
Future<LoadedCatalog> openInstalledCatalog(String path) async {
  final snapshot = await Isolate.run(() => loadCatalogSnapshot(path));
  return LoadedCatalog(snapshot, SqliteCatalogDetails.open(path));
}

const _mediaManifestAsset = 'assets/media/media.manifest.json';
const _mediaPackAsset = 'assets/media/media.sqlite.gz';

/// Loads images (sprites). Separate from the catalog: if the media pack is
/// missing or fails, the app keeps running without images.
abstract interface class MediaLoader {
  Future<MediaLibrary> load();
}

class BundledMediaLoader implements MediaLoader {
  BundledMediaLoader(this.directory, {AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final Directory directory;
  final AssetBundle _bundle;

  @override
  Future<MediaLibrary> load() async {
    try {
      final manifest = CatalogPackManifest.fromJson(
        jsonDecode(await _bundle.loadString(_mediaManifestAsset))
            as Map<String, Object?>,
      );
      final installer = CatalogInstaller(directory, format: PackFormat.media);
      final current = await installer.current();
      if (current != null && current.revision == manifest.revision) {
        return SqliteMediaLibrary.open(current.path);
      }
      final pack = (await _bundle.load(_mediaPackAsset)).buffer.asUint8List();
      final dir = directory;
      final installed = await Isolate.run(
        () => CatalogInstaller(
          dir,
          format: PackFormat.media,
        ).ensureInstalled(manifest, () => pack),
      );
      return SqliteMediaLibrary.open(installed.path);
    } on Object catch (e) {
      debugPrint('Media pack not available: $e');
      return const EmptyMediaLibrary();
    }
  }
}
