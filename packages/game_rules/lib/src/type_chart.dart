import 'package:mydex_domain/mydex_domain.dart';

import 'package:meta/meta.dart';

typedef _Row = Map<PokemonType, double>;

const _n = PokemonType.normal;
const _fir = PokemonType.fire;
const _wat = PokemonType.water;
const _ele = PokemonType.electric;
const _gra = PokemonType.grass;
const _ice = PokemonType.ice;
const _fig = PokemonType.fighting;
const _poi = PokemonType.poison;
const _gro = PokemonType.ground;
const _fly = PokemonType.flying;
const _psy = PokemonType.psychic;
const _bug = PokemonType.bug;
const _roc = PokemonType.rock;
const _gho = PokemonType.ghost;
const _dra = PokemonType.dragon;
const _dar = PokemonType.dark;
const _ste = PokemonType.steel;
const _fai = PokemonType.fairy;

/// Deviations from ×1 from Gen 6 (attacker → defender).
const Map<PokemonType, _Row> _gen6 = {
  _n: {_roc: .5, _gho: 0, _ste: .5},
  _fir: {
    _fir: .5,
    _wat: .5,
    _gra: 2,
    _ice: 2,
    _bug: 2,
    _roc: .5,
    _dra: .5,
    _ste: 2,
  },
  _wat: {_fir: 2, _wat: .5, _gra: .5, _gro: 2, _roc: 2, _dra: .5},
  _ele: {_wat: 2, _ele: .5, _gra: .5, _gro: 0, _fly: 2, _dra: .5},
  _gra: {
    _fir: .5,
    _wat: 2,
    _gra: .5,
    _poi: .5,
    _gro: 2,
    _fly: .5,
    _bug: .5,
    _roc: 2,
    _dra: .5,
    _ste: .5,
  },
  _ice: {
    _fir: .5,
    _wat: .5,
    _gra: 2,
    _ice: .5,
    _gro: 2,
    _fly: 2,
    _dra: 2,
    _ste: .5,
  },
  _fig: {
    _n: 2,
    _ice: 2,
    _poi: .5,
    _fly: .5,
    _psy: .5,
    _bug: .5,
    _roc: 2,
    _gho: 0,
    _dar: 2,
    _ste: 2,
    _fai: .5,
  },
  _poi: {_gra: 2, _poi: .5, _gro: .5, _roc: .5, _gho: .5, _ste: 0, _fai: 2},
  _gro: {
    _fir: 2,
    _ele: 2,
    _gra: .5,
    _poi: 2,
    _fly: 0,
    _bug: .5,
    _roc: 2,
    _ste: 2,
  },
  _fly: {_ele: .5, _gra: 2, _fig: 2, _bug: 2, _roc: .5, _ste: .5},
  _psy: {_fig: 2, _poi: 2, _psy: .5, _dar: 0, _ste: .5},
  _bug: {
    _fir: .5,
    _gra: 2,
    _fig: .5,
    _poi: .5,
    _fly: .5,
    _psy: 2,
    _gho: .5,
    _dar: 2,
    _ste: .5,
    _fai: .5,
  },
  _roc: {_fir: 2, _ice: 2, _fig: .5, _gro: .5, _fly: 2, _bug: 2, _ste: .5},
  _gho: {_n: 0, _psy: 2, _gho: 2, _dar: .5},
  _dra: {_dra: 2, _ste: .5, _fai: 0},
  _dar: {_fig: .5, _psy: 2, _gho: 2, _dar: .5, _fai: .5},
  _ste: {_fir: .5, _wat: .5, _ele: .5, _ice: 2, _roc: 2, _ste: .5, _fai: 2},
  _fai: {_fir: .5, _fig: 2, _poi: .5, _dra: 2, _dar: 2, _ste: .5},
};

/// Historical type chart of a ruleset.
@immutable
class TypeChart {
  TypeChart._(this.era, this.types, this._table);

  factory TypeChart.forEra(TypeChartEra era) => switch (era) {
    TypeChartEra.gen6plus => _gen6plusChart,
    TypeChartEra.gen2to5 => _gen2to5Chart,
    TypeChartEra.gen1 => _gen1Chart,
  };

  final TypeChartEra era;

  /// Types that exist in this era.
  final List<PokemonType> types;
  final Map<PokemonType, _Row> _table;

  bool contains(PokemonType t) => types.contains(t);

  /// Multiplier of an attacking type against a single defending type.
  double single(PokemonType attacker, PokemonType defender) {
    _check(attacker);
    _check(defender);
    return _table[attacker]?[defender] ?? 1;
  }

  /// Multiplier against a (dual) type combination.
  double against(PokemonType attacker, List<PokemonType> defenders) {
    var m = 1.0;
    for (final d in defenders.toSet()) {
      m *= single(attacker, d);
    }
    return m;
  }

  void _check(PokemonType t) {
    if (!contains(t)) {
      throw ArgumentError('Type ${t.key} does not exist in era ${era.key}');
    }
  }
}

final TypeChart _gen6plusChart = TypeChart._(
  TypeChartEra.gen6plus,
  List.unmodifiable(PokemonType.values),
  _gen6,
);

final TypeChart _gen2to5Chart = () {
  final table = <PokemonType, _Row>{
    for (final e in _gen6.entries)
      if (e.key != _fai) e.key: Map.of(e.value)..remove(_fai),
  };
  table[_gho]![_ste] = .5;
  table[_dar]![_ste] = .5;
  return TypeChart._(
    TypeChartEra.gen2to5,
    List.unmodifiable(PokemonType.values.where((t) => t != _fai)),
    table,
  );
}();

final TypeChart _gen1Chart = () {
  const absent = {_dar, _ste, _fai};
  final table = <PokemonType, _Row>{
    for (final e in _gen2to5Chart._table.entries)
      if (!absent.contains(e.key))
        e.key: Map.of(e.value)..removeWhere((k, _) => absent.contains(k)),
  };
  table[_bug]![_poi] = 2;
  table[_poi]![_bug] = 2;
  table[_gho]![_psy] = 0;
  table[_ice]!.remove(_fir);
  return TypeChart._(
    TypeChartEra.gen1,
    List.unmodifiable(PokemonType.values.where((t) => !absent.contains(t))),
    table,
  );
}();
