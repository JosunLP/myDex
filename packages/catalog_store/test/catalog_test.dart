// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';

import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';
import 'package:test/test.dart';

void main() {
  final source = File('../../data/fixtures/catalog.json').readAsStringSync();
  final catalog = parseCatalogJson(source);
  final queries = PokemonQueries(catalog);
  final search = PokemonSearchIndex(catalog);
  GameContext ctx(String v) => catalog.contextFor(GameVersionId(v));

  group('Fixture-Katalog', () {
    test('ist gültig', () {
      expect(validateCatalog(catalog), isEmpty);
      expect(catalog.forms, hasLength(15));
    });

    test('Versionen sind chronologisch, Standard ist die neueste', () {
      expect(catalog.versions.first.id, const GameVersionId('red'));
      expect(
        catalog.defaultContext.versionGroupId,
        const VersionGroupId('scarlet-violet'),
      );
    });
  });

  group('Validierung', () {
    test('kaputtes JSON wird abgelehnt', () {
      expect(
        () => parseCatalogJson('{'),
        throwsA(isA<CatalogValidationException>()),
      );
    });

    test('unbekannte Schemaversion wird abgelehnt', () {
      expect(
        () => parseCatalogJson(
          source.replaceFirst('"schemaVersion": 1', '"schemaVersion": 99'),
        ),
        throwsA(isA<CatalogValidationException>()),
      );
    });

    test('Fee in Gen 1 ist ein Fehler', () {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final clefairy = (json['forms'] as List).firstWhere(
        (f) => f['id'] == 'clefairy',
      );
      clefairy['profiles']['red-blue']['types'] = ['fairy'];
      expect(
        () => parseCatalogJson(jsonEncode(json)),
        throwsA(
          isA<CatalogValidationException>().having(
            (e) => e.problems.join(),
            'problems',
            contains('fairy existiert in dieser Ära nicht'),
          ),
        ),
      );
    });

    test('unbekanntes Item in Entwicklung ist ein Fehler', () {
      expect(
        () => parseCatalogJson(
          source.replaceFirst('"item": "moon-stone"', '"item": "sun-stone"'),
        ),
        throwsA(isA<CatalogValidationException>()),
      );
    });
  });

  group('Spielkontext', () {
    test('Piepi: Normal in Rot, Fee in X', () {
      expect(
        queries.detail(const FormId('clefairy'), ctx('red')).profile.types,
        [PokemonType.normal],
      );
      expect(queries.detail(const FormId('clefairy'), ctx('x')).profile.types, [
        PokemonType.fairy,
      ]);
    });

    test('Gen 1 hat keine Fähigkeiten', () {
      final d = queries.detail(const FormId('pikachu'), ctx('red'));
      expect(d.abilitiesApplicable, isFalse);
      expect(d.abilities, isEmpty);
      expect(d.context.ruleset.unifiedSpecial, isTrue);
    });

    test('Alola-Raichu fehlt in X/Y, existiert in Sonne', () {
      final inX = queries.list(ctx('x')).map((i) => i.form.id);
      expect(inX, isNot(contains(const FormId('raichu-alola'))));
      final inSun = queries.list(ctx('sun')).map((i) => i.form.id);
      expect(inSun, contains(const FormId('raichu-alola')));
    });

    test(
      'Datenlücken bleiben sichtbar, statt als „nicht verfügbar“ zu gelten',
      () {
        final sv = queries.list(ctx('scarlet'));
        final bulbasaur = sv.firstWhere(
          (i) => i.form.id == const FormId('bulbasaur'),
        );
        expect(bulbasaur.profile.availability, DataAvailability.notResearched);
      },
    );

    test('Entwicklungsfamilie hängt vom Spiel ab', () {
      List<String> family(String v) => [
        for (final e
            in queries.detail(const FormId('raichu'), ctx(v)).evolutions)
          e.to.id.value,
      ];
      expect(family('red'), ['raichu']);
      expect(
        queries
            .detail(const FormId('raichu-alola'), ctx('sun'))
            .evolutions
            .single
            .condition,
        isA<AllOf>(),
      );
    });

    test('Familie wird von jeder Stufe aus gefunden', () {
      final d = queries.detail(const FormId('venusaur'), ctx('red'));
      expect(d.evolutions.map((e) => e.to.id.value), ['ivysaur', 'venusaur']);
    });
  });

  group('Suche', () {
    List<String> ids(String q) => [
      for (final h in search.search(q)) h.form.value,
    ];

    test('sprachübergreifend', () {
      expect(ids('charizard').first, 'charizard');
      expect(ids('Glurak').first, 'charizard');
    });

    test('Nummer mit und ohne #', () {
      expect(ids('6'), ['charizard']);
      expect(ids('#26'), ['raichu', 'raichu-alola']);
    });

    test('Präfix vor Teilstring', () {
      expect(ids('bisa'), ['bulbasaur', 'ivysaur', 'venusaur']);
    });

    test('Tippfehlertoleranz', () {
      expect(ids('Glurk'), contains('charizard'));
      expect(ids('Pikachuu'), contains('pikachu'));
    });

    test('Formname und Artname finden die Form', () {
      expect(ids('alola'), contains('raichu-alola'));
      expect(search.search('Raichu').first.kind, MatchKind.exactName);
    });

    test('leere Anfrage', () {
      expect(ids('  '), isEmpty);
    });
  });
}
