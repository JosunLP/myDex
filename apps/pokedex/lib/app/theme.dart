import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Spacing of the design system.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Width classes in logical pixels (starting values, not device classes).
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1000.0;
}

/// Colours of the classic Pokédex: red casing, dark hinge, blue lens, signal
/// LEDs – deliberately a little muted (matte instead of glaring), like
/// classic Dex apps. Used for the app and navigation bars; content uses the
/// colour scheme derived from them.
abstract final class DexColors {
  static const red = Color(0xFFC4403F);
  static const redDark = Color(0xFF8E3332);
  static const hinge = Color(0xFF2E2C2C);
  static const lens = Color(0xFF4F9BC4);
  static const lensRim = Color(0xFFEDEBE8);
  static const ledRed = Color(0xFFE0574F);
  static const ledYellow = Color(0xFFE6C452);
  static const ledGreen = Color(0xFF5DBE6E);
  static const onRed = Colors.white;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: DexColors.red,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  // Dark: red app bar, navigation in the hinge's black.
  final chrome = dark ? DexColors.redDark : DexColors.red;
  final nav = dark ? DexColors.hinge : DexColors.red;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: dark ? const Color(0xFF1C1A1A) : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: chrome,
      foregroundColor: DexColors.onRed,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
        color: DexColors.onRed,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: nav,
      indicatorColor: dark ? DexColors.red : DexColors.onRed,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) && !dark
              ? DexColors.red
              : DexColors.onRed,
        ),
      ),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          color: DexColors.onRed,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: nav,
      indicatorColor: dark ? DexColors.red : DexColors.onRed,
      selectedIconTheme: IconThemeData(
        color: dark ? DexColors.onRed : DexColors.red,
      ),
      unselectedIconTheme: const IconThemeData(color: DexColors.onRed),
      selectedLabelTextStyle: const TextStyle(
        color: DexColors.onRed,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(color: DexColors.onRed),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}

/// Type colours only as an accent – types always carry their name as well.
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

/// Readable text colour on a type colour.
Color onTypeColor(Color background) => background.computeLuminance() > 0.35
    ? const Color(0xFF1B1B1F)
    : Colors.white;

const tabularFigures = [FontFeature.tabularFigures()];
