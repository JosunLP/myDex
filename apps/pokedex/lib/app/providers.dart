import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_user_store/mydex_user_store.dart';

import 'catalog_loader.dart';
import 'settings.dart';

/// Ablageort der persönlichen Daten.
class AppStorage {
  AppStorage(Directory dir)
    : collection = FileCollectionRepository(
        File('${dir.path}/collection.json'),
      ),
      preferences = JsonPreferencesRepository(
        File('${dir.path}/preferences.json'),
      ),
      catalogDirectory = Directory('${dir.path}/catalog');

  AppStorage.custom({
    required this.collection,
    required this.preferences,
    required this.catalogDirectory,
  });

  final CollectionRepository collection;
  final JsonPreferencesRepository preferences;

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
