import 'package:flutter/material.dart';
import 'dark_tactical_theme.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get darkTactical => buildDarkTacticalTheme();

  static ThemeData get sunlightDeck {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.sunlightBg,
      primaryColor: AppColors.sunlightCyan,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sunlightCyan,
        secondary: AppColors.sunlightGreen,
        error: AppColors.sunlightRed,
        surface: AppColors.sunlightSurface,
        background: AppColors.sunlightBg,
      ),
      cardTheme: CardThemeData(
        color: AppColors.sunlightSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.sunlightBorder, width: 1.5),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.sunlightSurface,
        elevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.sunlightTextPrimary,
        ),
      ),
    );
  }
}
