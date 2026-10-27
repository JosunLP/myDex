import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

/// Verbindung zum eigenen Sync-Server.
@immutable
class SyncConfig {
  const SyncConfig({required this.serverUrl, required this.token});

  factory SyncConfig.fromJson(Map<String, Object?> j) => SyncConfig(
    serverUrl: j['serverUrl']! as String,
    token: j['token']! as String,
  );

  final String serverUrl;
  final String token;

  Map<String, Object?> toJson() => {'serverUrl': serverUrl, 'token': token};
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

/// Im privaten App-Verzeichnis; Zugriff haben nur die App und das System.
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
