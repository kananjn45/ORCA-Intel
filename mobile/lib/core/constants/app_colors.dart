import 'package:flutter/material.dart';

class AppColors {
  // ============================================================================
  // Tactical Ocean Dark Mode (Primary Palette)
  // ============================================================================
  static const Color abyssBlack = Color(0xFF050B14);      // Deepest background base
  static const Color deepOcean = Color(0xFF0B192C);       // Container and card surfaces
  static const Color marineSurface = Color(0xFF1E3E62);   // Interactive elements and borders
  static const Color marineSurfaceLight = Color(0xFF28558A);

  // Navigational & Marine Indicators
  static const Color radarCyan = Color(0xFF00F0FF);       // Safe route, vessel heading vector
  static const Color bioGreen = Color(0xFF00FF88);        // Potential Fishing Zones (PFZs), safe status
  static const Color warningAmber = Color(0xFFFFB300);    // Squall warning, 5km buffer zone
  static const Color criticalRed = Color(0xFFFF2A6D);     // IMBL hard boundary, cyclone cell, emergency halt

  // High-Contrast Typography & Accents
  static const Color textPrimary = Color(0xFFF0F6FC);     // Primary high-visibility text
  static const Color textSecondary = Color(0xFF8B949E);   // Telemetry captions and labels
  static const Color textAccent = Color(0xFF38BDF8);      // Highlights and coordinates

  // Glassmorphic Surface Shaders
  static const Color glassFill = Color(0xCC0B192C);       // 80% opacity dark ocean
  static const Color glassBorder = Color(0x3300F0FF);     // 20% opacity radar cyan
  static const Color glassDanger = Color(0xCC2C0B19);     // 80% opacity danger red

  // ============================================================================
  // Sunlight Deck Mode (Ultra High-Contrast Day Setting)
  // ============================================================================
  static const Color sunlightBg = Color(0xFFFFFFFF);
  static const Color sunlightSurface = Color(0xFFF1F5F9);
  static const Color sunlightBorder = Color(0xFFCBD5E1);
  static const Color sunlightTextPrimary = Color(0xFF020617);
  static const Color sunlightTextSecondary = Color(0xFF334155);
  static const Color sunlightCyan = Color(0xFF0284C7);
  static const Color sunlightGreen = Color(0xFF15803D);
  static const Color sunlightAmber = Color(0xFFB45309);
  static const Color sunlightRed = Color(0xFFBE123C);
}
