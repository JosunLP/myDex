import 'package:mydex_domain/mydex_domain.dart';
import 'package:test/test.dart';

void main() {
  group('DataAvailability', () {
    test('only confirmed states count as facts', () {
      expect(DataAvailability.confirmedUnavailable.isConfirmed, isTrue);
      expect(DataAvailability.notResearched.isGap, isTrue);
      expect(DataAvailability.unknown.isGap, isTrue);
    });

    test('unknown key is an error', () {
      expect(() => DataAvailability.parse('maybe'), throwsFormatException);
    });
  });

  group('LocalizedText', () {
    const text = LocalizedText({'de': 'Glurak', 'en': 'Charizard'});

    test('exact language', () {
      final r = text.resolve('de');
      expect(r.text, 'Glurak');
      expect(r.isFallback, isFalse);
    });

    test('regional variant falls back to the base language', () {
      expect(text.resolve('de-AT').text, 'Glurak');
      expect(text.resolve('de-AT').isFallback, isFalse);
    });

    test('missing language is marked as fallback', () {
      final r = text.resolve('he');
      expect(r.text, 'Charizard');
      expect(r.isFallback, isTrue);
    });
  });

  group('Collection', () {
    final now = DateTime.utc(2026, 10, 25);
    const key = CollectionKey(
      scope: GameScope(GameVersionId('red')),
      form: FormId('pikachu'),
    );

    test('key is encoded reversibly', () {
      const shiny = CollectionKey(
        scope: GlobalScope(),
        form: FormId('raichu-alola'),
        shiny: true,
      );
      expect(CollectionKey.decode(shiny.encoded), shiny);
      expect(CollectionKey.decode(key.encoded), key);
      expect(
        shiny ==
            const CollectionKey(
              scope: GlobalScope(),
              form: FormId('raichu-alola'),
            ),
        isFalse,
      );
    });

    test('caught implies seen and sets the catch date', () {
      final e = CollectionEntry(key: key, updatedAt: now).withCaught(true, now);
      expect(e.seen, isTrue);
      expect(e.caughtAt, now);
      final later = now.add(const Duration(days: 1));
      expect(
        e.withCaught(true, later).caughtAt,
        now,
        reason: 'first catch date is kept',
      );
    });

    test('not seen implies not caught', () {
      final e = CollectionEntry(
        key: key,
        updatedAt: now,
      ).withCaught(true, now).withSeen(false, now);
      expect(e.caught, isFalse);
      expect(e.caughtAt, isNull);
      expect(e.isEmpty, isTrue);
    });

    test('JSON round trip', () {
      final e = CollectionEntry(
        key: key,
        updatedAt: now,
        note: 'Route 1',
      ).withCaught(true, now);
      final back = CollectionEntry.fromJson(e.toJson());
      expect(back.key, e.key);
      expect(back.caught, isTrue);
      expect(back.caughtAt, now);
      expect(back.note, 'Route 1');
    });
  });

  group('EvolutionCondition', () {
    test('nested tree is read', () {
      final c = EvolutionCondition.fromJson({
        'kind': 'allOf',
        'of': [
          {'kind': 'useItem', 'item': 'thunder-stone'},
          {'kind': 'region', 'region': 'alola'},
        ],
      });
      expect(c, isA<AllOf>());
      expect(c.referencedItems, [const ItemId('thunder-stone')]);
    });

    test('unknown nodes are rejected', () {
      expect(
        () => EvolutionCondition.fromJson({'kind': 'eval', 'code': 'x'}),
        throwsFormatException,
      );
    });

    test('invalid level is rejected', () {
      expect(
        () => EvolutionCondition.fromJson({'kind': 'minLevel', 'level': 101}),
        throwsFormatException,
      );
    });

    test('allOf with only one condition is rejected', () {
      expect(
        () => EvolutionCondition.fromJson({
          'kind': 'allOf',
          'of': [
            {'kind': 'trade'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  test('Gen 1 base stats count Special once', () {
    const s = BaseStats.gen1(
      hp: 78,
      attack: 84,
      defense: 78,
      special: 85,
      speed: 100,
    );
    expect(s.specialAttack, s.specialDefense);
    expect(s.total(unifiedSpecial: true), 425);
  });

  test(
    'evolution conditions: JSON round trip including special conditions',
    () {
      const c = AllOf([
        MinLevel(25),
        TimeOfDayCondition(TimeOfDay.dusk),
        SpecialCondition('party-type', value: 'dark'),
        SpecialCondition('overworld-rain'),
      ]);
      final back = EvolutionCondition.fromJson(c.toJson()) as AllOf;
      expect(back.conditions, hasLength(4));
      expect((back.conditions[1] as TimeOfDayCondition).time, TimeOfDay.dusk);
      final special = back.conditions[2] as SpecialCondition;
      expect(special.explanationKey, 'party-type');
      expect(special.value, 'dark');
      expect((back.conditions[3] as SpecialCondition).value, isNull);
    },
  );
}
