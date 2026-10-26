import 'dart:convert';

import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';
import 'package:test/test.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  final t1 = DateTime.utc(2026, 6, 1);
  CollectionEntry entry(String form, DateTime at) => CollectionEntry(
    key: CollectionKey(
      scope: const GameScope(GameVersionId('red')),
      form: FormId(form),
    ),
    updatedAt: at,
  ).withCaught(true, at);
  Team team(String id, String name, DateTime at) => Team(
    id: id,
    name: name,
    version: const GameVersionId('x'),
    updatedAt: at,
  );

  final data = BackupData(
    collection: [entry('pikachu', t0)],
    teams: [team('a', 'Kanto', t0)],
    presets: [
      FilterPreset(
        id: 'p',
        name: 'Feuer fehlt',
        filter: const DexFilter(
          types: {PokemonType.fire},
          collection: CollectionFilter.missing,
        ),
        updatedAt: t0,
      ),
    ],
    preferences: const {'themeMode': 'dark'},
    createdAt: t1,
  );

  group('Format', () {
    test('Rundreise ohne Passwort', () async {
      final bytes = await BackupCodec.encode(data);
      expect(BackupCodec.isEncrypted(bytes), isFalse);
      final back = await BackupCodec.decode(bytes);
      expect(back.collection.single.key.form, const FormId('pikachu'));
      expect(back.teams.single.name, 'Kanto');
      expect(back.presets.single.filter.types, {PokemonType.fire});
      expect(back.preferences['themeMode'], 'dark');
      expect(back.createdAt, t1);
    });

    test('Rundreise mit Passwort; falsches Passwort wird erkannt', () async {
      final bytes = await BackupCodec.encode(data, password: 'geheim');
      expect(BackupCodec.isEncrypted(bytes), isTrue);
      expect(
        utf8.decode(bytes),
        isNot(contains('Kanto')),
        reason: 'Inhalt ist verschlüsselt',
      );
      expect(
        (await BackupCodec.decode(bytes, password: 'geheim')).teams.single.name,
        'Kanto',
      );
      await expectLater(
        BackupCodec.decode(bytes, password: 'falsch'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.wrongPassword,
          ),
        ),
      );
      await expectLater(
        BackupCodec.decode(bytes),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.passwordRequired,
          ),
        ),
      );
    }, timeout: const Timeout(Duration(minutes: 1)));

    test('fremde Dateien und unbekannte Versionen werden abgelehnt', () async {
      await expectLater(
        BackupCodec.decode(utf8.encode('{"hallo": 1}')),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.notABackup,
          ),
        ),
      );
      await expectLater(
        BackupCodec.decode(utf8.encode('kein json')),
        throwsA(isA<BackupException>()),
      );
      await expectLater(
        BackupCodec.decode(
          utf8.encode('{"format": "mydex-backup", "version": 99}'),
        ),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.unsupportedVersion,
          ),
        ),
      );
    });

    test('unlesbare Einträge werden übersprungen und gezählt', () async {
      final json =
          jsonDecode(utf8.decode(await BackupCodec.encode(data)))
              as Map<String, dynamic>;
      (json['teams'] as List).add({'kaputt': true});
      final back = await BackupCodec.decode(utf8.encode(jsonEncode(json)));
      expect(back.teams, hasLength(1));
      expect(back.skippedEntries, 1);
    });
  });

  group('Import planen', () {
    final current = BackupData(
      collection: [entry('pikachu', t1), entry('eevee', t0)],
      teams: [team('a', 'Alt', t0), team('b', 'Nur lokal', t0)],
      createdAt: t1,
    );
    final incoming = BackupData(
      collection: [
        entry('pikachu', t0),
        entry('eevee', t1),
        entry('raichu', t0),
      ],
      teams: [team('a', 'Neu', t1)],
      preferences: const {'themeMode': 'dark'},
      createdAt: t1,
    );

    test('Zusammenführen: neuere Einträge gewinnen, nichts geht verloren', () {
      final plan = planImport(
        current: current,
        incoming: incoming,
        mode: ImportMode.merge,
      );
      expect(plan.collectionCounts.added, 1);
      expect(plan.collectionCounts.updated, 1);
      expect(plan.collectionCounts.kept, 1);
      expect(plan.collection, hasLength(3));
      expect(plan.teams.map((t) => t.name), containsAll(['Neu', 'Nur lokal']));
      expect(
        plan.preferences,
        isNull,
        reason: 'Einstellungen bleiben beim Zusammenführen',
      );
    });

    test('Ersetzen: Sicherung gilt vollständig, Entferntes wird gezählt', () {
      final plan = planImport(
        current: current,
        incoming: incoming,
        mode: ImportMode.replace,
      );
      expect(plan.teams.single.name, 'Neu');
      expect(plan.teamCounts.removed, 1);
      expect(plan.collection, hasLength(3));
      expect(plan.preferences, {'themeMode': 'dark'});
    });
  });
}
