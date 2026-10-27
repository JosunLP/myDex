import 'dart:convert';

import 'protocol.dart';

/// Datenzugriff eines Kontos innerhalb einer Transaktion.
abstract interface class SyncAccountTx {
  /// Höchste vergebene Revision des Kontos (0 = leer).
  int get head;

  SyncRecord? get(String kind, String id);

  /// Speichert [record]; seine Revision wird zur neuen [head].
  void put(SyncRecord record);

  /// Datensätze mit Revision > [revision], aufsteigend, höchstens [limit].
  List<SyncRecord> since(int revision, int limit);

  /// Entfernt alle Datensätze des Kontos.
  void deleteAll();
}

/// Ablage des Servers. [transaction] führt [action] atomar für ein Konto aus.
abstract interface class SyncStore {
  T transaction<T>(String account, T Function(SyncAccountTx tx) action);
}

/// Serverlogik unabhängig von HTTP und Datenbank: optimistische Nebenläufigkeit
/// über Revisionen, Grabsteine für Löschungen, seitenweises Abholen.
class SyncServerCore {
  SyncServerCore(this.store, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SyncStore store;
  final DateTime Function() _clock;
  static final _kind = RegExp(SyncLimits.kindPattern);

  SyncResponse handle(String account, SyncRequest request) {
    _validate(request);
    return store.transaction(account, (tx) {
      final results = <SyncResult>[];
      for (final change in request.changes) {
        final current = tx.get(change.kind, change.id);
        // Ein fehlender Datensatz (neu oder nach Kontolöschung) wird angenommen.
        if (current != null && current.revision != change.baseRevision) {
          results.add(
            SyncResult(
              kind: change.kind,
              id: change.id,
              status: SyncResultStatus.conflict,
              current: current,
            ),
          );
          continue;
        }
        final revision = tx.head + 1;
        tx.put(
          SyncRecord(
            kind: change.kind,
            id: change.id,
            revision: revision,
            // Zeitstempel des Geräts, aber nie in der Zukunft des Servers.
            updatedAt: _notAfterNow(change.updatedAt),
            deleted: change.deleted,
            data: change.deleted ? null : change.data,
          ),
        );
        results.add(
          SyncResult(
            kind: change.kind,
            id: change.id,
            status: SyncResultStatus.applied,
            revision: revision,
          ),
        );
      }
      final page = tx.since(request.since, SyncLimits.changesPerRequest + 1);
      final more = page.length > SyncLimits.changesPerRequest;
      final changes = more
          ? page.sublist(0, SyncLimits.changesPerRequest)
          : page;
      return SyncResponse(
        cursor: more ? changes.last.revision : tx.head,
        results: results,
        changes: changes,
        more: more,
      );
    });
  }

  /// Löscht alle Daten des Kontos (Datenschutz: „Daten auf dem Server löschen“).
  void wipe(String account) =>
      store.transaction(account, (tx) => tx.deleteAll());

  DateTime _notAfterNow(DateTime t) {
    final now = _clock().toUtc();
    return t.toUtc().isAfter(now) ? now : t.toUtc();
  }

  static void _validate(SyncRequest request) {
    if (request.since < 0) {
      throw const SyncProtocolException('invalidRequest', 'since');
    }
    if (request.changes.length > SyncLimits.changesPerRequest) {
      throw const SyncProtocolException('tooLarge', 'changes');
    }
    final keys = <String>{};
    for (final c in request.changes) {
      if (!_kind.hasMatch(c.kind) ||
          c.id.isEmpty ||
          c.id.length > SyncLimits.idMaxLength) {
        throw SyncProtocolException('invalidRequest', c.key);
      }
      if (!keys.add(c.key)) {
        throw SyncProtocolException('invalidRequest', 'duplicate ${c.key}');
      }
      if (!c.deleted) {
        if (c.data == null) {
          throw SyncProtocolException('invalidRequest', 'data ${c.key}');
        }
        if (utf8.encode(jsonEncode(c.data)).length > SyncLimits.recordBytes) {
          throw SyncProtocolException('tooLarge', c.key);
        }
      }
    }
  }
}

/// Ablage im Speicher (Tests, Entwicklung).
class MemorySyncStore implements SyncStore {
  final _accounts = <String, _MemoryAccount>{};

  @override
  T transaction<T>(String account, T Function(SyncAccountTx tx) action) {
    final acc = _accounts.putIfAbsent(account, _MemoryAccount.new);
    // Auf Kopie arbeiten, damit ein Fehler nichts halb schreibt.
    final draft = acc.copy();
    final result = action(draft);
    _accounts[account] = draft;
    return result;
  }
}

class _MemoryAccount implements SyncAccountTx {
  _MemoryAccount();

  @override
  int head = 0;
  final records = <String, SyncRecord>{};

  _MemoryAccount copy() => _MemoryAccount()
    ..head = head
    ..records.addAll(records);

  @override
  SyncRecord? get(String kind, String id) => records[recordKey(kind, id)];

  @override
  void put(SyncRecord record) {
    records[record.key] = record;
    if (record.revision > head) head = record.revision;
  }

  @override
  List<SyncRecord> since(int revision, int limit) =>
      (records.values.where((r) => r.revision > revision).toList()
            ..sort((a, b) => a.revision.compareTo(b.revision)))
          .take(limit)
          .toList();

  @override
  void deleteAll() => records.clear();
}
