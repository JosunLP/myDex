import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import 'http_transport.dart';
import 'protocol.dart';

/// Abgleichsstand eines Geräts: Cursor, bekannte Revisionen und Outbox.
class SyncState {
  SyncState({
    this.cursor = 0,
    Map<String, int>? revisions,
    Map<String, SyncChange>? outbox,
    this.lastSync,
  }) : revisions = revisions ?? {},
       outbox = outbox ?? {};

  factory SyncState.fromJson(Map<String, Object?> j) => SyncState(
    cursor: j['cursor']! as int,
    revisions: {
      for (final MapEntry(:key, :value)
          in (j['revisions']! as Map<String, Object?>).entries)
        key: value! as int,
    },
    outbox: {
      for (final c in j['outbox']! as List<Object?>)
        for (final change in [SyncChange.fromJson(c! as Map<String, Object?>)])
          change.key: change,
    },
    lastSync: j['lastSync'] == null
        ? null
        : DateTime.parse(j['lastSync']! as String),
  );

  int cursor;

  /// Zuletzt übernommene Server-Revision je Datensatz.
  final Map<String, int> revisions;

  /// Noch nicht bestätigte lokale Änderungen, je Datensatz zusammengefasst.
  final Map<String, SyncChange> outbox;
  DateTime? lastSync;

  Map<String, Object?> toJson() => {
    'cursor': cursor,
    'revisions': revisions,
    'outbox': [for (final c in outbox.values) c.toJson()],
    if (lastSync != null) 'lastSync': lastSync!.toUtc().toIso8601String(),
  };
}

abstract interface class SyncStateStore {
  Future<SyncState?> load();
  Future<void> save(SyncState state);
  Future<void> clear();
}

class MemorySyncStateStore implements SyncStateStore {
  SyncState? _state;

  @override
  Future<SyncState?> load() async => _state;

  @override
  Future<void> save(SyncState state) async => _state = state;

  @override
  Future<void> clear() async => _state = null;
}

/// Abgleichsstand als JSON-Datei (atomar, Schreibvorgänge nacheinander).
class FileSyncStateStore implements SyncStateStore {
  FileSyncStateStore(this.file);

  final File file;
  Future<void> _queue = Future.value();

  @override
  Future<SyncState?> load() async {
    if (!await file.exists()) return null;
    try {
      return SyncState.fromJson(
        jsonDecode(await file.readAsString()) as Map<String, Object?>,
      );
    } on Object {
      // Ein unlesbarer Stand erzwingt einen vollständigen Neuabgleich.
      await file.rename(
        '${file.path}.corrupt-${DateTime.now().toUtc().millisecondsSinceEpoch}',
      );
      return SyncState();
    }
  }

  @override
  Future<void> save(SyncState state) =>
      _enqueue(() => writeFileAtomic(file, jsonEncode(state.toJson())));

  @override
  Future<void> clear() => _enqueue(() async {
    if (await file.exists()) await file.delete();
  });

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.catchError((Object _) {});
    return next;
  }
}

/// Lösung eines Konflikts zwischen lokaler Änderung und Serverstand.
sealed class ConflictResolution {
  const ConflictResolution();
}

/// Der Serverstand gilt; die lokale Änderung wird verworfen.
final class TakeServer extends ConflictResolution {
  const TakeServer();
}

/// Die lokale Änderung gilt und wird auf den Serverstand aufgesetzt.
final class KeepLocal extends ConflictResolution {
  const KeepLocal();
}

/// Beide bleiben: der Serverstand unter der ursprünglichen ID, die lokale
/// Fassung als neue Kopie [copy] (bereits lokal gespeichert).
final class KeepBoth extends ConflictResolution {
  const KeepBoth(this.copy);
  final SyncChange copy;
}

/// Bindet eine Art persönlicher Daten an den Abgleich.
abstract interface class SyncAdapter {
  String get kind;

  /// Alle lokalen Datensätze, für die erste Übertragung.
  Future<List<SyncChange>> localRecords();

  /// Übernimmt einen Serverdatensatz lokal, ohne ihn erneut zu senden.
  Future<void> apply(SyncRecord record);

  Future<ConflictResolution> resolve(SyncChange local, SyncRecord server);
}

@immutable
class SyncReport {
  const SyncReport({
    this.sent = 0,
    this.received = 0,
    this.conflicts = 0,
    this.copies = 0,
  });

  final int sent;
  final int received;
  final int conflicts;

  /// Davon als Konfliktkopie erhalten.
  final int copies;
}

/// Client-Seite: sammelt lokale Änderungen in einer Outbox und gleicht sie
/// mit dem Server ab. Ohne Verbindung (`connected == false`) wird nichts
/// aufgezeichnet.
class SyncClient {
  SyncClient({
    required this.stateStore,
    required List<SyncAdapter> adapters,
    this.maxRounds = 50,
  }) : _adapters = {for (final a in adapters) a.kind: a};

