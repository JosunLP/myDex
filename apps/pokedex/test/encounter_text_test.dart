import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/l10n/generated/app_localizations.dart';
import 'package:mydex_app/widgets/encounter_text.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Encounter methods and conditions are translated by the app because the
/// catalog has them only partly (German about a quarter, Spanish and Italian
/// none). Checked against the bundled catalog, in every UI language.
void main() {
  late LoadedCatalog loaded;
  late Map<EncounterConditionId, int> conditionUse;

  setUpAll(() async {
    final manifest = CatalogPackManifest.fromJson(
      jsonDecode(
            File('assets/catalog/catalog.manifest.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    );
    final path =
        (await CatalogInstaller(
              Directory.systemTemp.createTempSync('mydex_encounter_text'),
            ).install(
              manifest,
              File('assets/catalog/catalog.sqlite.gz').readAsBytesSync(),
            ))
            .path;
    loaded = openLoadedCatalog(path);
    // How often each condition occurs, over all games.
    conditionUse = {};
    for (final v in loaded.snapshot.versions) {
      for (final location in loaded.details.locationsWithEncounters(v.id)) {
        for (final e in loaded.details.encountersAt(location, v.id)) {
          for (final c in e.conditions) {
            conditionUse[c] = (conditionUse[c] ?? 0) + 1;
          }
        }
      }
    }
  });
  tearDownAll(() => loaded.details.close());

  for (final locale in AppLocalizations.supportedLocales) {
    final lang = locale.languageCode;

    test('every encounter method has a name in $lang', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final id in loaded.snapshot.encounterMethods.keys) {
        expect(
          l10n.encounterMethod(id.value.replaceAll('-', '_')),
          isNotEmpty,
          reason: id.value,
        );
      }
    });

    test('encounter conditions are described in $lang', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final catalog = loaded.snapshot;
      var described = 0;
      var total = 0;
      for (final MapEntry(key: id, value: count) in conditionUse.entries) {
        final text = describeEncounterCondition(id, l10n, catalog, lang);
        expect(text, isNot(contains('?')), reason: id.value);
        total += count;
        // Own wording, not the (mostly English) catalog text.
        if (translateEncounterCondition(id, l10n, catalog, lang) != null) {
          described += count;
        }
      }
      expect(described / total, greaterThan(0.98));
    });
  }

  test('parameterized conditions use catalog names', () async {
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    String d(String id) => describeEncounterCondition(
      EncounterConditionId(id),
      de,
      loaded.snapshot,
      'de',
    );
    expect(d('time-morning'), 'Morgens');
    expect(d('item-helix-fossil'), 'Helixfossil im Beutel');
    expect(d('trade-abra'), 'Abra im Tausch abgeben');
    expect(d('starter-bulbasaur'), 'Bisasam als Starter');
    expect(d('slot2-firered'), 'Feuerrot in Slot 2');
    expect(d('coins-9999'), 'Mindestens 9999 Münzen');
    expect(d('johto-safari-blocks-water-min-10'), contains('Wasser'));
    expect(d('max-den-rating-5-star'), 'Dyna-Raid 5★');
    expect(d('time-04-00-to-19-59'), '04:00–19:59 Uhr');
    expect(d('trash-can-type-tuesday'), 'Wackelnde Mülltonne (Dienstag)');
    expect(d('other-caught-articuno'), 'Nach dem Fang von Arktos');
    expect(
      d('other-regirock-regice-registeel-in-party'),
      'Regirock, Regice und Registeel im Team',
    );
    expect(d('other-dialga-or-palkia-in-party'), 'Dialga oder Palkia im Team');
    // Unknown, nameless conditions read like words, never "?".
    expect(d('other-correct-password'), isNot('?'));
    expect(
      describeEncounterMethod(
        const EncounterMethodId('super-rod'),
        de,
        loaded.snapshot,
        'de',
      ),
      'Superangel',
    );
  });
}
