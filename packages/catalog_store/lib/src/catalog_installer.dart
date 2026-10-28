import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'package:sqlite3/sqlite3.dart';

import 'media.dart';
import 'schema.dart';
import 'sqlite_catalog.dart';

/// Description of a catalog pack (manifest).
@immutable
class CatalogPackManifest {
  const CatalogPackManifest({
    required this.revision,
    required this.schemaVersion,
    required this.sha256,
    required this.size,
    this.source = '',
    this.sourceRevision = '',
    this.sequence = 0,
  });

  factory CatalogPackManifest.fromJson(Map<String, Object?> j) =>
      CatalogPackManifest(
        revision: j['revision']! as String,
        schemaVersion: j['schemaVersion']! as int,
        sha256: j['sha256']! as String,
        size: j['size']! as int,
        source: (j['source'] as String?) ?? '',
        sourceRevision: (j['sourceRevision'] as String?) ?? '',
        sequence: (j['sequence'] as int?) ?? 0,
      );

  final String revision;
  final int schemaVersion;

  /// SHA-256 of the unpacked SQLite file.
  final String sha256;

  /// Size of the unpacked file in bytes.
  final int size;
  final String source;
  final String sourceRevision;

  /// Increasing order of the packs (higher = newer). Prevents an older pack
  /// from replacing a newer one. 0 = unknown.
  final int sequence;

  Map<String, Object?> toJson() => {
    'revision': revision,
    'schemaVersion': schemaVersion,
    'sha256': sha256,
    'size': size,
    'source': source,
    'sourceRevision': sourceRevision,
    if (sequence > 0) 'sequence': sequence,
  };
}

class CatalogInstallException implements Exception {
  CatalogInstallException(this.message);
  final String message;
  @override
  String toString() => 'Catalog installation failed: $message';
}

@immutable
class InstalledCatalog {
  const InstalledCatalog(
    this.path,
    this.revision, {
    this.installError,
    this.sequence = 0,
  });

  final String path;
  final String revision;

  /// Sequence of the installed pack (see [CatalogPackManifest.sequence]).
  final int sequence;

  /// Set when a new pack was discarded and the previous working version is
  /// used instead (rollback).
  final Object? installError;
}

/// Kind of installable pack: catalog or media.
@immutable
class PackFormat {
  const PackFormat({
    required this.name,
    required this.schemaVersion,
    required this.readMeta,
  });

  /// Prefix of the installed files.
  final String name;
  final int schemaVersion;

  /// Reads the metadata and checks the schema version (throws otherwise).
  final Map<String, String> Function(Database db) readMeta;

  static const catalog = PackFormat(
    name: 'catalog',
    schemaVersion: catalogSchemaVersion,
    readMeta: readCatalogMeta,
  );

  static const media = PackFormat(
    name: 'media',
    schemaVersion: mediaSchemaVersion,
    readMeta: readMediaMeta,
  );
}

/// Installs catalog packs so that an abort never leaves a half-finished
/// state: unpack → verify → activate atomically → keep the predecessor.
class CatalogInstaller {
  CatalogInstaller(this.directory, {this.format = PackFormat.catalog});

  final Directory directory;
  final PackFormat format;

  File get _activeFile => File('${directory.path}/active.json');

  /// Returns the active catalog and installs [manifest] from the
  /// gzip-compressed bytes [compressed] if needed.
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
      // Fall back only to a previous version this app version can read.
      if (active != null && _isUsable(active.path)) {
        return InstalledCatalog(
          active.path,
          active.revision,
          installError: e,
          sequence: active.sequence,
        );
      }
      rethrow;
    }
  }

  Future<InstalledCatalog> install(
    CatalogPackManifest manifest,
    List<int> compressed,
  ) async {
    if (manifest.schemaVersion != format.schemaVersion) {
      throw CatalogInstallException(
        'Schema version ${manifest.schemaVersion} is not supported',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(manifest.revision)) {
      throw CatalogInstallException('Invalid revision: ${manifest.revision}');
    }
    await directory.create(recursive: true);
    final tmp = File('${directory.path}/incoming-${manifest.revision}.tmp');
    final target = File(
      '${directory.path}/${format.name}-${manifest.revision}.sqlite',
    );
    try {
      final List<int> bytes;
      try {
        bytes = gzip.decode(compressed);
      } on FormatException catch (e) {
        throw CatalogInstallException('Pack is not valid gzip: ${e.message}');
      }
      if (bytes.length != manifest.size) {
        throw CatalogInstallException(
          'Size ${bytes.length} instead of ${manifest.size} bytes',
        );
      }
      final digest = sha256.convert(bytes).toString();
      if (digest != manifest.sha256) {
        throw CatalogInstallException('Checksum does not match');
      }
      await tmp.writeAsBytes(bytes, flush: true);
      _verifyDatabase(tmp.path, manifest.revision);
      await tmp.rename(target.path);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }

    final previous = await _readActive();
    await _writeActive(
      manifest.revision,
      target.path,
      previous?.path,
      manifest.sequence,
    );
    await _cleanup(keep: {target.path, ?previous?.path});
    return InstalledCatalog(
      target.path,
      manifest.revision,
      sequence: manifest.sequence,
    );
  }

  bool _isUsable(String path) {
    if (!File(path).existsSync()) return false;
    try {
      final db = openCatalogDatabase(path);
      try {
        format.readMeta(db);
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
        throw CatalogInstallException('Integrity check failed');
      }
      final meta = format.readMeta(db);
      if (meta['revision'] != revision) {
        throw CatalogInstallException(
          'Revision in the pack does not match the manifest',
        );
      }
    } on FormatException catch (e) {
      throw CatalogInstallException(e.message);
    } on Object catch (e) {
      if (e is CatalogInstallException) rethrow;
      throw CatalogInstallException('Database not readable: $e');
    } finally {
      db.close();
    }
  }

  /// The currently active catalog, if any.
  Future<InstalledCatalog?> current() async {
    final active = await _readActive();
    return active != null && await File(active.path).exists() ? active : null;
  }

  Future<InstalledCatalog?> _readActive() async {
    try {
      if (!await _activeFile.exists()) return null;
      final j =
          jsonDecode(await _activeFile.readAsString()) as Map<String, Object?>;
      return InstalledCatalog(
        j['path']! as String,
        j['revision']! as String,
        sequence: (j['sequence'] as int?) ?? 0,
      );
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> _writeActive(
    String revision,
    String path,
    String? previous,
    int sequence,
  ) async {
    final tmp = File('${_activeFile.path}.tmp');
    await tmp.writeAsString(
      jsonEncode({
        'revision': revision,
        'path': path,
        'previous': ?previous,
        if (sequence > 0) 'sequence': sequence,
      }),
      flush: true,
    );
    await tmp.rename(_activeFile.path);
  }

  /// File name of [path]. Compared by name because listed entries use the
  /// platform separator (`\` on Windows) while stored paths may use `/`.
  static String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

  Future<void> _cleanup({required Set<String> keep}) async {
    final keepNames = keep.map(_fileName).toSet();
    await for (final e in directory.list()) {
      if (e is File &&
          e.path.endsWith('.sqlite') &&
          !keepNames.contains(_fileName(e.path))) {
        try {
          await e.delete();
        } on FileSystemException {
          // Still open (e.g. Windows): try again on the next start.
        }
      }
    }
  }
}
