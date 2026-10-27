import 'dart:typed_data';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:sqlite3/sqlite3.dart';

import 'sqlite_catalog.dart';

/// Schema des Medienpakets (getrennt vom Katalog, eigene Version).
const mediaSchemaVersion = 1;

const mediaSchema = [
  'CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
  // Sprite-Sätze je Spiel in Spielreihenfolge.
  'CREATE TABLE slot(id TEXT PRIMARY KEY, sort INTEGER NOT NULL)',
  'CREATE TABLE version_slot(version TEXT PRIMARY KEY, slot TEXT NOT NULL)',
  // slot = '' für das Standard-Sprite. Bewusst mit rowid: Bilddaten in einer
  // WITHOUT-ROWID-Tabelle belegen etwa doppelt so viel Platz.
  '''CREATE TABLE sprite(form TEXT NOT NULL, slot TEXT NOT NULL,
    shiny INTEGER NOT NULL, png BLOB NOT NULL, UNIQUE(form, slot, shiny))''',
];

Map<String, String> readMediaMeta(Database db) {
  final meta = {
    for (final r in db.select('SELECT key, value FROM meta'))
      r['key'] as String: r['value'] as String,
  };
  final schema = int.tryParse(meta['schemaVersion'] ?? '');
  if (schema != mediaSchemaVersion) {
    throw FormatException('Nicht unterstützte Medien-Schemaversion: $schema');
  }
  return meta;
}

/// Liest Sprites aus dem installierten Medienpaket. Das Verzeichnis aller
/// vorhandenen Bilder liegt im Speicher, die Bilddaten werden bei Bedarf
/// gelesen und begrenzt zwischengespeichert.
class SqliteMediaLibrary implements MediaLibrary {
  SqliteMediaLibrary._(this._db, this.slots, this._versions, this._index);

  factory SqliteMediaLibrary.open(String path) {
    final db = openCatalogDatabase(path);
    try {
      readMediaMeta(db);
      final slots = [
        for (final r in db.select('SELECT id FROM slot ORDER BY sort'))
          r['id'] as String,
      ];
      final versions = {
        for (final r in db.select('SELECT version, slot FROM version_slot'))
          GameVersionId(r['version'] as String): r['slot'] as String,
      };
      final index = <FormId, List<SpriteKey>>{};
      for (final r in db.select(
        'SELECT form, slot, shiny FROM sprite ORDER BY form, shiny',
      )) {
        final form = FormId(r['form'] as String);
        index.putIfAbsent(form, () => []).add((
          form: form,
          slot: r['slot'] as String,
          shiny: r['shiny'] == 1,
        ));
      }
      return SqliteMediaLibrary._(db, slots, versions, index);
    } on Object {
      db.close();
      rethrow;
    }
  }

  final Database _db;
  @override
  final List<String> slots;
  final Map<GameVersionId, String> _versions;
  final Map<FormId, List<SpriteKey>> _index;
  final _cache = <String, Uint8List>{};
  static const _cacheSize = 512;
  PreparedStatement? _select;

  @override
  List<GameVersionId> versionsOf(String slot) => [
    for (final e in _versions.entries)
      if (e.value == slot) e.key,
  ];

  @override
  String? slotFor(GameVersionId version) => _versions[version];

  @override
  bool has(FormId form, {String slot = '', bool shiny = false}) =>
      _index[form]?.any((k) => k.slot == slot && k.shiny == shiny) ?? false;

  @override
  Uint8List? sprite(FormId form, {String slot = '', bool shiny = false}) {
    if (!has(form, slot: slot, shiny: shiny)) return null;
    final key = '${form.value}|$slot|${shiny ? 1 : 0}';
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final rows = (_select ??= _db.prepare(
      'SELECT png FROM sprite WHERE form = ? AND slot = ? AND shiny = ?',
    )).select([form.value, slot, shiny ? 1 : 0]);
    if (rows.isEmpty) return null;
    final png = rows.first['png'] as Uint8List;
    _cache[key] = png;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return png;
  }

  @override
  Uint8List? spriteFor(
    FormId form, {
    GameVersionId? version,
    bool shiny = false,
  }) {
    final slot = version == null ? null : slotFor(version);
    if (slot != null) {
      final own = sprite(form, slot: slot, shiny: shiny);
      if (own != null) return own;
    }
    return sprite(form, shiny: shiny);
  }

  @override
  List<SpriteKey> spritesOf(FormId form) {
    final order = {'': -1, for (final (i, s) in slots.indexed) s: i};
    return [...?_index[form]]..sort((a, b) {
      final c = (order[a.slot] ?? 999).compareTo(order[b.slot] ?? 999);
      return c != 0 ? c : (a.shiny ? 1 : 0).compareTo(b.shiny ? 1 : 0);
    });
  }

  @override
  void close() {
    _select?.close();
    _db.close();
  }
}
