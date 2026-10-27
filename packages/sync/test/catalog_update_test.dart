import 'dart:convert';
import 'dart:io';

import 'package:mydex_sync/mydex_sync.dart';
import 'package:test/test.dart';

void main() {
  final manifest = <String, Object?>{
    'revision': 'pokeapi-test-s5',
    'schemaVersion': 5,
    'sha256': 'ab' * 32,
    'size': 1234,
    'sequence': 179250036405,
  };

  test('kanonisches JSON ist unabhängig von der Schlüsselreihenfolge', () {
    expect(
      canonicalJson({
        'b': 1,
        'a': {
          'd': 2,
          'c': [3],
        },
      }),
      '{"a":{"c":[3],"d":2},"b":1}',
    );
  });

  test(
    'signiertes Update wird mit dem öffentlichen Schlüssel erkannt',
    () async {
      final key = CatalogSigningKey.generate();
      final update = await signCatalogUpdate(manifest, key);
      // Über JSON übertragen, Schlüsselreihenfolge darf sich ändern.
      final wire = jsonDecode(jsonEncode(update)) as Map<String, Object?>;
      final verified = await verifyCatalogUpdate(wire, [
        await key.publicKeyBase64(),
      ]);
      expect(verified['revision'], 'pokeapi-test-s5');
      expect(update['keyId'], await catalogKeyId(await key.publicKeyBase64()));
    },
  );

  test('veränderte Manifeste und fremde Schlüssel werden abgelehnt', () async {
    final key = CatalogSigningKey.generate();
    final other = CatalogSigningKey.generate();
    final update = await signCatalogUpdate(manifest, key);
    final tampered = {
      ...update,
      'manifest': {...manifest, 'sha256': 'cd' * 32},
    };
    Matcher code(String c) =>
        throwsA(isA<CatalogUpdateException>().having((e) => e.code, 'code', c));
    expect(
      verifyCatalogUpdate(tampered, [await key.publicKeyBase64()]),
      code('badSignature'),
    );
    expect(
      verifyCatalogUpdate(update, [await other.publicKeyBase64()]),
      code('badSignature'),
    );
    expect(verifyCatalogUpdate(update, const []), code('untrustedKey'));
    expect(
      verifyCatalogUpdate({'format': 'x'}, [await key.publicKeyBase64()]),
      code('invalid'),
    );
  });

  test('Server bietet Update und Paket nur angemeldet an', () async {
    final dir = Directory.systemTemp.createTempSync('mydex_catalog_update');
    addTearDown(() => dir.deleteSync(recursive: true));
    final handler = SyncHttpHandler(
      SyncServerCore(MemorySyncStore()),
      (t) => t == 'geheim' ? 'konto' : null,
      catalogDirectory: dir,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen(handler.call);
    final base = Uri.parse('http://127.0.0.1:${server.port}');

    final transport = HttpSyncTransport(base, 'geheim');
    addTearDown(transport.close);
    expect(await transport.catalogUpdate(), isNull);

    final key = CatalogSigningKey.generate();
    File(
      '${dir.path}/update.json',
    ).writeAsStringSync(jsonEncode(await signCatalogUpdate(manifest, key)));
    File('${dir.path}/catalog.sqlite.gz').writeAsBytesSync([1, 2, 3, 4]);
    final update = await transport.catalogUpdate();
    expect(
      (await verifyCatalogUpdate(update!, [
        await key.publicKeyBase64(),
      ]))['size'],
      1234,
    );
    expect(await transport.catalogPack(), [1, 2, 3, 4]);

    final stranger = HttpSyncTransport(base, 'falsch');
    addTearDown(stranger.close);
    expect(stranger.catalogPack(), throwsA(isA<SyncProtocolException>()));
  });
}
