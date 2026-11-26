import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  late Directory dir;
  late CatalogSnapshot catalog;
  late SqliteCatalogDetails details;
  late PokemonQueries queries;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('mydex_catalog');
    final path = await installFixture(dir);
    catalog = loadCatalogSnapshot(path);
    details = SqliteCatalogDetails.open(path);
    queries = PokemonQueries(catalog);
  });
  tearDownAll(() {
    details.close();
    dir.deleteSync(recursive: true);
  });

  GameContext ctx(String version) => catalog.contextFor(GameVersionId(version));
  FormGameProfile profile(String form, String group) =>
      catalog.forms[FormId(form)]!.profileFor(VersionGroupId(group));

  group('Catalog', () {
    test('is valid and fully loaded', () {
      expect(validateCatalog(catalog), isEmpty);
      expect(catalog.versions.length, greaterThan(40));
      expect(
        catalog.forms.keys,
        containsAll([
          const FormId('raichu-alola'),
          const FormId('venusaur-mega'),
        ]),
      );
      expect(details.source.source, 'PokéAPI');
    });

    test('default context is the International Pokédex', () {
      final ctx = catalog.defaultContext;
      expect(ctx.versionId, NationalDex.versionId);
      expect(
        catalog.versionGroups.values.every(
          (g) => g.order < ctx.versionGroup.order,
        ),
        isTrue,
        reason: 'newer than every game',
      );
      expect(validateCatalog(catalog), isEmpty, reason: 'derived, not stored');
    });

    test('every game has a distinct name in every language', () {
      for (final lang in ['de', 'en', 'fr', 'es', 'it']) {
        final names = [for (final v in catalog.versions) v.name(lang)];
        expect(names.toSet().length, names.length, reason: lang);
      }
      final red = catalog.versions.firstWhere(
        (v) => v.id == const GameVersionId('red-japan'),
      );
      expect(red.name('de'), 'Rot (JP)');
    });

    test('names in all core languages', () {
      final name = catalog.species[const SpeciesId('charizard')]!.name;
      expect(name('de'), 'Glurak');
      expect(name('en'), 'Charizard');
      expect(name('fr'), 'Dracaufeu');
      expect(name.resolve('ja').text, isNotEmpty);
    });
  });

  group('Historical values', () {
    test('Clefairy: Normal up to Gen 5, Fairy from Gen 6', () {
      expect(profile('clefairy', 'black-white').types, [PokemonType.normal]);
      expect(profile('clefairy', 'x-y').types, [PokemonType.fairy]);
    });

    test('Gen 1: shared Special stat, no abilities', () {
      final p = profile('pikachu', 'red-blue');
      expect(p.baseStats!.specialAttack, 50);
      expect(p.baseStats!.specialDefense, 50);
      expect(
        p.baseStats!.defense,
        30,
        reason: 'Pikachu\'s Defense only rose in Gen 6',
      );
      expect(p.abilities, isEmpty);
      expect(ctx('red').ruleset.unifiedSpecial, isTrue);
    });

    test('Gen 2: Special split, stats before Gen 6', () {
      final p = profile('pikachu', 'gold-silver');
      expect(p.baseStats!.specialDefense, 40);
      expect(p.baseStats!.defense, 30);
      expect(profile('pikachu', 'x-y').baseStats!.defense, 40);
    });

    test('hidden abilities only from Gen 5', () {
      expect(
        profile('bulbasaur', 'diamond-pearl').abilities.where((a) => a.hidden),
        isEmpty,
      );
      expect(
        profile('bulbasaur', 'black-white').abilities.where((a) => a.hidden),
        hasLength(1),
      );
    });

    test('move data per game', () {
      expect(
        details
            .moveProfile(
              const MoveId('thunderbolt'),
              const VersionGroupId('black-white'),
            )!
            .power,
        95,
      );
      expect(
        details
            .moveProfile(
              const MoveId('thunderbolt'),
              const VersionGroupId('x-y'),
            )!
            .power,
        90,
      );
    });

    test('damage class follows the type up to Gen 3', () {
      // Bite was Normal (physical) in Gen 1 and became Dark (special up to Gen 3).
      expect(
        details
            .moveProfile(
              const MoveId('bite'),
              const VersionGroupId('red-blue'),
            )!
            .type,
        PokemonType.normal,
      );
      final gen3 = details.moveProfile(
        const MoveId('bite'),
        const VersionGroupId('ruby-sapphire'),
      )!;
      expect(gen3.type, PokemonType.dark);
      expect(gen3.damageClass, DamageClass.special);
      expect(
        details
            .moveProfile(
              const MoveId('bite'),
              const VersionGroupId('diamond-pearl'),
            )!
            .damageClass,
        DamageClass.physical,
      );
    });

    test('moves only exist from their generation', () {
      expect(
        details.moveProfile(
          const MoveId('moonblast'),
          const VersionGroupId('black-white'),
        ),
        isNull,
      );
      expect(
        details.moveProfile(
          const MoveId('moonblast'),
          const VersionGroupId('x-y'),
        ),
        isNotNull,
      );
    });
  });

  group('Availability', () {
    test('Mega forms only from X/Y', () {
      expect(
        profile('venusaur-mega', 'black-white').availability,
        DataAvailability.confirmedUnavailable,
      );
    });

    test('forms with learnsets count as confirmed', () {
      expect(
        profile('raichu-alola', 'sun-moon').availability,
        DataAvailability.confirmedAvailable,
      );
      expect(
        profile('raichu-alola', 'x-y').availability,
        DataAvailability.confirmedUnavailable,
      );
    });

    test('missing data are gaps, not unavailability', () {
      final gaps = catalog.forms.values.where(
        (f) => f
            .profileFor(const VersionGroupId('sword-shield'))
            .availability
            .isGap,
      );
      expect(gaps, isNotEmpty);
      final coverage = details.coverage().firstWhere(
        (c) => c.versionGroup.value == 'sword-shield',
      );
      expect(coverage.formsGaps, gaps.length);
    });

    DataAvailability at(String form, String group) =>
        profile(form, group).availability;

    test('complete roster: species without data is not in the game', () {
      // Ekans is not in Sword/Shield, Pikachu is.
      expect(
        at('ekans', 'sword-shield'),
        DataAvailability.confirmedUnavailable,
      );
      expect(
        at('pikachu', 'sword-shield'),
        DataAvailability.confirmedAvailable,
      );
      // Mythical Pokémon are partly missing from the data: they stay gaps.
      expect(at('mew', 'legends-arceus').isGap, isTrue);
    });

    test('roster by regional Dex (Champions)', () {
      expect(at('clefable', 'champions'), DataAvailability.confirmedAvailable);
      expect(
        at('clefairy', 'champions'),
        DataAvailability.confirmedUnavailable,
      );
    });

    test('battle forms only with their game mechanic', () {
      expect(
        at('venusaur-mega', 'scarlet-violet'),
        DataAvailability.confirmedUnavailable,
      );
      expect(
        at('venusaur-gmax', 'scarlet-violet'),
        DataAvailability.confirmedUnavailable,
      );
      expect(at('venusaur-gmax', 'sword-shield').isGap, isTrue);
    });

    test('game-exclusive forms', () {
      expect(
        at('pikachu-starter', 'sword-shield'),
        DataAvailability.confirmedUnavailable,
      );
      expect(
        at('pikachu-cosplay', 'sun-moon'),
        DataAvailability.confirmedUnavailable,
      );
    });

    test('expansions inherit the base game', () {
      expect(
        at('pikachu', 'the-isle-of-armor'),
        DataAvailability.confirmedAvailable,
      );
      expect(
        at('ekans', 'the-crown-tundra'),
        DataAvailability.confirmedUnavailable,
      );
    });
  });

  group('Evolutions', () {
    List<String> family(String form, String version) => [
      for (final e in queries.detail(FormId(form), ctx(version)).evolutions)
        '${e.from.id.value}>${e.to.id.value}',
    ];

    test('Alolan Raichu replaces Raichu in Sun/Moon', () {
      expect(family('pikachu', 'sun'), contains('pikachu>raichu-alola'));
      expect(family('pikachu', 'sun'), isNot(contains('pikachu>raichu')));
      expect(family('pikachu', 'x'), contains('pikachu>raichu'));
      expect(family('pikachu', 'x'), isNot(contains('pikachu>raichu-alola')));
    });

    test('Magnezone: location depends on the game', () {
      AtLocation? location(String version) {
        final edge = queries
            .detail(const FormId('magneton'), ctx(version))
            .evolutions
            .firstWhere((e) => e.to.id.value == 'magnezone');
        return edge.condition is AtLocation
            ? edge.condition as AtLocation
            : null;
      }

      expect(location('diamond')!.location.value, 'mt-coronet');
      expect(location('x')!.location.value, 'kalos-route-13');
      expect(
        catalog.locationNames[const LocationId('mt-coronet')]!('de'),
        isNotEmpty,
      );
    });

    test('Eevee has several evolutions', () {
      expect(family('eevee', 'red').length, 3);
    });
  });

  group('Learnsets', () {
    test('Pikachu in Red/Blue: level-up and machines', () {
      final entries = details.learnset(
        const FormId('pikachu'),
        const VersionGroupId('red-blue'),
      );
      final thundershock = entries.firstWhere(
        (e) => e.move.value == 'thunder-shock',
      );
      expect(thundershock.method, LearnMethod.levelUp);
      final machines = entries.where((e) => e.method == LearnMethod.machine);
      expect(machines, isNotEmpty);
      expect(machines.every((e) => e.machine != null), isTrue);
    });

    test('who learns a move', () {
      final learners = details.learnersOf(
        const MoveId('thunderbolt'),
        const VersionGroupId('red-blue'),
      );
      expect(
        learners.map((l) => l.form.value),
        containsAll(['pikachu', 'raichu']),
      );
    });

    test('move history is chronological', () {
      final history = details.moveHistory(const MoveId('thunderbolt'));
      final orders = [
        for (final (g, _) in history) catalog.versionGroups[g]!.order,
      ];
      expect(orders, orderedEquals([...orders]..sort()));
    });
  });

  group('Search', () {
    test('moves across languages by prefix', () {
      final hits = details.searchEntities('donnerbl');
      expect(hits.first, const EntityHit(EntityKind.move, 'thunderbolt'));
      expect(details.searchEntities('Thunderbolt').first.id, 'thunderbolt');
    });

    test('abilities and items', () {
      expect(
        details.searchEntities('Notdünger').first,
        const EntityHit(EntityKind.ability, 'overgrow'),
      );
      expect(
        details.searchEntities('Donnerstein'),
        contains(const EntityHit(EntityKind.item, 'thunder-stone')),
      );
    });

    test('special characters in the query are harmless', () {
      expect(
        details.searchEntities('"; DROP TABLE move; --'),
        isA<List<EntityHit>>(),
      );
      expect(details.searchEntities('   '), isEmpty);
    });
  });

  group('Locations', () {
    List<String> locationsOf(String form, String version) => [
      for (final e in details.encountersOf(
        FormId(form),
        GameVersionId(version),
      ))
        catalog.locationAreas[e.area]!.location.value,
    ];

    test('Pikachu in Red: Viridian Forest and Power Plant', () {
      expect(
        locationsOf('pikachu', 'red'),
        containsAll(['viridian-forest', 'kanto-power-plant']),
      );
      final forest = details
          .encountersOf(const FormId('pikachu'), const GameVersionId('red'))
          .firstWhere(
            (e) =>
                catalog.locationAreas[e.area]!.location.value ==
                'viridian-forest',
          );
      expect(forest.minLevel, 3);
      expect(forest.maxLevel, 5);
      expect(forest.chance, inInclusiveRange(1, 100));
      expect(catalog.encounterMethods[forest.method]!.name('de'), isNotEmpty);
    });

    test('version exclusives: Ekans only in Red, Sandshrew only in Blue', () {
      expect(locationsOf('ekans', 'red'), isNotEmpty);
      expect(locationsOf('ekans', 'blue'), isEmpty);
      expect(locationsOf('sandshrew', 'blue'), isNotEmpty);
      expect(locationsOf('sandshrew', 'red'), isEmpty);
    });

    test('gifts are listed as their own method', () {
      final starter = details.encountersOf(
        const FormId('bulbasaur'),
        const GameVersionId('red'),
      );
      expect(starter.map((e) => e.method.value), contains('gift'));
    });

    test('a location shows all encounters of the version', () {
      final forest = details.encountersAt(
        const LocationId('viridian-forest'),
        const GameVersionId('red'),
      );
      expect(forest.map((e) => e.form.value), contains('pikachu'));
      expect(
        details.locationsWithEncounters(const GameVersionId('red')),
        contains(const LocationId('viridian-forest')),
      );
      expect(
        catalog.locations[const LocationId('viridian-forest')]!.region,
        const RegionId('kanto'),
      );
    });

    test(
      'missing location data is detected, not treated as "not catchable"',
      () {
        expect(details.hasEncounterData(const GameVersionId('red')), isTrue);
        expect(
          details.hasEncounterData(const GameVersionId('scarlet')),
          isFalse,
        );
        final sv = details.coverage().firstWhere(
          (c) => c.versionGroup.value == 'scarlet-violet',
        );
        expect(sv.encounterEntries, 0);
        final rb = details.coverage().firstWhere(
          (c) => c.versionGroup.value == 'red-blue',
        );
        expect(rb.encounterEntries, greaterThan(0));
      },
    );
  });

  group('Breeding', () {
    test('rulesets know breeding only from Gen 2 and not in special games', () {
      expect(ctx('red').ruleset.hasBreeding, isFalse);
      expect(ctx('gold').ruleset.hasBreeding, isTrue);
      expect(ctx('lets-go-pikachu').ruleset.hasBreeding, isFalse);
      expect(ctx('scarlet').ruleset.hasBreeding, isTrue);
    });

    test('hatchability per species', () {
      // Pichu is "undiscovered" itself but hatches from Pikachu/Raichu eggs.
      expect(catalog.species[const SpeciesId('pichu')]!.hatchable, isTrue);
      expect(catalog.species[const SpeciesId('eevee')]!.hatchable, isTrue);
      expect(catalog.species[const SpeciesId('magnemite')]!.hatchable, isTrue);
    });
  });

  group('Acquisition via trades and events', () {
    late AcquisitionQueries acquisition;
    setUp(() => acquisition = AcquisitionQueries(catalog, details));
    List<String> sources(String form, String version) => [
      for (final v in acquisition.tradeSources(FormId(form), ctx(version)))
        v.id.value,
    ];

    test('version exclusives: Sandshrew in Red by trade from Blue', () {
      expect(sources('sandshrew', 'red'), contains('blue'));
      expect(sources('ekans', 'blue'), contains('red'));
      expect(sources('sandshrew', 'red'), isNot(contains('red')));
    });

    test('Time Capsule: Gen 1 and 2 trade, Gen 3 not with Gen 1', () {
      final partners = [
        for (final v in acquisition.tradePartners(const GameVersionId('gold')))
          v.id.value,
      ];
      expect(partners, containsAll(['silver', 'crystal', 'red', 'yellow']));
      expect(partners, isNot(contains('ruby')));
      expect(
        acquisition.tradePartners(const GameVersionId('legends-arceus')),
        isEmpty,
      );
    });

    test('no trade for forms that do not exist in the game', () {
      expect(sources('raichu-alola', 'red'), isEmpty);
    });

    test('mythical Pokémon count as event Pokémon', () {
      expect(catalog.species[const SpeciesId('mew')]!.mythical, isTrue);
      expect(acquisition.isEventOnly(const FormId('mew'), ctx('red')), isTrue);
      expect(
        acquisition.isEventOnly(const FormId('pikachu'), ctx('red')),
        isFalse,
      );
    });
  });
}
