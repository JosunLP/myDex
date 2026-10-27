import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/app.dart';
import 'package:mydex_app/app/backup_files.dart';
import 'package:mydex_app/app/catalog_loader.dart';
import 'package:mydex_app/app/catalog_update.dart';
import 'package:mydex_app/app/providers.dart';
import 'package:mydex_app/app/speech.dart';
import 'package:mydex_app/app/sync_config.dart';
import 'package:mydex_app/app/sync_controller.dart';
import 'package:mydex_app/widgets/dex_decor.dart';
import 'package:mydex_app/widgets/form_artwork.dart';
import 'package:mydex_app/widgets/search_field.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

const _fixtureDir = '../../data/fixtures';
late String _catalogPath;
late String _mediaPath;
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

class _FixtureMedia implements MediaLoader {
  @override
  Future<MediaLibrary> load() async => SqliteMediaLibrary.open(_mediaPath);
}

class _FixtureRepository implements CatalogRepository {
  @override
  Future<LoadedCatalog> load() async => openLoadedCatalog(_catalogPath);
}

/// Update-Quelle im Speicher.
class _FakeUpdateSource implements CatalogUpdateSource {
  _FakeUpdateSource(this.update, this.pack);
  final Map<String, Object?>? update;
  final List<int> pack;

  @override
  Future<Map<String, Object?>?> catalogUpdate() async => update;

  @override
  Future<List<int>> catalogPack() async => pack;
}

class _Harness {
  final collection = MemoryCollectionRepository();
  final teams = MemoryTeamRepository();
  final presets = MemoryFilterPresetRepository();
  final files = _MemoryFiles();
  final speaker = _FakeSpeaker();
  final syncCore = SyncServerCore(MemorySyncStore());
  final syncConfig = MemorySyncConfigStore();
  final updateKeys = <String>[];
  CatalogUpdateSource updateSource = _FakeUpdateSource(null, const []);
  final dir = Directory.systemTemp.createTempSync('mydex_app_test');

  Widget build() => ProviderScope(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(_FixtureRepository()),
      mediaLoaderProvider.overrideWithValue(_FixtureMedia()),
      backupFilesProvider.overrideWithValue(files),
      speakerProvider.overrideWithValue(speaker),
      syncTransportFactoryProvider.overrideWithValue(
        (url, token) => _CoreTransport(syncCore, token),
      ),
      syncKdfIterationsProvider.overrideWithValue(1000),
      catalogUpdateKeysProvider.overrideWith((ref) => updateKeys),
      catalogUpdateSourceFactoryProvider.overrideWithValue(
        (url, token) => updateSource,
      ),
      syncKeyDerivationProvider.overrideWithValue(SyncKey.derive),
      appStorageProvider.overrideWithValue(
        AppStorage.custom(
          collection: collection,
          preferences: JsonPreferencesRepository(File('${dir.path}/p.json')),
          catalogDirectory: Directory('${dir.path}/catalog'),
          teams: teams,
          presets: presets,
          syncConfig: syncConfig,
        ),
      ),
    ],
    child: const MyDexApp(),
  );
}

/// Sync-Server im Speicher; nur der Schlüssel „geheim“ ist gültig.
class _CoreTransport implements SyncTransport {
  _CoreTransport(this.core, this.token);
  final SyncServerCore core;
  final String token;

  void _check() {
    if (token != 'geheim') throw const SyncProtocolException('unauthorized');
  }

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    _check();
    return SyncResponse.fromJson(
      core.handle('konto', SyncRequest.fromJson(request.toJson())).toJson(),
    );
  }

  @override
  Future<void> deleteAccountData() async {
    _check();
    core.wipe('konto');
  }
}

/// Merkt sich Vorlesetexte; die Ausgabe läuft, bis [finish] oder `stop`.
class _FakeSpeaker implements Speaker {
  final spoken = <(String, String)>[];
  Completer<void>? _running;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> speak(String text, {required String language}) {
    spoken.add((text, language));
    return (_running = Completer<void>()).future;
  }

  void finish() => _running?.complete();

  @override
  Future<void> stop() async {
    final running = _running;
    _running = null;
    if (running != null && !running.isCompleted) running.complete();
  }
}

class _MemoryFiles implements BackupFiles {
  Uint8List? stored;

