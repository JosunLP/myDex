import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_sync/mydex_sync.dart';

import 'providers.dart';
import 'sync_config.dart';

/// Die Android-Ausgabe „offline“ hat keine Internet-Berechtigung und daher
/// keinen Abgleich; alle anderen Ausgaben bieten ihn optional an.
final syncSupportedProvider = Provider<bool>((ref) => appFlavor != 'offline');

/// Baut die (unverschlüsselte) Verbindung zum Server; in Tests ersetzbar.
final syncTransportFactoryProvider =
    Provider<SyncTransport Function(String serverUrl, String token)>(
      (ref) =>
          (serverUrl, token) => HttpSyncTransport(Uri.parse(serverUrl), token),
    );

/// PBKDF2-Runden für neue Sync-Schlüssel (in Tests kleiner).
final syncKdfIterationsProvider = Provider<int>(
  (ref) => SyncEncryption.defaultIterations,
);

/// Schlüsselableitung; außerhalb des Webs in einem Hintergrund-Isolate.
final syncKeyDerivationProvider = Provider<KeyDerivation>(
  (ref) => kIsWeb ? SyncKey.derive : _deriveInBackground,
);

/// Mindestlänge des Sync-Passworts.
const syncPassphraseMinLength = 8;

// Eigenständig, damit das Isolate nichts aus der Oberfläche einfängt.
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

  /// `null` = nicht verbunden.
  final SyncConfig? config;
  final bool syncing;
  final DateTime? lastSync;
  final int pending;

  /// Fehlercode des letzten Versuchs (siehe [SyncProtocolException.code]).
  final String? error;
  final SyncReport? lastReport;

  bool get connected => config != null;
}

class SyncController extends Notifier<SyncStatus> {
  Timer? _debounce;
  StreamSubscription<void>? _changes;

  /// Wartezeit nach einer lokalen Änderung bis zum automatischen Abgleich.
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

  /// Verschlüsselte Verbindung (ADR 0014).
  EncryptingTransport _transport(SyncConfig config) => EncryptingTransport(
    _base(config),
    config.key,
    ref.read(appStorageProvider).syncAliases,
  );

  /// Verbindet mit einem Server und entsperrt die Verschlüsselung mit dem
  /// Sync-Passwort. Scheitert Anmeldung, Adresse oder Passwort, bleibt die
  /// App getrennt.
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

  /// Gleicht jetzt ab; liefert einen Fehlercode oder `null`.
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
      debugPrint('Abgleich fehlgeschlagen: $e');
      if (ref.mounted) state = _status(error: 'server');
      return 'server';
    } finally {
      transport.close();
    }
  }

  /// Trennt dieses Gerät; mit [wipeServer] werden vorher alle Daten des
  /// Kontos auf dem Server gelöscht.
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
