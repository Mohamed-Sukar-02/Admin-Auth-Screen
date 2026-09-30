import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material theme for the admin panel.
///
/// The colour schemes below mirror `AdminPalette` exactly — light from the
/// sage-green library, dark from the olive/terracotta one — so inherited
/// Material widgets (spinners, cursors, switches, snackbars) never show a
/// colour the dashboard tokens don't already own.
class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF2D7853); // Brand green (light)
  static const Color secondaryColor = Color(0xFFCD965A); // Clay accent
  static const Color tertiaryColor = Color(0xFF3F6B66); // Informational teal

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2D7853),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEDF5EB),
    onPrimaryContainer: Color(0xFF215C40),
    secondary: Color(0xFF448162),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF1F5E9),
    onSecondaryContainer: Color(0xFF2F5B41),
    tertiary: Color(0xFF3F6B66),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFEDF2F1),
    onTertiaryContainer: Color(0xFF41696B),
    error: Color(0xFFA65E3F),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFBF6ED),
    onErrorContainer: Color(0xFF96552F),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF263B32),
    surfaceDim: Color(0xFFF2F4F0),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFAFBF8),
    surfaceContainer: Color(0xFFF7F8F5),
    surfaceContainerHigh: Color(0xFFF5F7F2),
    surfaceContainerHighest: Color(0xFFF1F5E9),
    onSurfaceVariant: Color(0xFF8B938D),
    outline: Color(0xFFB6BDB4),
    outlineVariant: Color(0xFFE7EAE4),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF203428),
    inverseSurface: Color(0xFF263B32),
    onInverseSurface: Color(0xFFF7F8F5),
    inversePrimary: Color(0xFF8FC0A5),
    surfaceTint: Color(0xFF2D7853),
  );

  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFE3A079),
    onPrimary: Color(0xFF262A1E),
    primaryContainer: Color(0xFF352A21),
    onPrimaryContainer: Color(0xFFEDB08B),
    secondary: Color(0xFFA7B799),
    onSecondary: Color(0xFF1B1E1A),
    secondaryContainer: Color(0xFF222F1B),
    onSecondaryContainer: Color(0xFFBCCFAD),
    tertiary: Color(0xFFC5DCAC),
    onTertiary: Color(0xFF304226),
    tertiaryContainer: Color(0xFF2E3D22),
    onTertiaryContainer: Color(0xFFD8EACB),
    error: Color(0xFFECB99A),
    onError: Color(0xFF3A2820),
    errorContainer: Color(0xFF6D4831),
    onErrorContainer: Color(0xFFFDF3EB),
    surface: Color(0xFF1B1E1A),
    onSurface: Color(0xFFECEEE8),
    surfaceDim: Color(0xFF131513),
    surfaceBright: Color(0xFF23281E),
    surfaceContainerLowest: Color(0xFF0F110F),
    surfaceContainerLow: Color(0xFF151814),
    surfaceContainer: Color(0xFF1B1E1A),
    surfaceContainerHigh: Color(0xFF20261C),
    surfaceContainerHighest: Color(0xFF2B3324),
    onSurfaceVariant: Color(0xFF939B88),
    outline: Color(0xFF4B5B3D),
    outlineVariant: Color(0xFF31362C),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF0C130B),
    inverseSurface: Color(0xFFECEEE8),
    onInverseSurface: Color(0xFF131513),
    inversePrimary: Color(0xFF966040),
    surfaceTint: Color(0xFFE3A079),
  );

  static ThemeData get lightTheme {
    const colorScheme = lightColorScheme;

    final baseTextTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
      textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(baseTextTheme),
      scaffoldBackgroundColor: colorScheme.surfaceContainer,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData(
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      brightness: Brightness.dark,
      fontFamily: GoogleFonts.ibmPlexSansArabic().fontFamily,
      textTheme: GoogleFonts.ibmPlexSansArabicTextTheme(baseTextTheme),
      scaffoldBackgroundColor: darkColorScheme.surfaceDim,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: darkColorScheme.surfaceDim,
        foregroundColor: darkColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: darkColorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: darkColorScheme.outlineVariant, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkColorScheme.surfaceContainerHigh,
        side: BorderSide(color: darkColorScheme.outlineVariant, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: darkColorScheme.surface,
        indicatorColor: darkColorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkColorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkColorScheme.primary,
        foregroundColor: darkColorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkColorScheme.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.ibmPlexSansArabic(
          color: darkColorScheme.onSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: darkColorScheme.outlineVariant,
        thickness: 1,
      ),
    );
  }
}
