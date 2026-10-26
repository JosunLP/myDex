import 'package:meta/meta.dart';

import 'pokemon_type.dart';

enum TypeMatch {
  /// Mindestens einer der gewählten Typen.
  any,

  /// Alle gewählten Typen (bei zwei Typen: genau diese Kombination).
  all,
}

enum CollectionFilter { all, caught, missing, shinyMissing }

/// Kombinierbare Filter der Dex-Liste. Zwischen Gruppen gilt UND.
@immutable
class DexFilter {
  const DexFilter({
    this.types = const {},
    this.typeMatch = TypeMatch.any,
    this.generations = const {},
    this.collection = CollectionFilter.all,
    this.defaultFormsOnly = false,
  });

  /// Liest Filter beliebiger bekannter Versionen; unbekannte Werte werden ignoriert.
  factory DexFilter.fromJson(Map<String, Object?> j) => DexFilter(
    types: {
      for (final t in (j['types'] as List<Object?>?) ?? const <Object?>[])
        ?PokemonType.values.where((v) => v.key == t).firstOrNull,
    },
    typeMatch:
        TypeMatch.values.where((m) => m.name == j['typeMatch']).firstOrNull ??
        TypeMatch.any,
    generations: {
      for (final g in (j['generations'] as List<Object?>?) ?? const <Object?>[])
        if (g is int) g,
    },
    collection:
        CollectionFilter.values
            .where((c) => c.name == j['collection'])
            .firstOrNull ??
        CollectionFilter.all,
    defaultFormsOnly: (j['defaultFormsOnly'] as bool?) ?? false,
  );

  final Set<PokemonType> types;
  final TypeMatch typeMatch;
  final Set<int> generations;
  final CollectionFilter collection;
  final bool defaultFormsOnly;

  bool get isEmpty =>
      types.isEmpty &&
      generations.isEmpty &&
      collection == CollectionFilter.all &&
      !defaultFormsOnly;

  int get activeCount =>
      (types.isEmpty ? 0 : 1) +
      (generations.isEmpty ? 0 : 1) +
      (collection == CollectionFilter.all ? 0 : 1) +
      (defaultFormsOnly ? 1 : 0);

  /// Prüft die Typbedingung für die Typen einer Form.
  bool matchesTypes(List<PokemonType> formTypes) {
    if (types.isEmpty) return true;
    return switch (typeMatch) {
      TypeMatch.any => formTypes.any(types.contains),
      TypeMatch.all => types.every(formTypes.contains),
    };
  }

  DexFilter copyWith({
    Set<PokemonType>? types,
    TypeMatch? typeMatch,
    Set<int>? generations,
    CollectionFilter? collection,
    bool? defaultFormsOnly,
  }) => DexFilter(
    types: types ?? this.types,
    typeMatch: typeMatch ?? this.typeMatch,
    generations: generations ?? this.generations,
    collection: collection ?? this.collection,
    defaultFormsOnly: defaultFormsOnly ?? this.defaultFormsOnly,
  );

  Map<String, Object?> toJson() => {
    if (types.isNotEmpty)
      'types': [
        for (final t in PokemonType.values)
          if (types.contains(t)) t.key,
      ],
    if (typeMatch != TypeMatch.any) 'typeMatch': typeMatch.name,
    if (generations.isNotEmpty) 'generations': generations.toList()..sort(),
    if (collection != CollectionFilter.all) 'collection': collection.name,
    if (defaultFormsOnly) 'defaultFormsOnly': true,
  };

  @override
  bool operator ==(Object other) =>
      other is DexFilter &&
      other.typeMatch == typeMatch &&
      other.collection == collection &&
      other.defaultFormsOnly == defaultFormsOnly &&
      other.types.length == types.length &&
      other.types.containsAll(types) &&
      other.generations.length == generations.length &&
      other.generations.containsAll(generations);

  @override
  int get hashCode => Object.hash(
    typeMatch,
    collection,
    defaultFormsOnly,
    Object.hashAllUnordered(types),
    Object.hashAllUnordered(generations),
  );
}

/// Gespeicherte Filtervorlage. Das Format ist versioniert, damit alte
/// Vorlagen bei Änderungen der Filter migriert werden können.
@immutable
class FilterPreset {
  const FilterPreset({
    required this.id,
    required this.name,
    required this.filter,
    required this.updatedAt,
  });

  static const formatVersion = 1;

  factory FilterPreset.fromJson(Map<String, Object?> j) => FilterPreset(
    id: j['id']! as String,
    name: j['name']! as String,
    filter: DexFilter.fromJson(
      (j['filter'] as Map<String, Object?>?) ?? const {},
    ),
    updatedAt: DateTime.parse(j['updatedAt']! as String),
  );

  final String id;
  final String name;
  final DexFilter filter;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'version': formatVersion,
    'filter': filter.toJson(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
