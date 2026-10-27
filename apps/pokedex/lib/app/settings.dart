import 'package:flutter/material.dart';

/// Persönliche Einstellungen. Gespeichert getrennt vom Katalog.
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

  /// Gewählte Spielversion; `null` = neueste im Katalog.
  final String? gameVersion;

  /// Sprache der Spieldaten; `null` = wie App-Sprache.
  final String? dataLanguage;

  /// Sprache der Oberfläche; `null` = Systemsprache.
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
