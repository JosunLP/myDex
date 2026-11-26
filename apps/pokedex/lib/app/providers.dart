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

/// Storage location of personal data. Collection, teams and presets go
/// through the sync (ADR 0012); without a connection it records nothing.
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
    mediaDirectory: Directory('${dir.path}/media'),
    syncState: FileSyncStateStore(File('${dir.path}/sync_state.json')),
    syncConfig: FileSyncConfigStore(File('${dir.path}/sync_config.json')),
    syncAliases: FileSyncAliasStore(File('${dir.path}/sync_aliases.json')),
  );

  AppStorage.custom({
    required CollectionRepository collection,
    required this.preferences,
    required this.catalogDirectory,
    Directory? mediaDirectory,
    TeamRepository? teams,
    FilterPresetRepository? presets,
    SyncStateStore? syncState,
    SyncConfigStore? syncConfig,
    SyncAliasStore? syncAliases,
  }) : syncConfig = syncConfig ?? MemorySyncConfigStore(),
       syncAliases = syncAliases ?? MemorySyncAliasStore(),
       mediaDirectory =
           mediaDirectory ??
           Directory('${catalogDirectory.parent.path}/media') {
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

  /// Server address and access token – deliberately not in the settings so
  /// that they never end up in a backup.
  final SyncConfigStore syncConfig;

  /// Mapping of encrypted IDs (for deletions).
  final SyncAliasStore syncAliases;

  /// Suffix for conflict copies, in the app language (set by the app).
  String conflictLabel = 'conflict';

  /// Separate from the user data (ADR 0003).
  final Directory catalogDirectory;

  /// Installed media pack (sprites).
  final Directory mediaDirectory;
}

final appStorageProvider = Provider<AppStorage>(
  (ref) => throw UnimplementedError('appStorageProvider must be overridden'),
);

final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

/// The bundled catalog: the app works offline from the first start.
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) =>
      BundledCatalogRepository(ref.watch(appStorageProvider).catalogDirectory),
);

final mediaLoaderProvider = Provider<MediaLoader>(
  (ref) => BundledMediaLoader(ref.watch(appStorageProvider).mediaDirectory),
);

/// Images; empty until loaded and on errors (the app does not wait for them).
final mediaProvider = FutureProvider<MediaLibrary>((ref) async {
  final media = await ref.watch(mediaLoaderProvider).load();
  ref.onDispose(media.close);
  return media;
}, retry: (_, _) => null);

final catalogProvider = FutureProvider<LoadedCatalog>((ref) async {
  final loaded = await ref.watch(catalogRepositoryProvider).load();
  ref.onDispose(loaded.details.close);
  return loaded;
}, retry: (_, _) => null);

/// Only use inside [CatalogGate], where the catalog is loaded.
final readyCatalogProvider = Provider<CatalogSnapshot>(
  (ref) => ref.watch(catalogProvider).requireValue.snapshot,
);

/// Queries on large tables (learnsets, moves, search).
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

  /// Selects a game or the International Pokédex and remembers recent games.
  void setGameVersion(GameVersionId id) {
    final national = NationalDex.isNational(id);
    _update(
      state.copyWith(
        gameVersion: () => national ? null : id.value,
        recentGames: national
            ? null
            : [
                id.value,
                ...state.recentGames.where((g) => g != id.value),
              ].take(AppSettings.maxRecentGames).toList(),
      ),
    );
  }

  void setReduceMotion(bool value) =>
      _update(state.copyWith(reduceMotion: value));

  void setDexLayout(DexLayout layout) =>
      _update(state.copyWith(dexLayout: layout));

  void setDataLanguage(String? language) =>
      _update(state.copyWith(dataLanguage: () => language));

  void setUiLanguage(String? language) =>
      _update(state.copyWith(uiLanguage: () => language));

  /// Applies settings from a backup.
  void replaceAll(AppSettings settings) => _update(settings);
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// The current game context (ADR 0004). All game-dependent views depend on
/// it, so switching games updates them consistently.
final gameContextProvider = Provider<GameContext>((ref) {
  final catalog = ref.watch(readyCatalogProvider);
  final selected = ref.watch(settingsProvider.select((s) => s.gameVersion));
  if (selected != null && catalog.hasVersion(GameVersionId(selected))) {
    return catalog.contextFor(GameVersionId(selected));
  }
  // No game chosen (or one that no longer exists): International Pokédex.
  return catalog.defaultContext;
});

/// Whether the International Pokédex is selected.
final isNationalProvider = Provider<bool>(
  (ref) => NationalDex.isNational(ref.watch(gameContextProvider).versionId),
);

/// Collection marks in a context: per game, or – in the International
/// Pokédex – the global, game-independent list (ADR 0016).
CollectionScope collectionScopeOf(GameContext ctx) =>
    NationalDex.isNational(ctx.versionId)
    ? const GlobalScope()
    : GameScope(ctx.versionId);

/// Language of the game data: setting or app language.
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
      state = previous; // never let the display differ from the stored data
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

  /// Creates a team for the selected game.
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

/// Validation and analysis in the context of the team's game (not the global
/// one). A game this catalog does not know (e.g. from a backup or another
/// device) falls back to the International Pokédex instead of failing.
TeamEvaluator evaluatorFor(WidgetRef ref, Team team) {
  final catalog = ref.watch(readyCatalogProvider);
  return TeamEvaluator(
    catalog,
    ref.watch(catalogDetailsProvider),
    catalog.hasVersion(team.version)
        ? catalog.contextFor(team.version)
        : catalog.defaultContext,
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

/// Active filter of the Dex list (not stored; presets store it).
final dexFilterProvider = NotifierProvider<DexFilterController, DexFilter>(
  DexFilterController.new,
);
