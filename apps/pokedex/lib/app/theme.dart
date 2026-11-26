import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:mydex_domain/mydex_domain.dart';

/// Spacing of the design system (4-point grid).
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

/// Corner radii: small controls, cards, sheets and screens.
abstract final class Radii {
  static const s = 10.0;
  static const m = 16.0;
  static const l = 22.0;
  static const xl = 28.0;
}

/// Width classes in logical pixels (starting values, not device classes).
abstract final class Breakpoints {
  static const medium = 600.0;
  static const expanded = 1000.0;
}

/// Bundled typefaces (SIL OFL, see `assets/licenses`).
abstract final class AppFonts {
  /// Plus Jakarta Sans: friendly, geometric and very legible at small sizes.
  static const sans = 'PlusJakartaSans';

  /// JetBrains Mono for the digital Pokédex number.
  static const mono = 'JetBrainsMono';
}

/// Brand colours of myDex: the red Pokédex casing, the dark hinge, the blue
/// lens and the three signal LEDs. The red is tuned for contrast (≥ 4.5:1
/// against white) so it works for text and filled controls alike.
abstract final class DexColors {
  static const red = Color(0xFFCF3634);
  static const redDark = Color(0xFF9E2426);
  static const redLight = Color(0xFFFF8C82);
  static const hinge = Color(0xFF1D1A1B);
  static const lens = Color(0xFF3D8FD6);
  static const lensLight = Color(0xFF9FD2FA);
  static const lensRim = Color(0xFFF3F0EE);
  static const ledRed = Color(0xFFFF544D);
  static const ledYellow = Color(0xFFF2CC4E);
  static const ledGreen = Color(0xFF5CCB78);
  static const onRed = Colors.white;

  /// Text colour of the digital number display.
  static const display = Color(0xFF8BF0A6);
}

ColorScheme _scheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: DexColors.red,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  // Neutral, slightly warm surfaces instead of tinted ones: the content
  // (artwork colours, types) brings the colour, the chrome stays calm.
  return dark
      ? base.copyWith(
          primary: const Color(0xFFFFB4AB),
          onPrimary: const Color(0xFF5C1313),
          primaryContainer: const Color(0xFF7D2324),
          onPrimaryContainer: const Color(0xFFFFDAD5),
          surface: const Color(0xFF131112),
          onSurface: const Color(0xFFEDE7E6),
          onSurfaceVariant: const Color(0xFFD1C7C6),
          surfaceDim: const Color(0xFF131112),
          surfaceBright: const Color(0xFF3A3536),
          surfaceContainerLowest: const Color(0xFF0E0C0D),
          surfaceContainerLow: const Color(0xFF1B1819),
          surfaceContainer: const Color(0xFF201D1E),
          surfaceContainerHigh: const Color(0xFF2A2627),
          surfaceContainerHighest: const Color(0xFF353031),
          outline: const Color(0xFF9C9291),
          outlineVariant: const Color(0xFF4B4444),
          inverseSurface: const Color(0xFFEDE7E6),
          onInverseSurface: const Color(0xFF201D1E),
        )
      : base.copyWith(
          primary: DexColors.red,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFDAD5),
          onPrimaryContainer: const Color(0xFF6B1416),
          surface: const Color(0xFFFCFAFA),
          onSurface: const Color(0xFF1D1A1B),
          onSurfaceVariant: const Color(0xFF544D4C),
          surfaceDim: const Color(0xFFE2DCDB),
          surfaceBright: const Color(0xFFFCFAFA),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF7F3F3),
          surfaceContainer: const Color(0xFFF2EDEC),
          surfaceContainerHigh: const Color(0xFFECE6E5),
          surfaceContainerHighest: const Color(0xFFE5DEDD),
          outline: const Color(0xFF857B7A),
          outlineVariant: const Color(0xFFDCD3D2),
          inverseSurface: const Color(0xFF332F30),
          onInverseSurface: const Color(0xFFF7F0EF),
        );
}

