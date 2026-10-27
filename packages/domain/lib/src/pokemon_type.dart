/// The 18 types. Which of them exist in a game is decided by the ruleset's
/// type chart (e.g. no Dark/Steel in Gen 1).
enum PokemonType {
  normal,
  fire,
  water,
  electric,
  grass,
  ice,
  fighting,
  poison,
  ground,
  flying,
  psychic,
  bug,
  rock,
  ghost,
  dragon,
  dark,
  steel,
  fairy;

  /// Stable key for data packs and localization.
  String get key => name;

  static PokemonType parse(String key) => PokemonType.values.firstWhere(
    (t) => t.key == key,
    orElse: () => throw FormatException('Unknown type: $key'),
  );
}
