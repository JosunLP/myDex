import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'client.dart';
import 'protocol.dart';

/// Datenarten im Abgleich. Neue Arten bekommen einen neuen Namen; der Server
/// speichert sie, ohne sie zu kennen.
abstract final class SyncKinds {
  static const collection = 'collection';
  static const team = 'team';
  static const filterPreset = 'filter_preset';
}

/// Sammlungseinträge: bei Konflikt gewinnt der neuere Stand (je Eintrag).
/// Einträge sind klein und unabhängig; eine Konfliktkopie wäre hier sinnlos.
class CollectionSyncAdapter implements SyncAdapter {
  CollectionSyncAdapter(this.repository);

  /// Das ungekapselte Repository – Übernahmen landen nicht in der Outbox.
  final CollectionRepository repository;

  @override
  String get kind => SyncKinds.collection;

  static SyncChange changeFor(CollectionEntry entry) => entry.isEmpty
      ? SyncChange(
          kind: SyncKinds.collection,
          id: entry.key.encoded,
          updatedAt: entry.updatedAt,
          deleted: true,
        )
      : SyncChange(
          kind: SyncKinds.collection,
          id: entry.key.encoded,
          updatedAt: entry.updatedAt,
          data: entry.toJson(),
        );

  @override
  Future<List<SyncChange>> localRecords() async => [
    for (final e in (await repository.loadAll()).values)
      if (!e.isEmpty) changeFor(e),
  ];

  @override
  Future<void> apply(SyncRecord record) async {
    final CollectionKey key;
    try {
      key = CollectionKey.decode(record.id);
    } on FormatException {
      return; // Fremdes Format einer neueren Version: ignorieren.
    }
    if (record.deleted) {
      await repository.put(
        CollectionEntry(key: key, updatedAt: record.updatedAt),
      );
      return;
    }
    final entry = _tryParse(record.data!);
    if (entry != null && entry.key == key) await repository.put(entry);
  }

  static CollectionEntry? _tryParse(Map<String, Object?> j) {
    try {
      return CollectionEntry.fromJson(j);
    } on Object {
      return null;
    }
  }

  @override
  Future<ConflictResolution> resolve(
    SyncChange local,
    SyncRecord server,
  ) async => local.updatedAt.isAfter(server.updatedAt)
      ? const KeepLocal()
      : const TakeServer();
}

/// Dokumente mit eigener ID (Teams, Filtervorlagen):
/// - lokal geändert, auf dem Server gelöscht → lokale Fassung bleibt;
/// - lokal gelöscht, auf dem Server geändert → Serverfassung bleibt;
/// - beide geändert → Serverfassung unter der ID, lokale als Konfliktkopie.
/// So geht keine Bearbeitung still verloren.
class DocumentSyncAdapter implements SyncAdapter {
  DocumentSyncAdapter({
    required this.kind,
    required this.loadAll,
    required this.save,
    required this.delete,
    required this.conflictName,
    String Function()? newId,
  }) : _newId = newId ?? _defaultId;

  @override
  final String kind;

  /// Lokale Dokumente als JSON mit `id`, `name`, `updatedAt`.
  final Future<List<Map<String, Object?>>> Function() loadAll;

  /// Speichert ein Dokument aus JSON; wirft bei unlesbaren Daten.
  final Future<void> Function(Map<String, Object?> json) save;
  final Future<void> Function(String id) delete;

  /// Name der Konfliktkopie, z. B. „Team (Konflikt)“.
  final String Function(String name) conflictName;
  final String Function() _newId;

  static String _defaultId() =>
      'c${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

  factory DocumentSyncAdapter.teams(
    TeamRepository repository, {
    required String Function(String name) conflictName,
    String Function()? newId,
  }) => DocumentSyncAdapter(
    kind: SyncKinds.team,
    loadAll: () async => [
      for (final t in await repository.loadAll()) t.toJson(),
    ],
    save: (j) => repository.save(Team.fromJson(j)),
    delete: repository.delete,
    conflictName: conflictName,
    newId: newId,
  );

  factory DocumentSyncAdapter.filterPresets(
    FilterPresetRepository repository, {
    required String Function(String name) conflictName,
    String Function()? newId,
  }) => DocumentSyncAdapter(
    kind: SyncKinds.filterPreset,
    loadAll: () async => [
      for (final p in await repository.loadAll()) p.toJson(),
    ],
    save: (j) => repository.save(FilterPreset.fromJson(j)),
    delete: repository.delete,
    conflictName: conflictName,
    newId: newId,
  );

  @override
  Future<List<SyncChange>> localRecords() async => [
    for (final j in await loadAll()) documentChange(kind, j),
  ];

