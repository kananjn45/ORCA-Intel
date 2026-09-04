import 'package:flutter/material.dart';

class AppColors {
  // ============================================================================
  // Requested Ocean Palette (ISRO Marine Design System)
  // ============================================================================
  static const Color iceWhite = Color(0xFFE3F2FD);     // Primary high-contrast typography, highlights
  static const Color accentLight = Color(0xFF90CAF9); // Secondary typography, telemetry labels, active outlines
  static const Color primaryBlue = Color(0xFF2196F3); // Main action buttons, vessel heading, primary indicators
  static const Color navyDark = Color(0xFF0D47A1);    // Deep oceanic surfaces, containers, card borders

  // Atmospheric Deep Sea Surfaces
  static const Color bgMidnight = Color(0xFF051122);  // Rich, elegant midnight navy background
  static const Color cardSurface = Color(0xFF0A1E3B); // Refined card surface
  static const Color cardSurfaceLight = Color(0xFF0E284E);

  // Backward-compatible semantic aliases
  static const Color abyssBlack = bgMidnight;
  static const Color deepOcean = cardSurface;
  static const Color marineSurface = navyDark;
  static const Color marineSurfaceLight = cardSurfaceLight;

  static const Color radarCyan = primaryBlue;
  static const Color bioGreen = Color(0xFF2EC4B6);     // Refined sea-emerald for PFZ
  static const Color warningAmber = Color(0xFFFFB74D); // Warm nautical caution
  static const Color criticalRed = Color(0xFFEF5350);  // Clean safety crimson for IMBL

  static const Color textPrimary = iceWhite;
  static const Color textSecondary = accentLight;
  static const Color textAccent = primaryBlue;

  // Glassmorphic shaders
  static const Color glassFill = Color(0xD90A1E3B);
  static const Color glassBorder = Color(0x3390CAF9);
  static const Color glassDanger = Color(0x33EF5350);

  // ============================================================================
  // Sunlight Deck Mode
  // ============================================================================
  static const Color sunlightBg = Color(0xFFFFFFFF);
  static const Color sunlightSurface = Color(0xFFF1F5F9);
  static const Color sunlightBorder = Color(0xFFCBD5E1);
  static const Color sunlightTextPrimary = Color(0xFF020617);
  static const Color sunlightTextSecondary = Color(0xFF334155);
  static const Color sunlightCyan = primaryBlue;
  static const Color sunlightGreen = Color(0xFF15803D);
  static const Color sunlightAmber = Color(0xFFB45309);
  static const Color sunlightRed = Color(0xFFBE123C);
}
