import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/theme.dart';
import 'package:mydex_app/l10n/generated/app_localizations.dart';
import 'package:mydex_app/widgets/stat_bars.dart';
import 'package:mydex_domain/mydex_domain.dart';

void main() {
  // The bundled typeface: realistic text widths instead of the test font.
  setUpAll(() async {
    final loader = FontLoader(AppFonts.sans);
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/PlusJakartaSans-$weight.ttf').readAsBytesSync(),
          ),
        ),
      );
    }
    await loader.load();
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('values and labels stay on one line at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: StatBars(
                stats: BaseStats(
                  hp: 255,
                  attack: 190,
                  defense: 230,
                  specialAttack: 194,
                  specialDefense: 230,
                  speed: 200,
                ),
                unifiedSpecial: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final text in ['255', '1299', 'Initiative', 'Summe']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(text).first,
        );
        // As high as the text laid out without a width limit: one line.
        final oneLine = paragraph.getDryLayout(const BoxConstraints()).height;
        expect(paragraph.size.height, oneLine, reason: '"$text" wraps');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
