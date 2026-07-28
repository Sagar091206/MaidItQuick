import 'package:flutter/material.dart';

class BrandColors {
  const BrandColors._();

  static const evergreen = Color(0xff07170f);
  static const deepForest = Color(0xff0d2b1e);
  static const surface = Color(0xff0d2b1e);
  static const lime = Color(0xff22c55e);
  static const limeBright = Color(0xff16a34a);
  static const white = Color(0xffffffff);
  static const muted = Color(0xffb8cabc);
}

ThemeData maidItQuickTheme() {
  const colorScheme = ColorScheme.dark(
    primary: BrandColors.lime,
    secondary: BrandColors.limeBright,
    surface: BrandColors.surface,
    onPrimary: BrandColors.evergreen,
    onSurface: BrandColors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BrandColors.evergreen,
    // Keep the app self-contained for offline development and production.
    // Runtime Google Fonts fetching caused repeated exceptions on the Android
    // emulator when DNS/network access was unavailable.
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: BrandColors.white,
          displayColor: BrandColors.white,
        ),
    appBarTheme: const AppBarTheme(backgroundColor: BrandColors.evergreen, foregroundColor: BrandColors.white),
    cardTheme: CardThemeData(
      color: BrandColors.deepForest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BrandColors.lime,
        foregroundColor: BrandColors.evergreen,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
