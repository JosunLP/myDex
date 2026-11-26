import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mydex_app/app/settings.dart';

void main() {
  test('settings stored by 1.0 load unchanged with new defaults', () {
    // Exactly what 1.0 wrote (game chosen explicitly).
    final settings = AppSettings.fromJson({
      'themeMode': 'dark',
      'gameVersion': 'red',
      'dataLanguage': 'en',
      'uiLanguage': 'de',
    });
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.gameVersion, 'red', reason: 'a chosen game stays');
    expect(settings.dataLanguage, 'en');
    expect(settings.uiLanguage, 'de');
    expect(settings.reduceMotion, isFalse);
    expect(settings.recentGames, isEmpty);
    expect(settings.dexLayout, DexLayout.list);
    // Without a chosen game: the International Pokédex (null).
    expect(AppSettings.fromJson({'themeMode': 'system'}).gameVersion, isNull);
    // 1.0 wrote no schema: it is migrated once the catalog is loaded.
    expect(settings.schema, 1);
    expect(const AppSettings().toJson()['schema'], AppSettings.currentSchema);
  });

  test('new settings survive a round trip and tolerate bad values', () {
    const settings = AppSettings(
      reduceMotion: true,
      recentGames: ['red', 'x'],
      dexLayout: DexLayout.grid,
    );
    final again = AppSettings.fromJson(settings.toJson());
    expect(again.reduceMotion, isTrue);
    expect(again.recentGames, ['red', 'x']);
    expect(again.dexLayout, DexLayout.grid);
    final odd = AppSettings.fromJson({
      'recentGames': ['red', 3, null],
      'dexLayout': 'carousel',
    });
    expect(odd.recentGames, ['red']);
    expect(odd.dexLayout, DexLayout.list);
  });
}
