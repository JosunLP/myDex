// Renders screenshots of the real app (bundled catalog and media, real
// fonts) for design reviews and the README:
//
//   cd apps/pokedex
//   flutter test tool/screenshots/screenshots_test.dart \
//     --dart-define=OUT=/tmp/mydex-shots
//
// Not part of `flutter test` (lives outside test/).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/app.dart';
import 'package:mydex_app/app/catalog_loader.dart';
import 'package:mydex_app/app/providers.dart';
import 'package:mydex_app/app/settings.dart';
import 'package:mydex_app/app/speech.dart';
import 'package:mydex_app/widgets/search_field.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

const _out = String.fromEnvironment('OUT', defaultValue: '/tmp/mydex-shots');
late String _catalogPath;
late String _mediaPath;

class _Catalog implements CatalogRepository {
  @override
  Future<LoadedCatalog> load() async => openLoadedCatalog(_catalogPath);
}

class _Media implements MediaLoader {
  @override
  Future<MediaLibrary> load() async => SqliteMediaLibrary.open(_mediaPath);
}

Future<String> _install(String base, PackFormat format) async {
  final manifest = CatalogPackManifest.fromJson(
    jsonDecode(File('$base.manifest.json').readAsStringSync())
        as Map<String, Object?>,
  );
  final dir = Directory.systemTemp.createTempSync('mydex_shots');
  return (await CatalogInstaller(
    dir,
    format: format,
  ).install(manifest, File('$base.sqlite.gz').readAsBytesSync())).path;
}

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  const fonts = 'assets/fonts';
  await family('PlusJakartaSans', [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
      '$fonts/PlusJakartaSans-$w.ttf',
  ]);
  await family('JetBrainsMono', ['$fonts/JetBrainsMono-Bold.ttf']);
  // The Flutter SDK root: FLUTTER_ROOT, or derived from the Dart binary
  // (<sdk>/bin/cache/dart-sdk/bin/dart).
  final sdk =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  await family('MaterialIcons', [
    '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

Future<void> _shot(WidgetTester tester, String name) async {
  // Decode the visible images for real (twice: decoding can build more),
  // then settle the animations.
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        final image = element.widget as Image;
        await precacheImage(image.image, element);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
  }
  await tester.runAsync(() async {
    final boundary =
        tester.binding.rootElement!.renderObject!.debugLayer! as OffsetLayer;
    final view = tester.view;
    final image = await boundary.toImage(Offset.zero & view.physicalSize);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Brightness brightness, {
  AppSettings settings = const AppSettings(),
  MemoryCollectionRepository? collection,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.localesTestValue = const [Locale('de')];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final dir = Directory.systemTemp.createTempSync('mydex_shots_user');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(_Catalog()),
        mediaLoaderProvider.overrideWithValue(_Media()),
        speakerProvider.overrideWithValue(const NoSpeaker()),
        initialSettingsProvider.overrideWithValue(settings),
        appStorageProvider.overrideWithValue(
          AppStorage.custom(
            collection: collection ?? MemoryCollectionRepository(),
            preferences: JsonPreferencesRepository(File('${dir.path}/p.json')),
            catalogDirectory: Directory('${dir.path}/catalog'),
          ),
        ),
      ],
      child: const MyDexApp(),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String query, String name) async {
  await tester.enterText(find.byType(SearchField).first, query);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, name).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    _catalogPath = await _install('assets/catalog/catalog', PackFormat.catalog);
    _mediaPath = await _install('assets/media/media', PackFormat.media);
    await _loadFonts();
  });

  const phone = Size(412, 892);
  const desktop = Size(1440, 900);

  for (final b in Brightness.values) {
    final suffix = b.name;
    testWidgets('phone $suffix', (tester) async {
      final collection = MemoryCollectionRepository();
      final now = DateTime.utc(2026, 11, 1);
      for (final f in ['bulbasaur', 'charmander', 'pikachu', 'eevee']) {
        await collection.put(
          CollectionEntry(
            key: CollectionKey(scope: const GlobalScope(), form: FormId(f)),
            updatedAt: now,
          ).withCaught(true, now),
        );
      }
      await _pump(tester, phone, b, collection: collection);
      await _shot(tester, 'phone-dex-$suffix');
      await _open(tester, 'Glurak', 'Glurak');
      await _shot(tester, 'phone-detail-$suffix');
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -700),
      );
      await _shot(tester, 'phone-detail-sections-$suffix');
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -900),
      );
      await _shot(tester, 'phone-detail-evolution-$suffix');
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -700),
      );
      await _shot(tester, 'phone-detail-moves-$suffix');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Spiel').first);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-picker-$suffix');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sammlung').last);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-collection-$suffix');
      await tester.tap(find.text('Teams').last);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-teams-$suffix');
      await tester.tap(find.text('Mehr').last);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-more-$suffix');
    });

    testWidgets('phone flows $suffix', (tester) async {
      await _pump(tester, phone, b);
      await tester.tap(find.text('Filter').first);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-filter-$suffix');
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fundorte').last);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-locations-$suffix');
      await tester.enterText(find.byType(SearchField).last, 'Vertania-Wald');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Vertania-Wald').first);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-location-$suffix');
      await tester.tap(find.text('Teams').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neues Team').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pokémon hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchField).last, 'Pikachu');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Pikachu').first);
      await tester.pumpAndSettle();
      await _shot(tester, 'phone-team-$suffix');
    });

    testWidgets('phone grid $suffix', (tester) async {
      await _pump(
        tester,
        phone,
        b,
        settings: const AppSettings(dexLayout: DexLayout.grid),
      );
      await _shot(tester, 'phone-grid-$suffix');
    });

    testWidgets('desktop $suffix', (tester) async {
      await _pump(tester, desktop, b);
      await _open(tester, 'Evoli', 'Evoli');
      await _shot(tester, 'desktop-detail-$suffix');
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -1100),
      );
      await _shot(tester, 'desktop-detail-evolution-$suffix');
      await tester.tap(find.text('Fundorte').first);
      await tester.pumpAndSettle();
      await _shot(tester, 'desktop-locations-$suffix');
    });

    testWidgets('game $suffix', (tester) async {
      await _pump(
        tester,
        phone,
        b,
        settings: const AppSettings(gameVersion: 'red'),
      );
      await _shot(tester, 'phone-game-dex-$suffix');
      await _open(tester, 'Pikachu', 'Pikachu');
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -1500),
      );
      await _shot(tester, 'phone-game-acquisition-$suffix');
    });
  }
}
