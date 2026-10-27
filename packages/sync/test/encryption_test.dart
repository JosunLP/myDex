import 'dart:convert';

import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_user_store/mydex_user_store.dart';
import 'package:test/test.dart';

/// Ruft den Serverkern direkt auf und merkt sich, was der Server sieht.
class RecordingTransport implements SyncTransport {
  RecordingTransport(this.core);
  final SyncServerCore core;
  final seen = StringBuffer();

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    final wire = jsonEncode(request.toJson());
    seen.writeln(wire);
    final response = core
        .handle(
          'a',
          SyncRequest.fromJson(jsonDecode(wire) as Map<String, Object?>),
        )
        .toJson();
    seen.writeln(jsonEncode(response));
    return SyncResponse.fromJson(response);
  }

  @override
  Future<void> deleteAccountData() async => core.wipe('a');
}

class Device {
  Device(SyncServerCore core) : wire = RecordingTransport(core) {
    client = SyncClient(
      stateStore: MemorySyncStateStore(),
      adapters: [
        CollectionSyncAdapter(rawCollection),
        DocumentSyncAdapter.teams(
          rawTeams,
          conflictName: (n) => '$n (Konflikt)',
        ),
      ],
    );
    collection = SyncingCollectionRepository(rawCollection, client);
    teams = SyncingTeamRepository(rawTeams, client);
  }

  final RecordingTransport wire;
  final rawCollection = MemoryCollectionRepository();
  final rawTeams = MemoryTeamRepository();
  late final SyncClient client;
  late final SyncingCollectionRepository collection;
  late final SyncingTeamRepository teams;
  EncryptingTransport? transport;

  Future<void> connect(String passphrase) async {
    final key = await EncryptingTransport.unlock(
      wire,
      passphrase,
      iterations: 1000,
    );
    transport = EncryptingTransport(wire, key, MemorySyncAliasStore());
    await client.connect();
  }

  Future<SyncReport> sync() => client.sync(transport!);
}

final t0 = DateTime.utc(2026, 3, 1);
const pikachu = CollectionKey(
  scope: GameScope(GameVersionId('red')),
  form: FormId('pikachu'),
);

void main() {
  late SyncServerCore core;
  setUp(() => core = SyncServerCore(MemorySyncStore()));

  test('Geräte mit gleichem Passwort gleichen verschlüsselt ab', () async {
    final a = Device(core);
    final b = Device(core);
    await a.rawTeams.save(
      Team(
        id: 't1',
        name: 'Geheimteam',
        version: const GameVersionId('red'),
        updatedAt: t0,
      ),
    );
    await a.rawCollection.put(
      CollectionEntry(key: pikachu, updatedAt: t0).withCaught(true, t0),
    );
    await a.connect('richtig');
    await a.sync();
    await b.connect('richtig');
    await b.sync();

    expect((await b.teams.loadAll()).single.name, 'Geheimteam');
    expect((await b.collection.loadAll())[pikachu]?.caught, isTrue);

    // Der Server sieht weder Namen noch Pokémon noch Arten.
    final seen = '${a.wire.seen}${b.wire.seen}';
    for (final secret in ['Geheimteam', 'pikachu', 'game:red', '"team"']) {
      expect(seen, isNot(contains(secret)), reason: secret);
    }
  });

  test('Löschungen kommen trotz unlesbarer Grabsteine an', () async {
    final a = Device(core);
    final b = Device(core);
    await a.connect('pw');
    await b.connect('pw');
    await a.teams.save(
      Team(
        id: 't1',
        name: 'X',
        version: const GameVersionId('red'),
        updatedAt: t0,
      ),
    );
    await a.sync();
    await b.sync();
    expect(await b.teams.loadAll(), hasLength(1));
    await a.teams.delete('t1');
    await a.sync();
    await b.sync();
    expect(await b.teams.loadAll(), isEmpty);
  });

  test('Konfliktkopien funktionieren auch verschlüsselt', () async {
    final a = Device(core);
    final b = Device(core);
    await a.connect('pw');
    await b.connect('pw');
    await a.teams.save(
      Team(
        id: 't1',
        name: 'Rot',
        version: const GameVersionId('red'),
        updatedAt: t0,
      ),
    );
    await a.sync();
    await b.sync();
    await a.teams.save(
      Team(
        id: 't1',
        name: 'Rot A',
        version: const GameVersionId('red'),
        updatedAt: t0.add(const Duration(minutes: 1)),
      ),
    );
    await b.teams.save(
      Team(
        id: 't1',
        name: 'Rot B',
        version: const GameVersionId('red'),
        updatedAt: t0.add(const Duration(minutes: 2)),
      ),
    );
    await a.sync();
    await b.sync();
    await a.sync();
    for (final d in [a, b]) {
      expect(
        (await d.teams.loadAll()).map((t) => t.name),
        unorderedEquals(['Rot A', 'Rot B (Konflikt)']),
      );
    }
  });

  test('falsches Passwort wird erkannt', () async {
    await Device(core).connect('richtig');
    expect(
      () => Device(core).connect('falsch'),
      throwsA(
        isA<SyncProtocolException>().having(
          (e) => e.code,
          'code',
          'wrongPassphrase',
        ),
      ),
    );
  });

  test('Schlüssel übersteht Speichern und Laden', () async {
    final key = await SyncKey.derive('pw', [1, 2, 3, 4], 1000);
    final again = SyncKey.fromJson(
      jsonDecode(jsonEncode(key.toJson())) as Map<String, Object?>,
    );
    expect(again.encryption, key.encryption);
    expect(again.authentication, key.authentication);
    expect(key.encryption, isNot(key.authentication));
  });

  test('manipulierte Datensätze werden verworfen', () async {
    final a = Device(core);
    final b = Device(core);
    await a.connect('pw');
    await b.connect('pw');
    await a.teams.save(
      Team(
        id: 't1',
        name: 'X',
        version: const GameVersionId('red'),
        updatedAt: t0,
      ),
    );
    await a.sync();
    // Ein Angreifer mit Serverzugriff vertauscht den Inhalt zweier IDs.
    final stored = core.handle('a', const SyncRequest(since: 0)).changes;
    final record = stored.firstWhere((r) => r.kind == SyncEncryption.kind);
    core.handle(
      'a',
      SyncRequest(
        since: 0,
        changes: [
          SyncChange(
            kind: SyncEncryption.kind,
            id: 'andere-id',
            updatedAt: t0,
            data: record.data,
          ),
        ],
      ),
    );
    await b.sync();
    expect(await b.teams.loadAll(), hasLength(1));
  });
}
