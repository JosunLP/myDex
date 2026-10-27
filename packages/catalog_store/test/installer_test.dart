import 'dart:convert';
import 'dart:io';

import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mydex_installer'));
  tearDown(() => dir.deleteSync(recursive: true));

  CatalogPackManifest manifest({String? revision, String? sha, int? schema}) =>
      CatalogPackManifest(
        revision: revision ?? fixtureManifest.revision,
        schemaVersion: schema ?? fixtureManifest.schemaVersion,
        sha256: sha ?? fixtureManifest.sha256,
        size: fixtureManifest.size,
      );

  test('installs, verifies and activates a pack', () async {
    final installer = CatalogInstaller(dir);
    final installed = await installer.ensureInstalled(
      fixtureManifest,
      fixturePack,
    );
    expect(File(installed.path).existsSync(), isTrue);
    expect(installed.installError, isNull);
    final active =
        jsonDecode(File('${dir.path}/active.json').readAsStringSync()) as Map;
    expect(active['revision'], fixtureManifest.revision);
    expect(
      dir.listSync().whereType<File>().where((f) => f.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('sequence number is stored, directory is created', () async {
    expect(fixtureManifest.sequence, greaterThan(0));
    final nested = Directory('${dir.path}/neu/katalog');
    final installer = CatalogInstaller(nested);
    final installed = await installer.install(fixtureManifest, fixturePack());
    expect(installed.sequence, fixtureManifest.sequence);
    expect((await installer.current())!.sequence, fixtureManifest.sequence);
    expect(
      CatalogPackManifest.fromJson(fixtureManifest.toJson()).sequence,
      fixtureManifest.sequence,
    );
  });

  test('same revision is not unpacked again', () async {
    final installer = CatalogInstaller(dir);
    await installer.ensureInstalled(fixtureManifest, fixturePack);
    var called = false;
    await installer.ensureInstalled(fixtureManifest, () {
      called = true;
      return fixturePack();
    });
    expect(called, isFalse);
  });

  test('wrong checksum is rejected', () async {
    await expectLater(
      CatalogInstaller(dir).install(manifest(sha: '0' * 64), fixturePack()),
      throwsA(isA<CatalogInstallException>()),
    );
    expect(dir.listSync().whereType<File>(), isEmpty, reason: 'no leftovers');
  });

  test('non-gzip is rejected', () async {
    await expectLater(
      CatalogInstaller(dir).install(fixtureManifest, utf8.encode('kaputt')),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test('unknown schema version is rejected', () async {
    await expectLater(
      CatalogInstaller(dir).install(manifest(schema: 99), fixturePack()),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test('revision must match the content', () async {
    await expectLater(
      CatalogInstaller(
        dir,
      ).install(manifest(revision: 'andere-revision'), fixturePack()),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test('broken update falls back to the previous version', () async {
    final installer = CatalogInstaller(dir);
    final first = await installer.ensureInstalled(fixtureManifest, fixturePack);
    final broken = manifest(revision: 'neuer-stand', sha: 'f' * 64);
    final result = await installer.ensureInstalled(broken, fixturePack);
    expect(result.path, first.path);
    expect(result.revision, fixtureManifest.revision);
    expect(result.installError, isA<CatalogInstallException>());
  });

  test('without a previous version the error is reported', () async {
    await expectLater(
      CatalogInstaller(
        dir,
      ).ensureInstalled(manifest(sha: 'f' * 64), fixturePack),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test(
    'no fallback to a previous version with an incompatible schema',
    () async {
      // Simulate a previous version with an old schema.
      final old = File('${dir.path}/catalog-alt.sqlite');
      final db = sqlite3.open(old.path);
      db.execute(
        'CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
      db.execute(
        "INSERT INTO meta VALUES ('schemaVersion', '1'), ('revision', 'alt')",
      );
      db.close();
      File(
        '${dir.path}/active.json',
      ).writeAsStringSync(jsonEncode({'revision': 'alt', 'path': old.path}));
      await expectLater(
        CatalogInstaller(
          dir,
        ).ensureInstalled(manifest(sha: 'f' * 64), fixturePack),
        throwsA(isA<CatalogInstallException>()),
      );
    },
  );
}
