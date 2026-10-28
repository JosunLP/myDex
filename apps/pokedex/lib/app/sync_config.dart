import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

/// Connection to your own sync server.
@immutable
class SyncConfig {
  const SyncConfig({
    required this.serverUrl,
    required this.token,
    required this.key,
  });

  factory SyncConfig.fromJson(Map<String, Object?> j) => SyncConfig(
    serverUrl: j['serverUrl']! as String,
    token: j['token']! as String,
    key: SyncKey.fromJson(j['key']! as Map<String, Object?>),
  );

  final String serverUrl;
  final String token;

  /// Keys derived from the sync passphrase (ADR 0014). The passphrase itself
  /// is not stored.
  final SyncKey key;

  Map<String, Object?> toJson() => {
    'serverUrl': serverUrl,
    'token': token,
    'key': key.toJson(),
  };
}

abstract interface class SyncConfigStore {
  Future<SyncConfig?> load();
  Future<void> save(SyncConfig config);
  Future<void> clear();
}

class MemorySyncConfigStore implements SyncConfigStore {
  SyncConfig? _config;

  @override
  Future<SyncConfig?> load() async => _config;

  @override
  Future<void> save(SyncConfig config) async => _config = config;

  @override
  Future<void> clear() async => _config = null;
}

/// In the app's private directory; only the app and the system have access.
class FileSyncConfigStore implements SyncConfigStore {
  FileSyncConfigStore(this.file);

  final File file;

  @override
  Future<SyncConfig?> load() async {
    try {
      if (!await file.exists()) return null;
      return SyncConfig.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(SyncConfig config) =>
      writeFileAtomic(file, jsonEncode(config.toJson()));

  @override
  Future<void> clear() async {
    if (await file.exists()) await file.delete();
  }
}
