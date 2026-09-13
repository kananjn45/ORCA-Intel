import 'package:flutter/material.dart';

class AppColors {
  // ============================================================================
  // Web UI High-Tech Marine Design System (ORCA-Intel)
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
  // Stitch: ORCA Marine AI Interface Design System Tokens
  // ============================================================================
  static const Color stitchSurface = Color(0xFFF8F9FF);
  static const Color stitchSurfaceDim = Color(0xFFC4DCFF);
  static const Color stitchSurfaceBright = Color(0xFFF8F9FF);
  static const Color stitchSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color stitchSurfaceContainerLow = Color(0xFFEFF4FF);
  static const Color stitchSurfaceContainer = Color(0xFFE5EEFF);
  static const Color stitchSurfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color stitchSurfaceContainerHighest = Color(0xFFD2E4FF);

  static const Color stitchPrimary = Color(0xFF00647C);         // Deep Ocean Teal
  static const Color stitchOnPrimary = Color(0xFFFFFFFF);
  static const Color stitchPrimaryContainer = Color(0xFF007F9D);
  static const Color stitchOnPrimaryContainer = Color(0xFFFAFDFF);
  static const Color stitchPrimaryFixed = Color(0xFFB7EAFF);
  static const Color stitchPrimaryFixedDim = Color(0xFF6CD3F7);
  static const Color stitchOnPrimaryFixed = Color(0xFF001F28);

  static const Color stitchSecondary = Color(0xFF006C4A);       // Emerald Coastal
  static const Color stitchOnSecondary = Color(0xFFFFFFFF);
  static const Color stitchSecondaryContainer = Color(0xFF82F5C1);
  static const Color stitchOnSecondaryContainer = Color(0xFF00714E);
  static const Color stitchSecondaryFixed = Color(0xFF85F8C4);
  static const Color stitchSecondaryFixedDim = Color(0xFF68DBA9);
  static const Color stitchOnSecondaryFixed = Color(0xFF002114);

  static const Color stitchTertiary = Color(0xFF8D4B00);        // Amber Advisory
  static const Color stitchOnTertiary = Color(0xFFFFFFFF);
  static const Color stitchTertiaryContainer = Color(0xFFB15F00);
  static const Color stitchOnTertiaryContainer = Color(0xFFFFFBFF);
  static const Color stitchTertiaryFixed = Color(0xFFFFDCC3);
  static const Color stitchTertiaryFixedDim = Color(0xFFFFB77D);
  static const Color stitchOnTertiaryFixed = Color(0xFF2F1500);

  static const Color stitchError = Color(0xFFBA1A1A);           // IMBL Coral Alert Red
  static const Color stitchOnError = Color(0xFFFFFFFF);
  static const Color stitchErrorContainer = Color(0xFFFFDAD6);
  static const Color stitchOnErrorContainer = Color(0xFF93000A);

  static const Color stitchOnSurface = Color(0xFF001C37);       // Deep Oceanic Navy text
  static const Color stitchOnSurfaceVariant = Color(0xFF3E484D);// Muted slate text
  static const Color stitchOutline = Color(0xFF6E797E);
  static const Color stitchOutlineVariant = Color(0xFFBDC8CE);  // Subtle structural border

  // ============================================================================
  // Sunlight Deck Mode
  // ============================================================================
  static const Color sunlightBg = stitchSurface;
  static const Color sunlightSurface = stitchSurfaceContainerLowest;
  static const Color sunlightBorder = stitchOutlineVariant;
  static const Color sunlightTextPrimary = stitchOnSurface;
  static const Color sunlightTextSecondary = stitchOnSurfaceVariant;
  static const Color sunlightCyan = stitchPrimary;
  static const Color sunlightGreen = stitchSecondary;
  static const Color sunlightAmber = stitchTertiary;
  static const Color sunlightRed = stitchError;
}

