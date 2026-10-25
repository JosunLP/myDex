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

  group('Katalog', () {
    test('ist gültig und vollständig geladen', () {
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

    test('Standardkontext ist das neueste Spiel mit Daten', () {
      final group =
          catalog.versionGroups[catalog.defaultContext.versionGroupId]!;
      expect(group.hasData, isTrue);
      final later = catalog.versionGroups.values.where(
        (g) => g.order > group.order,
      );
      expect(later.every((g) => !g.hasData), isTrue);
    });

    test('Namen in allen Kernsprachen', () {
      final name = catalog.species[const SpeciesId('charizard')]!.name;
      expect(name('de'), 'Glurak');
      expect(name('en'), 'Charizard');
      expect(name('fr'), 'Dracaufeu');
      expect(name.resolve('ja').text, isNotEmpty);
    });
  });

  group('Historische Werte', () {
    test('Piepi: Normal bis Gen 5, Fee ab Gen 6', () {
      expect(profile('clefairy', 'black-white').types, [PokemonType.normal]);
      expect(profile('clefairy', 'x-y').types, [PokemonType.fairy]);
    });

    test('Gen 1: gemeinsamer Spezial-Wert, keine Fähigkeiten', () {
      final p = profile('pikachu', 'red-blue');
      expect(p.baseStats!.specialAttack, 50);
      expect(p.baseStats!.specialDefense, 50);
      expect(
        p.baseStats!.defense,
        30,
        reason: 'Pikachus Verteidigung stieg erst in Gen 6',
      );
      expect(p.abilities, isEmpty);
      expect(ctx('red').ruleset.unifiedSpecial, isTrue);
    });

    test('Gen 2: Spezial getrennt, Werte vor Gen 6', () {
      final p = profile('pikachu', 'gold-silver');
      expect(p.baseStats!.specialDefense, 40);
      expect(p.baseStats!.defense, 30);
      expect(profile('pikachu', 'x-y').baseStats!.defense, 40);
    });

    test('versteckte Fähigkeiten erst ab Gen 5', () {
      expect(
        profile('bulbasaur', 'diamond-pearl').abilities.where((a) => a.hidden),
        isEmpty,
      );
      expect(
        profile('bulbasaur', 'black-white').abilities.where((a) => a.hidden),
        hasLength(1),
      );
    });

    test('Attackenwerte je Spiel', () {
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

    test('Schadensklasse folgt bis Gen 3 dem Typ', () {
      // Biss war in Gen 1 Normal (physisch) und wurde Unlicht (bis Gen 3 speziell).
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

    test('Attacken existieren erst ab ihrer Generation', () {
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

  group('Verfügbarkeit', () {
    test('Mega-Formen erst ab X/Y', () {
      expect(
        profile('venusaur-mega', 'black-white').availability,
        DataAvailability.confirmedUnavailable,
      );
    });

    test('Formen mit Erlernbarkeit gelten als bestätigt', () {
      expect(
        profile('raichu-alola', 'sun-moon').availability,
        DataAvailability.confirmedAvailable,
      );
      expect(
        profile('raichu-alola', 'x-y').availability,
        DataAvailability.confirmedUnavailable,
      );
    });

    test('fehlende Daten sind Lücken, keine Nichtverfügbarkeit', () {
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
  });

  group('Entwicklungen', () {
    List<String> family(String form, String version) => [
      for (final e in queries.detail(FormId(form), ctx(version)).evolutions)
        '${e.from.id.value}>${e.to.id.value}',
    ];

    test('Alola-Raichu ersetzt Raichu in Sonne/Mond', () {
      expect(family('pikachu', 'sun'), contains('pikachu>raichu-alola'));
      expect(family('pikachu', 'sun'), isNot(contains('pikachu>raichu')));
      expect(family('pikachu', 'x'), contains('pikachu>raichu'));
      expect(family('pikachu', 'x'), isNot(contains('pikachu>raichu-alola')));
    });

    test('Magnezone: Ort hängt vom Spiel ab', () {
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

    test('Evoli hat mehrere Entwicklungen', () {
      expect(family('eevee', 'red').length, 3);
    });
  });

  group('Erlernbarkeit', () {
    test('Pikachu in Rot/Blau: Level und Maschinen', () {
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

    test('Wer erlernt eine Attacke', () {
      final learners = details.learnersOf(
        const MoveId('thunderbolt'),
        const VersionGroupId('red-blue'),
      );
      expect(
        learners.map((l) => l.form.value),
        containsAll(['pikachu', 'raichu']),
      );
    });

    test('Attackenhistorie ist chronologisch', () {
      final history = details.moveHistory(const MoveId('thunderbolt'));
      final orders = [
        for (final (g, _) in history) catalog.versionGroups[g]!.order,
      ];
      expect(orders, orderedEquals([...orders]..sort()));
    });
  });

  group('Suche', () {
    test('Attacken sprachübergreifend per Präfix', () {
      final hits = details.searchEntities('donnerbl');
      expect(hits.first, const EntityHit(EntityKind.move, 'thunderbolt'));
      expect(details.searchEntities('Thunderbolt').first.id, 'thunderbolt');
    });

    test('Fähigkeiten und Items', () {
      expect(
        details.searchEntities('Notdünger').first,
        const EntityHit(EntityKind.ability, 'overgrow'),
      );
      expect(
        details.searchEntities('Donnerstein'),
        contains(const EntityHit(EntityKind.item, 'thunder-stone')),
      );
    });

    test('Sonderzeichen in der Anfrage sind harmlos', () {
      expect(
        details.searchEntities('"; DROP TABLE move; --'),
        isA<List<EntityHit>>(),
      );
      expect(details.searchEntities('   '), isEmpty);
    });
  });
}
