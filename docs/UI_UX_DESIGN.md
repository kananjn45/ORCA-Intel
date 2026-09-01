# 🎨 ORCA: Mobile UI/UX Design Specification & Design System
> **Project:** ORCA (Marine EcOsystem Reasoning with Collaborative Agents)  
> **Problem Statement ID:** 26176 | **Target Platform:** Flutter Mobile Application (iOS & Android)  
> **Design Philosophy:** *High-Contrast Tactical Marine Glassmorphism with Zero-Friction Native Mobile Voice Interaction*  

---

## 1. 🌊 Mobile Maritime Human Factors

Navigating small watercraft on open seas presents severe physical and environmental constraints for smartphone usage:
1. **Bright Direct Sunlight Glare:** Standard subtle web palettes wash out completely on boat decks. ORCA provides an ultra-high-contrast **"Sunlight Deck Mode"** alongside a sleek **"Deep Ocean Tactical Mode"**.
2. **Rough Sea Motion & Wet Hands:** Touch targets must be oversized ($\ge 56\times 56\text{ dp}$), with a prominent floating push-to-talk mic button, native haptic feedback (`HapticFeedback.vibrate()`), and high-volume audio alerts.
3. **Emergency Visibility:** Instant color coding following international maritime safety conventions (Red = Border/Critical Hazard, Green = Safe/PFZ Catch Zone, Amber = Weather Advisory, Cyan = Safe Course).

---

## 2. 🎨 Flutter Design Tokens & Palette

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Deep Ocean Tactical Dark Theme (Default)
  static const Color abyssBlack = Color(0xFF050B14);
  static const Color deepOcean = Color(0xFF0B192C);
  static const Color marineSurface = Color(0xFF1E3E62);
  
  // Tactical Indicators & Navigational Accents
  static const Color radarCyan = Color(0xFF00F0FF);     // Active Route & Craft Heading
  static const Color bioGreen = Color(0xFF00FF88);      // Potential Fishing Zones (PFZs)
  static const Color warningAmber = Color(0xFFFFB300);  // Swell Alert & 5km Buffer
  static const Color criticalRed = Color(0xFFFF2A6D);   // IMBL Boundary & Emergency Halt
  
  // Typography
  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textAccent = Color(0xFF38BDF8);

  // Sunlight Deck Mode Colors
  static const Color sunlightBg = Color(0xFFFFFFFF);
  static const Color sunlightSurface = Color(0xFFF1F5F9);
  static const Color sunlightTextPrimary = Color(0xFF020617);
  static const Color sunlightCyan = Color(0xFF0284C7);
  static const Color sunlightRed = Color(0xFFBE123C);
}
```

---

## 3. 📱 Mobile Wireframe & Screen Layout

The mobile interface is designed around a full-screen **Interactive Marine Map Canvas** with an expandable **Conversational Voice Bottom Sheet** and a persistent **Top Telemetry HUD Bar**.

```text
+-----------------------------------------------------------+
| 🌊 ORCA  [GPS: 9.28°N, 79.31°E]  [8.4 kts]  [Lang: தமிழ் ▾]|
+-----------------------------------------------------------+
|                                                           |
|   FULLSCREEN TACTICAL MAP CANVAS (Flutter Map)            |
|                                                           |
|   ┌───────────────────────────────────────────────────┐   |
|   │ 🚨 CRITICAL ALERT: Approaching IMBL (4.8 km)      │   |
|   └───────────────────────────────────────────────────┘   |
|                                                           |
|       [Red Boundary: IMBL 2km Buffer]                     |
|                  \                                        |
|                   \   [Cyan Line: Safe A* Route]          |
|                    \          /                           |
|                     \     [Boat Marker] ──> Heading 082°  |
|                      \        \                           |
|                       \     [Green Circle: PFZ-04 Zone]   |
|                        \                                  |
|                                                           |
|   [Layer Controls: ☒ IMBL  ☒ PFZ  ☒ Weather]              |
|                                                           |
|   ┌───────────────────────────────────────────────────┐   |
|   │ TELEMETRY HUD: Wave: 1.3m | Wind: 12 kts | Safe   │   |
|   └───────────────────────────────────────────────────┘   |
|                                                           |
+-----------------------------------------------------------+
|  🤖 CONVERSATIONAL VOICE BOTTOM SHEET                     |
|                                                           |
|  "வானிலை பாதுகாப்பானது. PFZ-04 நோக்கி புதிய பாதை          |
|   வரைபடத்திலுள்ளது."                                      |
|                                                           |
|  [ ▶ Play Voice Advice 0:00 / 0:14 ılılılılı ]            |
|                                                           |
|  [ 🐟 Nearest PFZ ]  [ ⚠️ Check Border ]  [ 🏠 Harbor ]  |
|                                                           |
|                 ┌───────────────────┐                     |
|                 │ 🎙️ HOLD TO SPEAK  │  (Oversized Mic)   |
|                 └───────────────────┘                     |
+-----------------------------------------------------------+
```

---

## 4. 🧩 Flutter Widget Hierarchy

```text
DashboardScreen (Scaffold)
├── TopAppBar (TelemetryHUDBar)
│   ├── GPSCoordinatesTicker
│   ├── SpeedAndHeadingChip
│   ├── IMBLProximityPill (Color Shifting)
│   └── LanguageSelectorDropdown
│
├── Body: Stack
│   ├── MarineMapView (FlutterMap)
│   │   ├── TileLayer (CartoDB Dark Matter / Nautical Vector)
│   │   ├── PolygonLayer (IMBL Warning Buffers & PFZs)
│   │   ├── PolylineLayer (A* Safe Course LineString)
│   │   └── MarkerLayer (Live Vessel Heading Vector)
│   │
│   ├── TopPositioned: EmergencyBanner (Animated slide-down)
│   ├── FloatingPositioned: MapLayerControls (IMBL, PFZ, Weather toggles)
│   └── BottomPositioned: SeaStateGauge (Wave height & wind card)
│
└── BottomSheet: ConversationalSheet
    ├── AudioWaveformVisualizer (Amplitude bars)
    ├── MessageCard (Dual Language: Regional Text + Audio Player)
    ├── QuickPromptChips (Horizontal ListView)
    └── VoiceMicButton (Pulsating Circular Hero Button with Haptic feedback)
```

---

## 5. 📳 Haptic & Sound Feedback Specifications

- **Mic Press Down:** Light haptic click (`HapticFeedback.lightImpact()`).
- **Voice Response Synthesized:** Short audio chime + auto-play regional TTS.
- **IMBL Warning Zone ($< 5\text{ km}$):** Periodic caution beep (every 30 seconds).
- **IMBL Critical Violation ($< 2\text{ km}$):** High-priority pulsing emergency buzzer alarm + continuous vibration (`HapticFeedback.heavyImpact()`).
