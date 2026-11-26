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

/// Everything a detail page shows in the selected game context.
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

  /// Evolution family in this game context (only edges valid here).
  final List<ResolvedEvolution> evolutions;
  final List<PokemonForm> otherForms;

  /// Abilities only exist from Gen 3: then "not applicable" instead of empty.
  bool get abilitiesApplicable => context.ruleset.hasAbilities;
}

/// Read-only use cases, all explicitly in the game context (ADR 0004).
class PokemonQueries {
  const PokemonQueries(this.catalog);

  final CatalogSnapshot catalog;

  /// Forms, sorted by national number (default form first).
  /// Forms confirmed not to exist are hidden, data gaps are not.
  List<PokemonListItem> list(
    GameContext ctx, {
    bool includeUnavailable = false,
  }) {
    final items = <PokemonListItem>[
      for (final form in catalog.forms.values)
        if (includeUnavailable ||
            !_excluded(
              catalog.profileOf(form, ctx.versionGroupId).availability,
            ))
          PokemonListItem(
            form: form,
            species: catalog.species[form.speciesId]!,
            profile: catalog.profileOf(form, ctx.versionGroupId),
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
    if (form == null) throw ArgumentError('Unknown form: ${id.value}');
    final profile = catalog.profileOf(form, ctx.versionGroupId);
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
    final edges = catalog.evolutionsIn(group);
    // Walk to the root of the family, then collect all reachable edges.
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

/// Pre-evolutions of a form in the game, closest first (e.g. Raichu → Pikachu, Pichu).
/// Their moves are kept on evolution.
List<FormId> preEvolutionsOf(
  CatalogSnapshot catalog,
  FormId form,
  VersionGroupId group,
) {
  final result = <FormId>[];
  var current = form;
  while (true) {
    final edge = catalog
        .evolutionsIn(group)
        .where((e) => e.to == current)
        .firstOrNull;
    if (edge == null || edge.from == form || result.contains(edge.from)) break;
    result.add(edge.from);
    current = edge.from;
  }
  return result;
}
