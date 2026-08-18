// lib/theme/app_theme.dart
//
// Theme Studio design tokens — colors, typography, spacing, radius,
// elevation, and motion — implemented as real Flutter theme objects
// (not one-off hex values scattered through widgets).
//
// Usage in lib/main.dart:
//   import 'theme/app_theme.dart';
//   ...
//   MaterialApp(
//     theme: AppTheme.themeData,
//     ...
//   )
//
// Anywhere in the widget tree, reach tokens via:
//   AppColors.accentPrimary
//   AppSpacing.md
//   AppRadius.lg
//   AppMotion.standard
//   Theme.of(context).textTheme.headlineSmall  (mapped from §1 typography)

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Color tokens
// ---------------------------------------------------------------------------
class AppColors {
  AppColors._();

  // Backgrounds (dark)
  static const bgBase = Color(0xFF0E1013);
  static const bgSurface = Color(0xFF16191D);
  static const bgSurfaceRaised = Color(0xFF1E2227);
  static const bgOverlay = Color(0xEB1A1D21);

  // Borders
  static const borderSubtle = Color(0xFF2A2E34);
  static const borderFocus = Color(0xFF3A3F47);

  // Text
  static const textPrimary = Color(0xFFF2F3F5);
  static const textSecondary = Color(0xFF9AA0A8);
  static const textDisabled = Color(0xFF5C6169);

  // Accent
  static const accentPrimary = Color(0xFF00FFF0);
  static const accentPrimaryMuted = Color(0xFF1A5B57);

  // Status
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const error = Color(0xFFF87171);

  // Mood
  static const moodOcean = Color(0xFF2AA9C4);
  static const moodMidnight = Color(0xFF5B4B9E);
  static const moodSunset = Color(0xFFE8875A);
  static const moodForest = Color(0xFF4E9E6B);
  static const moodRose = Color(0xFFD8698C);

  static const List<Color> moodSwatches = [
    moodOcean,
    moodMidnight,
    moodSunset,
    moodForest,
    moodRose,
  ];
}

// ---------------------------------------------------------------------------
// Light color tokens -- mirrors AppColors structure for light theme
// ---------------------------------------------------------------------------
class AppColorsLight {
  AppColorsLight._();

  static const bgBase = Color(0xFFF5F5F5);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSurfaceRaised = Color(0xFFF0F0F0);
  static const bgOverlay = Color(0xF0FFFFFF);

  static const borderSubtle = Color(0xFFE0E0E0);
  static const borderFocus = Color(0xFFBDBDBD);

  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const textDisabled = Color(0xFFBDBDBD);

  static const accentPrimary = Color(0xFF00B8A9);
  static const accentPrimaryMuted = Color(0xFFD4F5F2);

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF57F17);
  static const error = Color(0xFFD32F2F);
}

// ---------------------------------------------------------------------------
// Spacing tokens — 4px base unit
// ---------------------------------------------------------------------------
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // Semantic aliases used throughout the spec
  static const double screenPadding = lg; // 16
  static const double cardPadding = lg; // 16
  static const double sectionGap = xl; // 24
}

// ---------------------------------------------------------------------------
// Radius tokens
// ---------------------------------------------------------------------------
class AppRadius {
  AppRadius._();

  static const double sm = 8; // chips, small buttons
  static const double md = 14; // rows, thumbnails
  static const double lg = 20; // preset/widget cards

  /// Control Center sheet — top corners only.
  static const double sheet = 28;

  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);

  static const BorderRadius sheetRadius = BorderRadius.only(
    topLeft: Radius.circular(sheet),
    topRight: Radius.circular(sheet),
  );
}

// ---------------------------------------------------------------------------
// Elevation tokens — background + shadow pairing per level
// ---------------------------------------------------------------------------
class AppElevation {
  AppElevation._();

  static const level0 = BoxDecoration(color: AppColors.bgBase);

  static BoxDecoration level1({BorderRadius? radius}) => BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000), // rgba(0,0,0,.4)
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      );

  static BoxDecoration level2({BorderRadius? radius}) => BoxDecoration(
        color: AppColors.bgSurfaceRaised,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000), // rgba(0,0,0,.35)
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration overlay({BorderRadius? radius}) => BoxDecoration(
        color: AppColors.bgOverlay,
        borderRadius: radius ?? AppRadius.sheetRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000), // rgba(0,0,0,.5)
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      );
  // NOTE: pair `overlay()` with a BackdropFilter(ImageFilter.blur(sigmaX: 20, sigmaY: 20))
  // in the widget that uses it — blur can't be expressed as a BoxDecoration alone.
}

// ---------------------------------------------------------------------------
// Motion tokens
// ---------------------------------------------------------------------------
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120); // press, chip select
  static const Duration standard = Duration(milliseconds: 200); // card/tab changes
  static const Duration sheet = Duration(milliseconds: 280); // Control Center slide
  static const Duration spinner = Duration(milliseconds: 900); // applying states (loop)

  static const Curve fastCurve = Curves.easeOut;
  static const Curve standardCurve = Curves.easeInOut;
  static const Curve sheetCurve = Curves.easeOut;
  static const Curve spinnerCurve = Curves.linear;
}

// ---------------------------------------------------------------------------
// Typography tokens
// ---------------------------------------------------------------------------
// Font family: Inter or Manrope. Add the chosen font via pubspec.yaml (fonts:)
// or google_fonts package, then set `fontFamily` below. Falls back to the
// platform default until a font asset is wired up.
class AppTypography {
  AppTypography._();

