import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Festgehaltener Stand von `PokeAPI/sprites` (Dateien je Commit unveränderlich).
const spritesRepository = 'https://github.com/PokeAPI/sprites';
const spritesCommit = 'd8c2fb78563e28ad7b3abe938cf6e79998d04e90';

/// Sprite-Satz eines Spiels: Verzeichnis in der Quelle, Versionen, Shiny ja/nein.
class SpriteSlot {
  const SpriteSlot(
    this.id,
    this.versionGroup,
    this.dir,
    this.versions, {
    this.shiny = true,
  });

  /// Kennung im Medienpaket, z. B. `gold`.
  final String id;

  /// Spielgruppe, deren Verfügbarkeit die Kandidaten bestimmt.
  final String versionGroup;

  /// Verzeichnis unter `sprites/pokemon/versions/`.
  final String dir;
  final List<String> versions;
  final bool shiny;
}

/// Spiele mit eigenen Sprites (Gen 1–5). Gen 1 und 2 in der transparenten
/// Fassung, damit sie auf hellem und dunklem Hintergrund passen.
const spriteSlots = [
  SpriteSlot('red-blue', 'red-blue', 'generation-i/red-blue/transparent', [
    'red-japan',
    'green-japan',
    'blue-japan',
    'red',
    'blue',
  ], shiny: false),
  SpriteSlot('yellow', 'yellow', 'generation-i/yellow/transparent', [
    'yellow',
  ], shiny: false),
  SpriteSlot('gold', 'gold-silver', 'generation-ii/gold/transparent', ['gold']),
  SpriteSlot('silver', 'gold-silver', 'generation-ii/silver/transparent', [
    'silver',
  ]),
  SpriteSlot('crystal', 'crystal', 'generation-ii/crystal/transparent', [
    'crystal',
  ]),
  SpriteSlot('ruby-sapphire', 'ruby-sapphire', 'generation-iii/ruby-sapphire', [
    'ruby',
    'sapphire',
  ]),
  SpriteSlot('emerald', 'emerald', 'generation-iii/emerald', ['emerald']),
  SpriteSlot(
    'firered-leafgreen',
    'firered-leafgreen',
    'generation-iii/firered-leafgreen',
    ['firered', 'leafgreen'],
  ),
  SpriteSlot('diamond-pearl', 'diamond-pearl', 'generation-iv/diamond-pearl', [
    'diamond',
    'pearl',
  ]),
  SpriteSlot('platinum', 'platinum', 'generation-iv/platinum', ['platinum']),
  SpriteSlot(
    'heartgold-soulsilver',
    'heartgold-soulsilver',
    'generation-iv/heartgold-soulsilver',
    ['heartgold', 'soulsilver'],
  ),
  SpriteSlot('black-white', 'black-white', 'generation-v/black-white', [
    'black',
    'white',
    'black-2',
    'white-2',
  ]),
];

/// Eine zu ladende Datei und ihr Ziel im Medienpaket.
class _Wanted {
  const _Wanted(this.form, this.slot, this.shiny, this.path);
  final String form;
  final String slot; // '' = Standard-Sprite
  final bool shiny;
  final String path;
}

class MediaReport {
  int requested = 0;
  int stored = 0;
  int missing = 0;
  int bytes = 0;

  @override
  String toString() =>
      'Sprites: $stored gespeichert ($bytes Bytes), $missing in der Quelle nicht vorhanden';
}

/// Baut das Medienpaket aus einem fertigen Katalog: Kandidaten sind alle Formen,
/// die im jeweiligen Spiel nicht bestätigt fehlen.
class MediaBuilder {
  MediaBuilder({required this.catalog, required this.cache, this.log});

  final File catalog;

  /// Ablage geladener Dateien; fehlende Dateien als `.missing`-Marke.
  final Directory cache;
  final void Function(String)? log;

  static Uri _url(String path) => Uri.parse(
    'https://raw.githubusercontent.com/PokeAPI/sprites/$spritesCommit/sprites/pokemon/$path',
  );

