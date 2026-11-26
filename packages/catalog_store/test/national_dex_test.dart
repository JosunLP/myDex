import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  late Directory dir;
  late LoadedCatalog loaded;
  late CatalogSnapshot catalog;
  late CatalogDetails details;
  late GameContext national;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('mydex_national');
    loaded = openLoadedCatalog(await installFixture(dir));
    catalog = loaded.snapshot;
    details = loaded.details;
    national = catalog.contextFor(NationalDex.versionId);
  });
  tearDownAll(() {
    details.close();
    dir.deleteSync(recursive: true);
  });

  PokemonForm form(String id) => catalog.forms[FormId(id)]!;
  FormGameProfile profile(String id) =>
      catalog.profileOf(form(id), national.versionGroupId);
  GameContext game(String id) => catalog.contextFor(GameVersionId(id));

  group('International Pokédex', () {
    test('is a context of its own, independent of any game', () {
      expect(national, catalog.nationalContext);
      expect(national.version.name('de'), 'Internationaler Pokédex');
      expect(national.version.name('en'), 'International Pokédex');
      expect(catalog.hasVersion(NationalDex.versionId), isTrue);
      expect(
        catalog.versionById(NationalDex.versionId)?.id,
        national.versionId,
      );
      expect(
        catalog.versions.map((v) => v.id),
        isNot(contains(NationalDex.versionId)),
        reason: 'not a game: never listed among the games',
      );
    });

    test('uses the newest rules', () {
      final newest = catalog.versionGroups.values
          .map((g) => g.generation)
          .reduce((a, b) => a > b ? a : b);
      expect(national.generation, newest);
      expect(national.ruleset.typeChartEra, TypeChartEra.gen6plus);
      expect(national.ruleset.statFormula, StatFormula.modern);
      expect(national.ruleset.hasAbilities, isTrue);
      expect(national.ruleset.hasBreeding, isTrue);
      expect(national.ruleset.unifiedSpecial, isFalse);
    });

    test('lists every Pokémon, not only the newest roster', () {
      final queries = PokemonQueries(catalog);
      final all = queries.list(national);
      final newestGame = queries.list(game(catalog.versions.last.id.value));
      expect(all.length, greaterThan(newestGame.length));
      expect(
        all.map((i) => i.form.id),
        containsAll(const [FormId('clefairy'), FormId('pikachu')]),
      );
      // National order, default forms first.
      final numbers = [for (final i in all) i.species.nationalNumber];
      expect(numbers, orderedEquals([...numbers]..sort()));
    });

    test('takes the newest known data of each form', () {
      // Clefairy: Normal up to Gen 5, Fairy since Gen 6.
      final clefairy = profile('clefairy');
      expect(clefairy.availability, DataAvailability.confirmedAvailable);
      expect(clefairy.types, [PokemonType.fairy]);
      expect(clefairy.baseStats, isNotNull);
      expect(
        clefairy.abilities.map((a) => a.abilityId),
        contains(const AbilityId('magic-guard')),
      );
      final source = catalog.national.profileSource(const FormId('clefairy'))!;
      final sourceGroup = catalog.versionGroups[source]!;
      expect(
        form('clefairy').profileFor(source).availability,
        DataAvailability.confirmedAvailable,
      );
      expect(sourceGroup.hasData, isTrue, reason: 'a game with own data');
      // No newer game with own data confirms Clefairy with complete data.
      for (final g in catalog.versionGroups.values) {
        if (g.order <= sourceGroup.order || !g.hasData) continue;
        final p = form('clefairy').profileFor(g.id);
        expect(
          p.availability == DataAvailability.confirmedAvailable &&
              p.types.isNotEmpty &&
              p.baseStats != null,
          isFalse,
          reason: '${g.id.value} is newer than the source',
        );
      }
    });

    test('expansions without own data are never the source', () {
      for (final f in catalog.forms.values) {
        final source = catalog.national.profileSource(f.id);
        if (source == null) continue;
        final confirmedWithData = catalog.versionGroups.values.any(
          (g) =>
              g.hasData &&
              f.profileFor(g.id).availability ==
                  DataAvailability.confirmedAvailable &&
              f.profileFor(g.id).types.isNotEmpty &&
              f.profileFor(g.id).baseStats != null,
        );
        if (confirmedWithData) {
          expect(
            catalog.versionGroups[source]!.hasData,
            isTrue,
            reason: f.id.value,
          );
        }
      }
    });

    test('abilities only from games that have abilities', () {
      for (final f in catalog.forms.values) {
        final p = profile(f.id.value);
        if (p.availability != DataAvailability.confirmedAvailable) continue;
        expect(p.types.length, inInclusiveRange(1, 2), reason: f.id.value);
        if (p.abilities.isEmpty) continue;
        final ids = [for (final a in p.abilities) a.abilityId];
        final fromGameWithAbilities = catalog.versionGroups.values.any((g) {
          final game = f.profileFor(g.id);
          return (catalog.rulesets[g.rulesetId]?.hasAbilities ?? false) &&
              game.abilities.length == ids.length &&
              [
                for (final (i, a) in game.abilities.indexed)
                  a.abilityId == ids[i],
              ].every((x) => x);
        });
        expect(fromGameWithAbilities, isTrue, reason: f.id.value);
      }
      expect(profile('pikachu').abilities, isNotEmpty);
    });

    test('inherited moves come from the same game as the own ones', () {
      final evaluator = TeamEvaluator(catalog, details, national);
      var checked = 0;
      for (final f in catalog.forms.values) {
        final pre = preEvolutionsOf(catalog, f.id, national.versionGroupId);
        final source = details.newestLearnsetGroups()[f.id];
        if (pre.isEmpty || source == null) continue;
        final sameGame = {
          for (final x in [f.id, ...pre])
            for (final e in details.learnset(x, source)) e.move,
        };
        expect(
          evaluator.learnable(f.id).keys.toSet().difference(sameGame),
          isEmpty,
          reason: '${f.id.value}: all from ${source.value}',
        );
        checked++;
      }
      expect(checked, greaterThan(0));
    });

    test('forms without any learnset inherit nothing (data gap)', () {
      final evaluator = TeamEvaluator(catalog, details, national);
      final withoutLearnset = [
        for (final f in catalog.forms.keys)
          if (!details.newestLearnsetGroups().containsKey(f)) f,
      ];
      expect(withoutLearnset, isNotEmpty);
      for (final f in withoutLearnset) {
        expect(evaluator.learnable(f), isEmpty, reason: f.value);
      }
    });

    test('detail and evolutions with the newest conditions', () {
      final detail = PokemonQueries(
        catalog,
      ).detail(const FormId('pikachu'), national);
      expect(detail.abilitiesApplicable, isTrue);
      final pairs = {
        for (final e in detail.evolutions) (e.from.id.value, e.to.id.value),
      };
      expect(pairs, contains(('pichu', 'pikachu')));
      expect(pairs, contains(('pikachu', 'raichu')));
      // Every pair appears with the conditions of one game only.
      for (final e in catalog.national.evolutions) {
        expect(e.versionGroups, {NationalDex.versionGroupId});
      }
      expect(
        preEvolutionsOf(
          catalog,
          const FormId('raichu'),
          national.versionGroupId,
        ),
        [const FormId('pikachu'), const FormId('pichu')],
      );
    });

    test('learnset of the newest game that has one', () {
      final source = details.newestLearnsetGroups()[const FormId('pikachu')]!;
      final learnset = details.learnset(
        const FormId('pikachu'),
        national.versionGroupId,
      );
      expect(learnset, isNotEmpty);
      expect(
        learnset.map((e) => e.move).toSet(),
        details
            .learnset(const FormId('pikachu'), source)
            .map((e) => e.move)
            .toSet(),
      );
      expect(
        learnset.any((e) => e.method == LearnMethod.levelUp),
        isTrue,
        reason: 'a core-series learnset with level-up moves',
      );
      final order = catalog.versionGroups[source]!.order;
      for (final g in catalog.versionGroups.values) {
        if (g.order > order) {
          expect(
            details
                .learnset(const FormId('pikachu'), g.id)
                .where((e) => e.method == LearnMethod.levelUp),
            isEmpty,
            reason: '${g.id.value} is newer than ${source.value}',
          );
        }
      }
    });

    test('moves with their newest values and learners', () {
      final history = details.moveHistory(const MoveId('thunderbolt'));
      final newest = details.moveProfile(
        const MoveId('thunderbolt'),
        national.versionGroupId,
      );
      expect(newest?.power, history.last.$2.power);
      expect(newest?.power, 90);
      final learners = details.learnersOf(
        const MoveId('thunderbolt'),
        national.versionGroupId,
      );
      expect(learners.map((l) => l.form), contains(const FormId('pikachu')));
    });

    test('moves take the newest confirmed values, never data gaps', () {
      for (final move in catalog.moves.keys) {
        final history = details.moveHistory(move);
        final confirmed = history.where(
          (e) => e.$2.availability == DataAvailability.confirmedAvailable,
        );
        if (confirmed.isEmpty) continue;
        final newest = details.moveProfile(move, national.versionGroupId)!;
        expect(
          newest.availability,
          DataAvailability.confirmedAvailable,
          reason: move.value,
        );
        expect(newest.sameValuesAs(confirmed.last.$2), isTrue);
      }
    });

    test('locations of all games, encounters per game', () {
      expect(details.hasEncounterData(national.versionId), isTrue);
      final all = details.locationsWithEncounters(national.versionId).toSet();
      expect(
        all,
        containsAll(
          details.locationsWithEncounters(const GameVersionId('red')),
        ),
      );
      expect(
        details.encountersOf(const FormId('pikachu'), national.versionId),
        isEmpty,
      );
      final versions = details.encounterVersionsOf(const FormId('pikachu'));
      expect(versions, contains(const GameVersionId('red')));
      for (final v in versions) {
        expect(details.encountersOf(const FormId('pikachu'), v), isNotEmpty);
      }
      final forest = details
          .encountersOf(const FormId('pikachu'), const GameVersionId('red'))
          .map((e) => catalog.locationAreas[e.area]!.location)
          .first;
      final atForest = details.encounterVersionsAt(forest);
      expect(atForest, contains(const GameVersionId('red')));
      // Chronological.
      int order(GameVersionId v) =>
          catalog.versions.indexWhere((x) => x.id == v);
      expect(
        atForest.map(order).toList(),
        orderedEquals([...atForest.map(order)]..sort()),
      );
    });

    test('teams follow the newest rules and learnsets', () {
      final evaluator = TeamEvaluator(catalog, details, national);
      final learnable = evaluator.learnable(const FormId('pikachu'));
      final moves = learnable.keys.take(4).toList();
      final team = Team(
        id: 't',
        name: 'Test',
        version: NationalDex.versionId,
        members: [
          TeamMember(
            form: const FormId('pikachu'),
            level: 50,
            ability: profile('pikachu').abilities.first.abilityId,
            moves: moves,
          ),
        ],
        updatedAt: DateTime.utc(2026),
      );
      expect(evaluator.check(team).status, CheckStatus.valid);
    });
  });
}
