import 'dart:convert';
import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'atomic_file.dart';

/// Sammlung als JSON-Datei. Schreibt atomar (temporäre Datei + Umbenennen),
/// damit ein Absturz nie zu einer halb geschriebenen Datei führt.
/// Wird später durch eine Drift-Datenbank hinter derselben Schnittstelle ersetzt.
class FileCollectionRepository implements CollectionRepository {
  FileCollectionRepository(this.file);

  static const schemaVersion = 1;

  final File file;
  Map<CollectionKey, CollectionEntry>? _entries;
  Future<void> _writeQueue = Future.value();

  /// Pfad einer beschädigten Datei, die beim Laden beiseitegelegt wurde.
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
    // Schreibvorgänge strikt nacheinander ausführen.
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
          throw FormatException('Unbekannte Schemaversion: $version');
        }
        for (final e in json['entries']! as List<Object?>) {
          final entry = CollectionEntry.fromJson(e! as Map<String, Object?>);
          result[entry.key] = entry;
        }
      } on Object catch (_) {
        // Nie still verwerfen: beschädigte Datei für Wiederherstellung aufheben.
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
