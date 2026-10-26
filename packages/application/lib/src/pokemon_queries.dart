import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'catalog_snapshot.dart';

@immutable
class PokemonListItem {
  const PokemonListItem({
    required this.form,
    required this.species,
    required this.profile,
  });

  final PokemonForm form;
  final Species species;
  final FormGameProfile profile;
}

@immutable
class ResolvedAbility {
  const ResolvedAbility(this.ability, {required this.hidden});
  final Ability ability;
  final bool hidden;
}

@immutable
class ResolvedEvolution {
  const ResolvedEvolution(this.from, this.to, this.condition);
  final PokemonForm from;
  final PokemonForm to;
  final EvolutionCondition condition;
}

/// Alles, was eine Detailseite im gewählten Spielkontext zeigt.
@immutable
class PokemonDetail {
  const PokemonDetail({
    required this.context,
    required this.form,
    required this.species,
    required this.profile,
    required this.abilities,
    required this.evolutions,
    required this.otherForms,
  });

  final GameContext context;
  final PokemonForm form;
  final Species species;
  final FormGameProfile profile;
  final List<ResolvedAbility> abilities;

  /// Entwicklungsfamilie in diesem Spielkontext (nur hier gültige Kanten).
  final List<ResolvedEvolution> evolutions;
  final List<PokemonForm> otherForms;

  /// Fähigkeiten gibt es erst ab Gen 3: dann „nicht anwendbar“ statt leer.
  bool get abilitiesApplicable => context.ruleset.hasAbilities;
}

/// Lesende Anwendungsfälle, alle explizit im Spielkontext (ADR 0004).
class PokemonQueries {
  const PokemonQueries(this.catalog);

  final CatalogSnapshot catalog;

  /// Formen, sortiert nach nationaler Nummer (Standardform zuerst).
  /// Bestätigt nicht existierende Formen werden ausgeblendet, Datenlücken nicht.
  List<PokemonListItem> list(
    GameContext ctx, {
    bool includeUnavailable = false,
  }) {
    final items = <PokemonListItem>[
      for (final form in catalog.forms.values)
        if (includeUnavailable ||
            !_excluded(form.profileFor(ctx.versionGroupId).availability))
          PokemonListItem(
            form: form,
            species: catalog.species[form.speciesId]!,
            profile: form.profileFor(ctx.versionGroupId),
          ),
    ];
    items.sort((a, b) {
      final n = a.species.nationalNumber.compareTo(b.species.nationalNumber);
      if (n != 0) return n;
      if (a.form.isDefault != b.form.isDefault) {
        return a.form.isDefault ? -1 : 1;
      }
      return a.form.id.value.compareTo(b.form.id.value);
    });
    return items;
  }

  static bool _excluded(DataAvailability a) =>
      a == DataAvailability.confirmedUnavailable ||
      a == DataAvailability.notApplicable;

  PokemonDetail detail(FormId id, GameContext ctx) {
    final form = catalog.forms[id];
    if (form == null) throw ArgumentError('Unbekannte Form: ${id.value}');
    final profile = form.profileFor(ctx.versionGroupId);
    return PokemonDetail(
      context: ctx,
      form: form,
      species: catalog.species[form.speciesId]!,
      profile: profile,
      abilities: [
        for (final slot in profile.abilities)
          ResolvedAbility(
            catalog.abilities[slot.abilityId]!,
            hidden: slot.hidden,
          ),
      ],
      evolutions: _family(form, ctx.versionGroupId),
      otherForms: [
        for (final f in catalog.forms.values)
          if (f.speciesId == form.speciesId && f.id != form.id) f,
      ],
    );
  }

  List<ResolvedEvolution> _family(PokemonForm form, VersionGroupId group) {
    final edges = [
      for (final e in catalog.evolutions)
        if (e.versionGroups.contains(group)) e,
    ];
    // Zur Wurzel der Familie laufen, dann alle erreichbaren Kanten sammeln.
    var root = form.id;
    final visited = <FormId>{root};
    while (true) {
      final parent = edges.where((e) => e.to == root).firstOrNull;
      if (parent == null || !visited.add(parent.from)) break;
      root = parent.from;
    }
    final result = <ResolvedEvolution>[];
    final queue = [root];
    final seen = <FormId>{root};
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final e in edges.where((e) => e.from == current)) {
        result.add(
          ResolvedEvolution(
            catalog.forms[e.from]!,
            catalog.forms[e.to]!,
            e.condition,
          ),
        );
        if (seen.add(e.to)) queue.add(e.to);
      }
    }
    return result;
  }
}

/// Vorentwicklungen einer Form im Spiel, nächste zuerst (z. B. Raichu → Pikachu, Pichu).
/// Ihre Attacken bleiben beim Entwickeln erhalten.
List<FormId> preEvolutionsOf(
  CatalogSnapshot catalog,
  FormId form,
  VersionGroupId group,
) {
  final result = <FormId>[];
  var current = form;
  while (true) {
    final edge = catalog.evolutions
        .where((e) => e.to == current && e.versionGroups.contains(group))
        .firstOrNull;
    if (edge == null || edge.from == form || result.contains(edge.from)) break;
    result.add(edge.from);
    current = edge.from;
  }
  return result;
}