  static const String? fontFamily = null; // e.g. 'Inter' once added to pubspec.yaml

  static const display = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const heading = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const bodySecondary = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const label = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  static const button = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
}

// ---------------------------------------------------------------------------
// Assembled ThemeData
// ---------------------------------------------------------------------------
class AppTheme {
  AppTheme._();

  /// Returns true if the current theme is light mode.
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  /// Returns the appropriate surface color based on current brightness.
  static Color surface(BuildContext context) =>
      isLight(context) ? AppColorsLight.bgSurface : AppColors.bgSurface;

  /// Returns the appropriate raised surface color based on current brightness.
  static Color surfaceRaised(BuildContext context) =>
      isLight(context) ? AppColorsLight.bgSurfaceRaised : AppColors.bgSurfaceRaised;

  /// Returns the appropriate scaffold background color.
  static Color scaffoldBg(BuildContext context) =>
      isLight(context) ? AppColorsLight.bgBase : AppColors.bgBase;

  /// Returns appropriate text primary color.
  static Color textPrimary(BuildContext context) =>
      isLight(context) ? AppColorsLight.textPrimary : AppColors.textPrimary;

  /// Returns appropriate text secondary color.
  static Color textSecondary(BuildContext context) =>
      isLight(context) ? AppColorsLight.textSecondary : AppColors.textSecondary;

  static ThemeData get darkThemeData {
    const colorScheme = ColorScheme.dark(
      surface: AppColors.bgSurface,
      onSurface: AppColors.textPrimary,
      primary: AppColors.accentPrimary,
      onPrimary: Color(0xFF00201E), // dark text for legibility on the cyan accent
      secondary: AppColors.accentPrimaryMuted,
      onSecondary: AppColors.accentPrimary,
      error: AppColors.error,
      onError: AppColors.textPrimary,
      outline: AppColors.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bgBase,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: const TextTheme(
        headlineMedium: AppTypography.display, // screen titles
        titleLarge: AppTypography.heading, // preset names, section headers
        bodyLarge: AppTypography.body, // primary copy
        bodySmall: AppTypography.bodySecondary, // metadata, package names
        labelSmall: AppTypography.label, // tabs, small status labels
        labelLarge: AppTypography.button, // button labels
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: AppTypography.display,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.bgSurface,
        indicatorColor: AppColors.accentPrimaryMuted,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.label.copyWith(
            color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.accentPrimary : AppColors.textSecondary,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentPrimaryMuted,
          foregroundColor: AppColors.accentPrimary,
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // Used for system-dialog-triggering actions, e.g. "Pin to Home Screen".
        // Outlined (not filled) is itself the signal that this isn't a
        // same-screen action — see build prompt §2 / §3.5.
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderSubtle),
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.accentPrimary
              : AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.accentPrimaryMuted
              : AppColors.bgSurfaceRaised;
        }),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bgSurfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
      ),
    );
  }

  static ThemeData get lightThemeData {
    const colorScheme = ColorScheme.light(
      surface: AppColorsLight.bgSurface,
      onSurface: AppColorsLight.textPrimary,
      primary: AppColorsLight.accentPrimary,
      onPrimary: Colors.white,
      secondary: AppColorsLight.accentPrimaryMuted,
      onSecondary: AppColorsLight.accentPrimary,
      error: AppColorsLight.error,
      onError: Colors.white,
      outline: AppColorsLight.borderSubtle,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColorsLight.bgBase,
      colorScheme: colorScheme,
      fontFamily: AppTypography.fontFamily,
      textTheme: TextTheme(
        headlineMedium: AppTypography.display.copyWith(color: AppColorsLight.textPrimary),
        titleLarge: AppTypography.heading.copyWith(color: AppColorsLight.textPrimary),
        bodyLarge: AppTypography.body.copyWith(color: AppColorsLight.textPrimary),
        bodySmall: AppTypography.bodySecondary.copyWith(color: AppColorsLight.textSecondary),
        labelSmall: AppTypography.label.copyWith(color: AppColorsLight.textSecondary),
        labelLarge: AppTypography.button.copyWith(color: AppColorsLight.textPrimary),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsLight.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 28,
          height: 34 / 28,
          fontWeight: FontWeight.w600,
          color: AppColorsLight.textPrimary,
        ),
        iconTheme: IconThemeData(color: AppColorsLight.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColorsLight.bgSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsLight.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColorsLight.bgSurface,
        indicatorColor: AppColorsLight.accentPrimaryMuted,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.label.copyWith(
            color: selected ? AppColorsLight.accentPrimary : AppColorsLight.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColorsLight.accentPrimary : AppColorsLight.textSecondary,
          );
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorsLight.accentPrimaryMuted,
          foregroundColor: AppColorsLight.accentPrimary,
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorsLight.textPrimary,
          side: const BorderSide(color: AppColorsLight.borderSubtle),
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smRadius),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColorsLight.accentPrimary
              : AppColorsLight.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColorsLight.accentPrimaryMuted
              : AppColorsLight.bgSurfaceRaised;
        }),
      ),
      iconTheme: const IconThemeData(color: AppColorsLight.textSecondary, size: 20),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorsLight.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgRadius),
      ),
    );
  }
}