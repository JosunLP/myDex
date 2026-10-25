import 'package:meta/meta.dart';

enum Stat { hp, attack, defense, specialAttack, specialDefense, speed }

/// Basiswerte einer Form in einem Spielkontext.
@immutable
class BaseStats {
  const BaseStats({
    required this.hp,
    required this.attack,
    required this.defense,
    required this.specialAttack,
    required this.specialDefense,
    required this.speed,
  });

  /// Gen-1-Werte: ein gemeinsamer Spezial-Wert.
  const BaseStats.gen1({
    required this.hp,
    required this.attack,
    required this.defense,
    required int special,
    required this.speed,
  }) : specialAttack = special,
       specialDefense = special;

  factory BaseStats.fromJson(Map<String, Object?> j) {
    if (j.containsKey('special')) {
      return BaseStats.gen1(
        hp: j['hp']! as int,
        attack: j['atk']! as int,
        defense: j['def']! as int,
        special: j['special']! as int,
        speed: j['spe']! as int,
      );
    }
    return BaseStats(
      hp: j['hp']! as int,
      attack: j['atk']! as int,
      defense: j['def']! as int,
      specialAttack: j['spa']! as int,
      specialDefense: j['spd']! as int,
      speed: j['spe']! as int,
    );
  }

  final int hp;
  final int attack;
  final int defense;
  final int specialAttack;
  final int specialDefense;
  final int speed;

  int operator [](Stat s) => switch (s) {
    Stat.hp => hp,
    Stat.attack => attack,
    Stat.defense => defense,
    Stat.specialAttack => specialAttack,
    Stat.specialDefense => specialDefense,
    Stat.speed => speed,
  };

  /// Summe. Bei vereinigtem Spezial-Wert wird dieser nur einmal gezählt.
  int total({bool unifiedSpecial = false}) =>
      hp +
      attack +
      defense +
      specialAttack +
      (unifiedSpecial ? 0 : specialDefense) +
      speed;
}
