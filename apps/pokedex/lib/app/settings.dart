import 'package:flutter/material.dart';

/// Personal settings. Stored separately from the catalog.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.gameVersion,
    this.dataLanguage,
    this.uiLanguage,
  });

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    gameVersion: j['gameVersion'] as String?,
    dataLanguage: j['dataLanguage'] as String?,
    uiLanguage: j['uiLanguage'] as String?,
  );

  final ThemeMode themeMode;

  /// Selected game version; `null` = newest in the catalog.
  final String? gameVersion;

  /// Language of the game data; `null` = same as the app language.
  final String? dataLanguage;

  /// UI language; `null` = system language.
  final String? uiLanguage;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? gameVersion,
    String? Function()? dataLanguage,
    String? Function()? uiLanguage,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    gameVersion: gameVersion ?? this.gameVersion,
    dataLanguage: dataLanguage == null ? this.dataLanguage : dataLanguage(),
    uiLanguage: uiLanguage == null ? this.uiLanguage : uiLanguage(),
  );

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    if (gameVersion != null) 'gameVersion': gameVersion,
    if (dataLanguage != null) 'dataLanguage': dataLanguage,
    if (uiLanguage != null) 'uiLanguage': uiLanguage,
  };
}
