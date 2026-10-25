import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_snapshot.dart';

/// Nur lesbarer öffentlicher Katalog (ADR 0003).
abstract interface class CatalogRepository {
  Future<CatalogSnapshot> load();
}

/// Persönliche Sammlungsdaten, getrennt vom Katalog.
abstract interface class CollectionRepository {
  Future<Map<CollectionKey, CollectionEntry>> loadAll();

  /// Speichert einen Eintrag; leere Einträge werden entfernt.
  Future<void> put(CollectionEntry entry);
}
