import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:mydex_game_rules/mydex_game_rules.dart';
import 'package:test/test.dart';

import 'fixture.dart';

void main() {
  late Directory dir;
  late CatalogSnapshot catalog;
  late SqliteCatalogDetails details;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('mydex_team');
    final path = await installFixture(dir);
    catalog = loadCatalogSnapshot(path);
    details = SqliteCatalogDetails.open(path);
  });
  tearDownAll(() {
    details.close();
    dir.deleteSync(recursive: true);
  });

  TeamEvaluator evaluator(String version) => TeamEvaluator(
    catalog,
    details,
    catalog.contextFor(GameVersionId(version)),
  );
  Team team(String version, List<TeamMember> members) => Team(
    id: 't',
    name: 'Test',
    version: GameVersionId(version),
    members: members,
    updatedAt: DateTime.utc(2026),
  );
  Set<IssueKind> kinds(MemberCheck c) => {for (final i in c.issues) i.kind};

  group('Prüfung', () {
    test('gültiges Gen-1-Team', () {
      final check = evaluator('red').check(
        team('red', const [
          TeamMember(
            form: FormId('pikachu'),
            level: 25,
            moves: [MoveId('thunder-shock'), MoveId('thunderbolt')],
          ),
        ]),
      );
      expect(check.status, CheckStatus.valid);
    });

    test('Fähigkeiten, Items und Wesen gibt es in Gen 1 nicht', () {
      final c = evaluator('red').checkMember(
        const TeamMember(
          form: FormId('pikachu'),
          ability: AbilityId('static'),
          item: ItemId('leftovers'),
          nature: NatureId('modest'),
        ),
      );
      expect(c.status, CheckStatus.invalid);
      expect(
        kinds(c),
        containsAll([
          IssueKind.abilityNotApplicable,
          IssueKind.heldItemsNotApplicable,
          IssueKind.naturesNotApplicable,
        ]),
      );
    });

    test('Fähigkeit muss zur Form passen', () {
      final ok = evaluator('x').checkMember(
        const TeamMember(
          form: FormId('pikachu'),
          ability: AbilityId('lightning-rod'),
        ),
      );
      expect(ok.status, CheckStatus.valid);
      final wrong = evaluator('x').checkMember(
        const TeamMember(
          form: FormId('pikachu'),
          ability: AbilityId('overgrow'),
        ),
      );
      expect(kinds(wrong), contains(IssueKind.abilityNotAvailable));
    });

    test('Items: tragbar je Generation, Basis-Items nie', () {
      expect(
        evaluator('gold')
            .checkMember(
              const TeamMember(
                form: FormId('pikachu'),
                item: ItemId('leftovers'),
              ),
            )
            .status,
        CheckStatus.valid,
      );
      expect(
        kinds(
          evaluator('x').checkMember(
            const TeamMember(form: FormId('pikachu'), item: ItemId('bicycle')),
          ),
        ),
        contains(IssueKind.itemNotHoldable),
      );
    });

    test(
      'Attacken: nicht im Spiel = ungültig, nicht erfasst erlernbar = teilweise geprüft',
      () {
        final notInGame = evaluator('red').checkMember(
          const TeamMember(
            form: FormId('pikachu'),
            moves: [MoveId('moonblast')],
          ),
        );
        expect(kinds(notInGame), contains(IssueKind.moveNotInGame));
        expect(notInGame.status, CheckStatus.invalid);

        final notLearnable = evaluator('red').checkMember(
          const TeamMember(
            form: FormId('pikachu'),
            moves: [MoveId('flamethrower')],
          ),
        );
        expect(kinds(notLearnable), contains(IssueKind.moveNotInLearnset));
        expect(notLearnable.status, CheckStatus.partial);

        final duplicate = evaluator('red').checkMember(
          const TeamMember(
            form: FormId('pikachu'),
            moves: [MoveId('thunder-shock'), MoveId('thunder-shock')],
          ),
        );
        expect(kinds(duplicate), contains(IssueKind.duplicateMove));
      },
    );

    test('Form muss im Spiel existieren', () {
      final c = evaluator(
        'red',
      ).checkMember(const TeamMember(form: FormId('raichu-alola')));
      expect(kinds(c), contains(IssueKind.formNotInGame));
    });

    test('ungültige Werte und zu große Teams', () {
      final evs = evaluator('x').checkMember(
        const TeamMember(
          form: FormId('pikachu'),
          evs: {Stat.hp: 252, Stat.attack: 252, Stat.speed: 252},
        ),
      );
      expect(kinds(evs), contains(IssueKind.statValuesInvalid));
      final big = evaluator('x').check(
        team('x', [
          for (var i = 0; i < 7; i++) const TeamMember(form: FormId('pikachu')),
        ]),
      );
      expect(
        big.teamIssues.map((i) => i.kind),
        contains(IssueKind.teamTooLarge),
      );
      expect(big.status, CheckStatus.invalid);
    });
  });

  test('Werte mit Wesen (Pikachu, X, Lv. 50, Mäßig)', () {
    final stats = evaluator('x').stats(
      const TeamMember(form: FormId('pikachu'), nature: NatureId('modest')),
    )!;
    expect(stats[Stat.hp], 110);
    expect(stats[Stat.specialAttack], 77);
    expect(stats[Stat.attack], 67);
  });

  test('Wesen haben Namen und Effekte', () {
    final modest = catalog.natures[const NatureId('modest')]!;
    expect(modest.name('de'), 'Mäßig');
    expect(modest.increased, Stat.specialAttack);
    expect(modest.decreased, Stat.attack);
    expect(catalog.natures[const NatureId('hardy')]!.isNeutral, isTrue);
  });

  test('Vorschläge schließen Abdeckungslücken mit erlernbaren Attacken', () {
    final t = team('x', const [
      TeamMember(form: FormId('pikachu'), moves: [MoveId('thunder-shock')]),
    ]);
    final insights = evaluator('x').insights(t);
    final gaps = insights.analysis.findings.whereType<CoverageGap>().map(
      (g) => g.defendingType,
    );
    expect(gaps, contains(PokemonType.ground));
    expect(insights.suggestions, isNotEmpty);
    // Inkl. Vorentwicklung (Pichu).
    final learnable = evaluator(
      'x',
    ).learnable(const FormId('pikachu')).keys.toSet();
    for (final s in insights.suggestions) {
      expect(learnable, contains(s.move));
      expect(gaps, contains(s.covers));
    }
  });

  group('Vorentwicklungen', () {
    test('Kette rückwärts im Spiel', () {
      expect(
        preEvolutionsOf(
          catalog,
          const FormId('raichu'),
          const VersionGroupId('gold-silver'),
        ),
        [const FormId('pikachu'), const FormId('pichu')],
      );
      expect(
        preEvolutionsOf(
          catalog,
          const FormId('raichu'),
          const VersionGroupId('red-blue'),
        ),
        [const FormId('pikachu')],
        reason: 'Pichu gibt es erst ab Gen 2',
      );
    });

    test('Attacken der Vorentwicklung sind legal (Ei- und Zuchtattacken)', () {
      final glurak = evaluator('x').checkMember(
        const TeamMember(
          form: FormId('charizard'),
          moves: [MoveId('dragon-pulse')],
        ),
      );
      expect(
        glurak.status,
        CheckStatus.valid,
        reason: 'Drachenpuls ist Glumandas Ei-Attacke',
      );
      final pikachu = evaluator('x').checkMember(
        const TeamMember(
          form: FormId('pikachu'),
          moves: [MoveId('volt-tackle')],
        ),
      );
      expect(
        pikachu.status,
        CheckStatus.valid,
        reason: 'Volttackle über Pichu (Kugelblitz-Zucht)',
      );
      expect(
        evaluator('x').learnable(const FormId('pikachu'))[const MoveId(
          'volt-tackle',
        )],
        const FormId('pichu'),
      );
    });
  });
}
