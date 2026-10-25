import 'package:meta/meta.dart';

import 'availability.dart';
import 'ids.dart';
import 'localized_text.dart';
import 'pokemon_type.dart';

/// Schadensklasse. Bis Gen 3 hing sie vom Typ ab, ab Gen 4 von der Attacke.
enum DamageClass {
  physical,
  special,
  status;

  static DamageClass parse(String s) => values.firstWhere(
    (c) => c.name == s,
    orElse: () => throw FormatException('Unbekannte Schadensklasse: $s'),
  );
}

@immutable
class Move {
  const Move({required this.id, required this.name, required this.generation});

  final MoveId id;
  final LocalizedText name;

  /// Generation, in der die Attacke eingeführt wurde.
  final int generation;
}

/// Werte einer Attacke in einer Spielgruppe (historische Änderungen eingerechnet).
@immutable
class MoveGameProfile {
  const MoveGameProfile({
    required this.availability,
    required this.type,
    required this.damageClass,
    this.power,
    this.accuracy,
    this.pp,
    this.priority = 0,
  });

  final DataAvailability availability;
  final PokemonType type;
  final DamageClass damageClass;

  /// `null` = keine feste Stärke (z. B. Statusattacken oder variable Stärke).
  final int? power;

  /// `null` = trifft immer bzw. keine Genauigkeitsprüfung.
  final int? accuracy;
  final int? pp;
  final int priority;

  bool sameValuesAs(MoveGameProfile o) =>
      type == o.type &&
      damageClass == o.damageClass &&
      power == o.power &&
      accuracy == o.accuracy &&
      pp == o.pp &&
      priority == o.priority;
}

/// Wie eine Attacke erlernt wird.
enum LearnMethod {
  levelUp('level-up'),
  machine('machine'),
  egg('egg'),
  tutor('tutor'),
  other('other');

  const LearnMethod(this.key);

  final String key;

  static LearnMethod parse(String key) =>
      values.firstWhere((m) => m.key == key, orElse: () => LearnMethod.other);
}

@immutable
class LearnsetEntry {
  const LearnsetEntry({
    required this.move,
    required this.method,
    this.level,
    this.machine,
    this.methodDetail,
  });

  final MoveId move;
  final LearnMethod method;

  /// Level bei [LearnMethod.levelUp]; 0 = beim Entwickeln/Erinnern.
  final int? level;

  /// Item der Maschine (z. B. `tm26`) bei [LearnMethod.machine].
  final ItemId? machine;

  /// Quellschlüssel für [LearnMethod.other] (z. B. `form-change`).
  final String? methodDetail;
}
