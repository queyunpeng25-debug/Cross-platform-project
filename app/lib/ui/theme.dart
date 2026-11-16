import 'package:flutter/material.dart';

import '../core/models.dart';

/// Status palette retained for Mustafa's Map data contract (`MapFeatureSlot`).
/// The Side Menu itself uses the sober monochrome & warm-stone typography
/// defined in [CsAppTheme] instead of traffic-light dots.
class CsStatusColors {
  const CsStatusColors._();

  static const Color currentRed = Color(0xFFC85A48);
  static const Color visitedGreen = Color(0xFF5D7A68);
  static const Color unvisitedBlue = Color(0xFF567396);

  static Color forStatus(StationVisitStatus status) {
    return switch (status) {
      StationVisitStatus.current => currentRed,
      StationVisitStatus.visited => visitedGreen,
      StationVisitStatus.unvisited => unvisitedBlue,
    };
  }
}

/// Sober *AMuse* museum palette: matte charcoal, warm stone/taupe, and clean ivory
/// (no Aalto corporate green or loud primary colors).
class CsAppTheme {
  const CsAppTheme._();

  // Light Mode — Sober Editorial Ivory & Matte Charcoal
  static const Color lightBackground = Color(0xFFF7F6F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCharcoal = Color(0xFF262523);
  static const Color lightTaupe = Color(0xFF8A7B68);
  static const Color lightMutedGrey = Color(0xFF9E9A92);
  static const Color lightBorder = Color(0xFFE6E2DA);

  // Dark Mode — Sober Matte Obsidian & Warm Stone
  static const Color darkBackground = Color(0xFF151514);
  static const Color darkSurface = Color(0xFF201F1E);
  static const Color darkIvory = Color(0xFFF3F1EC);
  static const Color darkSand = Color(0xFFC7B8A3);
  static const Color darkMutedGrey = Color(0xFF6E6A63);
  static const Color darkBorder = Color(0xFF2E2C2A);

  static ThemeData light() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: lightTaupe,
      brightness: Brightness.light,
    );

    final colorScheme = baseScheme.copyWith(
      primary: lightCharcoal,
      onPrimary: const Color(0xFFF8F7F4),
      primaryContainer: const Color(0xFFEBE8E1),
      onPrimaryContainer: lightCharcoal,
      secondary: lightTaupe,
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFFEFECE5),
      onSecondaryContainer: const Color(0xFF2E2923),
      tertiary: const Color(0xFF6E655B),
      onTertiary: const Color(0xFFFFFFFF),
      surface: lightSurface,
      onSurface: lightCharcoal,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF3F1EC),
      surfaceContainer: const Color(0xFFECE9E1),
      surfaceContainerHigh: const Color(0xFFE5E1D8),
      surfaceContainerHighest: const Color(0xFFDDD8CE),
      onSurfaceVariant: const Color(0xFF6B675F),
      outline: const Color(0xFFC8C2B8),
      outlineVariant: lightBorder,
    );

    final baseText = ThemeData.light(useMaterial3: true).textTheme.apply(
      bodyColor: lightCharcoal,
      displayColor: lightCharcoal,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      textTheme: baseText.copyWith(
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        foregroundColor: lightCharcoal,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightSurface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: lightCharcoal,
        contentTextStyle: const TextStyle(color: Color(0xFFF7F6F2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightCharcoal,
          foregroundColor: const Color(0xFFF8F7F4),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightCharcoal,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: Color(0xFFC8C2B8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFF8F7F4);
          }
          return const Color(0xFF8C877E);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return lightCharcoal;
          }
          return const Color(0xFFE4E0D8);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData dark() {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: darkSand,
      brightness: Brightness.dark,
    );

    final colorScheme = baseScheme.copyWith(
      primary: darkIvory,
      onPrimary: darkBackground,
      primaryContainer: const Color(0xFF2C2A27),
      onPrimaryContainer: darkIvory,
      secondary: darkSand,
      onSecondary: const Color(0xFF1C1A17),
      secondaryContainer: const Color(0xFF2E2B27),
      onSecondaryContainer: darkIvory,
      tertiary: const Color(0xFFA39888),
      onTertiary: darkBackground,
      surface: darkSurface,
      onSurface: darkIvory,
      surfaceContainerLowest: const Color(0xFF1A1918),
      surfaceContainerLow: const Color(0xFF21201E),
      surfaceContainer: const Color(0xFF262523),
      surfaceContainerHigh: const Color(0xFF2E2C29),
      surfaceContainerHighest: const Color(0xFF363430),
      onSurfaceVariant: const Color(0xFFA7A29A),
      outline: const Color(0xFF4A4742),
      outlineVariant: darkBorder,
    );

    final baseText = ThemeData.dark(useMaterial3: true).textTheme.apply(
      bodyColor: darkIvory,
      displayColor: darkIvory,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: baseText.copyWith(
        headlineMedium: baseText.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: baseText.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkIvory,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E2C29),
        contentTextStyle: const TextStyle(color: darkIvory),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF2B2927),
          foregroundColor: darkIvory,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkIvory,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: Color(0xFF4A4742)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkBackground;
          }
          return const Color(0xFF9C968D);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return darkSand;
          }
          return const Color(0xFF2E2C2A);
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
