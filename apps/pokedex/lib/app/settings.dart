import 'package:flutter/material.dart';

/// Persönliche Einstellungen. Gespeichert getrennt vom Katalog.
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.gameVersion,
    this.dataLanguage,
  });

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == j['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    gameVersion: j['gameVersion'] as String?,
    dataLanguage: j['dataLanguage'] as String?,
  );

  final ThemeMode themeMode;

  /// Gewählte Spielversion; `null` = neueste im Katalog.
  final String? gameVersion;

  /// Sprache der Spieldaten; `null` = wie App-Sprache.
  final String? dataLanguage;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? gameVersion,
    String? Function()? dataLanguage,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    gameVersion: gameVersion ?? this.gameVersion,
    dataLanguage: dataLanguage == null ? this.dataLanguage : dataLanguage(),
  );

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    if (gameVersion != null) 'gameVersion': gameVersion,
    if (dataLanguage != null) 'dataLanguage': dataLanguage,
  };
}