  @override
  Future<void> apply(SyncRecord record) async {
    if (record.deleted) {
      await delete(record.id);
      return;
    }
    final data = record.data!;
    if (data['id'] != record.id) return;
    try {
      await save(data);
    } on Object {
      // Unlesbares Dokument (z. B. neuere Version): lokal nicht übernehmen.
    }
  }

  @override
  Future<ConflictResolution> resolve(
    SyncChange local,
    SyncRecord server,
  ) async {
    if (server.deleted) return const KeepLocal();
    if (local.deleted) return const TakeServer();
    if (jsonEquals(local.data, server.data)) return const TakeServer();
    final copy = {
      ...local.data!,
      'id': _newId(),
      'name': conflictName((local.data!['name'] as String?) ?? ''),
    };
    try {
      await save(copy);
    } on Object {
      return const TakeServer();
    }
    return KeepBoth(documentChange(kind, copy));
  }
}

SyncChange documentChange(String kind, Map<String, Object?> json) => SyncChange(
  kind: kind,
  id: json['id']! as String,
  updatedAt: DateTime.parse(json['updatedAt']! as String),
  data: json,
);

SyncChange deletionChange(String kind, String id) =>
    SyncChange(kind: kind, id: id, updatedAt: DateTime.now(), deleted: true);

/// Strukturgleichheit von JSON-Werten, unabhängig von der Schlüsselreihenfolge.
bool jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !jsonEquals(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Sammlung mit Aufzeichnung für den Abgleich.
class SyncingCollectionRepository implements CollectionRepository {
  SyncingCollectionRepository(this.inner, this.client);

  final CollectionRepository inner;
  final SyncClient client;

  @override
  Future<Map<CollectionKey, CollectionEntry>> loadAll() => inner.loadAll();

  @override
  Future<void> put(CollectionEntry entry) async {
    await inner.put(entry);
    await client.record(CollectionSyncAdapter.changeFor(entry));
  }

  @override
  Future<void> replaceAll(Iterable<CollectionEntry> entries) async {
    final before = await inner.loadAll();
    final after = {for (final e in entries) e.key: e};
    await inner.replaceAll(after.values);
    final now = DateTime.now();
    await client.recordAll([
      for (final e in after.values)
        if (!jsonEquals(before[e.key]?.toJson(), e.toJson()))
          CollectionSyncAdapter.changeFor(e),
      for (final key in before.keys)
        if (!after.containsKey(key))
          CollectionSyncAdapter.changeFor(
            CollectionEntry(key: key, updatedAt: now),
          ),
    ]);
  }
}

class SyncingTeamRepository implements TeamRepository {
  SyncingTeamRepository(this.inner, this.client);

  final TeamRepository inner;
  final SyncClient client;

  @override
  Future<List<Team>> loadAll() => inner.loadAll();

  @override
  Future<void> save(Team team) async {
    await inner.save(team);
    await client.record(documentChange(SyncKinds.team, team.toJson()));
  }

  @override
  Future<void> delete(String id) async {
    await inner.delete(id);
    await client.record(deletionChange(SyncKinds.team, id));
  }

  @override
  Future<void> replaceAll(Iterable<Team> teams) async {
    final before = {for (final t in await inner.loadAll()) t.id: t};
    final after = {for (final t in teams) t.id: t};
    await inner.replaceAll(after.values);
    await client.recordAll([
      for (final t in after.values)
        if (!jsonEquals(before[t.id]?.toJson(), t.toJson()))
          documentChange(SyncKinds.team, t.toJson()),
      for (final id in before.keys)
        if (!after.containsKey(id)) deletionChange(SyncKinds.team, id),
    ]);
  }
}

class SyncingFilterPresetRepository implements FilterPresetRepository {
  SyncingFilterPresetRepository(this.inner, this.client);

  final FilterPresetRepository inner;
  final SyncClient client;

  @override
  Future<List<FilterPreset>> loadAll() => inner.loadAll();

  @override
  Future<void> save(FilterPreset preset) async {
    await inner.save(preset);
    await client.record(
      documentChange(SyncKinds.filterPreset, preset.toJson()),
    );
  }

  @override
  Future<void> delete(String id) async {
    await inner.delete(id);
    await client.record(deletionChange(SyncKinds.filterPreset, id));
  }

  @override
  Future<void> replaceAll(Iterable<FilterPreset> presets) async {
    final before = {for (final p in await inner.loadAll()) p.id: p};
    final after = {for (final p in presets) p.id: p};
    await inner.replaceAll(after.values);
    await client.recordAll([
      for (final p in after.values)
        if (!jsonEquals(before[p.id]?.toJson(), p.toJson()))
          documentChange(SyncKinds.filterPreset, p.toJson()),
      for (final id in before.keys)
        if (!after.containsKey(id)) deletionChange(SyncKinds.filterPreset, id),
    ]);
  }
}
