import 'dart:io';

import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_user_store/mydex_user_store.dart';
import 'package:test/test.dart';

/// Ruft den Serverkern direkt auf, wie es die HTTP-Schicht täte.
class DirectTransport implements SyncTransport {
  DirectTransport(this.core, this.account);
  final SyncServerCore core;
  final String account;
  int requests = 0;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    requests++;
    // Über JSON, damit die Serialisierung mitgeprüft wird.
    final wire = SyncRequest.fromJson(request.toJson());
    return SyncResponse.fromJson(core.handle(account, wire).toJson());
  }

  @override
  Future<void> deleteAccountData() async => core.wipe(account);
}

/// Ein Gerät mit eigenem Speicher und Abgleich.
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
          conflictName: (name) => '$name (Konflikt)',
          newId: () => 'copy-$suffix-${n++}',
        ),
        DocumentSyncAdapter.filterPresets(
          rawPresets,
          conflictName: (name) => '$name (Konflikt)',
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
  group('Serverkern', () {
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

    test('nimmt neue Datensätze an und vergibt fortlaufende Revisionen', () {
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

    test('veraltete Basisrevision ergibt einen Konflikt mit Serverstand', () {
      core.handle('a', SyncRequest(since: 0, changes: [change('1')]));
      core.handle('a', SyncRequest(since: 1, changes: [change('1', base: 1)]));
      final r = core.handle(
        'a',
        SyncRequest(since: 2, changes: [change('1', base: 1)]),
      );
      expect(r.results.single.status, SyncResultStatus.conflict);
      expect(r.results.single.current!.revision, 2);
    });

    test('Löschungen bleiben als Grabstein sichtbar', () {
      core.handle('a', SyncRequest(since: 0, changes: [change('1')]));
      core.handle(
        'a',
        SyncRequest(since: 1, changes: [change('1', base: 1, deleted: true)]),
      );
      final r = core.handle('a', const SyncRequest(since: 0));
      expect(r.changes.single.deleted, isTrue);
      expect(r.changes.single.data, isNull);
    });

    test('Konten sind voneinander getrennt', () {
      core.handle('a', SyncRequest(since: 0, changes: [change('1')]));
      expect(core.handle('b', const SyncRequest(since: 0)).changes, isEmpty);
    });

    test('seitenweises Abholen', () {
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

    test('ungültige Anfragen werden abgelehnt', () {
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
              SyncChange(kind: 'Böse', id: '1', updatedAt: t0, data: const {}),
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

    test('Zeitstempel aus der Zukunft werden gekappt', () {
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

  group('Geräte gleichen sich ab', () {
    late SyncServerCore core;
    late Device a, b;
    setUp(() async {
      core = SyncServerCore(MemorySyncStore());
      a = Device(core, suffix: 'a');
      b = Device(core, suffix: 'b');
    });

    test('vorhandene Daten beider Geräte werden zusammengeführt', () async {
      await a.rawCollection.put(
        CollectionEntry(
          key: key('pikachu'),
          updatedAt: t0,
        ).withCaught(true, t0),
      );
      await a.rawTeams.save(team('t1', 'Rot', t0));
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
        expect((await d.teams.loadAll()).single.name, 'Rot');
        expect(d.client.pending, 0);
      }
    });

    test('laufende Änderungen und Löschungen kommen an', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Rot', t0));
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

    test('gleichzeitige Team-Bearbeitung ergibt eine Konfliktkopie', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Rot', t0));
      await a.sync();
      await b.sync();

      await a.teams.save(
        team('t1', 'Rot A', t0.add(const Duration(minutes: 1))),
      );
      await b.teams.save(
        team('t1', 'Rot B', t0.add(const Duration(minutes: 2))),
      );
      await a.sync();
      final report = await b.sync();
      await a.sync();

      expect(report.conflicts, 1);
      expect(report.copies, 1);
      for (final d in [a, b]) {
        final names = (await d.teams.loadAll()).map((t) => t.name);
        expect(names, unorderedEquals(['Rot A', 'Rot B (Konflikt)']));
      }
      expect(
        (await b.teams.loadAll()).firstWhere((t) => t.id == 't1').name,
        'Rot A',
      );
    });

    test('Bearbeitung gewinnt gegen Löschung', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Rot', t0));
      await a.sync();
      await b.sync();

      await a.teams.delete('t1');
      await b.teams.save(
        team('t1', 'Rot neu', t0.add(const Duration(minutes: 1))),
      );
      await a.sync();
      await b.sync();
      await a.sync();
      for (final d in [a, b]) {
        expect((await d.teams.loadAll()).single.name, 'Rot neu');
      }
    });

    test('Sammlung: der neuere Eintrag gewinnt', () async {
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

    test('Import (Ersetzen) überträgt Änderungen und Löschungen', () async {
      await a.client.connect();
      await b.client.connect();
      await a.teams.save(team('t1', 'Alt', t0));
      await a.sync();
      await b.sync();
      await a.teams.replaceAll([team('t2', 'Neu', t0)]);
      await a.sync();
      await b.sync();
      expect((await b.teams.loadAll()).single.id, 't2');
    });

    test('ohne Verbindung wird nichts aufgezeichnet', () async {
      await a.teams.save(team('t1', 'Rot', t0));
      expect(a.client.pending, 0);
      expect(() => a.sync(), throwsA(isA<SyncProtocolException>()));
    });

    test('Trennen löscht nur den Abgleichsstand', () async {
      await a.client.connect();
      await a.teams.save(team('t1', 'Rot', t0));
      await a.client.disconnect();
      expect(a.client.connected, isFalse);
      expect(await a.teams.loadAll(), hasLength(1));
    });

    test('Abgleichsstand übersteht einen Neustart (Datei)', () async {
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
