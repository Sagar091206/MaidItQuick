import 'package:flutter/material.dart';

/// Brand palette used across MaidItQuick.
///
/// [muted], [deepForest] and friends are tuned for the dark brand look;
/// light-mode equivalents live on the [maidItQuickLightTheme] scheme so
/// widgets should prefer `Theme.of(context).colorScheme` (or the
/// [BrandThemeContext] helpers) instead of these constants.
abstract final class BrandColors {
  static const evergreen = Color(0xff07170f);
  static const deepForest = Color(0xff0d2b1e);
  static const surface = Color(0xff0d2b1e);
  static const lime = Color(0xff22c55e);
  static const limeBright = Color(0xff16a34a);
  static const white = Color(0xffffffff);
  static const muted = Color(0xffb8cabc);

  static const lightScaffold = Color(0xfff4f9f5);
  static const lightSurface = Color(0xffffffff);
  static const lightMuted = Color(0xff54685c);
  static const lightOnSurface = Color(0xff0a1f15);
}

/// Theme helpers that resolve correctly in light and dark mode.
extension BrandThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  Color get brandMuted =>
      Theme.of(this).brightness == Brightness.dark
          ? BrandColors.muted
          : BrandColors.lightMuted;

  Color get brandCard => Theme.of(this).colorScheme.surfaceContainerLow;

  Color get brandSurface => Theme.of(this).colorScheme.surface;
}

ThemeData maidItQuickDarkTheme() => _buildTheme(
      brightness: Brightness.dark,
      scaffold: const Color(0xff000000),
      surface: const Color(0xff000000),
      card: const Color(0xff121815),
      muted: BrandColors.muted,
      onSurface: BrandColors.white,
      primary: BrandColors.lime,
      onPrimary: BrandColors.evergreen,
      secondary: BrandColors.limeBright,
      fieldFill: const Color(0xff0d1410),
      fieldFocusedFill: const Color(0xff1a241e),
    );

ThemeData maidItQuickLightTheme() => _buildTheme(
      brightness: Brightness.light,
      scaffold: BrandColors.lightScaffold,
      surface: BrandColors.lightSurface,
      card: BrandColors.lightSurface,
      muted: BrandColors.lightMuted,
      onSurface: BrandColors.lightOnSurface,
      primary: BrandColors.lime,
      onPrimary: BrandColors.evergreen,
      secondary: BrandColors.limeBright,
      fieldFill: const Color(0xffeaf3ed),
      fieldFocusedFill: const Color(0xffffffff),
    );

ThemeData _buildTheme({
  required Brightness brightness,
  required Color scaffold,
  required Color surface,
  required Color card,
  required Color muted,
  required Color onSurface,
  required Color primary,
  required Color onPrimary,
  required Color secondary,
  required Color fieldFill,
  required Color fieldFocusedFill,
}) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primary.withValues(alpha: 0.18),
    onPrimaryContainer: onSurface,
    secondary: secondary,
    onSecondary: onPrimary,
    secondaryContainer: secondary.withValues(alpha: 0.18),
    onSecondaryContainer: onSurface,
    tertiary: secondary,
    onTertiary: onPrimary,
    tertiaryContainer: secondary.withValues(alpha: 0.14),
    onTertiaryContainer: onSurface,
    error: const Color(0xffff6b6b),
    onError: const Color(0xff2c0a0a),
    errorContainer: const Color(0xff4a1d1d),
    onErrorContainer: const Color(0xffffdada),
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: card,
    surfaceContainerHigh: card,
    surfaceContainer: card,
    surfaceContainerLow: card,
    surfaceContainerLowest: scaffold,
    onSurfaceVariant: muted,
    outline: muted.withValues(alpha: 0.45),
    outlineVariant: muted.withValues(alpha: 0.22),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: onSurface,
    onInverseSurface: scaffold,
    inversePrimary: primary,
    surfaceTint: Colors.transparent,
  );

  final baseText = (brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light())
      .textTheme
      .apply(bodyColor: onSurface, displayColor: onSurface);

  final radius = BorderRadius.circular(14);
  final inputBorder = OutlineInputBorder(
    borderRadius: radius,
    borderSide: BorderSide.none,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    textTheme: baseText.copyWith(
      headlineLarge: baseText.headlineLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      headlineMedium: baseText.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleLarge:
          baseText.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      labelLarge:
          baseText.labelLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: baseText.titleLarge?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w800,
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: const EdgeInsets.all(4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant, width: 0.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        disabledBackgroundColor: primary.withValues(alpha: 0.4),
        disabledForegroundColor: onPrimary.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: baseText.labelLarge?.copyWith(
          color: onPrimary,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: baseText.labelLarge?.copyWith(color: onSurface, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: baseText.labelLarge?.copyWith(fontSize: 14),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xffff6b6b), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0xffff6b6b), width: 1.8),
      ),
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted.withValues(alpha: 0.7)),
      helperStyle: TextStyle(color: muted, fontSize: 12),
      errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      prefixIconColor: muted,
      suffixIconColor: muted,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: fieldFill,
      selectedColor: primary,
      disabledColor: fieldFill.withValues(alpha: 0.5),
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      labelStyle: baseText.labelMedium?.copyWith(
        color: onSurface,
        fontWeight: FontWeight.w700,
      ),
      secondaryLabelStyle: baseText.labelMedium?.copyWith(
        color: onPrimary,
        fontWeight: FontWeight.w800,
      ),
      checkmarkColor: onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surfaceContainerHighest,
      contentTextStyle: TextStyle(color: onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: primary, linearTrackColor: fieldFill),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : muted,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : Colors.transparent,
      ),
      side: BorderSide(color: scheme.outlineVariant, width: 1.6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: onSurface,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: baseText.titleLarge?.copyWith(color: onSurface),
      contentTextStyle: TextStyle(color: muted, height: 1.35),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: card,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: primary,
      headerForegroundColor: onPrimary,
      dayForegroundColor: WidgetStatePropertyAll(onSurface),
      dayBackgroundColor: WidgetStatePropertyAll(Colors.transparent),
      todayForegroundColor: WidgetStatePropertyAll(primary),
      todayBorder: BorderSide(color: primary, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
