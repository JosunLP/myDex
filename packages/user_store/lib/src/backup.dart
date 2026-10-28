import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Contents of a backup (personal data only, never the catalog).
@immutable
class BackupData {
  const BackupData({
    this.collection = const [],
    this.teams = const [],
    this.presets = const [],
    this.preferences = const {},
    required this.createdAt,
    this.skippedEntries = 0,
  });

  final List<CollectionEntry> collection;
  final List<Team> teams;
  final List<FilterPreset> presets;
  final Map<String, Object?> preferences;
  final DateTime createdAt;

  /// Unreadable entries skipped while reading.
  final int skippedEntries;
}

enum BackupError {
  notABackup,
  unsupportedVersion,
  passwordRequired,
  wrongPassword,
}

class BackupException implements Exception {
  BackupException(this.error);
  final BackupError error;
  @override
  String toString() => 'BackupException(${error.name})';
}

/// Versioned exchange format, optionally password-encrypted
/// (PBKDF2-HMAC-SHA256 → AES-256-GCM).
abstract final class BackupCodec {
  static const format = 'mydex-backup';
  static const encryptedFormat = 'mydex-backup-encrypted';
  static const version = 1;
  static const iterations = 210000;

  static Future<List<int>> encode(BackupData data, {String? password}) async {
    final plain = utf8.encode(
      const JsonEncoder.withIndent(' ').convert({
        'format': format,
        'version': version,
        'createdAt': data.createdAt.toUtc().toIso8601String(),
        'collection': [for (final e in data.collection) e.toJson()],
        'teams': [for (final t in data.teams) t.toJson()],
        'filterPresets': [for (final p in data.presets) p.toJson()],
        'preferences': data.preferences,
      }),
    );
    if (password == null || password.isEmpty) return plain;

    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(password, salt, iterations);
    final box = await AesGcm.with256bits().encrypt(plain, secretKey: key);
    return utf8.encode(
      jsonEncode({
        'format': encryptedFormat,
        'version': version,
        'kdf': {
          'name': 'pbkdf2-hmac-sha256',
          'iterations': iterations,
          'salt': base64Encode(salt),
        },
        'cipher': {
          'name': 'aes-256-gcm',
          'nonce': base64Encode(box.nonce),
          'mac': base64Encode(box.mac.bytes),
        },
        'data': base64Encode(box.cipherText),
      }),
    );
  }

  /// Whether the file needs a password. Throws for foreign files.
  static bool isEncrypted(List<int> bytes) =>
      _envelope(bytes)['format'] == encryptedFormat;

  static Future<BackupData> decode(List<int> bytes, {String? password}) async {
    var json = _envelope(bytes);
    if (json['format'] == encryptedFormat) {
      if (json['version'] != version) {
        throw BackupException(BackupError.unsupportedVersion);
      }
      if (password == null || password.isEmpty) {
        throw BackupException(BackupError.passwordRequired);
      }
      try {
        final kdf = json['kdf']! as Map<String, Object?>;
        final cipher = json['cipher']! as Map<String, Object?>;
        final key = await _deriveKey(
          password,
          base64Decode(kdf['salt']! as String),
          kdf['iterations']! as int,
        );
        final plain = await AesGcm.with256bits().decrypt(
          SecretBox(
            base64Decode(json['data']! as String),
            nonce: base64Decode(cipher['nonce']! as String),
            mac: Mac(base64Decode(cipher['mac']! as String)),
          ),
          secretKey: key,
        );
        json = _envelope(plain);
      } on SecretBoxAuthenticationError {
        throw BackupException(BackupError.wrongPassword);
      } on BackupException {
        rethrow;
      } on Object {
        throw BackupException(BackupError.notABackup);
      }
    }
    if (json['format'] != format) throw BackupException(BackupError.notABackup);
    if (json['version'] != version) {
      throw BackupException(BackupError.unsupportedVersion);
    }

    var skipped = 0;
    List<T> list<T>(String key, T Function(Map<String, Object?>) parse) {
      final result = <T>[];
      for (final e in (json[key] as List<Object?>?) ?? const <Object?>[]) {
        final value = _tryParse(e, parse);
        if (value == null) {
          skipped++;
        } else {
          result.add(value);
        }
      }
      return result;
    }

    final collection = list('collection', CollectionEntry.fromJson);
    final teams = list('teams', Team.fromJson);
    final presets = list('filterPresets', FilterPreset.fromJson);
    return BackupData(
      collection: collection,
      teams: teams,
      presets: presets,
      preferences: (json['preferences'] as Map<String, Object?>?) ?? const {},
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.utc(1970),
      skippedEntries: skipped,
    );
  }

