import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Flüchtiger Speicher für Tests und Vorschauen.
class MemoryCollectionRepository implements CollectionRepository {
  final _entries = <CollectionKey, CollectionEntry>{};

  @override
  Future<Map<CollectionKey, CollectionEntry>> loadAll() async =>
      Map.of(_entries);

  @override
  Future<void> put(CollectionEntry entry) async {
    if (entry.isEmpty) {
      _entries.remove(entry.key);
    } else {
      _entries[entry.key] = entry;
    }
  }
}
