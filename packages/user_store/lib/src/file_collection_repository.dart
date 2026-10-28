import 'dart:convert';
import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'atomic_file.dart';

/// Collection as a JSON file. Writes atomically (temporary file + rename) so
/// that a crash never leads to a half-written file.
/// May later be replaced by a database behind the same interface.
class FileCollectionRepository implements CollectionRepository {
  FileCollectionRepository(this.file);

  static const schemaVersion = 1;

  final File file;
  Map<CollectionKey, CollectionEntry>? _entries;
  Future<void> _writeQueue = Future.value();

  /// Path of a corrupted file that was set aside while loading.
  String? quarantinedPath;

  @override
  Future<Map<CollectionKey, CollectionEntry>> loadAll() async =>
      Map.of(await _load());

  @override
  Future<void> put(CollectionEntry entry) async {
    final entries = await _load();
    if (entry.isEmpty) {
      entries.remove(entry.key);
    } else {
      entries[entry.key] = entry;
    }
    final snapshot = _encode(entries);
    // Run writes strictly one after another.
    final write = _writeQueue.then((_) => _writeAtomic(snapshot));
    _writeQueue = write.catchError((Object _) {});
    return write;
  }

  @override
  Future<void> replaceAll(Iterable<CollectionEntry> entries) async {
    final current = await _load();
    current
      ..clear()
      ..addAll({
        for (final e in entries)
          if (!e.isEmpty) e.key: e,
      });
    final snapshot = _encode(current);
    final write = _writeQueue.then((_) => _writeAtomic(snapshot));
    _writeQueue = write.catchError((Object _) {});
    return write;
  }

  Future<Map<CollectionKey, CollectionEntry>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    final result = <CollectionKey, CollectionEntry>{};
    if (await file.exists()) {
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, Object?>;
        final version = json['schemaVersion'];
        if (version != schemaVersion) {
          throw FormatException('Unknown schema version: $version');
        }
        for (final e in json['entries']! as List<Object?>) {
          final entry = CollectionEntry.fromJson(e! as Map<String, Object?>);
          result[entry.key] = entry;
        }
      } on Object catch (_) {
        // Never discard silently: keep the corrupted file for recovery.
        final target =
            '${file.path}.corrupt-${DateTime.now().toUtc().millisecondsSinceEpoch}';
        await file.rename(target);
        quarantinedPath = target;
        result.clear();
      }
    }
    return _entries ??= result;
  }

  String _encode(Map<CollectionKey, CollectionEntry> entries) {
    final sorted = entries.values.toList()
      ..sort((a, b) => a.key.encoded.compareTo(b.key.encoded));
    return const JsonEncoder.withIndent(' ').convert({
      'schemaVersion': schemaVersion,
      'entries': [for (final e in sorted) e.toJson()],
    });
  }

  Future<void> _writeAtomic(String content) => writeFileAtomic(file, content);
}
