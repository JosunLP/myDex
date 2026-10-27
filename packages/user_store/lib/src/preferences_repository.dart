import 'dart:convert';
import 'dart:io';

import 'atomic_file.dart';

/// Small settings file (theme, selected game, data language).
/// Unreadable files lead to defaults instead of a crash.
class JsonPreferencesRepository {
  JsonPreferencesRepository(this.file);

  final File file;
  Future<void> _queue = Future.value();

  Future<Map<String, Object?>> load() async {
    try {
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, Object?> ? decoded : {};
    } on Object catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, Object?> values) {
    final content = jsonEncode(values);
    final write = _queue.then((_) => writeFileAtomic(file, content));
    _queue = write.catchError((Object _) {});
    return write;
  }
}
