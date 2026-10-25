import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';

/// Ein Katalogpaket verletzt Schema- oder Referenzregeln.
class CatalogValidationException implements Exception {
  CatalogValidationException(this.problems);
  final List<String> problems;

  @override
  String toString() =>
      'Ungültiges Katalogpaket (${problems.length} Probleme):\n- ${problems.take(50).join('\n- ')}';
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
