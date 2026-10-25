import 'dart:io';

import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  final now = DateTime.utc(2026, 10, 25, 12);
  const key = CollectionKey(
    scope: GameScope(GameVersionId('red')),
    form: FormId('bulbasaur'),
  );

  setUp(() => dir = Directory.systemTemp.createTempSync('mydex_user_store'));
  tearDown(() => dir.deleteSync(recursive: true));

  File file() => File('${dir.path}/collection.json');

  test('übersteht Neustart', () async {
    final repo = FileCollectionRepository(file());
    await repo.put(
      CollectionEntry(key: key, updatedAt: now).withCaught(true, now),
    );
    final reloaded = await FileCollectionRepository(file()).loadAll();
    expect(reloaded[key]?.caught, isTrue);
    expect(File('${file().path}.tmp').existsSync(), isFalse);
  });

  test('leere Einträge werden entfernt', () async {
    final repo = FileCollectionRepository(file());
    final caught = CollectionEntry(
      key: key,
      updatedAt: now,
    ).withCaught(true, now);
    await repo.put(caught);
    await repo.put(caught.withSeen(false, now));
    expect(await FileCollectionRepository(file()).loadAll(), isEmpty);
  });

  test('parallele Schreibvorgänge gehen nicht verloren', () async {
    final repo = FileCollectionRepository(file());
    await Future.wait([
      for (var i = 0; i < 20; i++)
        repo.put(
          CollectionEntry(
            key: CollectionKey(scope: const GlobalScope(), form: FormId('f$i')),
            updatedAt: now,
          ).withCaught(true, now),
        ),
    ]);
    expect(await FileCollectionRepository(file()).loadAll(), hasLength(20));
  });

  test('beschädigte Datei wird beiseitegelegt, nicht gelöscht', () async {
    file().writeAsStringSync('{ kaputt');
    final repo = FileCollectionRepository(file());
    expect(await repo.loadAll(), isEmpty);
    expect(repo.quarantinedPath, isNotNull);
    expect(File(repo.quarantinedPath!).readAsStringSync(), '{ kaputt');
  });

  test('Einstellungen: Rundreise und robuste Standardwerte', () async {
    final prefs = JsonPreferencesRepository(File('${dir.path}/prefs.json'));
    expect(await prefs.load(), isEmpty);
    await prefs.save({'theme': 'dark'});
    expect(await prefs.load(), {'theme': 'dark'});
    File('${dir.path}/prefs.json').writeAsStringSync('[1,');
    expect(await prefs.load(), isEmpty);
  });
}
