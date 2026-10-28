import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_sync/mydex_sync.dart';

import 'providers.dart';

/// Trusted public keys for catalog updates, set at build time:
/// `--dart-define=MYDEX_CATALOG_KEY=<base64>[,<base64>]` (ADR 0015).
final catalogUpdateKeysProvider = Provider<List<String>>(
  (ref) => [
    for (final k in const String.fromEnvironment(
      'MYDEX_CATALOG_KEY',
    ).split(','))
      if (k.trim().isNotEmpty) k.trim(),
  ],
);

/// Connection to the update source (replaceable in tests).
final catalogUpdateSourceFactoryProvider =
    Provider<CatalogUpdateSource Function(String serverUrl, String token)>(
      (ref) =>
          (serverUrl, token) => HttpSyncTransport(Uri.parse(serverUrl), token),
    );

/// Result of the last check.
@immutable
class CatalogUpdateStatus {
  const CatalogUpdateStatus({this.busy = false, this.result, this.revision});

  final bool busy;

  /// `installed`, `upToDate`, `noUpdate`, `notConfigured`, `notConnected`,
  /// `incompatible`, `badSignature`, `invalid`, `network`, `failed`.
  final String? result;
  final String? revision;
}

// Standalone so that the isolate captures nothing from the UI.
Future<InstalledCatalog> _install(
  String directory,
  CatalogPackManifest manifest,
  List<int> pack,
) => Isolate.run(
  () => CatalogInstaller(Directory(directory)).install(manifest, pack),
);

class CatalogUpdateController extends Notifier<CatalogUpdateStatus> {
  @override
  CatalogUpdateStatus build() => const CatalogUpdateStatus();

  /// Checks your own sync server for a signed, newer catalog pack and
  /// installs it. On any error the previous catalog stays active.
  Future<CatalogUpdateStatus> check() async {
    state = const CatalogUpdateStatus(busy: true);
    final result = await _check();
    if (ref.mounted) state = result;
    return result;
  }

  Future<CatalogUpdateStatus> _check() async {
    const done = CatalogUpdateStatus.new;
    final keys = ref.read(catalogUpdateKeysProvider);
    if (keys.isEmpty) return done(result: 'notConfigured');
    final storage = ref.read(appStorageProvider);
    final config = await storage.syncConfig.load();
    if (config == null) return done(result: 'notConnected');
    final source = ref.read(catalogUpdateSourceFactoryProvider)(
      config.serverUrl,
      config.token,
    );
    try {
      final update = await source.catalogUpdate();
      if (update == null) return done(result: 'noUpdate');
      final CatalogPackManifest manifest;
      try {
        manifest = CatalogPackManifest.fromJson(
          await verifyCatalogUpdate(update, keys),
        );
      } on CatalogUpdateException catch (e) {
        return done(result: e.code == 'invalid' ? 'invalid' : 'badSignature');
      } on Object {
        return done(result: 'invalid');
      }
      if (manifest.schemaVersion != catalogSchemaVersion) {
        return done(result: 'incompatible', revision: manifest.revision);
      }
      final current = await CatalogInstaller(
        storage.catalogDirectory,
      ).current();
      if (current != null && manifest.sequence <= current.sequence) {
        return done(result: 'upToDate', revision: current.revision);
      }
      final pack = await source.catalogPack();
      final installed = await _install(
        storage.catalogDirectory.path,
        manifest,
        pack,
      );
      ref.invalidate(catalogProvider);
      return done(result: 'installed', revision: installed.revision);
    } on SyncProtocolException catch (e) {
      return done(result: e.code == 'network' ? 'network' : 'failed');
    } on Object catch (e) {
      // Also file errors etc.: the previous catalog stays active.
      debugPrint('Catalog update discarded: $e');
      return done(result: 'failed');
    } finally {
      if (source case final HttpSyncTransport http) http.close();
    }
  }
}

final catalogUpdateProvider =
    NotifierProvider<CatalogUpdateController, CatalogUpdateStatus>(
      CatalogUpdateController.new,
    );
