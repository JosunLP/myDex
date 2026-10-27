import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:sqlite3/sqlite3.dart';

import 'artwork.dart';

/// Pinned state of `PokeAPI/sprites` (files at a commit are immutable).
const spritesRepository = 'https://github.com/PokeAPI/sprites';
const spritesCommit = 'd8c2fb78563e28ad7b3abe938cf6e79998d04e90';

/// Sprite set of a game: directory in the source, versions, shiny yes/no.
class SpriteSlot {
  const SpriteSlot(
    this.id,
    this.versionGroup,
    this.dir,
    this.versions, {
    this.shiny = true,
    this.ext = 'png',
    this.still = false,
  });

  /// Identifier in the media pack, e.g. `gold`.
  final String id;

  /// Version group whose availability determines the candidates.
  final String versionGroup;

  /// Directory under `sprites/pokemon/versions/`.
  final String dir;
  final List<String> versions;
  final bool shiny;

  /// File extension in the source.
  final String ext;

  /// From Gen 7: shrink to a still image (see `shrinkStill`).
  final bool still;
}

/// Games with their own images. Gen 1 and 2 in the transparent version so that
/// they fit on light and dark backgrounds.
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
  SpriteSlot('x-y', 'x-y', 'generation-vi/x-y', ['x', 'y']),
  SpriteSlot(
    'omega-ruby-alpha-sapphire',
    'omega-ruby-alpha-sapphire',
    'generation-vi/omega-ruby-alpha-sapphire',
    ['omega-ruby', 'alpha-sapphire'],
  ),
  // From Gen 7 there are only animated 3D models (0.1–6 MB per image) or box
  // icons; a downscaled still image is stored, without shiny.
  SpriteSlot(
    'ultra-sun-ultra-moon',
    'ultra-sun-ultra-moon',
    'generation-vii/ultra-sun-ultra-moon',
    ['sun', 'moon', 'ultra-sun', 'ultra-moon'],
    shiny: false,
    ext: 'gif',
    still: true,
  ),
  SpriteSlot(
    'lets-go',
    'lets-go-pikachu-lets-go-eevee',
    'generation-vii/lets-go-pikachu-lets-go-eevee/icons',
    ['lets-go-pikachu', 'lets-go-eevee'],
    shiny: false,
    still: true,
  ),
  SpriteSlot(
    'sword-shield',
    'sword-shield',
    'generation-viii/sword-shield/icons',
    [
      'sword',
      'shield',
      'the-isle-of-armor-sword',
      'the-isle-of-armor-shield',
      'the-crown-tundra-sword',
      'the-crown-tundra-shield',
    ],
    shiny: false,
    still: true,
  ),
  SpriteSlot(
    'brilliant-diamond-shining-pearl',
    'brilliant-diamond-shining-pearl',
    'generation-viii/brilliant-diamond-shining-pearl/icons',
    ['brilliant-diamond', 'shining-pearl'],
    shiny: false,
    still: true,
  ),
  SpriteSlot(
    'legends-arceus',
    'legends-arceus',
    'generation-viii/legends-arceus/icons',
    ['legends-arceus'],
    shiny: false,
    still: true,
  ),
  SpriteSlot(
    'scarlet-violet',
    'scarlet-violet',
    'generation-ix/scarlet-violet/icons',
    [
      'scarlet',
      'violet',
      'the-teal-mask-scarlet',
      'the-teal-mask-violet',
      'the-indigo-disk-scarlet',
      'the-indigo-disk-violet',
    ],
    shiny: false,
    still: true,
  ),
  SpriteSlot(
    'legends-za',
    'legends-za',
    'generation-ix/legends-za/icons',
    ['legends-za', 'mega-dimension'],
    shiny: false,
    still: true,
  ),
  SpriteSlot(
    'champions',
    'champions',
    'generation-ix/champions/icons',
    ['champions'],
    shiny: false,
    still: true,
  ),
];

/// Official artwork per form (not an in-game sprite, so no entry in `slot`).
const artworkSlot = 'artwork';

/// A file to download and its target in the media pack.
class _Wanted {
  const _Wanted(
    this.form,
    this.slot,
    this.shiny,
    this.path, {
    this.still = false,
  });
  final String form;
  final String slot; // '' = default sprite
  final bool shiny;
  final String path;
  final bool still;
}

class MediaReport {
  int requested = 0;
  int stored = 0;
  int missing = 0;
  int bytes = 0;

