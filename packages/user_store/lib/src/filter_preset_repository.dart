import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'json_file_store.dart';

/// Filtervorlagen als JSON-Datei.
class FileFilterPresetRepository implements FilterPresetRepository {
  FileFilterPresetRepository(File file)
    : _store = JsonFileStore(file, schemaVersion: 1);

  final JsonFileStore _store;
  Map<String, FilterPreset>? _presets;

  Future<Map<String, FilterPreset>> _load() async {
    if (_presets case final p?) return p;
    final result = <String, FilterPreset>{};
    for (final j in await _store.read()) {
      try {
        final preset = FilterPreset.fromJson(j);
        result[preset.id] = preset;
      } on Object {
        // Unlesbare Vorlage überspringen.
      }
    }
    return _presets = result;
  }

  @override
  Future<List<FilterPreset>> loadAll() async =>
      (await _load()).values.toList()..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<void> save(FilterPreset preset) async {
    (await _load())[preset.id] = preset;
    await _persist();
  }

  @override
  Future<void> delete(String id) async {
    (await _load()).remove(id);
    await _persist();
  }

  @override
  Future<void> replaceAll(Iterable<FilterPreset> presets) async {
    (await _load())
      ..clear()
      ..addAll({for (final p in presets) p.id: p});
    await _persist();
  }

  Future<void> _persist() async {
    final sorted = (await _load()).values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    await _store.write([for (final p in sorted) p.toJson()]);
  }
}

class MemoryFilterPresetRepository implements FilterPresetRepository {
  final _presets = <String, FilterPreset>{};

  @override
  Future<List<FilterPreset>> loadAll() async =>
      _presets.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<void> save(FilterPreset preset) async => _presets[preset.id] = preset;

  @override
  Future<void> delete(String id) async => _presets.remove(id);

  @override
  Future<void> replaceAll(Iterable<FilterPreset> presets) async {
    _presets
      ..clear()
      ..addAll({for (final p in presets) p.id: p});
  }
}
