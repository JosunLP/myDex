import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'schema.dart';
import 'sqlite_catalog.dart';

/// Beschreibung eines Katalogpakets (Manifest).
@immutable
class CatalogPackManifest {
  const CatalogPackManifest({
    required this.revision,
    required this.schemaVersion,
    required this.sha256,
    required this.size,
    this.source = '',
    this.sourceRevision = '',
  });

  factory CatalogPackManifest.fromJson(Map<String, Object?> j) =>
      CatalogPackManifest(
        revision: j['revision']! as String,
        schemaVersion: j['schemaVersion']! as int,
        sha256: j['sha256']! as String,
        size: j['size']! as int,
        source: (j['source'] as String?) ?? '',
        sourceRevision: (j['sourceRevision'] as String?) ?? '',
      );

  final String revision;
  final int schemaVersion;

  /// SHA-256 der entpackten SQLite-Datei.
  final String sha256;

  /// Größe der entpackten Datei in Bytes.
  final int size;
  final String source;
  final String sourceRevision;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'schemaVersion': schemaVersion,
    'sha256': sha256,
    'size': size,
    'source': source,
    'sourceRevision': sourceRevision,
  };
}

class CatalogInstallException implements Exception {
  CatalogInstallException(this.message);
  final String message;
  @override
  String toString() => 'Katalog-Installation fehlgeschlagen: $message';
}

@immutable
class InstalledCatalog {
  const InstalledCatalog(this.path, this.revision, {this.installError});

  final String path;
  final String revision;

  /// Gesetzt, wenn ein neues Paket verworfen wurde und die vorherige
  /// funktionierende Version weiterverwendet wird (Rollback).
  final Object? installError;
}

/// Installiert Katalogpakete so, dass ein Abbruch nie einen halben Stand
/// hinterlässt: entpacken → prüfen → atomar aktivieren → Vorgänger behalten.
class CatalogInstaller {
  CatalogInstaller(this.directory);

  final Directory directory;

  File get _activeFile => File('${directory.path}/active.json');

  /// Liefert den aktiven Katalog und installiert [manifest] bei Bedarf aus
  /// den gzip-komprimierten Bytes [compressed].
  Future<InstalledCatalog> ensureInstalled(
    CatalogPackManifest manifest,
    List<int> Function() compressed,
  ) async {
    await directory.create(recursive: true);
    final active = await _readActive();
    if (active != null &&
        active.revision == manifest.revision &&
        await File(active.path).exists()) {
      return active;
    }
    try {
      final installed = await install(manifest, compressed());
      return installed;
    } on Object catch (e) {
      // Rückfall nur auf eine Vorversion, die diese App-Version lesen kann.
      if (active != null && _isUsable(active.path)) {
        return InstalledCatalog(active.path, active.revision, installError: e);
      }
      rethrow;
    }
  }

  Future<InstalledCatalog> install(
    CatalogPackManifest manifest,
    List<int> compressed,
  ) async {
    if (manifest.schemaVersion != catalogSchemaVersion) {
      throw CatalogInstallException(
        'Schemaversion ${manifest.schemaVersion} wird nicht unterstützt',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(manifest.revision)) {
      throw CatalogInstallException('Ungültige Revision: ${manifest.revision}');
    }
    final tmp = File('${directory.path}/incoming-${manifest.revision}.tmp');
    final target = File(
      '${directory.path}/catalog-${manifest.revision}.sqlite',
    );
    try {
      final List<int> bytes;
      try {
        bytes = gzip.decode(compressed);
      } on FormatException catch (e) {
        throw CatalogInstallException(
          'Paket ist kein gültiges gzip: ${e.message}',
        );
      }
      if (bytes.length != manifest.size) {
        throw CatalogInstallException(
          'Größe ${bytes.length} statt ${manifest.size} Bytes',
        );
      }
      final digest = sha256.convert(bytes).toString();
      if (digest != manifest.sha256) {
        throw CatalogInstallException('Prüfsumme stimmt nicht überein');
      }
      await tmp.writeAsBytes(bytes, flush: true);
      _verifyDatabase(tmp.path, manifest.revision);
      await tmp.rename(target.path);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }

    final previous = await _readActive();
    await _writeActive(manifest.revision, target.path, previous?.path);
    await _cleanup(keep: {target.path, ?previous?.path});
    return InstalledCatalog(target.path, manifest.revision);
  }

  static bool _isUsable(String path) {
    if (!File(path).existsSync()) return false;
    try {
      final db = openCatalogDatabase(path);
      try {
        readCatalogMeta(db);
        return true;
      } finally {
        db.close();
      }
    } on Object {
      return false;
    }
  }

  void _verifyDatabase(String path, String revision) {
    final db = openCatalogDatabase(path);
    try {
      final check = db.select('PRAGMA integrity_check');
      if (check.length != 1 || check.first.values.first != 'ok') {
        throw CatalogInstallException('Integritätsprüfung fehlgeschlagen');
      }
      final meta = readCatalogMeta(db);
      if (meta['revision'] != revision) {
        throw CatalogInstallException(
          'Revision im Paket passt nicht zum Manifest',
        );
      }
    } on FormatException catch (e) {
      throw CatalogInstallException(e.message);
    } on Object catch (e) {
      if (e is CatalogInstallException) rethrow;
      throw CatalogInstallException('Datenbank nicht lesbar: $e');
    } finally {
      db.close();
    }
  }

  /// Der aktuell aktive Katalog, falls vorhanden.
  Future<InstalledCatalog?> current() async {
    final active = await _readActive();
    return active != null && await File(active.path).exists() ? active : null;
  }

  Future<InstalledCatalog?> _readActive() async {
    try {
      if (!await _activeFile.exists()) return null;
      final j =
          jsonDecode(await _activeFile.readAsString()) as Map<String, Object?>;
      return InstalledCatalog(j['path']! as String, j['revision']! as String);
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _writeActive(
    String revision,
    String path,
    String? previous,
  ) async {
    final tmp = File('${_activeFile.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({'revision': revision, 'path': path, 'previous': ?previous}),
      flush: true,
    );
    await tmp.rename(_activeFile.path);
  }

  Future<void> _cleanup({required Set<String> keep}) async {
    await for (final e in directory.list()) {
      if (e is File && e.path.endsWith('.sqlite') && !keep.contains(e.path)) {
        try {
          await e.delete();
        } on FileSystemException {
          // Noch geöffnet (z. B. Windows): beim nächsten Start erneut versuchen.
        }
      }
    }
  }
}
