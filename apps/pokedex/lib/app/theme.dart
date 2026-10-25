import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Abstände des Designsystems.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Breitenklassen in logischen Pixeln (Startwerte, keine Geräteklassen).
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1000.0;
}

const _seed = Color(0xFF3949AB);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}

/// Typfarben nur als Akzent – Typen tragen immer zusätzlich ihren Namen.
Color typeColor(PokemonType type) => switch (type) {
  PokemonType.normal => const Color(0xFFA8A77A),
  PokemonType.fire => const Color(0xFFEE8130),
  PokemonType.water => const Color(0xFF6390F0),
  PokemonType.electric => const Color(0xFFF7D02C),
  PokemonType.grass => const Color(0xFF7AC74C),
  PokemonType.ice => const Color(0xFF96D9D6),
  PokemonType.fighting => const Color(0xFFC22E28),
  PokemonType.poison => const Color(0xFFA33EA1),
  PokemonType.ground => const Color(0xFFE2BF65),
  PokemonType.flying => const Color(0xFFA98FF3),
  PokemonType.psychic => const Color(0xFFF95587),
  PokemonType.bug => const Color(0xFFA6B91A),
  PokemonType.rock => const Color(0xFFB6A136),
  PokemonType.ghost => const Color(0xFF735797),
  PokemonType.dragon => const Color(0xFF6F35FC),
  PokemonType.dark => const Color(0xFF705746),
  PokemonType.steel => const Color(0xFFB7B7CE),
  PokemonType.fairy => const Color(0xFFD685AD),
};

/// Lesbare Textfarbe auf einer Typfarbe.
Color onTypeColor(Color background) => background.computeLuminance() > 0.35
    ? const Color(0xFF1B1B1F)
    : Colors.white;

const tabularFigures = [FontFeature.tabularFigures()];
