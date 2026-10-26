import 'dart:convert';
import 'dart:io';

import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('mydex_teams'));
  tearDown(() => dir.deleteSync(recursive: true));
  File file() => File('${dir.path}/teams.json');

  final team = Team(
    id: 'a',
    name: 'Kanto',
    version: const GameVersionId('red'),
    members: const [
      TeamMember(
        form: FormId('pikachu'),
        nickname: 'Pika',
        level: 25,
        moves: [MoveId('thunderbolt')],
        evs: {Stat.speed: 252},
      ),
    ],
    updatedAt: DateTime.utc(2026, 10, 26),
  );

  test('Rundreise über Neustart', () async {
    await FileTeamRepository(file()).save(team);
    final loaded = await FileTeamRepository(file()).loadAll();
    expect(loaded.single.name, 'Kanto');
    final m = loaded.single.members.single;
    expect(m.nickname, 'Pika');
    expect(m.moves, [const MoveId('thunderbolt')]);
    expect(m.evs[Stat.speed], 252);
  });

  test('Löschen', () async {
    final repo = FileTeamRepository(file());
    await repo.save(team);
    await repo.delete('a');
    expect(await FileTeamRepository(file()).loadAll(), isEmpty);
  });

  test('unlesbare Einträge bleiben erhalten', () async {
    file().writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'entries': [
          {'kaputt': true},
        ],
      }),
    );
    final repo = FileTeamRepository(file());
    expect(await repo.loadAll(), isEmpty);
    await repo.save(team);
    final raw = jsonDecode(file().readAsStringSync()) as Map;
    expect((raw['entries'] as List), hasLength(2));
  });

  test('copyWith setzt optionale Felder gezielt zurück', () {
    const m = TeamMember(form: FormId('pikachu'), item: ItemId('light-ball'));
    expect(m.copyWith(item: null).item, isNull);
    expect(m.copyWith(level: 30).item, const ItemId('light-ball'));
  });
}
