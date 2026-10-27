import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

import 'pokemon_queries.dart';

/// Filters a Dex list. The collection status refers to [scope].
List<PokemonListItem> applyDexFilter(
  List<PokemonListItem> items,
  DexFilter filter, {
  required Map<CollectionKey, CollectionEntry> collection,
  required CollectionScope scope,
}) {
  if (filter.isEmpty) return items;
  bool caught(FormId form, {bool shiny = false}) =>
      collection[CollectionKey(scope: scope, form: form, shiny: shiny)]
          ?.caught ??
      false;
  return [
    for (final item in items)
      if ((!filter.defaultFormsOnly || item.form.isDefault) &&
          (filter.generations.isEmpty ||
              filter.generations.contains(item.species.generation)) &&
          filter.matchesTypes(item.profile.types) &&
          switch (filter.collection) {
            CollectionFilter.all => true,
            CollectionFilter.caught => caught(item.form.id),
            CollectionFilter.missing => !caught(item.form.id),
            CollectionFilter.shinyMissing => !caught(item.form.id, shiny: true),
          })
        item,
  ];
}

/// Progress of a form across all games.
@immutable
class CrossGameStatus {
  const CrossGameStatus({
    required this.caughtIn,
    required this.shinyCaughtIn,
    this.firstCaughtAt,
  });

  final Set<GameVersionId> caughtIn;
  final Set<GameVersionId> shinyCaughtIn;
  final DateTime? firstCaughtAt;

  bool get caught => caughtIn.isNotEmpty;
  bool get shinyCaught => shinyCaughtIn.isNotEmpty;
}

/// Combines the marks of all games per form (global checklist).
/// The separate "global" list also counts as caught.
Map<FormId, CrossGameStatus> crossGameOverview(
  Iterable<CollectionEntry> entries,
) {
  final caught = <FormId, Set<GameVersionId>>{};
  final shiny = <FormId, Set<GameVersionId>>{};
  final first = <FormId, DateTime>{};
  const global = GameVersionId('');
  for (final e in entries) {
    if (!e.caught) continue;
    final version = switch (e.key.scope) {
      GameScope(:final game) => game,
      GlobalScope() => global,
    };
    (e.key.shiny ? shiny : caught)
        .putIfAbsent(e.key.form, () => {})
        .add(version);
    if (e.caughtAt case final at?) {
      final current = first[e.key.form];
      if (current == null || at.isBefore(current)) first[e.key.form] = at;
    }
  }
  return {
    for (final form in {...caught.keys, ...shiny.keys})
      form: CrossGameStatus(
        caughtIn: caught[form] ?? const {},
        shinyCaughtIn: shiny[form] ?? const {},
        firstCaughtAt: first[form],
      ),
  };
}
