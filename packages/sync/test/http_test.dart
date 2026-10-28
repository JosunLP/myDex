import 'dart:io';

import 'package:mydex_sync/mydex_sync.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late Uri base;

  setUp(() async {
    final handler = SyncHttpHandler(
      SyncServerCore(MemorySyncStore()),
      (token) => token == 'secret' ? 'konto' : null,
    );
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(handler.call);
    base = Uri.parse('http://127.0.0.1:${server.port}/');
  });
  tearDown(() => server.close(force: true));

  final change = SyncChange(
    kind: 'team',
    id: 't1',
    updatedAt: DateTime.utc(2026),
    data: const {'id': 't1'},
  );

  test('sync via HTTP', () async {
    final transport = HttpSyncTransport(base, 'secret');
    addTearDown(transport.close);
    final r = await transport.sync(SyncRequest(since: 0, changes: [change]));
    expect(r.results.single.status, SyncResultStatus.applied);
    expect(r.cursor, 1);

    await transport.deleteAccountData();
    final after = await transport.sync(const SyncRequest(since: 0));
    expect(after.changes, isEmpty);
  });

  test('wrong access token', () async {
    final transport = HttpSyncTransport(base, 'falsch');
    addTearDown(transport.close);
    expect(
      transport.sync(const SyncRequest(since: 0)),
      throwsA(
        isA<SyncProtocolException>().having(
          (e) => e.code,
          'code',
          'unauthorized',
        ),
      ),
    );
  });

  test('unreachable server results in a network error', () async {
    final port = server.port;
    await server.close(force: true);
    final transport = HttpSyncTransport(
      Uri.parse('http://127.0.0.1:$port'),
      'secret',
      timeout: const Duration(seconds: 5),
    );
    addTearDown(transport.close);
    expect(
      transport.sync(const SyncRequest(since: 0)),
      throwsA(
        isA<SyncProtocolException>().having((e) => e.code, 'code', 'network'),
      ),
    );
  });

  test('plain HTTP only locally', () {
    expect(
      () => HttpSyncTransport.checkServerUrl(Uri.parse('http://example.org')),
      throwsA(
        isA<SyncProtocolException>().having(
          (e) => e.code,
          'code',
          'insecureConnection',
        ),
      ),
    );
    HttpSyncTransport.checkServerUrl(Uri.parse('https://example.org/sync'));
    HttpSyncTransport.checkServerUrl(Uri.parse('http://localhost:8787'));
  });

  test('health check without authentication', () async {
    final client = HttpClient();
    addTearDown(client.close);
    final res = await (await client.getUrl(base.resolve('v1/health'))).close();
    expect(res.statusCode, 200);
  });
}
