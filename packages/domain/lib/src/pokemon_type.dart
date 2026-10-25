/// Die 18 Typen. Welche davon in einem Spiel existieren, bestimmt die
/// Typentabelle des Regelwerks (z. B. kein Unlicht/Stahl in Gen 1).
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

  /// Stabiler Schlüssel für Datenpakete und Lokalisierung.
  String get key => name;

  static PokemonType parse(String key) => PokemonType.values.firstWhere(
    (t) => t.key == key,
    orElse: () => throw FormatException('Unbekannter Typ: $key'),
  );
}
