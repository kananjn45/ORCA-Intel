import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dark_tactical_theme.dart';
import '../constants/app_colors.dart';

class ThemeController {
  // Locked to Light Theme (Sunlight Deck) per presentation requirements
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(false);

  static void toggleTheme() {
    // Theme toggle removed - app locked to Light mode
  }

  static void setDarkMode(bool dark) {
    isDarkMode.value = false;
  }
}

class AppTheme {
  static ThemeData get darkTactical => buildDarkTacticalTheme();

  static ThemeData get sunlightDeck => stitchTacticalLight;

  static ThemeData get stitchTacticalLight {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.stitchSurface,
      primaryColor: AppColors.stitchPrimary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.stitchPrimary,
        onPrimary: AppColors.stitchOnPrimary,
        primaryContainer: AppColors.stitchPrimaryContainer,
        onPrimaryContainer: AppColors.stitchOnPrimaryContainer,
        secondary: AppColors.stitchSecondary,
        onSecondary: AppColors.stitchOnSecondary,
        secondaryContainer: AppColors.stitchSecondaryContainer,
        onSecondaryContainer: AppColors.stitchOnSecondaryContainer,
        tertiary: AppColors.stitchTertiary,
        onTertiary: AppColors.stitchOnTertiary,
        tertiaryContainer: AppColors.stitchTertiaryContainer,
        onTertiaryContainer: AppColors.stitchOnTertiaryContainer,
        error: AppColors.stitchError,
        onError: AppColors.stitchOnError,
        errorContainer: AppColors.stitchErrorContainer,
        onErrorContainer: AppColors.stitchOnErrorContainer,
        surface: AppColors.stitchSurface,
        onSurface: AppColors.stitchOnSurface,
        onSurfaceVariant: AppColors.stitchOnSurfaceVariant,
        outline: AppColors.stitchOutline,
        outlineVariant: AppColors.stitchOutlineVariant,
      ),
      cardTheme: CardThemeData(
        color: AppColors.stitchSurfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.stitchOutlineVariant, width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.stitchSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.stitchOnSurface,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

