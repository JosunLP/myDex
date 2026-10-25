import 'dart:convert';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';

/// Ein Katalogpaket verletzt Schema- oder Referenzregeln.
class CatalogValidationException implements Exception {
  CatalogValidationException(this.problems);
  final List<String> problems;

  @override
  String toString() =>
      'Ungültiges Katalogpaket (${problems.length} Probleme):\n- ${problems.join('\n- ')}';
}

/// Unterstützte Schemaversionen des Katalogformats.
const supportedCatalogSchemas = {1};

/// Parst ein JSON-Katalogpaket und prüft alle Referenzen, bevor es aktiviert
/// werden darf. Ein ungültiges Paket wird vollständig abgelehnt.
CatalogSnapshot parseCatalogJson(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    throw CatalogValidationException(['Kein gültiges JSON: ${e.message}']);
  }
  if (decoded is! Map<String, Object?>) {
    throw CatalogValidationException(['Wurzel muss ein Objekt sein']);
  }
  final schema = decoded['schemaVersion'];
  if (!supportedCatalogSchemas.contains(schema)) {
    throw CatalogValidationException([
      'Nicht unterstützte Schemaversion: $schema',
    ]);
  }

  List<T> list<T>(String key, T Function(Map<String, Object?>) parse) => [
    for (final e in (decoded as Map<String, Object?>)[key]! as List<Object?>)
      parse(e! as Map<String, Object?>),
  ];

  final CatalogSnapshot snapshot;
  try {
    snapshot = CatalogSnapshot(
      revision: decoded['revision']! as String,
      schemaVersion: schema! as int,
      rulesets: list('rulesets', Ruleset.fromJson),
      versionGroups: list('versionGroups', VersionGroup.fromJson),
      versions: list('versions', GameVersion.fromJson),
      species: list('species', Species.fromJson),
      forms: list('forms', PokemonForm.fromJson),
      abilities: list('abilities', Ability.fromJson),
      itemNames: {
        for (final i in list('items', (j) => j))
          ItemId(i['id']! as String): LocalizedText.fromJson(
            i['name']! as Map<String, Object?>,
          ),
      },
      evolutions: list('evolutions', EvolutionEdge.fromJson),
    );
  } on FormatException catch (e) {
    throw CatalogValidationException([e.message]);
  } on TypeError catch (e) {
    throw CatalogValidationException(['Feld fehlt oder hat falschen Typ: $e']);
  } on StateError catch (e) {
    throw CatalogValidationException([e.message]);
  }

  final problems = validateCatalog(snapshot);
  if (problems.isNotEmpty) throw CatalogValidationException(problems);
  return snapshot;
}

/// Referenz- und Plausibilitätsprüfungen.
List<String> validateCatalog(CatalogSnapshot c) {
  final p = <String>[];
  if (c.versions.isEmpty) p.add('Keine Spielversionen');
  for (final g in c.versionGroups.values) {
    if (!c.rulesets.containsKey(g.rulesetId)) {
      p.add(
        'Spielgruppe ${g.id.value}: unbekanntes Regelwerk ${g.rulesetId.value}',
      );
    }
  }
  for (final v in c.versions) {
    if (!c.versionGroups.containsKey(v.versionGroupId)) {
      p.add('Version ${v.id.value}: unbekannte Spielgruppe');
    }
  }
  for (final f in c.forms.values) {
    if (!c.species.containsKey(f.speciesId)) {
      p.add('Form ${f.id.value}: unbekannte Art ${f.speciesId.value}');
    }
    for (final MapEntry(key: groupId, value: profile) in f.profiles.entries) {
      final group = c.versionGroups[groupId];
      if (group == null) {
        p.add('Form ${f.id.value}: unbekannte Spielgruppe ${groupId.value}');
        continue;
      }
      final ruleset = c.rulesets[group.rulesetId];
      if (ruleset == null) continue;
      final where = 'Form ${f.id.value} in ${groupId.value}';
      if (profile.availability == DataAvailability.confirmedAvailable) {
        if (profile.types.isEmpty || profile.types.length > 2) {
          p.add('$where: 1–2 Typen erwartet');
        }
        if (profile.baseStats == null) p.add('$where: Basiswerte fehlen');
      }
      final chart = TypeChart.forEra(ruleset.typeChartEra);
      for (final t in profile.types) {
        if (!chart.contains(t)) {
          p.add('$where: Typ ${t.key} existiert in dieser Ära nicht');
        }
      }
      if (!ruleset.hasAbilities && profile.abilities.isNotEmpty) {
        p.add('$where: Regelwerk kennt keine Fähigkeiten');
      }
      for (final a in profile.abilities) {
        if (!c.abilities.containsKey(a.abilityId)) {
          p.add('$where: unbekannte Fähigkeit ${a.abilityId.value}');
        }
      }
    }
    final defaults = c.forms.values.where(
      (x) => x.speciesId == f.speciesId && x.isDefault,
    );
    if (defaults.length != 1) {
      p.add('Art ${f.speciesId.value}: genau eine Standardform erwartet');
    }
  }
  for (final e in c.evolutions) {
    final edge = '${e.from.value} → ${e.to.value}';
    if (!c.forms.containsKey(e.from) || !c.forms.containsKey(e.to)) {
      p.add('Entwicklung $edge: unbekannte Form');
    }
    for (final g in e.versionGroups) {
      if (!c.versionGroups.containsKey(g)) {
        p.add('Entwicklung $edge: unbekannte Spielgruppe ${g.value}');
      }
    }
    for (final item in e.condition.referencedItems) {
      if (!c.itemNames.containsKey(item)) {
        p.add('Entwicklung $edge: unbekanntes Item ${item.value}');
      }
    }
  }
  return p.toSet().toList();
}

/// Katalog aus einer beliebigen Quelle (Asset, Datei), z. B. das gebündelte Paket.
class JsonCatalogRepository implements CatalogRepository {
  JsonCatalogRepository(this._read);

  final Future<String> Function() _read;
  Future<CatalogSnapshot>? _cached;

  @override
  Future<CatalogSnapshot> load() => _cached ??= _loadOnce();

  Future<CatalogSnapshot> _loadOnce() async {
    try {
      return parseCatalogJson(await _read());
    } catch (_) {
      _cached = null; // beim nächsten Aufruf erneut versuchen
      rethrow;
    }
  }
}