  List<_Wanted> _candidates() {
    final db = openCatalogDatabase(catalog.path);
    try {
      final wanted = <_Wanted>[];
      final forms = db.select('SELECT rid, id FROM form ORDER BY rid');
      for (final f in forms) {
        final rid = f['rid'] as int;
        final id = f['id'] as String;
        wanted
          ..add(_Wanted(id, '', false, '$rid.png'))
          ..add(_Wanted(id, '', true, 'shiny/$rid.png'));
      }
      for (final slot in spriteSlots) {
        final rows = db.select(
          'SELECT f.rid, f.id FROM form_profile fp '
          'JOIN version_group vg ON vg.rid = fp.version_group '
          'JOIN form f ON f.rid = fp.form '
          "WHERE vg.id = ? AND fp.availability != 'confirmed_unavailable' "
          'ORDER BY f.rid',
          [slot.versionGroup],
        );
        for (final f in rows) {
          final rid = f['rid'] as int;
          final id = f['id'] as String;
          wanted.add(
            _Wanted(id, slot.id, false, 'versions/${slot.dir}/$rid.png'),
          );
          if (slot.shiny) {
            wanted.add(
              _Wanted(id, slot.id, true, 'versions/${slot.dir}/shiny/$rid.png'),
            );
          }
        }
      }
      return wanted;
    } finally {
      db.close();
    }
  }

  /// Lädt fehlende Dateien parallel in den Cache.
  Future<void> _fetch(List<_Wanted> wanted, {int parallel = 16}) async {
    final queue = Queue.of(
      wanted.where((w) {
        final f = File('${cache.path}/${w.path}');
        return !f.existsSync() && !File('${f.path}.missing').existsSync();
      }),
    );
    if (queue.isEmpty) return;
    log?.call('lade ${queue.length} Sprites …');
    final client = HttpClient()..maxConnectionsPerHost = parallel;
    var done = 0;
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final w = queue.removeFirst();
        await _download(client, w.path);
        if (++done % 500 == 0) log?.call('  $done');
      }
    }

    try {
      await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
    } finally {
      client.close();
    }
  }

  Future<void> _download(HttpClient client, String path) async {
    final target = File('${cache.path}/$path');
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await (await client.getUrl(_url(path))).close();
        if (response.statusCode == 404) {
          await response.drain<void>();
          await File('${target.path}.missing').create(recursive: true);
          return;
        }
        if (response.statusCode != 200) {
          await response.drain<void>();
          throw HttpException('HTTP ${response.statusCode} für $path');
        }
        final bytes = BytesBuilder(copy: false);
        await response.forEach(bytes.add);
        final data = bytes.takeBytes();
        if (!_isPng(data)) throw FormatException('Kein PNG: $path');
        await target.parent.create(recursive: true);
        final tmp = File('${target.path}.part');
        await tmp.writeAsBytes(data, flush: true);
        await tmp.rename(target.path);
        return;
      } on Object {
        if (attempt >= 4) rethrow;
        await Future<void>.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }

  static bool _isPng(List<int> b) =>
      b.length > 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47;

  /// Lädt (falls nötig) und schreibt die Mediendatenbank nach [out].
  Future<MediaReport> build(
    File out, {
    required String revision,
    Set<String>? onlyForms,
  }) async {
    final wanted = [
      for (final w in _candidates())
        if (onlyForms == null || onlyForms.contains(w.form)) w,
    ];
    await _fetch(wanted);
    if (out.existsSync()) out.deleteSync();
    final report = MediaReport()..requested = wanted.length;
    final db = sqlite3.open(out.path);
    try {
      for (final statement in mediaSchema) {
        db.execute(statement);
      }
      final insertMeta = db.prepare('INSERT INTO meta VALUES (?, ?)');
      for (final e in {
        'schemaVersion': '$mediaSchemaVersion',
        'revision': revision,
        'source': 'PokeAPI/sprites',
        'sourceRevision': spritesCommit,
      }.entries) {
        insertMeta.execute([e.key, e.value]);
      }
      insertMeta.close();
      final insertSlot = db.prepare('INSERT INTO slot VALUES (?, ?)');
      final insertVersion = db.prepare(
        'INSERT INTO version_slot VALUES (?, ?)',
      );
      for (final (i, s) in spriteSlots.indexed) {
        insertSlot.execute([s.id, i]);
        for (final v in s.versions) {
          insertVersion.execute([v, s.id]);
        }
      }
      insertSlot.close();
      insertVersion.close();

      final insert = db.prepare('INSERT INTO sprite VALUES (?, ?, ?, ?)');
      db.execute('BEGIN');
      for (final w in wanted) {
        final file = File('${cache.path}/${w.path}');
        if (!file.existsSync()) {
          report.missing++;
          continue;
        }
        final png = file.readAsBytesSync();
        insert.execute([w.form, w.slot, w.shiny ? 1 : 0, png]);
        report.stored++;
        report.bytes += png.length;
      }
      db.execute('COMMIT');
      insert.close();
      db.execute('VACUUM');
    } finally {
      db.close();
    }
    return report;
  }
}
