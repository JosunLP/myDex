import 'dart:convert';
import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:test/test.dart';

const _dir = '../../data/fixtures';

void main() {
  late Directory dir;
  late SqliteMediaLibrary media;
  final manifest = CatalogPackManifest.fromJson(
    jsonDecode(File('$_dir/media_test.manifest.json').readAsStringSync())
        as Map<String, Object?>,
  );
  List<int> pack() => File('$_dir/media_test.sqlite.gz').readAsBytesSync();

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('mydex_media');
    final installed = await CatalogInstaller(
      dir,
      format: PackFormat.media,
    ).ensureInstalled(manifest, pack);
    media = SqliteMediaLibrary.open(installed.path);
  });
  tearDown(() {
    media.close();
    dir.deleteSync(recursive: true);
  });

  bool isPng(List<int>? b) =>
      b != null && b.length > 8 && b[1] == 0x50 && b[2] == 0x4E;

  test('installed as its own pack next to the catalog', () {
    expect(
      dir.listSync().map((e) => e.uri.pathSegments.last),
      contains(startsWith('media-')),
    );
  });

  test('a catalog pack is rejected as a media pack', () async {
    final catalog = CatalogPackManifest.fromJson(
      jsonDecode(File('$_dir/catalog_test.manifest.json').readAsStringSync())
          as Map<String, Object?>,
    );
    expect(
      () => CatalogInstaller(dir, format: PackFormat.media).install(
        catalog,
        File('$_dir/catalog_test.sqlite.gz').readAsBytesSync(),
      ),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test('default and shiny sprite', () {
    const pikachu = FormId('pikachu');
    expect(isPng(media.sprite(pikachu)), isTrue);
    expect(isPng(media.sprite(pikachu, shiny: true)), isTrue);
    // Same instance for the UI's image cache.
    expect(identical(media.sprite(pikachu), media.sprite(pikachu)), isTrue);
  });

  test('sprite per game with fallback to the default sprite', () {
    const pikachu = FormId('pikachu');
    expect(media.slotFor(const GameVersionId('red')), 'red-blue');
    expect(media.slotFor(const GameVersionId('white-2')), 'black-white');
    expect(media.slotFor(const GameVersionId('scarlet')), 'scarlet-violet');
    // Colosseum has no sprites of its own.
    expect(media.slotFor(const GameVersionId('colosseum')), isNull);
    final red = media.spriteFor(pikachu, version: const GameVersionId('red'));
    expect(isPng(red), isTrue);
    expect(identical(red, media.sprite(pikachu)), isFalse);
    expect(
      identical(
        media.spriteFor(pikachu, version: const GameVersionId('colosseum')),
        media.sprite(pikachu),
      ),
      isTrue,
    );
    // Gen 1 has no shiny sprites: fall back to the default shiny.
    expect(media.has(pikachu, slot: 'red-blue', shiny: true), isFalse);
    expect(
      identical(
        media.spriteFor(
          pikachu,
          version: const GameVersionId('red'),
          shiny: true,
        ),
        media.sprite(pikachu, shiny: true),
      ),
      isTrue,
    );
  });

  test('Alolan Raichu has no Gen 1 sprites', () {
    expect(media.has(const FormId('raichu-alola'), slot: 'red-blue'), isFalse);
    expect(media.has(const FormId('raichu-alola')), isTrue);
  });

  test('gallery: artwork, default, then games in order', () {
    final keys = media.spritesOf(const FormId('pikachu'));
    expect(keys.first, (
      form: const FormId('pikachu'),
      slot: 'artwork',
      shiny: false,
    ));
    final slots = {for (final k in keys) k.slot}.toList();
    expect(slots.take(4), ['artwork', '', 'red-blue', 'yellow']);
    expect(slots, containsAllInOrder(['black-white', 'x-y', 'scarlet-violet']));
    expect(media.versionsOf('red-blue'), contains(const GameVersionId('blue')));
  });

  test('main colour from the artwork', () {
    final rgb = media.artworkColor(const FormId('pikachu'))!;
    final (r, g, b) = (rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF);
    expect(
      r > 180 && g > 140 && b < 140,
      isTrue,
      reason: 'yellow: #${rgb.toRadixString(16)}',
    );
    expect(media.artworkColor(const FormId('gibt-es-nicht')), isNull);
  });

  test('without a media pack everything stays empty', () {
    const empty = EmptyMediaLibrary();
    expect(empty.artworkColor(const FormId('pikachu')), isNull);
    expect(empty.sprite(const FormId('pikachu')), isNull);
    expect(empty.spritesOf(const FormId('pikachu')), isEmpty);
  });
}
