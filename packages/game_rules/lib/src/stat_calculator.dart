import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Individuelle Eingaben für die Statusberechnung.
@immutable
class StatInputs {
  const StatInputs({
    required this.level,
    this.ivs = const {},
    this.evs = const {},
    this.natureUp,
    this.natureDown,
  });

  final int level;

  /// Ab Gen 3: IVs 0–31. Gen 1–2: DVs 0–15.
  final Map<Stat, int> ivs;

  /// Ab Gen 3: EVs 0–252 (Summe ≤ 510). Gen 1–2: Status-EP 0–65535.
  final Map<Stat, int> evs;
  final Stat? natureUp;
  final Stat? natureDown;
}

class StatCalculator {
  const StatCalculator(this.formula);

  final StatFormula formula;

  Map<Stat, int> calculate(BaseStats base, StatInputs input) {
    _validate(input);
    return {for (final s in Stat.values) s: _one(s, base[s], input)};
  }

  int _one(Stat stat, int base, StatInputs i) {
    final level = i.level;
    switch (formula) {
      case StatFormula.modern:
        final iv = i.ivs[stat] ?? 31;
        final ev = i.evs[stat] ?? 0;
        final core = ((2 * base + iv + ev ~/ 4) * level) ~/ 100;
        if (stat == Stat.hp) return core + level + 10;
        final raw = core + 5;
        if (i.natureUp == i.natureDown) return raw;
        if (stat == i.natureUp) return (raw * 110) ~/ 100;
        if (stat == i.natureDown) return (raw * 90) ~/ 100;
        return raw;
      case StatFormula.gen1to2:
        final dv = i.ivs[stat] ?? _gen12HpDv(i);
        final statExp = i.evs[stat] ?? 0;
        // Das Spiel begrenzt die Wurzel aus den Status-EP auf 255.
        final expTerm = math.min(255, math.sqrt(statExp).ceil()) ~/ 4;
        final core = (((base + dv) * 2 + expTerm) * level) ~/ 100;
        return stat == Stat.hp ? core + level + 10 : core + 5;
    }
  }

  /// In Gen 1–2 leitet sich der KP-DV aus den anderen DVs ab.
  int _gen12HpDv(StatInputs i) {
    int bit(Stat s, int shift) => ((i.ivs[s] ?? 15) & 1) << shift;
    return bit(Stat.attack, 3) |
        bit(Stat.defense, 2) |
        bit(Stat.speed, 1) |
        bit(Stat.specialAttack, 0);
  }

  void _validate(StatInputs i) {
    if (i.level < 1 || i.level > 100) {
      throw ArgumentError.value(i.level, 'level', 'muss 1–100 sein');
    }
    final (maxIv, maxEv) = switch (formula) {
      StatFormula.modern => (31, 252),
      StatFormula.gen1to2 => (15, 65535),
    };
    for (final v in i.ivs.values) {
      if (v < 0 || v > maxIv) {
        throw ArgumentError.value(v, 'iv', 'muss 0–$maxIv sein');
      }
    }
    for (final v in i.evs.values) {
      if (v < 0 || v > maxEv) {
        throw ArgumentError.value(v, 'ev', 'muss 0–$maxEv sein');
      }
    }
    if (formula == StatFormula.modern) {
      final sum = i.evs.values.fold(0, (a, b) => a + b);
      if (sum > 510) {
        throw ArgumentError.value(sum, 'evs', 'Summe muss ≤ 510 sein');
      }
    } else if (i.natureUp != null || i.natureDown != null) {
      throw ArgumentError('Wesen existieren erst ab Gen 3');
    }
  }
}