TextTheme _textTheme(ColorScheme scheme) {
  final base = Typography.material2021(
    platform: TargetPlatform.android,
    colorScheme: scheme,
  ).black.apply(fontFamily: AppFonts.sans);
  final theme = scheme.brightness == Brightness.dark
      ? Typography.material2021(
          platform: TargetPlatform.android,
          colorScheme: scheme,
        ).white.apply(fontFamily: AppFonts.sans)
      : base;
  TextStyle? tight(TextStyle? s, FontWeight w, double spacing) =>
      s?.copyWith(fontWeight: w, letterSpacing: spacing);
  return theme
      .copyWith(
        displayLarge: tight(theme.displayLarge, FontWeight.w800, -1.2),
        displayMedium: tight(theme.displayMedium, FontWeight.w800, -1),
        displaySmall: tight(theme.displaySmall, FontWeight.w800, -0.8),
        headlineLarge: tight(theme.headlineLarge, FontWeight.w800, -0.6),
        headlineMedium: tight(theme.headlineMedium, FontWeight.w800, -0.5),
        headlineSmall: tight(theme.headlineSmall, FontWeight.w700, -0.3),
        titleLarge: tight(theme.titleLarge, FontWeight.w800, -0.2),
        titleMedium: tight(theme.titleMedium, FontWeight.w700, 0),
        titleSmall: tight(theme.titleSmall, FontWeight.w700, 0.1),
        labelLarge: tight(theme.labelLarge, FontWeight.w700, 0.1),
        labelMedium: tight(theme.labelMedium, FontWeight.w600, 0.2),
        labelSmall: tight(theme.labelSmall, FontWeight.w600, 0.3),
        bodyLarge: theme.bodyLarge?.copyWith(height: 1.45),
        bodyMedium: theme.bodyMedium?.copyWith(height: 1.45),
      )
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = _scheme(brightness);
  final text = _textTheme(scheme);
  const stadium = StadiumBorder();
  final controlText = text.labelLarge;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: AppFonts.sans,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Android follows the predictive back gesture (Android 14+) and
        // otherwise fades forwards; desktops fade forwards; iOS and macOS
        // keep the native slide including the back swipe.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleSpacing: Space.l,
      titleTextStyle: text.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: stadium,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: stadium,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: text.labelLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelTextStyle: text.labelLarge?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.l)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: Space.xs),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        textStyle: controlText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        textStyle: controlText,
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: stadium,
        minimumSize: const Size(48, 48),
        textStyle: controlText,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      highlightElevation: 4,
      extendedTextStyle: controlText,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.l)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        minimumSize: const Size(48, 48),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.m)),
      ),
      titleTextStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      iconColor: scheme.onSurfaceVariant,
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.onPrimaryContainer,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: scheme.onSurfaceVariant,
      collapsedIconColor: scheme.onSurfaceVariant,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.xl)),
      ),
      titleTextStyle: text.headlineSmall,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.m)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      // On the inverse surface: ≥ 4.5:1 in both themes.
      actionTextColor: brightness == Brightness.dark
          ? DexColors.redDark
          : DexColors.redLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.m)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.m),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      textStyle: text.labelMedium?.copyWith(color: scheme.onInverseSurface),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(Radii.s),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Icon(Icons.check)
            : null,
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

/// Lighter top stop of a type colour's gradient (badges).
Color typeHighlight(Color color) => Color.lerp(color, Colors.white, 0.08)!;

/// Readable text colour on a type colour (and its [typeHighlight]): white
/// or near-black, whichever has the higher contrast on both (≥ 4.5:1 for
/// every type).
Color onTypeColor(Color background) {
  const dark = Color(0xFF1B1B1F);
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  double worst(Color text) => math.min(
    contrast(text, background),
    contrast(text, typeHighlight(background)),
  );
  return worst(Colors.white) >= worst(dark) ? Colors.white : dark;
}

const tabularFigures = [FontFeature.tabularFigures()];
