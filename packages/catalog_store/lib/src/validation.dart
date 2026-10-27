import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';

/// A catalog pack violates schema or reference rules.
class CatalogValidationException implements Exception {
  CatalogValidationException(this.problems);
  final List<String> problems;

  @override
  String toString() =>
      'Invalid catalog pack (${problems.length} problems):\n- ${problems.take(50).join('\n- ')}';
}

/// Reference and plausibility checks.
List<String> validateCatalog(CatalogSnapshot c) {
  final p = <String>[];
  if (c.versions.isEmpty) p.add('No game versions');
  for (final g in c.versionGroups.values) {
    if (!c.rulesets.containsKey(g.rulesetId)) {
      p.add(
        'Version group ${g.id.value}: unknown ruleset ${g.rulesetId.value}',
      );
    }
  }
  for (final v in c.versions) {
    if (!c.versionGroups.containsKey(v.versionGroupId)) {
      p.add('Version ${v.id.value}: unknown version group');
    }
  }
  for (final f in c.forms.values) {
    if (!c.species.containsKey(f.speciesId)) {
      p.add('Form ${f.id.value}: unknown species ${f.speciesId.value}');
    }
    for (final MapEntry(key: groupId, value: profile) in f.profiles.entries) {
      final group = c.versionGroups[groupId];
      if (group == null) {
        p.add('Form ${f.id.value}: unknown version group ${groupId.value}');
        continue;
      }
      final ruleset = c.rulesets[group.rulesetId];
      if (ruleset == null) continue;
      final where = 'Form ${f.id.value} in ${groupId.value}';
      if (profile.availability == DataAvailability.confirmedAvailable) {
        if (profile.types.isEmpty || profile.types.length > 2) {
          p.add('$where: 1–2 types expected');
        }
        if (profile.baseStats == null) p.add('$where: base stats missing');
      }
      final chart = TypeChart.forEra(ruleset.typeChartEra);
      for (final t in profile.types) {
        if (!chart.contains(t)) {
          p.add('$where: type ${t.key} does not exist in this era');
        }
      }
      if (!ruleset.hasAbilities && profile.abilities.isNotEmpty) {
        p.add('$where: ruleset has no abilities');
      }
      for (final a in profile.abilities) {
        if (!c.abilities.containsKey(a.abilityId)) {
          p.add('$where: unknown ability ${a.abilityId.value}');
        }
      }
    }
    final defaults = c.forms.values.where(
      (x) => x.speciesId == f.speciesId && x.isDefault,
    );
    if (defaults.length != 1) {
      p.add('Species ${f.speciesId.value}: exactly one default form expected');
    }
  }
  for (final e in c.evolutions) {
    final edge = '${e.from.value} → ${e.to.value}';
    if (!c.forms.containsKey(e.from) || !c.forms.containsKey(e.to)) {
      p.add('Evolution $edge: unknown form');
    }
    for (final g in e.versionGroups) {
      if (!c.versionGroups.containsKey(g)) {
        p.add('Evolution $edge: unknown version group ${g.value}');
      }
    }
    for (final item in e.condition.referencedItems) {
      if (!c.itemNames.containsKey(item)) {
        p.add('Evolution $edge: unknown item ${item.value}');
      }
    }
  }
  return p.toSet().toList();
}
