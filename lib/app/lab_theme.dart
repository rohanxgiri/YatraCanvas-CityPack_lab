import 'package:flutter/material.dart';

abstract final class LabPalette {
  static const ink = Color(0xFF173832);
  static const inkStrong = Color(0xFF0E2925);
  static const teal = Color(0xFF1F6A5C);
  static const tealSoft = Color(0xFFDDEDE7);
  static const saffron = Color(0xFFE39A32);
  static const saffronSoft = Color(0xFFFFE8C2);
  static const paper = Color(0xFFF5F1E8);
  static const surface = Color(0xFFFFFDF8);
  static const outline = Color(0xFFD8D2C4);
  static const muted = Color(0xFF61706C);
  static const danger = Color(0xFFB42318);
  static const dangerSoft = Color(0xFFFFE4E0);
  static const success = Color(0xFF247A4D);
  static const successSoft = Color(0xFFDDF3E6);
  static const plum = Color(0xFF6750A4);
}

abstract final class LabSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class LabRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
}

abstract final class LabTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: LabPalette.teal,
      brightness: Brightness.light,
      primary: LabPalette.teal,
      secondary: LabPalette.saffron,
      surface: LabPalette.surface,
      error: LabPalette.danger,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: LabPalette.paper,
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          color: LabPalette.inkStrong,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.1,
          height: 1.05,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          color: LabPalette.inkStrong,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: LabPalette.inkStrong,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: LabPalette.ink,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          color: LabPalette.ink,
          height: 1.45,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          color: LabPalette.muted,
          height: 1.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: LabPalette.inkStrong,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: LabPalette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LabRadius.md),
          side: const BorderSide(color: LabPalette.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LabRadius.sm),
          borderSide: const BorderSide(color: LabPalette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LabRadius.sm),
          borderSide: const BorderSide(color: LabPalette.outline),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LabSpacing.md,
          vertical: LabSpacing.sm,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 46),
          elevation: 0,
          backgroundColor: LabPalette.teal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LabRadius.sm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 46),
          foregroundColor: LabPalette.ink,
          side: const BorderSide(color: LabPalette.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LabRadius.sm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: LabPalette.surface,
        indicatorColor: LabPalette.tealSoft,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: LabPalette.surface,
        indicatorColor: LabPalette.tealSoft,
        selectedIconTheme: IconThemeData(color: LabPalette.teal),
        selectedLabelTextStyle: TextStyle(
          color: LabPalette.ink,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: LabPalette.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerColor: LabPalette.outline,
    );
  }
}
