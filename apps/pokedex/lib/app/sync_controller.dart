import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_sync/mydex_sync.dart';

import 'providers.dart';
import 'sync_config.dart';

/// The Android flavor "offline" has no internet permission and therefore no
/// sync; all other editions offer it optionally.
final syncSupportedProvider = Provider<bool>((ref) => appFlavor != 'offline');

/// Builds the (unencrypted) connection to the server; replaceable in tests.
final syncTransportFactoryProvider =
    Provider<SyncTransport Function(String serverUrl, String token)>(
      (ref) =>
          (serverUrl, token) => HttpSyncTransport(Uri.parse(serverUrl), token),
    );

/// PBKDF2 iterations for new sync keys (smaller in tests).
final syncKdfIterationsProvider = Provider<int>(
  (ref) => SyncEncryption.defaultIterations,
);

/// Key derivation; outside the web in a background isolate.
final syncKeyDerivationProvider = Provider<KeyDerivation>(
  (ref) => kIsWeb ? SyncKey.derive : _deriveInBackground,
);

/// Minimum length of the sync passphrase.
const syncPassphraseMinLength = 8;

// Standalone so that the isolate captures nothing from the UI.
Future<SyncKey> _deriveInBackground(
  String passphrase,
  List<int> salt,
  int iterations,
) => Isolate.run(() => SyncKey.derive(passphrase, salt, iterations));

@immutable
class SyncStatus {
  const SyncStatus({
    this.config,
    this.syncing = false,
    this.lastSync,
    this.pending = 0,
    this.error,
    this.lastReport,
  });

  /// `null` = not connected.
  final SyncConfig? config;
  final bool syncing;
  final DateTime? lastSync;
  final int pending;

  /// Error code of the last attempt (see [SyncProtocolException.code]).
  final String? error;
  final SyncReport? lastReport;

  bool get connected => config != null;
}

class SyncController extends Notifier<SyncStatus> {
  Timer? _debounce;
  StreamSubscription<void>? _changes;

  /// Delay after a local change until the automatic sync.
  static const debounce = Duration(seconds: 5);

  SyncClient get _client => ref.read(appStorageProvider).sync;
  SyncConfigStore get _store => ref.read(appStorageProvider).syncConfig;

  @override
  SyncStatus build() {
    ref.onDispose(() {
      _debounce?.cancel();
      _changes?.cancel();
    });
    _changes = _client.localChanges.listen((_) => _schedule());
    unawaited(_restore());
    return const SyncStatus();
  }

  Future<void> _restore() async {
    final config = await _store.load();
    if (!ref.mounted || config == null || !_client.connected) return;
    state = _status(config: config);
    _schedule(const Duration(seconds: 2));
  }

  SyncStatus _status({
    SyncConfig? config,
    bool syncing = false,
    String? error,
    SyncReport? report,
  }) => SyncStatus(
    config: config ?? state.config,
    syncing: syncing,
    lastSync: _client.lastSync,
    pending: _client.pending,
    error: error,
    lastReport: report ?? state.lastReport,
  );

  void _schedule([Duration delay = debounce]) {
    if (!state.connected) return;
    state = _status(error: state.error);
    _debounce?.cancel();
    _debounce = Timer(delay, () => unawaited(syncNow()));
  }

  SyncTransport _base(SyncConfig config) =>
      ref.read(syncTransportFactoryProvider)(config.serverUrl, config.token);

  /// Encrypted connection (ADR 0014).
  EncryptingTransport _transport(SyncConfig config) => EncryptingTransport(
    _base(config),
    config.key,
    ref.read(appStorageProvider).syncAliases,
  );

  /// Connects to a server and unlocks the encryption with the sync
  /// passphrase. If authentication, address or passphrase fail, the app stays
  /// disconnected.
  Future<String?> connect(
    String serverUrl,
    String token,
    String passphrase,
  ) async {
    final url = serverUrl.trim();
    final secret = token.trim();
    try {
      HttpSyncTransport.checkServerUrl(Uri.parse(url));
    } on SyncProtocolException catch (e) {
      return e.code;
    } on FormatException {
      return 'invalidRequest';
    }
    if (passphrase.length < syncPassphraseMinLength) {
      return 'passphraseTooShort';
    }
    state = _status(syncing: true);
    final base = ref.read(syncTransportFactoryProvider)(url, secret);
    final SyncKey key;
    try {
      key = await EncryptingTransport.unlock(
        base,
        passphrase,
        iterations: ref.read(syncKdfIterationsProvider),
        derive: ref.read(syncKeyDerivationProvider),
      );
    } on SyncProtocolException catch (e) {
      if (ref.mounted) state = _status(error: e.code);
      return e.code;
    } finally {
      if (base is HttpSyncTransport) base.close();
    }
    final config = SyncConfig(serverUrl: url, token: secret, key: key);
    await ref.read(appStorageProvider).syncAliases.clear();
    await _client.connect();
    await _store.save(config);
    state = _status(config: config);
    final error = await syncNow();
    if (error case 'unauthorized' || 'insecureConnection' || 'notFound') {
      await disconnect();
      state = _status(error: error);
    }
    return error;
  }

  /// Syncs now; returns an error code or `null`.
  Future<String?> syncNow() async {
    final config = state.config;
    if (config == null) return 'notConnected';
    _debounce?.cancel();
    state = _status(syncing: true);
    final transport = _transport(config);
    try {
      final report = await _client.sync(transport);
      if (!ref.mounted) return null;
      if (report.received > 0 || report.copies > 0 || report.conflicts > 0) {
        ref
          ..invalidate(collectionProvider)
          ..invalidate(teamsProvider)
          ..invalidate(presetsProvider);
      }
      state = _status(report: report);
      return null;
    } on SyncProtocolException catch (e) {
      if (ref.mounted) state = _status(error: e.code);
      return e.code;
    } on Object catch (e) {
      debugPrint('Sync failed: $e');
      if (ref.mounted) state = _status(error: 'server');
      return 'server';
    } finally {
      transport.close();
    }
  }

  /// Disconnects this device; with [wipeServer] all data of the account on
  /// the server is deleted first.
  Future<String?> disconnect({bool wipeServer = false}) async {
    final config = state.config;
    if (wipeServer && config != null) {
      final transport = _base(config);
      try {
        await transport.deleteAccountData();
      } on SyncProtocolException catch (e) {
        state = _status(error: e.code);
        return e.code;
      } finally {
        if (transport is HttpSyncTransport) transport.close();
      }
    }
    _debounce?.cancel();
    await _client.disconnect();
    await _store.clear();
    await ref.read(appStorageProvider).syncAliases.clear();
    state = const SyncStatus();
    return null;
  }
}

final syncProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);
