import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/app.dart';
import 'package:mydex_app/app/catalog_loader.dart';
import 'package:mydex_app/app/providers.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

const _fixtureDir = '../../data/fixtures';
late String _catalogPath;
late Directory _tmp;

/// Liefert den Testkatalog aus, als wäre er ein App-Asset.
class _FixtureBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = switch (key) {
      'assets/catalog/catalog.manifest.json' =>
        '$_fixtureDir/catalog_test.manifest.json',
      'assets/catalog/catalog.sqlite.gz' =>
        '$_fixtureDir/catalog_test.sqlite.gz',
      _ => throw StateError('Unbekanntes Asset $key'),
    };
    return ByteData.sublistView(File(file).readAsBytesSync());
  }
}

class _FixtureRepository implements CatalogRepository {
  @override
  Future<LoadedCatalog> load() async => openLoadedCatalog(_catalogPath);
}

class _Harness {
  final collection = MemoryCollectionRepository();
  final dir = Directory.systemTemp.createTempSync('mydex_app_test');

  Widget build() => ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(_FixtureRepository()),
      appStorageProvider.overrideWithValue(
        AppStorage.custom(
          collection: collection,
          preferences: JsonPreferencesRepository(File('${dir.path}/p.json')),
          catalogDirectory: Directory('${dir.path}/catalog'),
        ),
      ),
    ],
    child: const MyDexApp(),
  );
}

Future<_Harness> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.localesTestValue = const [Locale('de')];
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final h = _Harness();
  addTearDown(() => h.dir.deleteSync(recursive: true));
  await tester.pumpWidget(h.build());
  await tester.pumpAndSettle();
  return h;
}

Future<void> _selectGame(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Spiel').first);
  await tester.pumpAndSettle();
  // Das Menü ist lang (neueste Spiele oben) und muss ggf. gescrollt werden.
  // Neueste zuerst: bei gleichnamigen Versionen (z. B. japanische Fassungen)
  // ist der erste Treffer die gemeinte.
  final entry = find
      .descendant(
        of: find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
        matching: find.text(name),
      )
      .first;
  await tester.scrollUntilVisible(
    entry,
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(SearchBar), query);
  await tester.pumpAndSettle();
}

Finder _listScrollable() => find
    .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
    .first;

void main() {
  setUpAll(() async {
    _tmp = Directory.systemTemp.createTempSync('mydex_app_catalog');
    final manifest = CatalogPackManifest.fromJson(
      jsonDecode(
            File('$_fixtureDir/catalog_test.manifest.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    );
    _catalogPath = (await CatalogInstaller(_tmp).install(
      manifest,
      File('$_fixtureDir/catalog_test.sqlite.gz').readAsBytesSync(),
    )).path;
  });
  tearDownAll(() => _tmp.deleteSync(recursive: true));

  test(
    'mitgeliefertes Paket wird beim ersten Start installiert und geladen',
    () async {
      final dir = Directory.systemTemp.createTempSync('mydex_bundle');
      addTearDown(() => dir.deleteSync(recursive: true));
      final repo = BundledCatalogRepository(dir, bundle: _FixtureBundle());
      final loaded = await repo.load();
      expect(loaded.snapshot.forms, isNotEmpty);
      expect(repo.installError, isNull);
      loaded.details.close();
      // Zweiter Start: bereits installiert, kein erneutes Entpacken nötig.
      final again = await BundledCatalogRepository(
        dir,
        bundle: _FixtureBundle(),
      ).load();
      expect(again.snapshot.revision, loaded.snapshot.revision);
      again.details.close();
    },
  );

  testWidgets('Smartphone: suchen, Detail öffnen, als gefangen markieren', (
    tester,
  ) async {
    final h = await _pump(tester, const Size(400, 860));
    expect(find.byType(NavigationBar), findsOneWidget);

    await _search(tester, 'charizard');
    expect(find.text('Glurak'), findsOneWidget);
    expect(find.text('Pikachu'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Glurak'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Gefangen'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final version = container.read(gameContextProvider).versionId;
    final entries = await h.collection.loadAll();
    final key = CollectionKey(
      scope: GameScope(version),
      form: const FormId('charizard'),
    );
    expect(entries[key]?.caught, isTrue);
    expect(entries[key]?.seen, isTrue);
  });

  testWidgets('Spielwechsel ändert Typ, Werte und Fähigkeiten konsistent', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 1600));
    await _search(tester, 'Piepi');
    await tester.tap(find.widgetWithText(ListTile, 'Piepi'));
    await tester.pumpAndSettle();

    await _selectGame(tester, 'Rot');
    expect(find.text('Normal'), findsWidgets);
    expect(find.text('Spezial'), findsOneWidget);
    expect(
      find.text('In dieser Generation gibt es keine Fähigkeiten.'),
      findsOneWidget,
    );

    await _selectGame(tester, 'X');
    expect(find.text('Fee'), findsWidgets);
    expect(find.text('Sp.-Ang.'), findsOneWidget);
    expect(find.text('Magieschild'), findsOneWidget);
  });

  testWidgets('Attacken: Erlernbarkeit, Attackenseite und Historie', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 1400));
    await _selectGame(tester, 'Rot');
    await _search(tester, 'Pikachu');
    await tester.tap(find.widgetWithText(ListTile, 'Pikachu'));
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Donnerschock'),
      300,
      scrollable: scrollable,
    );
    expect(find.textContaining('Levelaufstieg'), findsOneWidget);
    await tester.tap(find.text('Donnerschock'));
    await tester.pumpAndSettle();

    expect(find.text('Stärke'), findsOneWidget);
    expect(
      find.text('Speziell'),
      findsOneWidget,
      reason: 'Elektro war bis Gen 3 speziell',
    );
    expect(find.widgetWithText(ActionChip, 'Raichu'), findsOneWidget);
  });

  testWidgets('Suche findet Attacken und zeigt deren Änderungen', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 1400));
    await _search(tester, 'Donnerblitz');
    expect(find.text('Attacken'), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Donnerblitz'));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen zwischen den Spielen'), findsOneWidget);
    expect(find.textContaining('Stärke 95'), findsOneWidget);
    expect(find.textContaining('Stärke 90'), findsOneWidget);
  });

  testWidgets('Desktop: Sidebar, Liste und Detail nebeneinander', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 900));
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(find.text('Offline verfügbar'), findsOneWidget);
    expect(find.text('Wähle ein Pokémon aus der Liste.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Evoli'),
      300,
      scrollable: _listScrollable(),
    );
    await tester.tap(find.text('Evoli'));
    await tester.pumpAndSettle();
    expect(
      find.text('Entwicklung'),
      findsOneWidget,
      reason: 'Detail neben der Liste',
    );
    expect(find.text('Evoli'), findsAtLeastNWidgets(2));
    expect(find.byType(SearchBar), findsOneWidget);
  });

  testWidgets('Datenstand zeigt Quelle und Abdeckung', (tester) async {
    await _pump(tester, const Size(500, 1200));
    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Datenstand und Abdeckung'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PokéAPI'), findsOneWidget);
    expect(find.textContaining('bestätigt'), findsWidgets);
  });
}
