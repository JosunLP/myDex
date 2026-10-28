import 'dart:io';

import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_sync_server/sync_server.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late HttpServer server;
  late AccountRegistry accounts;
  late Uri base;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('mydex_sync_server');
    final db = openSyncDatabase('${dir.path}/sync.sqlite');
    accounts = AccountRegistry(db);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(
      SyncHttpHandler(
        SyncServerCore(SqliteSyncStore(db)),
        accounts.authenticate,
      ).call,
    );
    base = Uri.parse('http://127.0.0.1:${server.port}');
    addTearDown(() async {
      await server.close(force: true);
      db.close();
      dir.deleteSync(recursive: true);
    });
  });

  SyncChange change(String id, {int? base}) => SyncChange(
    kind: 'team',
    id: id,
    baseRevision: base,
    updatedAt: DateTime.utc(2026),
    data: {'id': id},
  );

  test('accounts, revisions and conflicts with SQLite', () async {
    final alice = HttpSyncTransport(base, accounts.create('alice'));
    final bob = HttpSyncTransport(base, accounts.create('bob'));
    addTearDown(alice.close);
    addTearDown(bob.close);

    final first = await alice.sync(
      SyncRequest(since: 0, changes: [change('t1'), change('t2')]),
    );
    expect(first.cursor, 2);
    final conflict = await alice.sync(
      SyncRequest(since: 2, changes: [change('t1')]),
    );
    expect(conflict.results.single.status, SyncResultStatus.conflict);
    final update = await alice.sync(
      SyncRequest(since: 2, changes: [change('t1', base: 1)]),
    );
    expect(update.results.single.revision, 3);

    expect((await bob.sync(const SyncRequest(since: 0))).changes, isEmpty);
    expect(accounts.list().map((a) => (a.name, a.records)), [
      ('alice', 2),
      ('bob', 0),
    ]);

    await alice.deleteAccountData();
    final after = await alice.sync(
      SyncRequest(since: 0, changes: [change('t3')]),
    );
    // Revisions do not go backwards after deletion.
    expect(after.results.single.revision, 4);
  });

  test('rotating the token invalidates the old one', () async {
    final old = accounts.create('carol');
    final fresh = accounts.rotate('carol');
    expect(accounts.authenticate(old), isNull);
    expect(accounts.authenticate(fresh), isNotNull);
    expect(accounts.authenticate(''), isNull);
  });

  test('deleting an account removes its data', () async {
    final token = accounts.create('dave');
    final t = HttpSyncTransport(base, token);
    addTearDown(t.close);
    await t.sync(SyncRequest(since: 0, changes: [change('t1')]));
    expect(accounts.delete('dave'), isTrue);
    expect(accounts.authenticate(token), isNull);
    expect(accounts.list(), isEmpty);
  });
}
