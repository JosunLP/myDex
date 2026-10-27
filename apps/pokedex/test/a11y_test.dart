import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/app.dart';
import 'package:mydex_app/app/catalog_loader.dart';
import 'package:mydex_app/app/providers.dart';
import 'package:mydex_app/app/speech.dart';
import 'package:mydex_app/widgets/search_field.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

const _fixtureDir = '../../data/fixtures';
late String _catalogPath;
late String _mediaPath;

class _FixtureMedia implements MediaLoader {
  @override
  Future<MediaLibrary> load() async => SqliteMediaLibrary.open(_mediaPath);
}

class _FixtureRepository implements CatalogRepository {
  @override
  Future<LoadedCatalog> load() async => openLoadedCatalog(_catalogPath);
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Brightness brightness,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('de')];
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final dir = Directory.systemTemp.createTempSync('mydex_a11y');
  addTearDown(() => dir.deleteSync(recursive: true));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(_FixtureRepository()),
        mediaLoaderProvider.overrideWithValue(_FixtureMedia()),
        speakerProvider.overrideWithValue(const NoSpeaker()),
        appStorageProvider.overrideWithValue(
          AppStorage.custom(
            collection: MemoryCollectionRepository(),
            preferences: JsonPreferencesRepository(File('${dir.path}/p.json')),
            catalogDirectory: Directory('${dir.path}/catalog'),
          ),
        ),
      ],
      child: const MyDexApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _checkGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

void main() {
  setUpAll(() async {
    final tmp = Directory.systemTemp.createTempSync('mydex_a11y_catalog');
    final manifest = CatalogPackManifest.fromJson(
      jsonDecode(
            File('$_fixtureDir/catalog_test.manifest.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    );
    _catalogPath = (await CatalogInstaller(tmp).install(
      manifest,
      File('$_fixtureDir/catalog_test.sqlite.gz').readAsBytesSync(),
    )).path;
    final mediaManifest = CatalogPackManifest.fromJson(
      jsonDecode(
            File('$_fixtureDir/media_test.manifest.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    );
    _mediaPath =
        (await CatalogInstaller(
              Directory.systemTemp.createTempSync('mydex_app_media'),
              format: PackFormat.media,
            ).install(
              mediaManifest,
              File('$_fixtureDir/media_test.sqlite.gz').readAsBytesSync(),
            ))
            .path;
  });

  for (final brightness in Brightness.values) {
    for (final (name, size) in [
      ('Smartphone', const Size(400, 860)),
      ('Desktop', const Size(1400, 900)),
    ]) {
      testWidgets('Barrierefreiheit: $name, ${brightness.name}', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, size, brightness);
        for (final tab in ['Dex', 'Fundorte', 'Sammlung', 'Teams', 'Mehr']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          await _checkGuidelines(tester);
        }
        // Pokémon-Detail
        await tester.tap(find.text('Dex').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(SearchField), 'pikachu');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Pikachu').first);
        await tester.pumpAndSettle();
        await _checkGuidelines(tester);

        // Unterseiten unter „Mehr“ und ein Team im Editor.
        for (final page in [
          'Hilfe',
          'Synchronisierung',
          'Datenstand und Abdeckung',
        ]) {
          await tester.tap(find.text('Mehr').last);
          await tester.pumpAndSettle();
          await tester.dragUntilVisible(
            find.widgetWithText(ListTile, page),
            find.byType(ListView).last,
            const Offset(0, -200),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(ListTile, page));
          await tester.pumpAndSettle();
          await _checkGuidelines(tester);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Teams').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Neues Team'));
        await tester.pumpAndSettle();
        await _checkGuidelines(tester);
        handle.dispose();
      });
    }
  }
}
