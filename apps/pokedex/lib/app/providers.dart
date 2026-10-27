import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_sync/mydex_sync.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import 'catalog_loader.dart';
import 'settings.dart';
import 'sync_config.dart';

/// Ablageort der persönlichen Daten. Sammlung, Teams und Vorlagen laufen über
/// den Abgleich (ADR 0012); ohne Verbindung zeichnet er nichts auf.
class AppStorage {
  factory AppStorage(Directory dir) => AppStorage.custom(
    collection: FileCollectionRepository(File('${dir.path}/collection.json')),
    preferences: JsonPreferencesRepository(
      File('${dir.path}/preferences.json'),
    ),
    teams: FileTeamRepository(File('${dir.path}/teams.json')),
    presets: FileFilterPresetRepository(
      File('${dir.path}/filter_presets.json'),
    ),
    catalogDirectory: Directory('${dir.path}/catalog'),
    syncState: FileSyncStateStore(File('${dir.path}/sync_state.json')),
    syncConfig: FileSyncConfigStore(File('${dir.path}/sync_config.json')),
  );

  AppStorage.custom({
    required CollectionRepository collection,
    required this.preferences,
    required this.catalogDirectory,
    TeamRepository? teams,
    FilterPresetRepository? presets,
    SyncStateStore? syncState,
    SyncConfigStore? syncConfig,
  }) : syncConfig = syncConfig ?? MemorySyncConfigStore() {
    final rawTeams = teams ?? MemoryTeamRepository();
    final rawPresets = presets ?? MemoryFilterPresetRepository();
    String conflictName(String name) => '$name ($conflictLabel)';
    sync = SyncClient(
      stateStore: syncState ?? MemorySyncStateStore(),
      adapters: [
        CollectionSyncAdapter(collection),
        DocumentSyncAdapter.teams(rawTeams, conflictName: conflictName),
        DocumentSyncAdapter.filterPresets(
          rawPresets,
          conflictName: conflictName,
        ),
      ],
    );
    this.collection = SyncingCollectionRepository(collection, sync);
    this.teams = SyncingTeamRepository(rawTeams, sync);
    this.presets = SyncingFilterPresetRepository(rawPresets, sync);
  }

  late final CollectionRepository collection;
  final JsonPreferencesRepository preferences;
  late final TeamRepository teams;
  late final FilterPresetRepository presets;
  late final SyncClient sync;

  /// Serveradresse und Zugangsschlüssel – bewusst nicht in den Einstellungen,
  /// damit sie nie in einer Datensicherung landen.
  final SyncConfigStore syncConfig;

  /// Zusatz für Konfliktkopien, in der App-Sprache (wird von der App gesetzt).
  String conflictLabel = 'Konflikt';

  /// Getrennt von den Nutzerdaten (ADR 0003).
  final Directory catalogDirectory;
}

final appStorageProvider = Provider<AppStorage>(
  (ref) =>
      throw UnimplementedError('appStorageProvider muss überschrieben werden'),
);

final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// Der gebündelte Katalog: Die App funktioniert ab dem ersten Start offline.
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) =>
      BundledCatalogRepository(ref.watch(appStorageProvider).catalogDirectory),
);

final catalogProvider = FutureProvider<LoadedCatalog>((ref) async {
  final loaded = await ref.watch(catalogRepositoryProvider).load();
  ref.onDispose(loaded.details.close);
  return loaded;
}, retry: (_, _) => null);

/// Nur innerhalb von [CatalogGate] verwenden, wo der Katalog geladen ist.
final readyCatalogProvider = Provider<CatalogSnapshot>(
  (ref) => ref.watch(catalogProvider).requireValue.snapshot,
);

/// Abfragen auf große Tabellen (Erlernbarkeit, Attacken, Suche).
final catalogDetailsProvider = Provider<CatalogDetails>(
  (ref) => ref.watch(catalogProvider).requireValue.details,
);

final queriesProvider = Provider<PokemonQueries>(
  (ref) => PokemonQueries(ref.watch(readyCatalogProvider)),
);

