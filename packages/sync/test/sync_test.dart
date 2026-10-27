import 'dart:io';

import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_user_store/mydex_user_store.dart';
import 'package:test/test.dart';

/// Calls the server core directly, as the HTTP layer would.
class DirectTransport implements SyncTransport {
  DirectTransport(this.core, this.account);
  final SyncServerCore core;
  final String account;
  int requests = 0;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    requests++;
    // Via JSON so that serialization is tested as well.
    final wire = SyncRequest.fromJson(request.toJson());
    return SyncResponse.fromJson(core.handle(account, wire).toJson());
  }

  @override
  Future<void> deleteAccountData() async => core.wipe(account);
}

/// A device with its own storage and sync.
class Device {
  Device(SyncServerCore core, {String account = 'a', String suffix = 'x'})
    : transport = DirectTransport(core, account) {
    var n = 0;
    client = SyncClient(
      stateStore: MemorySyncStateStore(),
      adapters: [
        CollectionSyncAdapter(rawCollection),
        DocumentSyncAdapter.teams(
          rawTeams,
          conflictName: (name) => '$name (conflict)',
          newId: () => 'copy-$suffix-${n++}',
        ),
        DocumentSyncAdapter.filterPresets(
          rawPresets,
          conflictName: (name) => '$name (conflict)',
        ),
      ],
    );
    collection = SyncingCollectionRepository(rawCollection, client);
    teams = SyncingTeamRepository(rawTeams, client);
    presets = SyncingFilterPresetRepository(rawPresets, client);
  }

  final rawCollection = MemoryCollectionRepository();
  final rawTeams = MemoryTeamRepository();
  final rawPresets = MemoryFilterPresetRepository();
  final DirectTransport transport;
  late final SyncClient client;
  late final SyncingCollectionRepository collection;
  late final SyncingTeamRepository teams;
  late final SyncingFilterPresetRepository presets;

  Future<SyncReport> sync() => client.sync(transport);
}

final t0 = DateTime.utc(2026, 3, 1);
CollectionKey key(String form) => CollectionKey(
  scope: const GameScope(GameVersionId('red')),
  form: FormId(form),
);

Team team(String id, String name, DateTime at) => Team(
  id: id,
  name: name,
  version: const GameVersionId('red'),
  updatedAt: at,
);

