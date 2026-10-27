import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:test/test.dart';

void main() {
  final at = DateTime.utc(2026);
  PokemonListItem item(
    String id,
    int gen,
    List<PokemonType> types, {
    bool isDefault = true,
  }) => PokemonListItem(
    form: PokemonForm(
      id: FormId(id),
      speciesId: SpeciesId(id),
      isDefault: isDefault,
      profiles: const {},
    ),
    species: Species(
      id: SpeciesId(id),
      nationalNumber: 1,
      name: const LocalizedText({}),
      generation: gen,
    ),
    profile: FormGameProfile(
      availability: DataAvailability.confirmedAvailable,
      types: types,
    ),
  );
  final items = [
    item('charizard', 1, [PokemonType.fire, PokemonType.flying]),
    item('arcanine', 1, [PokemonType.fire]),
    item('pidgey', 1, [PokemonType.normal, PokemonType.flying]),
    item('torchic', 3, [PokemonType.fire]),
    item('raichu-alola', 1, [
      PokemonType.electric,
      PokemonType.psychic,
    ], isDefault: false),
  ];
  const scope = GameScope(GameVersionId('red'));
  final collection = {
    for (final e in [
      CollectionEntry(
        key: const CollectionKey(scope: scope, form: FormId('arcanine')),
        updatedAt: at,
      ).withCaught(true, at),
    ])
      e.key: e,
  };
  List<String> ids(DexFilter f) => [
    for (final i in applyDexFilter(
      items,
      f,
      collection: collection,
      scope: scope,
    ))
      i.form.id.value,
  ];

  test('type filter: contains any or all types', () {
    expect(ids(const DexFilter(types: {PokemonType.fire})), [
      'charizard',
      'arcanine',
      'torchic',
    ]);
    expect(
      ids(
        const DexFilter(
          types: {PokemonType.fire, PokemonType.flying},
          typeMatch: TypeMatch.all,
        ),
      ),
      ['charizard'],
    );
    expect(
      ids(const DexFilter(types: {PokemonType.fire, PokemonType.flying})),
      ['charizard', 'arcanine', 'pidgey', 'torchic'],
    );
  });

  test('generation, default forms and collection status combined (AND)', () {
    expect(ids(const DexFilter(generations: {3})), ['torchic']);
    expect(
      ids(const DexFilter(defaultFormsOnly: true)),
      isNot(contains('raichu-alola')),
    );
    expect(
      ids(
        const DexFilter(
          types: {PokemonType.fire},
          collection: CollectionFilter.missing,
        ),
      ),
      ['charizard', 'torchic'],
    );
    expect(ids(const DexFilter(collection: CollectionFilter.caught)), [
      'arcanine',
    ]);
  });

  test('filter JSON tolerates versions', () {
    const f = DexFilter(
      types: {PokemonType.water},
      generations: {1, 2},
      collection: CollectionFilter.shinyMissing,
    );
    expect(DexFilter.fromJson(f.toJson()), f);
    expect(
      DexFilter.fromJson({
        'types': ['unbekannt', 'fire'],
        'collection': 'neu',
      }),
      const DexFilter(types: {PokemonType.fire}),
    );
  });

  test('overview across all games', () {
    final early = DateTime.utc(2025);
    final entries = [
      CollectionEntry(
        key: const CollectionKey(
          scope: GameScope(GameVersionId('red')),
          form: FormId('pikachu'),
        ),
        updatedAt: at,
      ).withCaught(true, at),
      CollectionEntry(
        key: const CollectionKey(
          scope: GameScope(GameVersionId('x')),
          form: FormId('pikachu'),
        ),
        updatedAt: early,
      ).withCaught(true, early),
      CollectionEntry(
        key: const CollectionKey(
          scope: GameScope(GameVersionId('x')),
          form: FormId('pikachu'),
          shiny: true,
        ),
        updatedAt: at,
      ).withCaught(true, at),
      CollectionEntry(
        key: const CollectionKey(
          scope: GameScope(GameVersionId('x')),
          form: FormId('eevee'),
        ),
        updatedAt: at,
      ).withSeen(true, at),
    ];
    final overview = crossGameOverview(entries);
    final pikachu = overview[const FormId('pikachu')]!;
    expect(pikachu.caughtIn, {
      const GameVersionId('red'),
      const GameVersionId('x'),
    });
    expect(pikachu.shinyCaught, isTrue);
    expect(pikachu.firstCaughtAt, early);
    expect(
      overview.containsKey(const FormId('eevee')),
      isFalse,
      reason: 'only seen',
    );
  });
}
