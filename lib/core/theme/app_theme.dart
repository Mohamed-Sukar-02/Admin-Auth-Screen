import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 theme definitions for 'أكلة النهاردة' — Admin app.
/// Built on the app's brand indigo (#635BFF, shared with the admin sign-in
/// screens) over a cool slate neutral scale, with amber and green accents.
class AppTheme {
  AppTheme._();

  static const Color seedColor = Color(0xFF635BFF); // Brand indigo
  static const Color secondaryColor = Color(0xFFB45309); // Amber
  static const Color tertiaryColor = Color(0xFF15803D); // Green

  /// Tailored Material 3 dark color scheme — slate neutrals matched to
  /// AdminPalette.dark so inherited widgets (spinners, cursors, switches)
  /// stay in the same family as the dashboard tokens.
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA5B4FC), // Soft indigo
    onPrimary: Color(0xFF1E1B4B),
    primaryContainer: Color(0xFF3A35BD),
    onPrimaryContainer: Color(0xFFDFE2FF),
    secondary: Color(0xFFFBBF24), // Amber
    onSecondary: Color(0xFF422006),
    secondaryContainer: Color(0xFF573A0B),
    onSecondaryContainer: Color(0xFFFDE68A),
    tertiary: Color(0xFF86EFAC), // Green
    onTertiary: Color(0xFF052E16),
    tertiaryContainer: Color(0xFF14532D),
    onTertiaryContainer: Color(0xFFBBF7D0),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0F172A), // Slate canvas
    onSurface: Color(0xFFF1F5F9), // Soft white text
    surfaceDim: Color(0xFF0B1220), // Deepest slate
    surfaceBright: Color(0xFF222E45),
    surfaceContainerLowest: Color(0xFF0B1220),
    surfaceContainerLow: Color(0xFF1A2436), // Subtle card / panel level
    surfaceContainer: Color(0xFF1F2A3E),
    surfaceContainerHigh: Color(0xFF222E45),
    surfaceContainerHighest: Color(0xFF2B3752),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF3E4C6E),
    outlineVariant: Color(0xFF2B3752),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF1F5F9),
    onInverseSurface: Color(0xFF0F172A),
    inversePrimary: Color(0xFF635BFF),
  );

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    final baseTextTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
    ).textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: GoogleFonts.cairoTextTheme(baseTextTheme),
      scaffoldBackgroundColor: colorScheme.surface,
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
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: GoogleFonts.cairo(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
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
      fontFamily: GoogleFonts.cairo().fontFamily,
      textTheme: GoogleFonts.cairoTextTheme(baseTextTheme),
      scaffoldBackgroundColor: darkColorScheme.surfaceDim,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: darkColorScheme.surfaceDim,
        foregroundColor: darkColorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: darkColorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: darkColorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkColorScheme.surfaceContainer,
        side: BorderSide(
          color: darkColorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: darkColorScheme.surfaceContainerLowest,
        indicatorColor: darkColorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkColorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkColorScheme.primary,
        foregroundColor: darkColorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: darkColorScheme.surfaceContainerHighest,
        contentTextStyle: GoogleFonts.cairo(color: darkColorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: darkColorScheme.outlineVariant.withValues(alpha: 0.3),
        thickness: 1,
      ),
    );
  }
}
