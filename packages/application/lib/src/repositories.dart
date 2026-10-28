import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_details.dart';
import 'catalog_snapshot.dart';

/// A loaded catalog: core data in memory, large tables on demand.
class LoadedCatalog {
  const LoadedCatalog(this.snapshot, this.details);
  final CatalogSnapshot snapshot;
  final CatalogDetails details;
}

/// Read-only public catalog (ADR 0003).
abstract interface class CatalogRepository {
  Future<LoadedCatalog> load();
}

/// Personal collection data, separate from the catalog.
abstract interface class CollectionRepository {
  Future<Map<CollectionKey, CollectionEntry>> loadAll();

  /// Saves an entry; empty entries are removed.
  Future<void> put(CollectionEntry entry);

  /// Replaces all entries (import).
  Future<void> replaceAll(Iterable<CollectionEntry> entries);
}

/// Personal teams, separate from the catalog.
abstract interface class TeamRepository {
  Future<List<Team>> loadAll();

  Future<void> save(Team team);

  Future<void> delete(String id);

  /// Replaces all teams (import).
  Future<void> replaceAll(Iterable<Team> teams);
}

/// Saved filter presets.
abstract interface class FilterPresetRepository {
  Future<List<FilterPreset>> loadAll();

  Future<void> save(FilterPreset preset);

  Future<void> delete(String id);

  Future<void> replaceAll(Iterable<FilterPreset> presets);
}
