import 'dart:convert';

import 'package:mydex_sync/mydex_sync.dart';
import 'package:sqlite3/sqlite3.dart';

/// Öffnet (und legt bei Bedarf an) die Server-Datenbank.
Database openSyncDatabase(String path) {
  final db = sqlite3.open(path);
  db.execute('''
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;
    CREATE TABLE IF NOT EXISTS account (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      token_hash TEXT NOT NULL UNIQUE,
      head INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS record (
      account INTEGER NOT NULL REFERENCES account(id) ON DELETE CASCADE,
      kind TEXT NOT NULL,
      id TEXT NOT NULL,
      revision INTEGER NOT NULL,
      deleted INTEGER NOT NULL,
      data TEXT,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (account, kind, id)
    ) WITHOUT ROWID;
    CREATE INDEX IF NOT EXISTS record_by_revision ON record (account, revision);
  ''');
  return db;
}

/// Ablage in SQLite; jede Anfrage läuft in einer eigenen Transaktion.
class SqliteSyncStore implements SyncStore {
  SqliteSyncStore(this.db);

  final Database db;

  @override
  T transaction<T>(String account, T Function(SyncAccountTx tx) action) {
    final id = int.parse(account);
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action(_SqliteAccountTx(db, id));
      db.execute('COMMIT');
      return result;
    } on Object {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

class _SqliteAccountTx implements SyncAccountTx {
  _SqliteAccountTx(this.db, this.account)
    : head =
          db.select('SELECT head FROM account WHERE id = ?', [
                account,
              ]).firstOrNull?['head']
              as int? ??
          (throw StateError('Unbekanntes Konto $account'));

  final Database db;
  final int account;

  @override
  int head;

  static SyncRecord _record(Row r) => SyncRecord(
    kind: r['kind'] as String,
    id: r['id'] as String,
    revision: r['revision'] as int,
    updatedAt: DateTime.parse(r['updated_at'] as String),
    deleted: (r['deleted'] as int) != 0,
    data: r['data'] == null
        ? null
        : jsonDecode(r['data'] as String) as Map<String, Object?>,
  );

  @override
  SyncRecord? get(String kind, String id) {
    final rows = db.select(
      'SELECT * FROM record WHERE account = ? AND kind = ? AND id = ?',
      [account, kind, id],
    );
    return rows.isEmpty ? null : _record(rows.first);
  }

  @override
  void put(SyncRecord record) {
    db.execute(
      'INSERT OR REPLACE INTO record '
      '(account, kind, id, revision, deleted, data, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        account,
        record.kind,
        record.id,
        record.revision,
        record.deleted ? 1 : 0,
        record.data == null ? null : jsonEncode(record.data),
        record.updatedAt.toUtc().toIso8601String(),
      ],
    );
    if (record.revision > head) {
      head = record.revision;
      db.execute('UPDATE account SET head = ? WHERE id = ?', [head, account]);
    }
  }

  @override
  List<SyncRecord> since(int revision, int limit) => [
    for (final r in db.select(
      'SELECT * FROM record WHERE account = ? AND revision > ? '
      'ORDER BY revision LIMIT ?',
      [account, revision, limit],
    ))
      _record(r),
  ];

  /// Datensätze entfernen; `head` bleibt, damit Revisionen nie zurückspringen.
  @override
  void deleteAll() =>
      db.execute('DELETE FROM record WHERE account = ?', [account]);
}
