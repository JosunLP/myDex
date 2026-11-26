import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_application/mydex_application.dart';
import 'package:mydex_catalog_store/mydex_catalog_store.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// International Pokédex against the bundled catalog: cases the small test
/// catalog does not contain.
void main() {
  late LoadedCatalog loaded;

  setUpAll(() async {
    final manifest = CatalogPackManifest.fromJson(
      jsonDecode(
            File('assets/catalog/catalog.manifest.json').readAsStringSync(),
          )
          as Map<String, Object?>,
    );
    final path =
        (await CatalogInstaller(
              Directory.systemTemp.createTempSync('mydex_national_catalog'),
            ).install(
              manifest,
              File('assets/catalog/catalog.sqlite.gz').readAsBytesSync(),
            ))
            .path;
    loaded = openLoadedCatalog(path);
  });
  tearDownAll(() => loaded.details.close());

  test('inherited moves come from the form\'s own source game', () {
    final catalog = loaded.snapshot;
    final details = loaded.details;
    final national = catalog.nationalContext;
    final evaluator = TeamEvaluator(catalog, details, national);
    // Alolan Marowak: own learnset from Sword/Shield, Cubone's newest from
    // Brilliant Diamond/Shining Pearl; Galarian Mr. Mime and Mime Jr. alike.
    for (final id in ['marowak-alola', 'mr-mime-galar']) {
      final form = FormId(id);
      final source = details.newestLearnsetGroups()[form]!;
      final pre = preEvolutionsOf(catalog, form, national.versionGroupId);
      expect(pre, isNotEmpty, reason: id);
      expect(
        details.newestLearnsetGroups()[pre.first],
        isNot(source),
        reason: 'the case this test is about',
      );
      final sameGame = {
        for (final x in [form, ...pre])
          for (final e in details.learnset(x, source)) e.move,
      };
      expect(
        evaluator.learnable(form).keys.toSet().difference(sameGame),
        isEmpty,
        reason: '$id: everything from ${source.value}',
      );
    }
  });
}
