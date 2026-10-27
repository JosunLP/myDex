import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';
import 'package:test/test.dart';

void main() {
  final gen1 = TypeChart.forEra(TypeChartEra.gen1);
  final gen5 = TypeChart.forEra(TypeChartEra.gen2to5);
  final gen6 = TypeChart.forEra(TypeChartEra.gen6plus);
  const t = PokemonType.values;

  group('Type charts', () {
    test('number of types per era', () {
      expect(gen1.types, hasLength(15));
      expect(gen5.types, hasLength(17));
      expect(gen6.types, hasLength(18));
    });

    test('Ghost → Psychic: Gen 1 ×0, afterwards ×2', () {
      expect(gen1.single(PokemonType.ghost, PokemonType.psychic), 0);
      expect(gen5.single(PokemonType.ghost, PokemonType.psychic), 2);
    });

    test('Gen 1 special cases', () {
      expect(gen1.single(PokemonType.bug, PokemonType.poison), 2);
      expect(gen1.single(PokemonType.poison, PokemonType.bug), 2);
      expect(gen1.single(PokemonType.ice, PokemonType.fire), 1);
      expect(gen5.single(PokemonType.ice, PokemonType.fire), .5);
      expect(gen5.single(PokemonType.bug, PokemonType.poison), .5);
    });

    test('Steel resists Ghost/Dark only up to Gen 5', () {
      expect(gen5.single(PokemonType.ghost, PokemonType.steel), .5);
      expect(gen5.single(PokemonType.dark, PokemonType.steel), .5);
      expect(gen6.single(PokemonType.ghost, PokemonType.steel), 1);
      expect(gen6.single(PokemonType.dark, PokemonType.steel), 1);
    });

    test('Fairy does not exist before Gen 6', () {
      expect(
        () => gen5.single(PokemonType.fairy, PokemonType.dragon),
        throwsArgumentError,
      );
      expect(gen6.single(PokemonType.dragon, PokemonType.fairy), 0);
    });

    test('dual types multiply', () {
      expect(
        gen6.against(PokemonType.rock, [PokemonType.fire, PokemonType.flying]),
        4,
      );
      expect(
        gen6.against(PokemonType.electric, [
          PokemonType.water,
          PokemonType.flying,
        ]),
        4,
      );
      expect(
        gen6.against(PokemonType.ground, [
          PokemonType.electric,
          PokemonType.flying,
        ]),
        0,
      );
    });

    test('Gen 6 chart is fully defined 18×18', () {
      for (final a in t) {
        for (final d in t) {
          expect([0, .5, 1, 2], contains(gen6.single(a, d)));
        }
      }
    });
  });

  group('Stats', () {
    test('modern formula (reference example Garchomp Lv. 78)', () {
      const base = BaseStats(
        hp: 108,
        attack: 130,
        defense: 95,
        specialAttack: 80,
        specialDefense: 85,
        speed: 102,
      );
      final r = const StatCalculator(StatFormula.modern).calculate(
        base,
        const StatInputs(
          level: 78,
          ivs: {
            Stat.hp: 24,
            Stat.attack: 12,
            Stat.defense: 30,
            Stat.specialAttack: 16,
            Stat.specialDefense: 23,
            Stat.speed: 5,
          },
          evs: {
            Stat.hp: 74,
            Stat.attack: 190,
            Stat.defense: 91,
            Stat.specialAttack: 48,
            Stat.specialDefense: 84,
            Stat.speed: 23,
          },
          natureUp: Stat.attack,
          natureDown: Stat.specialAttack,
        ),
      );
      expect(r[Stat.hp], 289);
      expect(r[Stat.attack], 278);
      expect(r[Stat.defense], 193);
      expect(r[Stat.specialAttack], 135);
      expect(r[Stat.specialDefense], 171);
      expect(r[Stat.speed], 171);
    });

    test('Gen 1 formula with maximum DVs and stat exp (Mewtwo Lv. 100)', () {
      const base = BaseStats.gen1(
        hp: 106,
        attack: 110,
        defense: 90,
        special: 154,
        speed: 130,
      );
      final max = {for (final s in Stat.values) s: 65535};
      final r = const StatCalculator(StatFormula.gen1to2).calculate(
        base,
        StatInputs(
          level: 100,
          ivs: {
            for (final s in Stat.values)
              if (s != Stat.hp) s: 15,
          },
          evs: max,
        ),
      );
      expect(r[Stat.defense], 278);
      expect(r[Stat.specialAttack], 406);
      expect(r[Stat.speed], 358);
    });

    test('invalid input is rejected', () {
      const base = BaseStats(
        hp: 1,
        attack: 1,
        defense: 1,
        specialAttack: 1,
        specialDefense: 1,
        speed: 1,
      );
      const modern = StatCalculator(StatFormula.modern);
      expect(
        () => modern.calculate(base, const StatInputs(level: 0)),
        throwsArgumentError,
      );
      expect(
        () => modern.calculate(
          base,
          const StatInputs(level: 50, ivs: {Stat.hp: 32}),
        ),
        throwsArgumentError,
      );
      expect(
        () => modern.calculate(
          base,
          const StatInputs(
            level: 50,
            evs: {Stat.hp: 252, Stat.attack: 252, Stat.speed: 8},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => const StatCalculator(StatFormula.gen1to2).calculate(
          base,
          const StatInputs(
            level: 50,
            natureUp: Stat.attack,
            natureDown: Stat.speed,
          ),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Team analysis', () {
    test('shared weakness without resistance is reported', () {
      final a = TeamAnalyzer(gen6).analyze(const [
        TeamMemberTyping(
          label: 'A',
          types: [PokemonType.grass],
          attackTypes: [PokemonType.grass],
        ),
        TeamMemberTyping(
          label: 'B',
          types: [PokemonType.grass, PokemonType.poison],
        ),
        TeamMemberTyping(label: 'C', types: [PokemonType.bug]),
      ]);
      final fire = a.defensive.firstWhere(
        (r) => r.attackType == PokemonType.fire,
      );
      expect(fire.weak, 3);
      expect(
        a.findings.whereType<SharedWeakness>().map((f) => f.attackType),
        contains(PokemonType.fire),
      );
      final gaps = a.findings.whereType<CoverageGap>().map(
        (f) => f.defendingType,
      );
      expect(gaps, contains(PokemonType.fire));
      expect(gaps, isNot(contains(PokemonType.water)));
    });

    test('immunity prevents the report', () {
      final a = TeamAnalyzer(gen6).analyze(const [
        TeamMemberTyping(label: 'A', types: [PokemonType.water]),
        TeamMemberTyping(label: 'B', types: [PokemonType.water]),
        TeamMemberTyping(label: 'C', types: [PokemonType.water]),
        TeamMemberTyping(label: 'D', types: [PokemonType.ground]),
      ]);
      final ele = a.defensive.firstWhere(
        (r) => r.attackType == PokemonType.electric,
      );
      expect(ele.weak, 3);
      expect(ele.immune, 1);
      final shared = a.findings.whereType<SharedWeakness>().map(
        (f) => f.attackType,
      );
      expect(shared, isNot(contains(PokemonType.electric)));
      expect(
        shared,
        contains(PokemonType.grass),
        reason: 'Grass hits Water and Ground',
      );
      expect(
        a.findings.whereType<CoverageGap>(),
        isEmpty,
        reason: 'no coverage statement without moves',
      );
    });
  });
}
