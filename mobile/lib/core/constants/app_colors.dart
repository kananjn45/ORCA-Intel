import 'package:flutter/material.dart';

class AppColors {
  // ============================================================================
  // Web UI High-Tech Marine Design System (SeaSentinel / ORCA)
  // ============================================================================
  static const Color brandNavy = Color(0xFF061C2C);        // Deep obsidian midnight sea
  static const Color brandSurface = Color(0xFF082537);     // Command deck and card surface
  static const Color brandSurfaceGlass = Color(0xD9082A38);// Frosted glass container fill (85% opacity)
  static const Color neonLime = Color(0xFFC8FA62);         // High-visibility acid lime accent (PFZ & CTAs)
  static const Color electricCyan = Color(0xFF63BAFF);     // Electric route cyan & telemetry wave
  static const Color hazardAmber = Color(0xFFFF9F5A);      // Weather watch / hazard amber
  static const Color safetyRed = Color(0xFFFF7068);        // IMBL border & critical alert red
  static const Color electricTeal = Color(0xFF2CD6C8);     // Locate crosshair & border icon
  static const Color inkLight = Color(0xFFE9F5F4);         // Crisp header & primary text
  static const Color textMuted = Color(0xFF8BADB2);        // Monospace telemetry labels & subtitles
  static const Color cardBorder = Color(0xFF287082);       // Glass card stroke
  static const Color glassBorderSubtle = Color(0xFF245667);// Layer button stroke
  static const Color brandHandle = Color(0xFF466875);      // Deck handle pill

  // ============================================================================
  // Requested Ocean Palette (ISRO Marine Design System & Backward Compatibility)
  // ============================================================================
  static const Color iceWhite = inkLight;
  static const Color accentLight = textMuted;
  static const Color primaryBlue = electricCyan;
  static const Color navyDark = brandSurface;

  // Atmospheric Deep Sea Surfaces
  static const Color bgMidnight = brandNavy;
  static const Color cardSurface = brandSurface;
  static const Color cardSurfaceLight = Color(0xFF0E284E);

  // Backward-compatible semantic aliases
  static const Color abyssBlack = bgMidnight;
  static const Color deepOcean = cardSurface;
  static const Color marineSurface = navyDark;
  static const Color marineSurfaceLight = cardSurfaceLight;

  static const Color radarCyan = electricCyan;
  static const Color bioGreen = neonLime;
  static const Color warningAmber = hazardAmber;
  static const Color criticalRed = safetyRed;

  static const Color textPrimary = inkLight;
  static const Color textSecondary = textMuted;
  static const Color textAccent = electricCyan;

  // Glassmorphic shaders
  static const Color glassFill = brandSurfaceGlass;
  static const Color glassBorder = cardBorder;
  static const Color glassDanger = Color(0x33FF7068);

  // ============================================================================
  // Sunlight Deck Mode
  // ============================================================================
  static const Color sunlightBg = Color(0xFFFFFFFF);
  static const Color sunlightSurface = Color(0xFFF1F5F9);
  static const Color sunlightBorder = Color(0xFFCBD5E1);
  static const Color sunlightTextPrimary = Color(0xFF020617);
  static const Color sunlightTextSecondary = Color(0xFF334155);
  static const Color sunlightCyan = electricCyan;
  static const Color sunlightGreen = Color(0xFF15803D);
  static const Color sunlightAmber = Color(0xFFB45309);
  static const Color sunlightRed = Color(0xFFBE123C);
}