  final SyncStateStore stateStore;
  final Map<String, SyncAdapter> _adapters;
  final int maxRounds;

  SyncState? _state;
  Future<SyncReport>? _running;
  final _changes = StreamController<void>.broadcast();

  /// Meldet jede neue lokale Änderung (für verzögertes automatisches Abgleichen).
  Stream<void> get localChanges => _changes.stream;

  bool get connected => _state != null;
  int get pending => _state?.outbox.length ?? 0;
  DateTime? get lastSync => _state?.lastSync;
  bool get isSyncing => _running != null;

  Future<void> open() async => _state = await stateStore.load();

  /// Beginnt den Abgleich: alle lokalen Daten werden zur Übertragung vorgemerkt.
  Future<void> connect() async {
    final state = SyncState();
    for (final adapter in _adapters.values) {
      for (final change in await adapter.localRecords()) {
        state.outbox[change.key] = change;
      }
    }
    _state = state;
    await stateStore.save(state);
  }

  /// Beendet den Abgleich auf diesem Gerät; lokale Daten bleiben erhalten.
  Future<void> disconnect() async {
    await _running?.catchError((Object _) => const SyncReport());
    _state = null;
    await stateStore.clear();
  }

  /// Merkt eine lokale Änderung vor. Neuere Änderungen ersetzen ältere.
  Future<void> record(SyncChange change) => recordAll([change]);

  /// Merkt mehrere Änderungen auf einmal vor (z. B. beim Import).
  Future<void> recordAll(Iterable<SyncChange> changes) async {
    final state = _state;
    if (state == null) return;
    var any = false;
    for (final change in changes) {
      state.outbox[change.key] = change;
      any = true;
    }
    if (!any) return;
    _changes.add(null);
    await stateStore.save(state);
  }

  /// Gleicht ab. Läuft bereits ein Abgleich, wird dessen Ergebnis geliefert.
  Future<SyncReport> sync(SyncTransport transport) {
    if (_state == null) {
      return Future.error(const SyncProtocolException('notConnected'));
    }
    return _running ??= _sync(transport).whenComplete(() => _running = null);
  }

  Future<SyncReport> _sync(SyncTransport transport) async {
    final state = _state!;
    var sent = 0, received = 0, conflicts = 0, copies = 0;
    for (var round = 0; round < maxRounds; round++) {
      final batch = Map.fromEntries(
        state.outbox.entries.take(SyncLimits.changesPerRequest),
      );
      final response = await transport.sync(
        SyncRequest(
          since: state.cursor,
          changes: [
            for (final c in batch.values) c.withBase(state.revisions[c.key]),
          ],
        ),
      );
      // Nur entfernen, was während der Anfrage nicht erneut geändert wurde.
      void settle(String key) {
        if (identical(state.outbox[key], batch[key])) state.outbox.remove(key);
      }

      for (final r in response.results) {
        final local = batch[r.key];
        if (local == null) continue;
        switch (r.status) {
          case SyncResultStatus.applied:
            state.revisions[r.key] = r.revision!;
            settle(r.key);
            sent++;
          case SyncResultStatus.conflict:
            conflicts++;
            final server = r.current!;
            settle(r.key);
            final adapter = _adapters[r.kind];
            final resolution = adapter == null
                ? const TakeServer()
                : await adapter.resolve(local, server);
            state.revisions[r.key] = server.revision;
            switch (resolution) {
              case TakeServer():
                if (!state.outbox.containsKey(r.key)) {
                  await adapter?.apply(server);
                }
              case KeepLocal():
                state.outbox.putIfAbsent(r.key, () => local);
              case KeepBoth(:final copy):
                copies++;
                if (!state.outbox.containsKey(r.key)) {
                  await adapter?.apply(server);
                }
                state.outbox[copy.key] = copy;
            }
        }
      }
      for (final record in response.changes) {
        if ((state.revisions[record.key] ?? 0) >= record.revision) continue;
        // Offene lokale Änderung: der nächste Durchgang meldet den Konflikt.
        if (state.outbox.containsKey(record.key)) continue;
        await _adapters[record.kind]?.apply(record);
        state.revisions[record.key] = record.revision;
        received++;
      }
      state.cursor = response.cursor;
      await stateStore.save(state);
      if (!response.more && state.outbox.isEmpty) break;
    }
    state.lastSync = DateTime.now();
    await stateStore.save(state);
    return SyncReport(
      sent: sent,
      received: received,
      conflicts: conflicts,
      copies: copies,
    );
  }

  Future<void> close() => _changes.close();
}
