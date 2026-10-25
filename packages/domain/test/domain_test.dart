import 'package:mydex_domain/mydex_domain.dart';
import 'package:test/test.dart';

void main() {
  group('DataAvailability', () {
    test('nur bestätigte Zustände gelten als Fakt', () {
      expect(DataAvailability.confirmedUnavailable.isConfirmed, isTrue);
      expect(DataAvailability.notResearched.isGap, isTrue);
      expect(DataAvailability.unknown.isGap, isTrue);
    });

    test('unbekannter Schlüssel ist ein Fehler', () {
      expect(() => DataAvailability.parse('maybe'), throwsFormatException);
    });
  });

  group('LocalizedText', () {
    const text = LocalizedText({'de': 'Glurak', 'en': 'Charizard'});

    test('exakte Sprache', () {
      final r = text.resolve('de');
      expect(r.text, 'Glurak');
      expect(r.isFallback, isFalse);
    });

    test('Regionalvariante fällt auf Basissprache zurück', () {
      expect(text.resolve('de-AT').text, 'Glurak');
      expect(text.resolve('de-AT').isFallback, isFalse);
    });

    test('fehlende Sprache wird als Fallback gekennzeichnet', () {
      final r = text.resolve('he');
      expect(r.text, 'Charizard');
      expect(r.isFallback, isTrue);
    });
  });

  group('Sammlung', () {
    final now = DateTime.utc(2026, 10, 25);
    const key = CollectionKey(
      scope: GameScope(GameVersionId('red')),
      form: FormId('pikachu'),
    );

    test('Schlüssel ist umkehrbar kodiert', () {
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

    test('gefangen impliziert gesehen und setzt Fangdatum', () {
      final e = CollectionEntry(key: key, updatedAt: now).withCaught(true, now);
      expect(e.seen, isTrue);
      expect(e.caughtAt, now);
      final later = now.add(const Duration(days: 1));
      expect(
        e.withCaught(true, later).caughtAt,
        now,
        reason: 'erstes Fangdatum bleibt',
      );
    });

    test('nicht gesehen impliziert nicht gefangen', () {
      final e = CollectionEntry(
        key: key,
        updatedAt: now,
      ).withCaught(true, now).withSeen(false, now);
      expect(e.caught, isFalse);
      expect(e.caughtAt, isNull);
      expect(e.isEmpty, isTrue);
    });

    test('JSON-Rundreise', () {
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
    test('verschachtelter Baum wird gelesen', () {
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

    test('unbekannte Knoten werden abgelehnt', () {
      expect(
        () => EvolutionCondition.fromJson({'kind': 'eval', 'code': 'x'}),
        throwsFormatException,
      );
    });

    test('ungültiges Level wird abgelehnt', () {
      expect(
        () => EvolutionCondition.fromJson({'kind': 'minLevel', 'level': 101}),
        throwsFormatException,
      );
    });

    test('allOf mit nur einer Bedingung wird abgelehnt', () {
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

  test('Gen-1-Basiswerte zählen Spezial einmal', () {
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
}
