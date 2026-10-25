import 'package:meta/meta.dart';

import 'ids.dart';

/// Deklarative Entwicklungsbedingung (ADR 0006). Wird nie als Code ausgeführt.
@immutable
sealed class EvolutionCondition {
  const EvolutionCondition();

  /// Liest und validiert einen Bedingungsbaum. Unbekannte Knoten sind Fehler.
  factory EvolutionCondition.fromJson(Map<String, Object?> j, {int depth = 0}) {
    if (depth > 8) {
      throw const FormatException(
        'Entwicklungsbedingung zu tief verschachtelt',
      );
    }
    final kind = j['kind'];
    List<EvolutionCondition> children() {
      final list = (j['of'] as List<Object?>?) ?? const <Object?>[];
      if (list.length < 2) {
        throw FormatException('$kind benötigt mindestens zwei Bedingungen');
      }
      return [
        for (final c in list)
          EvolutionCondition.fromJson(
            c! as Map<String, Object?>,
            depth: depth + 1,
          ),
      ];
    }

    T req<T>(String key) {
      final v = j[key];
      if (v is! T) {
        throw FormatException('$kind: Feld "$key" fehlt oder ist ungültig');
      }
      return v;
    }

    return switch (kind) {
      'allOf' => AllOf(children()),
      'anyOf' => AnyOf(children()),
      'minLevel' => MinLevel(_range(req<int>('level'), 1, 100, 'level')),
      'useItem' => UseItem(ItemId(req<String>('item'))),
      'holdItem' => HoldItem(ItemId(req<String>('item'))),
      'timeOfDay' => TimeOfDayCondition(TimeOfDay.parse(req<String>('time'))),
      'location' => AtLocation(LocationId(req<String>('location'))),
      'region' => InRegion(req<String>('region')),
      'minFriendship' => MinFriendship(
        _range(req<int>('value'), 0, 255, 'value'),
      ),
      'knowsMove' => KnowsMove(MoveId(req<String>('move'))),
      'trade' => const Trade(),
      'gender' => GenderCondition(Gender.parse(req<String>('gender'))),
      'special' => SpecialCondition(
        req<String>('explanationKey'),
        value: j['value'] as String?,
      ),
      _ => throw FormatException('Unbekannte Entwicklungsbedingung: $kind'),
    };
  }

  static int _range(int v, int min, int max, String field) {
    if (v < min || v > max) {
      throw FormatException('$field außerhalb $min–$max: $v');
    }
    return v;
  }

  /// Serialisierung für Katalogpakete (Gegenstück zu [EvolutionCondition.fromJson]).
  Map<String, Object?> toJson() => switch (this) {
    AllOf(:final conditions) => {
      'kind': 'allOf',
      'of': [for (final c in conditions) c.toJson()],
    },
    AnyOf(:final conditions) => {
      'kind': 'anyOf',
      'of': [for (final c in conditions) c.toJson()],
    },
    MinLevel(:final level) => {'kind': 'minLevel', 'level': level},
    UseItem(:final item) => {'kind': 'useItem', 'item': item.value},
    HoldItem(:final item) => {'kind': 'holdItem', 'item': item.value},
    TimeOfDayCondition(:final time) => {'kind': 'timeOfDay', 'time': time.name},
    AtLocation(:final location) => {
      'kind': 'location',
      'location': location.value,
    },
    InRegion(:final region) => {'kind': 'region', 'region': region},
    MinFriendship(:final value) => {'kind': 'minFriendship', 'value': value},
    KnowsMove(:final move) => {'kind': 'knowsMove', 'move': move.value},
    Trade() => {'kind': 'trade'},
    GenderCondition(:final gender) => {'kind': 'gender', 'gender': gender.name},
    SpecialCondition(:final explanationKey, :final value) => {
      'kind': 'special',
      'explanationKey': explanationKey,
      'value': ?value,
    },
  };

  /// Alle Item-IDs, auf die der Baum verweist (für Referenzprüfungen).
  Iterable<ItemId> get referencedItems => switch (this) {
    AllOf(:final conditions) ||
    AnyOf(:final conditions) => conditions.expand((c) => c.referencedItems),
    UseItem(:final item) || HoldItem(:final item) => [item],
    _ => const [],
  };
}

final class AllOf extends EvolutionCondition {
  const AllOf(this.conditions);
  final List<EvolutionCondition> conditions;
}

final class AnyOf extends EvolutionCondition {
  const AnyOf(this.conditions);
  final List<EvolutionCondition> conditions;
}

final class MinLevel extends EvolutionCondition {
  const MinLevel(this.level);
  final int level;
}

final class UseItem extends EvolutionCondition {
  const UseItem(this.item);
  final ItemId item;
}

final class HoldItem extends EvolutionCondition {
  const HoldItem(this.item);
  final ItemId item;
}

enum TimeOfDay {
  morning,
  day,
  evening,
  dusk,
  night;

  static TimeOfDay parse(String s) => values.firstWhere(
    (t) => t.name == s,
    orElse: () => throw FormatException('Unbekannte Tageszeit: $s'),
  );
}

final class TimeOfDayCondition extends EvolutionCondition {
  const TimeOfDayCondition(this.time);
  final TimeOfDay time;
}

final class AtLocation extends EvolutionCondition {
  const AtLocation(this.location);
  final LocationId location;
}

final class InRegion extends EvolutionCondition {
  const InRegion(this.region);
  final String region;
}

final class MinFriendship extends EvolutionCondition {
  const MinFriendship(this.value);
  final int value;
}

final class KnowsMove extends EvolutionCondition {
  const KnowsMove(this.move);
  final MoveId move;
}

final class Trade extends EvolutionCondition {
  const Trade();
}

enum Gender {
  male,
  female;

  static Gender parse(String s) => values.firstWhere(
    (g) => g.name == s,
    orElse: () => throw FormatException('Unbekanntes Geschlecht: $s'),
  );
}

final class GenderCondition extends EvolutionCondition {
  const GenderCondition(this.gender);
  final Gender gender;
}

/// Seltene Sonderbedingung mit geprüftem, lokalisiertem Erklärungstext.
/// [value] ist ein optionaler Parameter (z. B. eine Art-ID oder ein Typ).
final class SpecialCondition extends EvolutionCondition {
  const SpecialCondition(this.explanationKey, {this.value});
  final String explanationKey;
  final String? value;
}

/// Kante im Entwicklungsgraphen, gültig für bestimmte Spielgruppen.
@immutable
class EvolutionEdge {
  const EvolutionEdge({
    required this.from,
    required this.to,
    required this.condition,
    required this.versionGroups,
  });

  factory EvolutionEdge.fromJson(Map<String, Object?> j) => EvolutionEdge(
    from: FormId(j['from']! as String),
    to: FormId(j['to']! as String),
    condition: EvolutionCondition.fromJson(
      j['condition']! as Map<String, Object?>,
    ),
    versionGroups: {
      for (final g in j['versionGroups']! as List<Object?>)
        VersionGroupId(g! as String),
    },
  );

  final FormId from;
  final FormId to;
  final EvolutionCondition condition;
  final Set<VersionGroupId> versionGroups;
}
