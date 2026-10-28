import 'package:meta/meta.dart';

import 'availability.dart';
import 'ids.dart';
import 'localized_text.dart';
import 'pokemon_type.dart';

/// Damage class. Up to Gen 3 it depended on the type, from Gen 4 on the move.
enum DamageClass {
  physical,
  special,
  status;

  static DamageClass parse(String s) => values.firstWhere(
    (c) => c.name == s,
    orElse: () => throw FormatException('Unknown damage class: $s'),
  );
}

@immutable
class Move {
  const Move({required this.id, required this.name, required this.generation});

  final MoveId id;
  final LocalizedText name;

  /// Generation in which the move was introduced.
  final int generation;
}

/// Data of a move in a version group (historical changes applied).
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

  /// `null` = no fixed power (e.g. status moves or variable power).
  final int? power;

  /// `null` = always hits or no accuracy check.
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

/// How a move is learned.
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

  /// Level for [LearnMethod.levelUp]; 0 = on evolution/via the reminder.
  final int? level;

  /// Item of the machine (e.g. `tm26`) for [LearnMethod.machine].
  final ItemId? machine;

  /// Source key for [LearnMethod.other] (e.g. `form-change`).
  final String? methodDetail;
}
