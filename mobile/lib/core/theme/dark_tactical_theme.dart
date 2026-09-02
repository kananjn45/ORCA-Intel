import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

ThemeData buildDarkTacticalTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.abyssBlack,
    primaryColor: AppColors.radarCyan,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.radarCyan,
      secondary: AppColors.bioGreen,
      error: AppColors.criticalRed,
      surface: AppColors.deepOcean,
      background: AppColors.abyssBlack,
    ),
    fontFamily: 'Inter',
    cardTheme: CardThemeData(
      color: AppColors.glassFill,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.glassBorder, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deepOcean,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: AppColors.textSecondary),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    ),
  );
}