  static T? _tryParse<T>(Object? e, T Function(Map<String, Object?>) parse) {
    try {
      return parse(e! as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  static Map<String, Object?> _envelope(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, Object?>) return decoded;
    } on Object {
      // falls through
    }
    throw BackupException(BackupError.notABackup);
  }

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  ).deriveKeyFromPassword(password: password, nonce: salt);
}

enum ImportMode {
  /// Newer entries win, nothing is deleted.
  merge,

  /// Personal data is completely replaced by the backup.
  replace,
}

@immutable
class ImportCounts {
  const ImportCounts({
    this.added = 0,
    this.updated = 0,
    this.kept = 0,
    this.removed = 0,
  });
  final int added;
  final int updated;

  /// Unchanged because the existing state is as new or newer.
  final int kept;

  /// Only when replacing: existing entries that are not in the backup.
  final int removed;
}

/// Result of planning: preview and the data to apply.
@immutable
class ImportPlan {
  const ImportPlan({
    required this.mode,
    required this.collection,
    required this.teams,
    required this.presets,
    required this.preferences,
    required this.collectionCounts,
    required this.teamCounts,
    required this.presetCounts,
  });

  final ImportMode mode;
  final List<CollectionEntry> collection;
  final List<Team> teams;
  final List<FilterPreset> presets;

  /// `null` = settings stay unchanged.
  final Map<String, Object?>? preferences;
  final ImportCounts collectionCounts;
  final ImportCounts teamCounts;
  final ImportCounts presetCounts;
}

/// Plans an import without changing anything (basis of the preview).
ImportPlan planImport({
  required BackupData current,
  required BackupData incoming,
  required ImportMode mode,
}) {
  (List<T>, ImportCounts) merge<K, T>(
    List<T> mine,
    List<T> theirs,
    K Function(T) key,
    DateTime Function(T) updated,
  ) {
    final result = {for (final m in mine) key(m): m};
    var added = 0, changed = 0, kept = 0;
    for (final t in theirs) {
      final existing = result[key(t)];
      if (existing == null) {
        added++;
        result[key(t)] = t;
      } else if (updated(t).isAfter(updated(existing))) {
        changed++;
        result[key(t)] = t;
      } else {
        kept++;
      }
    }
    if (mode == ImportMode.replace) {
      final theirKeys = {for (final t in theirs) key(t)};
      final removed = mine.where((m) => !theirKeys.contains(key(m))).length;
      final existing = {for (final m in mine) key(m)};
      return (
        theirs,
        ImportCounts(
          added: theirs.where((t) => !existing.contains(key(t))).length,
          updated: theirs.where((t) => existing.contains(key(t))).length,
          removed: removed,
        ),
      );
    }
    return (
      result.values.toList(),
      ImportCounts(added: added, updated: changed, kept: kept),
    );
  }

  final (collection, cc) = merge<String, CollectionEntry>(
    current.collection,
    incoming.collection,
    (e) => e.key.encoded,
    (e) => e.updatedAt,
  );
  final (teams, tc) = merge<String, Team>(
    current.teams,
    incoming.teams,
    (t) => t.id,
    (t) => t.updatedAt,
  );
  final (presets, pc) = merge<String, FilterPreset>(
    current.presets,
    incoming.presets,
    (p) => p.id,
    (p) => p.updatedAt,
  );
  return ImportPlan(
    mode: mode,
    collection: collection,
    teams: teams,
    presets: presets,
    preferences: mode == ImportMode.replace ? incoming.preferences : null,
    collectionCounts: cc,
    teamCounts: tc,
    presetCounts: pc,
  );
}
