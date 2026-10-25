import 'dart:convert';
import 'dart:io';

import 'package:mydex_catalog_store/mydex_catalog_store.dart';
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

  test('installiert, prüft und aktiviert ein Paket', () async {
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

  test('gleiche Revision wird nicht erneut entpackt', () async {
    final installer = CatalogInstaller(dir);
    await installer.ensureInstalled(fixtureManifest, fixturePack);
    var called = false;
    await installer.ensureInstalled(fixtureManifest, () {
      called = true;
      return fixturePack();
    });
    expect(called, isFalse);
  });

  test('falsche Prüfsumme wird abgelehnt', () async {
    await expectLater(
      CatalogInstaller(dir).install(manifest(sha: '0' * 64), fixturePack()),
      throwsA(isA<CatalogInstallException>()),
    );
    expect(dir.listSync().whereType<File>(), isEmpty, reason: 'keine Reste');
  });

  test('kein gzip wird abgelehnt', () async {
    await expectLater(
      CatalogInstaller(dir).install(fixtureManifest, utf8.encode('kaputt')),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test('unbekannte Schemaversion wird abgelehnt', () async {
    await expectLater(
      CatalogInstaller(dir).install(manifest(schema: 99), fixturePack()),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test('Revision muss zum Inhalt passen', () async {
    await expectLater(
      CatalogInstaller(
        dir,
      ).install(manifest(revision: 'andere-revision'), fixturePack()),
      throwsA(isA<CatalogInstallException>()),
    );
  });

  test('defektes Update fällt auf die vorherige Version zurück', () async {
    final installer = CatalogInstaller(dir);
    final first = await installer.ensureInstalled(fixtureManifest, fixturePack);
    final broken = manifest(revision: 'neuer-stand', sha: 'f' * 64);
    final result = await installer.ensureInstalled(broken, fixturePack);
    expect(result.path, first.path);
    expect(result.revision, fixtureManifest.revision);
    expect(result.installError, isA<CatalogInstallException>());
  });

  test('ohne vorherige Version wird der Fehler gemeldet', () async {
    await expectLater(
      CatalogInstaller(
        dir,
      ).ensureInstalled(manifest(sha: 'f' * 64), fixturePack),
      throwsA(isA<CatalogInstallException>()),
    );
  });
}
