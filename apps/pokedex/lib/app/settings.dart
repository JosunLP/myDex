import 'package:flutter/material.dart';

/// How the Dex list is shown.
enum DexLayout { list, grid }

/// Personal settings. Stored separately from the catalog.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.gameVersion,
    this.dataLanguage,
    this.uiLanguage,
    this.reduceMotion = false,
    this.recentGames = const [],
    this.dexLayout = DexLayout.list,
  });

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    gameVersion: j['gameVersion'] as String?,
    dataLanguage: j['dataLanguage'] as String?,
    uiLanguage: j['uiLanguage'] as String?,
    reduceMotion: (j['reduceMotion'] as bool?) ?? false,
    recentGames: [
      for (final g in (j['recentGames'] as List<Object?>?) ?? const [])
        if (g is String) g,
    ],
    dexLayout: DexLayout.values.firstWhere(
      (l) => l.name == j['dexLayout'],
      orElse: () => DexLayout.list,
    ),
  );

  /// How many recently used games the game picker offers.
  static const maxRecentGames = 4;

  final ThemeMode themeMode;

  /// Selected game version; `null` = the International Pokédex (ADR 0016).
  final String? gameVersion;

  /// Language of the game data; `null` = same as the app language.
  final String? dataLanguage;

  /// UI language; `null` = system language.
  final String? uiLanguage;

  /// Switches animations off in addition to the system setting.
  final bool reduceMotion;

  /// Recently selected game versions, newest first.
  final List<String> recentGames;

  final DexLayout dexLayout;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? Function()? gameVersion,
    String? Function()? dataLanguage,
    String? Function()? uiLanguage,
    bool? reduceMotion,
    List<String>? recentGames,
    DexLayout? dexLayout,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    gameVersion: gameVersion == null ? this.gameVersion : gameVersion(),
    dataLanguage: dataLanguage == null ? this.dataLanguage : dataLanguage(),
    uiLanguage: uiLanguage == null ? this.uiLanguage : uiLanguage(),
    reduceMotion: reduceMotion ?? this.reduceMotion,
    recentGames: recentGames ?? this.recentGames,
    dexLayout: dexLayout ?? this.dexLayout,
  );

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    if (gameVersion != null) 'gameVersion': gameVersion,
    if (dataLanguage != null) 'dataLanguage': dataLanguage,
    if (uiLanguage != null) 'uiLanguage': uiLanguage,
    if (reduceMotion) 'reduceMotion': true,
    if (recentGames.isNotEmpty) 'recentGames': recentGames,
    if (dexLayout != DexLayout.list) 'dexLayout': dexLayout.name,
  };
}