  @override
  Future<bool> save(Uint8List bytes, String fileName) async {
    stored = bytes;
    return true;
  }

  @override
  Future<Uint8List?> open() async => stored;
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
  await tester.enterText(find.byType(SearchField), query);
  await tester.pumpAndSettle();
}

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
    await tester.ensureVisible(find.text('Donnerschock'));
    await tester.pumpAndSettle();
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

    await _search(tester, 'Evoli');
    await tester.tap(find.widgetWithText(ListTile, 'Evoli'));
    await tester.pumpAndSettle();
    // Pokédex-Anzeige mit Artwork und Nummer im Detail neben der Liste.
    expect(find.byType(DexScreen), findsOneWidget);
    expect(find.text('#0133'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Entwicklung'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      find.text('Entwicklung'),
      findsOneWidget,
      reason: 'Detail neben der Liste',
    );
    expect(find.text('Evoli'), findsAtLeastNWidgets(2));
    expect(find.byType(SearchField), findsOneWidget);
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

  testWidgets('Fundorte auf der Pokémon-Seite und als eigener Bereich', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 1600));
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
      find.text('Vertania-Wald'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Fundorte und Beschaffung'), findsOneWidget);
    await tester.tap(find.text('Vertania-Wald'));
    await tester.pumpAndSettle();
    expect(find.text('Kanto'), findsOneWidget);
    expect(find.text('Pikachu'), findsWidgets);

    // Eigener Navigationsbereich mit allen Orten der Version.
    await tester.tap(find.text('Fundorte').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchField).last, 'vertania');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Vertania-Wald'), findsOneWidget);
  });

  testWidgets('Ohne Fundortdaten erscheint ein Hinweis statt „nicht fangbar“', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 1200));
    await _selectGame(tester, 'Karmesin');
    await tester.tap(find.text('Fundorte').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Für Karmesin liegen noch keine Fundortdaten vor.'),
      findsOneWidget,
    );
  });

  testWidgets('Team anlegen, Pokémon hinzufügen, prüfen und analysieren', (
    tester,
  ) async {
    final h = await _pump(tester, const Size(500, 1600));
    await _selectGame(tester, 'Rot');
    await tester.tap(find.text('Teams').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Noch keine Teams. Lege eins für das gewählte Spiel an.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Neues Team'));
    await tester.pumpAndSettle();
    expect(find.text('Spiel: Rot'), findsOneWidget);
    expect(find.text('0 von 6 Pokémon'), findsOneWidget);

    await tester.tap(find.text('Pokémon hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchField).last, 'Pikachu');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Pikachu').first);
    await tester.pumpAndSettle();

    expect(find.text('1 von 6 Pokémon'), findsOneWidget);
    expect(find.text('Gültig'), findsOneWidget);
    expect(find.text('Typanalyse'), findsOneWidget);
    expect(find.textContaining('schwach'), findsWidgets);

    final saved = (await h.teams.loadAll()).single;
    expect(saved.version, const GameVersionId('red'));
    final member = saved.members.single;
    expect(member.form, const FormId('pikachu'));
    expect(member.ability, isNull, reason: 'Gen 1 hat keine Fähigkeiten');
    expect(
      member.moves,
      isNotEmpty,
      reason: 'Level-Attacken bis Lv. 50 vorbelegt',
    );
    expect(member.moves.length, lessThanOrEqualTo(4));

    // Mitglied öffnen: Gen 1 zeigt DVs und kein Wesen/Item/Fähigkeit.
    await tester.tap(find.textContaining('Lv. 50').first);
    await tester.pumpAndSettle();
    expect(find.text('DVs'), findsOneWidget);
    expect(find.text('Wesen'), findsNothing);
    expect(find.text('Getragenes Item'), findsNothing);
    expect(find.text('Berechnete Werte'), findsOneWidget);
  });

  testWidgets('Moderne Spiele: Fähigkeit, Wesen und Item im Editor', (
    tester,
  ) async {
    final h = await _pump(tester, const Size(500, 2000));
    await _selectGame(tester, 'X');
    await tester.tap(find.text('Teams').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neues Team'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokémon hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(SearchField).last, 'Glurak');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Glurak').first);
    await tester.pumpAndSettle();

    final member = (await h.teams.loadAll()).single.members.single;
    expect(
      member.ability,
      const AbilityId('blaze'),
      reason: 'erste reguläre Fähigkeit',
    );

    await tester.tap(find.textContaining('Lv. 50').first);
    await tester.pumpAndSettle();
    expect(find.text('Wesen'), findsOneWidget);
    expect(find.text('Getragenes Item'), findsOneWidget);
    expect(find.text('EVs'), findsOneWidget);
    expect(find.text('Summe 0 / 510'), findsOneWidget);
  });

  testWidgets('Filter kombinieren und als Vorlage speichern', (tester) async {
    final h = await _pump(tester, const Size(500, 1400));
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Feuer'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Anwenden'));
    await tester.tap(find.text('Anwenden'));
    await tester.pumpAndSettle();

    expect(find.text('Filter (1)'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Glumanda'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Pikachu'), findsNothing);

    // Als Vorlage speichern.
    await tester.tap(find.text('Filter (1)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Als Vorlage speichern'));
    await tester.tap(find.text('Als Vorlage speichern'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Feuer');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect((await h.presets.loadAll()).single.filter.types, {PokemonType.fire});

    // Vorlage abwählen setzt den Filter zurück.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Feuer'));
    await tester.pumpAndSettle();
    expect(find.text('Filter'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Bisasam'), findsOneWidget);
  });

  testWidgets('Globale Checkliste fasst alle Spiele zusammen', (tester) async {
    final h = await _pump(tester, const Size(500, 1400));
    final at = DateTime.utc(2026, 1, 15);
    await h.collection.put(
      CollectionEntry(
        key: const CollectionKey(
          scope: GameScope(GameVersionId('red')),
          form: FormId('bulbasaur'),
        ),
        updatedAt: at,
      ).withCaught(true, at),
    );
    // Direkt in den Speicher geschrieben: Anzeige neu laden.
    ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).invalidate(collectionProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sammlung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alle Spiele zusammen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gefangen in: Rot'), findsOneWidget);
    expect(find.textContaining('15.1.2026'), findsOneWidget);
  });

  testWidgets('Export und Import (Zusammenführen) über eine Datei', (
    tester,
  ) async {
    final h = await _pump(tester, const Size(500, 1600));
    final at = DateTime.utc(2026, 2, 1);
    await h.collection.put(
      CollectionEntry(
        key: const CollectionKey(
          scope: GameScope(GameVersionId('red')),
          form: FormId('pikachu'),
        ),
        updatedAt: at,
      ).withCaught(true, at),
    );
    await h.teams.save(
      Team(
        id: 't1',
        name: 'Sicherung',
        version: const GameVersionId('red'),
        updatedAt: at,
      ),
    );

    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportieren'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Exportieren'));
      // Hintergrundarbeit (Isolate) läuft in Echtzeit; Frames weiterschalten.
      for (
        var i = 0;
        i < 100 && find.byType(SnackBar).evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(h.files.stored, isNotNull);
    expect(find.text('Sicherung gespeichert.'), findsOneWidget);

    // Daten verlieren, dann wiederherstellen.
    await h.collection.replaceAll(const []);
    await h.teams.replaceAll(const []);
    await tester.runAsync(() async {
      await tester.tap(find.text('Importieren'));
      for (
        var i = 0;
        i < 50 && find.text('Zusammenführen').evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Teams: 1 neu'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Importieren'));
      for (
        var i = 0;
        i < 50 && find.text('Sicherung importiert.').evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Sicherung importiert.'), findsOneWidget);

    expect((await h.teams.loadAll()).single.name, 'Sicherung');
    expect(
      (await h.collection.loadAll()).values.single.key.form,
      const FormId('pikachu'),
    );
  });

  testWidgets('Vorlesen: Zusammenfassung aus Katalogfakten, Stopp', (
    tester,
  ) async {
    final h = await _pump(tester, const Size(400, 860));
    await _search(tester, 'pikachu');
    await tester.tap(find.widgetWithText(ListTile, 'Pikachu'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Vorlesen'));
    await tester.pump();
    final (text, language) = h.speaker.spoken.single;
    expect(language, 'de');
    expect(text, startsWith('Pikachu, Nummer 25.'));
    expect(text, contains('Typ Elektro.'));
    expect(text, contains('Entwickelt sich aus Pichu'));
    expect(find.byTooltip('Vorlesen beenden'), findsOneWidget);

    await tester.tap(find.byTooltip('Vorlesen beenden'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Vorlesen'), findsOneWidget);

    // Endet die Ausgabe von selbst, wird der Knopf wieder zu „Vorlesen“.
    await tester.tap(find.byTooltip('Vorlesen'));
    await tester.pump();
    h.speaker.finish();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Vorlesen'), findsOneWidget);
    expect(h.speaker.spoken, hasLength(2));
  });

  testWidgets('App-Sprache umstellen und Hilfe öffnen', (tester) async {
    await _pump(tester, const Size(500, 1600));
    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hilfe').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Datenlücken und Verfügbarkeit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('noch nicht recherchiert'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wie System'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();
    expect(find.text('Équipes'), findsWidgets);
    expect(find.text('Langue de l’app'), findsOneWidget);

    // Die Datensprache folgt der App-Sprache.
    await tester.tap(find.text('Dex'));
    await tester.pumpAndSettle();
    await _search(tester, 'glurak');
    expect(find.text('Dracaufeu'), findsOneWidget);
  });

  testWidgets('Synchronisierung: verbinden, empfangen, trennen', (
    tester,
  ) async {
    final h = await _pump(tester, const Size(500, 1600));
    // Ein anderes Gerät hat bereits ein Team verschlüsselt hochgeladen.
    final other = Team(
      id: 'fremd',
      name: 'Vom Tablet',
      version: const GameVersionId('red'),
      updatedAt: DateTime.utc(2026, 3, 1),
    );
    final tablet = _CoreTransport(h.syncCore, 'geheim');
    final key = await EncryptingTransport.unlock(
      tablet,
      'tablet-passwort',
      iterations: 1000,
    );
    await EncryptingTransport(tablet, key, MemorySyncAliasStore()).sync(
      SyncRequest(
        since: 0,
        changes: [
          SyncChange(
            kind: SyncKinds.team,
            id: other.id,
            updatedAt: other.updatedAt,
            data: other.toJson(),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synchronisierung').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ende-zu-Ende'), findsWidgets);

    // Unverschlüsselt ins Netz ist nicht erlaubt.
    await tester.enterText(
      find.widgetWithText(TextField, 'Serveradresse'),
      'http://sync.example.org',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Zugangsschlüssel'),
      'falsch',
    );
    await tester.tap(find.text('Verbinden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nur HTTPS'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Serveradresse'),
      'https://sync.example.org',
    );
    // Zu kurzes Sync-Passwort.
    await tester.enterText(
      find.widgetWithText(TextField, 'Sync-Passwort'),
      'kurz',
    );
    await tester.tap(find.text('Verbinden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mindestens 8 Zeichen'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Sync-Passwort'),
      'tablet-passwort',
    );
    await tester.tap(find.text('Verbinden'));
    await tester.pumpAndSettle();
    expect(find.text('Der Zugangsschlüssel ist ungültig.'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Zugangsschlüssel'),
      'geheim',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Sync-Passwort'),
      'falsches-passwort',
    );
    await tester.tap(find.text('Verbinden'));
    await tester.pumpAndSettle();
    expect(find.textContaining('passt nicht'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Sync-Passwort'),
      'tablet-passwort',
    );
    await tester.tap(find.text('Verbinden'));
    await tester.pumpAndSettle();
    expect(find.text('https://sync.example.org'), findsOneWidget);
    expect(find.textContaining('1 empfangen'), findsOneWidget);
    expect((await h.teams.loadAll()).single.name, 'Vom Tablet');

    await tester.tap(find.text('Teams'));
    await tester.pumpAndSettle();
    expect(find.text('Vom Tablet'), findsOneWidget);

    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trennen'));
    await tester.pumpAndSettle();
    expect(find.text('Verbinden'), findsOneWidget);
    // Lokale Daten bleiben nach dem Trennen.
    expect(await h.teams.loadAll(), hasLength(1));
  });

  testWidgets('Galerie: Sprites je Spiel, Kopfbild folgt dem Spiel', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 2400));
    await _search(tester, 'pikachu');
    // Vorschaubilder in der Liste.
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Pikachu'),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Pikachu'));
    await tester.pumpAndSettle();

    // Kleines Spiel-Sprite in der Pokédex-Anzeige.
    Uint8List headerBytes() =>
        (tester
                    .widget<Image>(
                      find.descendant(
                        of: find.byKey(const ValueKey('dexScreenSprite')),
                        matching: find.byType(Image),
                      ),
                    )
                    .image
                as MemoryImage)
            .bytes;
    // Offizielles Artwork als großes Bild.
    expect(
      find.descendant(
        of: find.byType(DexScreen),
        matching: find.byType(FormArtwork),
      ),
      findsOneWidget,
    );
    final modern = headerBytes();

    await tester.scrollUntilVisible(
      find.text('Galerie'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Offizielles Artwork'), findsOneWidget);
    expect(find.text('Rot / Blau'), findsOneWidget);
    expect(find.text('Schwarz / Weiß / Schwarz 2 / Weiß 2'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Pikachu – Rot / Blau'), findsOneWidget);
    expect(find.bySemanticsLabel('Pikachu (Shiny) – Gold'), findsOneWidget);
    semantics.dispose();

    await _selectGame(tester, 'Rot');
    await tester.scrollUntilVisible(
      find.text('#0025'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(identical(headerBytes(), modern), isFalse);
  });

  testWidgets('Beschaffung: Tausch aus anderem Spiel und Event-Pokémon', (
    tester,
  ) async {
    await _pump(tester, const Size(500, 2400));
    await _selectGame(tester, 'Rot');

    await _search(tester, 'sandan');
    await tester.tap(find.widgetWithText(ListTile, 'Sandan'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Durch Tausch aus'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Durch Tausch aus Blau'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await _search(tester, 'mew');
    await tester.tap(find.widgetWithText(ListTile, 'Mew'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Event-Verteilungen'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Mysteriöses Pokémon'), findsOneWidget);
  });

  testWidgets(
    'Katalog-Update: fremde Signatur abgelehnt, gültige installiert',
    (tester) async {
      final h = await _pump(tester, const Size(500, 1600));
      final manifest =
          jsonDecode(
                File(
                  '$_fixtureDir/catalog_test.manifest.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final newer = {
        ...manifest,
        'sequence': (manifest['sequence']! as int) + 1,
      };
      final pack = File(
        '$_fixtureDir/catalog_test.sqlite.gz',
      ).readAsBytesSync();
      final (update, trusted, foreign) = (await tester.runAsync(() async {
        final key = CatalogSigningKey.generate();
        return (
          await signCatalogUpdate(newer, key),
          await key.publicKeyBase64(),
          await CatalogSigningKey.generate().publicKeyBase64(),
        );
      }))!;
      h.updateSource = _FakeUpdateSource(update, pack);
      await tester.runAsync(
        () => h.syncConfig.save(
          SyncConfig(
            serverUrl: 'https://sync.example.org',
            token: 'geheim',
            key: SyncKey(
              encryption: List.filled(32, 1),
              authentication: List.filled(32, 2),
              salt: List.filled(16, 3),
              iterations: 1000,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datenstand und Abdeckung'));
      await tester.pumpAndSettle();
      expect(find.text('Katalog-Updates'), findsOneWidget);

      // Läuft außerhalb der künstlichen Zeit, weil der Katalog über echte
      // Dateizugriffe und ein Isolate installiert wird.
      Future<void> check() async {
        await tester.runAsync(() async {
          await tester.tap(find.text('Prüfen'));
          for (var i = 0; i < 500; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump();
            // Nach einer Installation lädt der Katalog neu (Ladeanzeige).
            if (find.text('Prüfen').evaluate().isNotEmpty &&
                find.byType(CircularProgressIndicator).evaluate().isEmpty) {
              break;
            }
          }
        });
        await tester.pumpAndSettle();
      }

      // Ohne hinterlegten Schlüssel gibt es keine Updates.
      await check();
      expect(find.textContaining('nicht eingerichtet'), findsOneWidget);

      h.updateKeys.add(foreign);
      await check();
      expect(find.textContaining('abgelehnt'), findsOneWidget);

      h.updateKeys.add(trusted);
      await check();
      expect(
        find.text('Katalog auf ${manifest['revision']} aktualisiert.'),
        findsOneWidget,
      );

      // Dasselbe Update ein zweites Mal: nichts Neues.
      await check();
      expect(find.textContaining('ist aktuell'), findsOneWidget);
    },
  );
}
