import 'dart:convert';
import 'dart:io';

import 'atomic_file.dart';

/// Gemeinsame Basis für Nutzerdaten als JSON-Datei: atomares Schreiben,
/// Schreibvorgänge nacheinander, beschädigte Dateien werden aufbewahrt.
class JsonFileStore {
  JsonFileStore(this.file, {required this.schemaVersion});

  final File file;
  final int schemaVersion;
  Future<void> _queue = Future.value();

  /// Pfad einer beschädigten Datei, die beim Laden beiseitegelegt wurde.
  String? quarantinedPath;

  /// Liefert die Einträge (`entries`) oder eine leere Liste.
  Future<List<Map<String, Object?>>> read() async {
    if (!await file.exists()) return [];
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, Object?>;
      if (json['schemaVersion'] != schemaVersion) {
        throw FormatException(
          'Unbekannte Schemaversion: ${json['schemaVersion']}',
        );
      }
      return [
        for (final e in json['entries']! as List<Object?>)
          e! as Map<String, Object?>,
      ];
    } on Object catch (_) {
      final target =
          '${file.path}.corrupt-${DateTime.now().toUtc().millisecondsSinceEpoch}';
      await file.rename(target);
      quarantinedPath = target;
      return [];
    }
  }

  Future<void> write(List<Map<String, Object?>> entries) {
    final content = const JsonEncoder.withIndent(
      ' ',
    ).convert({'schemaVersion': schemaVersion, 'entries': entries});
    final write = _queue.then((_) => writeFileAtomic(file, content));
    _queue = write.catchError((Object _) {});
    return write;
  }
}
