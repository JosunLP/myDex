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

  test('Installation als eigenes Paket neben dem Katalog', () {
    expect(
      dir.listSync().map((e) => e.uri.pathSegments.last),
      contains(startsWith('media-')),
    );
  });

  test('ein Katalogpaket wird als Medienpaket abgelehnt', () async {
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

  test('Standard- und Shiny-Sprite', () {
    const pikachu = FormId('pikachu');
    expect(isPng(media.sprite(pikachu)), isTrue);
    expect(isPng(media.sprite(pikachu, shiny: true)), isTrue);
    // Gleiche Instanz für den Bild-Cache der Oberfläche.
    expect(identical(media.sprite(pikachu), media.sprite(pikachu)), isTrue);
  });

  test('Sprite je Spiel mit Rückfall auf das Standard-Sprite', () {
    const pikachu = FormId('pikachu');
    expect(media.slotFor(const GameVersionId('red')), 'red-blue');
    expect(media.slotFor(const GameVersionId('white-2')), 'black-white');
    expect(media.slotFor(const GameVersionId('scarlet')), isNull);
    final red = media.spriteFor(pikachu, version: const GameVersionId('red'));
    expect(isPng(red), isTrue);
    expect(identical(red, media.sprite(pikachu)), isFalse);
    expect(
      identical(
        media.spriteFor(pikachu, version: const GameVersionId('scarlet')),
        media.sprite(pikachu),
      ),
      isTrue,
    );
    // Gen 1 hat keine Shiny-Sprites: Rückfall auf das Standard-Shiny.
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

  test('Alola-Raichu hat keine Gen-1-Sprites', () {
    expect(media.has(const FormId('raichu-alola'), slot: 'red-blue'), isFalse);
    expect(media.has(const FormId('raichu-alola')), isTrue);
  });

  test('Galerie: Artwork, Standard, dann Spiele in Reihenfolge', () {
    final keys = media.spritesOf(const FormId('pikachu'));
    expect(keys.first, (
      form: const FormId('pikachu'),
      slot: 'artwork',
      shiny: false,
    ));
    final slots = {for (final k in keys) k.slot}.toList();
    expect(slots.take(4), ['artwork', '', 'red-blue', 'yellow']);
    expect(slots.last, 'black-white');
    expect(media.versionsOf('red-blue'), contains(const GameVersionId('blue')));
  });

  test('Hauptfarbe aus dem Artwork', () {
    final rgb = media.artworkColor(const FormId('pikachu'))!;
    final (r, g, b) = (rgb >> 16 & 0xFF, rgb >> 8 & 0xFF, rgb & 0xFF);
    expect(
      r > 180 && g > 140 && b < 140,
      isTrue,
      reason: 'gelb: #${rgb.toRadixString(16)}',
    );
    expect(media.artworkColor(const FormId('gibt-es-nicht')), isNull);
  });

  test('ohne Medienpaket bleibt alles leer', () {
    const empty = EmptyMediaLibrary();
    expect(empty.artworkColor(const FormId('pikachu')), isNull);
    expect(empty.sprite(const FormId('pikachu')), isNull);
    expect(empty.spritesOf(const FormId('pikachu')), isEmpty);
  });
}
