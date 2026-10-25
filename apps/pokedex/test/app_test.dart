import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/app.dart';
import 'package:mydex_app/app/providers.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

final _fixture = File('../../data/fixtures/catalog.json').readAsStringSync();

class _Harness {
  final collection = MemoryCollectionRepository();
  final prefsDir = Directory.systemTemp.createTempSync('mydex_app_test');

  Widget build() => ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(
        JsonCatalogRepository(() => Future.value(_fixture)),
      ),
      appStorageProvider.overrideWithValue(
        AppStorage.custom(
          collection: collection,
          preferences: JsonPreferencesRepository(
            File('${prefsDir.path}/p.json'),
          ),
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
  addTearDown(() => h.prefsDir.deleteSync(recursive: true));
  await tester.pumpWidget(h.build());
  await tester.pumpAndSettle();
  return h;
}

Future<void> _selectGame(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Spiel').first);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(name).last);
  await tester.pumpAndSettle();
}

void main() {
  test('gebündeltes Katalog-Asset entspricht dem Fixture', () {
    expect(File('assets/catalog/catalog.json').readAsStringSync(), _fixture);
  });

  testWidgets('Smartphone: suchen, Detail öffnen, als gefangen markieren', (
    tester,
  ) async {
    final h = await _pump(tester, const Size(400, 860));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Pikachu'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'charizard');
    await tester.pumpAndSettle();
    expect(find.text('Glurak'), findsOneWidget);
    expect(find.text('Pikachu'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'Glurak'));
    await tester.pumpAndSettle();
    expect(
      find.text('Basiswerte'),
      findsNothing,
      reason: 'Glurak ist in Karmesin noch nicht recherchiert',
    );
    expect(find.textContaining('noch nicht recherchiert'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Gefangen'));
    await tester.pumpAndSettle();
    final entries = await h.collection.loadAll();
    const key = CollectionKey(
      scope: GameScope(GameVersionId('violet')),
      form: FormId('charizard'),
    );
    expect(entries[key]?.caught, isTrue);
    expect(entries[key]?.seen, isTrue);
  });

  testWidgets('Spielwechsel ändert Typ und Werte konsistent', (tester) async {
    await _pump(tester, const Size(400, 1400));
    await tester.enterText(find.byType(SearchBar), 'Piepi');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Piepi'));
    await tester.pumpAndSettle();

    await _selectGame(tester, 'Rot');
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Spezial'), findsOneWidget);
    expect(
      find.text('In dieser Generation gibt es keine Fähigkeiten.'),
      findsOneWidget,
    );

    await _selectGame(tester, 'X  ·');
    expect(find.text('Fee'), findsOneWidget);
    expect(find.text('Sp.-Ang.'), findsOneWidget);
    expect(find.text('Magieschild'), findsOneWidget);
  });

  testWidgets('Desktop: Sidebar, Liste und Detail nebeneinander', (
    tester,
  ) async {
    await _pump(tester, const Size(1280, 860));
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(find.text('Offline verfügbar'), findsOneWidget);
    expect(find.text('Wähle ein Pokémon aus der Liste.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Evoli'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Evoli'));
    await tester.pumpAndSettle();
    expect(
      find.text('Evoli'),
      findsNWidgets(2),
      reason: 'Liste und Detail sichtbar',
    );
    expect(find.text('Anpassung'), findsOneWidget);
    expect(find.byType(SearchBar), findsOneWidget);
  });

  testWidgets('Alola-Raichu: Entwicklung nur in Alola', (tester) async {
    await _pump(tester, const Size(1280, 1000));
    await _selectGame(tester, 'Sonne');
    await tester.tap(find.text('Alola-Raichu'));
    await tester.pumpAndSettle();
    expect(
      find.text('(Donnerstein verwenden und in der Region Alola)'),
      findsOneWidget,
    );
    expect(find.text('Psycho'), findsWidgets);
  });
}