void main() {
  group('Server core', () {
    late SyncServerCore core;
    setUp(() => core = SyncServerCore(MemorySyncStore()));

    SyncChange change(String id, {int? base, bool deleted = false}) =>
        SyncChange(
          kind: 'team',
          id: id,
          baseRevision: base,
          updatedAt: t0,
          deleted: deleted,
          data: deleted ? null : {'id': id},
        );

    test('accepts new records and assigns increasing revisions', () {
      final r = core.handle(
        'a',
        SyncRequest(since: 0, changes: [change('1'), change('2')]),
      );
      expect(r.results.map((x) => (x.status, x.revision)), [
        (SyncResultStatus.applied, 1),
        (SyncResultStatus.applied, 2),
      ]);
      expect(r.cursor, 2);
      expect(r.changes.map((c) => c.id), ['1', '2']);
    });

    test(
      'outdated base revision results in a conflict with the server state',
      () {
        core.handle('a', SyncRequest(since: 0, changes: [change('1')]));
        core.handle(
          'a',
          SyncRequest(since: 1, changes: [change('1', base: 1)]),
        );
        final r = core.handle(
          'a',
          SyncRequest(since: 2, changes: [change('1', base: 1)]),
        );
        expect(r.results.single.status, SyncResultStatus.conflict);
        expect(r.results.single.current!.revision, 2);
      },
    );

    test('deletions stay visible as tombstones', () {
      core.handle('a', SyncRequest(since: 0, changes: [change('1')]));
      core.handle(
        'a',
        SyncRequest(since: 1, changes: [change('1', base: 1, deleted: true)]),
      );
      final r = core.handle('a', const SyncRequest(since: 0));
      expect(r.changes.single.deleted, isTrue);
      expect(r.changes.single.data, isNull);
    });

    test('accounts are separated from each other', () {
      core.handle('a', SyncRequest(since: 0, changes: [change('1')]));
      expect(core.handle('b', const SyncRequest(since: 0)).changes, isEmpty);
    });

    test('paged fetching', () {
      for (var i = 0; i < 3; i++) {
        core.handle(
          'a',
          SyncRequest(
            since: 0,
            changes: [
              for (var j = 0; j < SyncLimits.changesPerRequest; j++)
                change('$i-$j'),
            ],
          ),
        );
      }
      final first = core.handle('a', const SyncRequest(since: 0));
      expect(first.more, isTrue);
      expect(first.changes, hasLength(SyncLimits.changesPerRequest));
      expect(first.cursor, SyncLimits.changesPerRequest);
    });

    test('invalid requests are rejected', () {
      expect(
        () => core.handle(
          'a',
          SyncRequest(since: 0, changes: [change('1'), change('1')]),
        ),
        throwsA(isA<SyncProtocolException>()),
      );
      expect(
        () => core.handle(
          'a',
          SyncRequest(
            since: 0,
            changes: [
              SyncChange(kind: 'Bad!', id: '1', updatedAt: t0, data: const {}),
            ],
          ),
        ),
        throwsA(isA<SyncProtocolException>()),
      );
      expect(
        () => core.handle(
          'a',
          SyncRequest(
            since: 0,
            changes: [
              SyncChange(
                kind: 'team',
                id: '1',
                updatedAt: t0,
                data: {'x': 'y' * (SyncLimits.recordBytes + 1)},
              ),
            ],
          ),
        ),
        throwsA(isA<SyncProtocolException>()),
      );
      expect(
        () => SyncRequest.fromJson({'protocol': 99, 'since': 0}),
        throwsA(isA<SyncProtocolException>()),
      );
    });

    test('timestamps from the future are capped', () {
      final now = DateTime.utc(2026, 1, 1);
      final c = SyncServerCore(MemorySyncStore(), clock: () => now);
      final r = c.handle(
        'a',
        SyncRequest(
          since: 0,
          changes: [
            SyncChange(
              kind: 'team',
              id: '1',
              updatedAt: DateTime.utc(2099),
              data: const {'id': '1'},
            ),
          ],
        ),
      );
      expect(r.changes.single.updatedAt, now);
    });
  });

  group('Devices sync with each other', () {
    late SyncServerCore core;
    late Device a, b;
    setUp(() async {
      core = SyncServerCore(MemorySyncStore());
      a = Device(core, suffix: 'a');
      b = Device(core, suffix: 'b');
    });

    test('existing data of both devices is merged', () async {
      await a.rawCollection.put(
        CollectionEntry(
          key: key('pikachu'),
          updatedAt: t0,
        ).withCaught(true, t0),
      );
      await a.rawTeams.save(team('t1', 'Red', t0));
      await b.rawCollection.put(
        CollectionEntry(key: key('eevee'), updatedAt: t0).withSeen(true, t0),
      );
      await a.client.connect();
      await b.client.connect();
      expect(a.client.pending, 2);

      await a.sync();
      final report = await b.sync();
      await a.sync();

      expect(report.received, 2);
      expect(report.sent, 1);
      for (final d in [a, b]) {
        final entries = await d.collection.loadAll();
        expect(entries.keys, unorderedEquals([key('pikachu'), key('eevee')]));
        expect((await d.teams.loadAll()).single.name, 'Red');
        expect(d.client.pending, 0);
      }
    });

    test('ongoing changes and deletions arrive', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Red', t0));
      await a.collection.put(
        CollectionEntry(
          key: key('pikachu'),
          updatedAt: t0,
        ).withCaught(true, t0),
      );
      await a.sync();
      await b.sync();
      expect(await b.teams.loadAll(), hasLength(1));

      await b.teams.delete('t1');
      await b.collection.put(
        (await b.collection.loadAll())[key('pikachu')]!.withSeen(
          false,
          t0.add(const Duration(minutes: 1)),
        ),
      );
      await b.sync();
      await a.sync();
      expect(await a.teams.loadAll(), isEmpty);
      expect(await a.collection.loadAll(), isEmpty);
    });

    test('concurrent team edits result in a conflict copy', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Red', t0));
      await a.sync();
      await b.sync();

      await a.teams.save(
        team('t1', 'Red A', t0.add(const Duration(minutes: 1))),
      );
      await b.teams.save(
        team('t1', 'Red B', t0.add(const Duration(minutes: 2))),
      );
      await a.sync();
      final report = await b.sync();
      await a.sync();

      expect(report.conflicts, 1);
      expect(report.copies, 1);
      for (final d in [a, b]) {
        final names = (await d.teams.loadAll()).map((t) => t.name);
        expect(names, unorderedEquals(['Red A', 'Red B (conflict)']));
      }
      expect(
        (await b.teams.loadAll()).firstWhere((t) => t.id == 't1').name,
        'Red A',
      );
    });

    test('edit wins over deletion', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Red', t0));
      await a.sync();
      await b.sync();

      await a.teams.delete('t1');
      await b.teams.save(
        team('t1', 'Red new', t0.add(const Duration(minutes: 1))),
      );
      await a.sync();
      await b.sync();
      await a.sync();
      for (final d in [a, b]) {
        expect((await d.teams.loadAll()).single.name, 'Red new');
      }
    });

    test('collection: the newer entry wins', () async {
      await a.client.connect();
      await b.client.connect();
      final early = t0;
      final late = t0.add(const Duration(hours: 1));
      await b.collection.put(
        CollectionEntry(
          key: key('pikachu'),
          updatedAt: late,
        ).withCaught(true, late),
      );
      await a.collection.put(
        CollectionEntry(
          key: key('pikachu'),
          updatedAt: early,
        ).withSeen(true, early),
      );
      await b.sync();
      await a.sync();
      await b.sync();
      for (final d in [a, b]) {
        expect((await d.collection.loadAll())[key('pikachu')]!.caught, isTrue);
      }
    });

    test('import (replace) transfers changes and deletions', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Old', t0));
      await a.sync();
      await b.sync();
      await a.teams.replaceAll([team('t2', 'New', t0)]);
      await a.sync();
      await b.sync();
      expect((await b.teams.loadAll()).single.id, 't2');
    });

    test('nothing is recorded without a connection', () async {
      await a.teams.save(team('t1', 'Red', t0));
      expect(a.client.pending, 0);
      expect(() => a.sync(), throwsA(isA<SyncProtocolException>()));
    });

    test('disconnecting only clears the sync state', () async {
      await a.client.connect();
      await a.teams.save(team('t1', 'Red', t0));
      await a.client.disconnect();
      expect(a.client.connected, isFalse);
      expect(await a.teams.loadAll(), hasLength(1));
    });

    test('sync state survives a restart (file)', () async {
      final dir = Directory.systemTemp.createTempSync('mydex_sync');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = FileSyncStateStore(File('${dir.path}/sync.json'));
      final client = SyncClient(stateStore: store, adapters: const []);
      await client.connect();
      await client.record(
        SyncChange(
          kind: 'team',
          id: 't1',
          updatedAt: t0,
          data: const {'id': 't1'},
        ),
      );
      final again = SyncClient(stateStore: store, adapters: const []);
      await again.open();
      expect(again.connected, isTrue);
      expect(again.pending, 1);
    });
  });
}