  @override
  String toString() =>
      'Sprites: $stored stored ($bytes bytes), $missing not present in the source';
}

/// Builds the media pack from a finished catalog: candidates are all forms not
/// confirmed missing from the respective game.
class MediaBuilder {
  MediaBuilder({required this.catalog, required this.cache, this.log});

  final File catalog;

  /// Storage of downloaded files; missing files as a `.missing` marker.
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
          ..add(_Wanted(id, '', true, 'shiny/$rid.png'))
          ..add(
            _Wanted(id, artworkSlot, false, 'other/official-artwork/$rid.png'),
          );
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
            _Wanted(
              id,
              slot.id,
              false,
              'versions/${slot.dir}/$rid.${slot.ext}',
              still: slot.still,
            ),
          );
          if (slot.shiny) {
            wanted.add(
              _Wanted(
                id,
                slot.id,
                true,
                'versions/${slot.dir}/shiny/$rid.${slot.ext}',
                still: slot.still,
              ),
            );
          }
        }
      }
      return wanted;
    } finally {
      db.close();
    }
  }

  /// Downloads missing files into the cache in parallel.
  Future<void> _fetch(List<_Wanted> wanted, {int parallel = 16}) async {
    final queue = Queue.of(
      wanted.where((w) {
        final f = File('${cache.path}/${w.path}');
        return !f.existsSync() &&
            !File('${f.path}.missing').existsSync() &&
            !(w.still && _stillFile(w.path).existsSync());
      }),
    );
    if (queue.isEmpty) return;
    log?.call('downloading ${queue.length} sprites …');
    final client = HttpClient()..maxConnectionsPerHost = parallel;
    var done = 0;
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final w = queue.removeFirst();
        await _download(client, w.path);
        if (w.still) _still(w.path);
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
          throw HttpException('HTTP ${response.statusCode} for $path');
        }
        final bytes = BytesBuilder(copy: false);
        await response.forEach(bytes.add);
        final data = bytes.takeBytes();
        if (!_isImage(data)) throw FormatException('Not an image: $path');
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

  /// PNG, GIF or WebP (RIFF…WEBP).
  static bool _isImage(List<int> b) =>
      b.length > 12 &&
      ((b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) ||
          (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) ||
          (b[0] == 0x52 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42));

  File _stillFile(String path) => File('${cache.path}/$stillProcess/$path.png');

  /// Still image from Gen 7; the (large) original is deleted afterwards, only
  /// the result stays in the cache.
  List<int>? _still(String path) {
    final cached = _stillFile(path);
    if (cached.existsSync()) return cached.readAsBytesSync();
    final original = File('${cache.path}/$path');
    if (!original.existsSync()) return null;
    final png = shrinkStill(original.readAsBytesSync());
    cached.parent.createSync(recursive: true);
    cached.writeAsBytesSync(png);
    original.deleteSync();
    return png;
  }

  /// Downscaled artwork, cached next to the original.
  List<int> _shrunk(String path, File original) {
    final cached = File('${cache.path}/$artworkProcess/$path');
    if (cached.existsSync()) return cached.readAsBytesSync();
    final png = shrinkArtwork(original.readAsBytesSync());
    cached.parent.createSync(recursive: true);
    cached.writeAsBytesSync(png);
    return png;
  }

  /// Downloads (if needed) and writes the media database to [out].
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
      final insertColor = db.prepare('INSERT INTO artwork_color VALUES (?, ?)');
      db.execute('BEGIN');
      for (final w in wanted) {
        final file = File('${cache.path}/${w.path}');
        final List<int> png;
        if (w.still) {
          final still = _still(w.path);
          if (still == null) {
            report.missing++;
            continue;
          }
          png = still;
        } else if (!file.existsSync()) {
          report.missing++;
          continue;
        } else {
          png = w.slot == artworkSlot
              ? _shrunk(w.path, file)
              : file.readAsBytesSync();
        }
        insert.execute([w.form, w.slot, w.shiny ? 1 : 0, png]);
        if (w.slot == artworkSlot && !w.shiny) {
          insertColor.execute([w.form, artworkColor(png)]);
        }
        report.stored++;
        report.bytes += png.length;
      }
      db.execute('COMMIT');
      insert.close();
      insertColor.close();
      db.execute('VACUUM');
    } finally {
      db.close();
    }
    return report;
  }
}
