import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'json_file_store.dart';

/// Teams as a JSON file (written atomically).
class FileTeamRepository implements TeamRepository {
  FileTeamRepository(File file)
    : _store = JsonFileStore(file, schemaVersion: 1);

  final JsonFileStore _store;
  Map<String, Team>? _teams;

  /// Unreadable entries are kept unchanged when saving.
  final _unreadable = <Map<String, Object?>>[];

  String? get quarantinedPath => _store.quarantinedPath;

  Future<Map<String, Team>> _load() async {
    if (_teams case final teams?) return teams;
    final teams = <String, Team>{};
    for (final j in await _store.read()) {
      // Skip individual unreadable teams instead of losing everything.
      final team = _tryParse(j);
      if (team != null) {
        teams[team.id] = team;
      } else {
        _unreadable.add(j);
      }
    }
    return _teams = teams;
  }

  static Team? _tryParse(Map<String, Object?> j) {
    try {
      return Team.fromJson(j);
    } on Object {
      return null;
    }
  }

  @override
  Future<List<Team>> loadAll() async =>
      (await _load()).values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> save(Team team) async {
    final teams = await _load();
    teams[team.id] = team;
    await _persist(teams);
  }

  @override
  Future<void> delete(String id) async {
    final teams = await _load();
    teams.remove(id);
    await _persist(teams);
  }

  @override
  Future<void> replaceAll(Iterable<Team> teams) async {
    final current = await _load();
    current
      ..clear()
      ..addAll({for (final t in teams) t.id: t});
    _unreadable.clear();
    await _persist(current);
  }

  Future<void> _persist(Map<String, Team> teams) {
    final sorted = teams.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return _store.write([for (final t in sorted) t.toJson(), ..._unreadable]);
  }
}

/// Volatile store for tests.
class MemoryTeamRepository implements TeamRepository {
  final _teams = <String, Team>{};

  @override
  Future<List<Team>> loadAll() async =>
      _teams.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> save(Team team) async => _teams[team.id] = team;

  @override
  Future<void> delete(String id) async => _teams.remove(id);

  @override
  Future<void> replaceAll(Iterable<Team> teams) async {
    _teams
      ..clear()
      ..addAll({for (final t in teams) t.id: t});
  }
}
