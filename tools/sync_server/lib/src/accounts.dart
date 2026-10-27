import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqlite3/sqlite3.dart';

/// Konten mit Zugangsschlüssel. Gespeichert wird nur ein SHA-256-Hash des
/// Schlüssels; der Schlüssel selbst wird einmalig beim Anlegen ausgegeben.
class AccountRegistry {
  AccountRegistry(this.db, {Random? random})
    : _random = random ?? Random.secure();

  final Database db;
  final Random _random;

  static String _hash(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  /// Legt ein Konto an und liefert dessen Zugangsschlüssel.
  String create(String name) {
    if (name.trim().isEmpty) throw ArgumentError('Name fehlt');
    final token = base64Url
        .encode(List.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    db.execute(
      'INSERT INTO account (name, token_hash, created_at) VALUES (?, ?, ?)',
      [name.trim(), _hash(token), DateTime.now().toUtc().toIso8601String()],
    );
    return token;
  }

  /// Neuer Schlüssel für ein bestehendes Konto; der alte wird ungültig.
  String rotate(String name) {
    final token = base64Url
        .encode(List.generate(32, (_) => _random.nextInt(256)))
        .replaceAll('=', '');
    db.execute('UPDATE account SET token_hash = ? WHERE name = ?', [
      _hash(token),
      name,
    ]);
    if (db.updatedRows == 0) throw ArgumentError('Unbekanntes Konto $name');
    return token;
  }

  /// Entfernt Konto und alle Daten.
  bool delete(String name) {
    db.execute('DELETE FROM account WHERE name = ?', [name]);
    return db.updatedRows > 0;
  }

  List<({String name, int records, String createdAt})> list() => [
    for (final r in db.select(
      'SELECT a.name, a.created_at, COUNT(r.id) AS records FROM account a '
      'LEFT JOIN record r ON r.account = a.id GROUP BY a.id ORDER BY a.name',
    ))
      (
        name: r['name'] as String,
        records: r['records'] as int,
        createdAt: r['created_at'] as String,
      ),
  ];

  /// Konto-ID zum Schlüssel oder `null`.
  String? authenticate(String token) {
    if (token.isEmpty || token.length > 200) return null;
    final rows = db.select('SELECT id FROM account WHERE token_hash = ?', [
      _hash(token),
    ]);
    return rows.isEmpty ? null : '${rows.first['id']}';
  }
}