final searchIndexProvider = Provider<PokemonSearchIndex>(
  (ref) => PokemonSearchIndex(ref.watch(readyCatalogProvider)),
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  void _update(AppSettings next) {
    state = next;
    ref.read(appStorageProvider).preferences.save(next.toJson()).ignore();
  }

  void setThemeMode(ThemeMode mode) => _update(state.copyWith(themeMode: mode));

  void setGameVersion(GameVersionId id) =>
      _update(state.copyWith(gameVersion: id.value));

  void setDataLanguage(String? language) =>
      _update(state.copyWith(dataLanguage: () => language));

  void setUiLanguage(String? language) =>
      _update(state.copyWith(uiLanguage: () => language));

  /// Übernimmt Einstellungen aus einer Sicherung.
  void replaceAll(AppSettings settings) => _update(settings);
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// Der aktuelle Spielkontext (ADR 0004). Alle spielabhängigen Ansichten hängen
/// davon ab, daher aktualisiert ein Spielwechsel sie konsistent.
final gameContextProvider = Provider<GameContext>((ref) {
  final catalog = ref.watch(readyCatalogProvider);
  final selected = ref.watch(settingsProvider.select((s) => s.gameVersion));
  if (selected != null &&
      catalog.versions.any((v) => v.id == GameVersionId(selected))) {
    return catalog.contextFor(GameVersionId(selected));
  }
  return catalog.defaultContext;
});

/// Sprache der Spieldaten: Einstellung oder App-Sprache.
String dataLanguageOf(BuildContext context, WidgetRef ref) =>
    ref.watch(settingsProvider.select((s) => s.dataLanguage)) ??
    Localizations.localeOf(context).languageCode;

class CollectionController
    extends AsyncNotifier<Map<CollectionKey, CollectionEntry>> {
  CollectionRepository get _repo => ref.read(appStorageProvider).collection;

  @override
  Future<Map<CollectionKey, CollectionEntry>> build() => _repo.loadAll();

  CollectionEntry entryFor(CollectionKey key) =>
      state.value?[key] ?? CollectionEntry(key: key, updatedAt: DateTime.now());

  Future<void> setCaught(CollectionKey key, bool caught) =>
      _put(entryFor(key).withCaught(caught, DateTime.now()));

  Future<void> setSeen(CollectionKey key, bool seen) =>
      _put(entryFor(key).withSeen(seen, DateTime.now()));

  Future<void> _put(CollectionEntry entry) async {
    final current = {...?state.value};
    if (entry.isEmpty) {
      current.remove(entry.key);
    } else {
      current[entry.key] = entry;
    }
    final previous = state;
    state = AsyncData(current);
    try {
      await _repo.put(entry);
    } catch (_) {
      state = previous; // Anzeige nie von gespeicherten Daten abweichen lassen
      rethrow;
    }
  }
}

final collectionProvider =
    AsyncNotifierProvider<
      CollectionController,
      Map<CollectionKey, CollectionEntry>
    >(CollectionController.new);

class TeamsController extends AsyncNotifier<List<Team>> {
  TeamRepository get _repo => ref.read(appStorageProvider).teams;

  @override
  Future<List<Team>> build() => _repo.loadAll();

  Team? byId(String id) => state.value?.where((t) => t.id == id).firstOrNull;

  /// Legt ein Team für das gewählte Spiel an.
  Future<Team> create(String name, GameVersionId version) async {
    final now = DateTime.now();
    final team = Team(
      id: '${now.microsecondsSinceEpoch.toRadixString(36)}-${(state.value?.length ?? 0)}',
      name: name,
      version: version,
      updatedAt: now,
    );
    await save(team);
    return team;
  }

  Future<void> save(Team team) async {
    final previous = state;
    final others = [...?state.value?.where((t) => t.id != team.id)];
    state = AsyncData([team, ...others]);
    try {
      await _repo.save(team);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final previous = state;
    state = AsyncData([...?state.value?.where((t) => t.id != id)]);
    try {
      await _repo.delete(id);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final teamsProvider = AsyncNotifierProvider<TeamsController, List<Team>>(
  TeamsController.new,
);

/// Prüfung und Analyse im Kontext des Team-Spiels (nicht des globalen Spiels).
TeamEvaluator evaluatorFor(WidgetRef ref, Team team) {
  final catalog = ref.watch(readyCatalogProvider);
  return TeamEvaluator(
    catalog,
    ref.watch(catalogDetailsProvider),
    catalog.contextFor(team.version),
  );
}

class PresetsController extends AsyncNotifier<List<FilterPreset>> {
  FilterPresetRepository get _repo => ref.read(appStorageProvider).presets;

  @override
  Future<List<FilterPreset>> build() => _repo.loadAll();

  Future<void> add(String name, DexFilter filter) async {
    final now = DateTime.now();
    await _repo.save(
      FilterPreset(
        id: now.microsecondsSinceEpoch.toRadixString(36),
        name: name,
        filter: filter,
        updatedAt: now,
      ),
    );
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    ref.invalidateSelf();
  }
}

final presetsProvider =
    AsyncNotifierProvider<PresetsController, List<FilterPreset>>(
      PresetsController.new,
    );

class DexFilterController extends Notifier<DexFilter> {
  @override
  DexFilter build() => const DexFilter();

  void set(DexFilter filter) => state = filter;
}

/// Aktiver Filter der Dex-Liste (nicht gespeichert; Vorlagen speichern ihn).
final dexFilterProvider = NotifierProvider<DexFilterController, DexFilter>(
  DexFilterController.new,
);
