import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_details.dart';
import 'catalog_snapshot.dart';

/// Ein geladener Katalog: Kerndaten im Speicher, große Tabellen auf Abruf.
class LoadedCatalog {
  const LoadedCatalog(this.snapshot, this.details);
  final CatalogSnapshot snapshot;
  final CatalogDetails details;
}

/// Nur lesbarer öffentlicher Katalog (ADR 0003).
abstract interface class CatalogRepository {
  Future<LoadedCatalog> load();
}

/// Persönliche Sammlungsdaten, getrennt vom Katalog.
abstract interface class CollectionRepository {
  Future<Map<CollectionKey, CollectionEntry>> loadAll();

  /// Speichert einen Eintrag; leere Einträge werden entfernt.
  Future<void> put(CollectionEntry entry);

  /// Ersetzt alle Einträge (Import).
  Future<void> replaceAll(Iterable<CollectionEntry> entries);
}

/// Persönliche Teams, getrennt vom Katalog.
abstract interface class TeamRepository {
  Future<List<Team>> loadAll();

  Future<void> save(Team team);

  Future<void> delete(String id);

  /// Ersetzt alle Teams (Import).
  Future<void> replaceAll(Iterable<Team> teams);
}

/// Gespeicherte Filtervorlagen.
abstract interface class FilterPresetRepository {
  Future<List<FilterPreset>> loadAll();

  Future<void> save(FilterPreset preset);

  Future<void> delete(String id);

  Future<void> replaceAll(Iterable<FilterPreset> presets);
}
