import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import 'http_transport.dart';
import 'protocol.dart';

/// Sync state of a device: cursor, known revisions and outbox.
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

  /// Last applied server revision per record.
  final Map<String, int> revisions;

  /// Local changes not yet confirmed, coalesced per record.
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

/// Sync state as a JSON file (atomic, writes one after another).
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
      // An unreadable state forces a full resync.
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

/// Resolution of a conflict between a local change and the server state.
sealed class ConflictResolution {
  const ConflictResolution();
}

/// The server state wins; the local change is discarded.
final class TakeServer extends ConflictResolution {
  const TakeServer();
}

/// The local change wins and is rebased onto the server state.
final class KeepLocal extends ConflictResolution {
  const KeepLocal();
}

/// Both stay: the server state under the original ID, the local version as
/// a new copy [copy] (already stored locally).
final class KeepBoth extends ConflictResolution {
  const KeepBoth(this.copy);
  final SyncChange copy;
}

/// Binds one kind of personal data to the sync.
abstract interface class SyncAdapter {
  String get kind;

  /// All local records, for the initial upload.
  Future<List<SyncChange>> localRecords();

  /// Applies a server record locally without sending it again.
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

  /// Of which kept as conflict copies.
  final int copies;
}

/// Client side: collects local changes in an outbox and syncs them with the
/// server. Without a connection (`connected == false`) nothing is
/// recorded.
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

  /// Reports every new local change (for delayed automatic syncing).
  Stream<void> get localChanges => _changes.stream;

  bool get connected => _state != null;
  int get pending => _state?.outbox.length ?? 0;
  DateTime? get lastSync => _state?.lastSync;
  bool get isSyncing => _running != null;

  Future<void> open() async => _state = await stateStore.load();

  /// Starts syncing: all local data is queued for upload.
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

  /// Stops syncing on this device; local data is kept.
  Future<void> disconnect() async {
    await _running?.catchError((Object _) => const SyncReport());
    _state = null;
    await stateStore.clear();
  }

  /// Queues a local change. Newer changes replace older ones.
  Future<void> record(SyncChange change) => recordAll([change]);

  /// Queues several changes at once (e.g. on import).
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

  /// Syncs. If a sync is already running, its result is returned.
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
      // Only remove what was not changed again during the request.
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
        // Pending local change: the next round reports the conflict.
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
