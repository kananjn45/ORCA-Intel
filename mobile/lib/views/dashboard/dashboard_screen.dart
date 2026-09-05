import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/geofence_model.dart';
import '../../data/models/weather_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/marine_repository.dart';
import '../../data/repositories/chat_repository.dart';
import 'widgets/emergency_banner.dart';
import '../map/marine_map_view.dart';
import '../map/tactical_radar_canvas.dart';
import '../chat/conversational_sheet.dart';
import '../chat/widgets/language_selector_sheet.dart';
import '../offline/pre_voyage_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MarineRepository _marineRepo = MarineRepository();
  final ChatRepository _chatRepo = ChatRepository();

  // Dynamic Telemetry (defaults to Tamil Nadu coastal waters)
  TelemetryModel _telemetry = TelemetryModel(
    latitude: 12.80,
    longitude: 80.36,
    speedKnots: 8.4,
    headingDeg: 82.0,
    timestamp: DateTime.now(),
  );

  WeatherModel? _weather;
  GeofenceModel _geofence = const GeofenceModel(
    distanceToImblKm: 18.4,
    nearestImblPoint: {'lat': 12.71, 'lon': 80.83},
    lookaheadBreachProjected: false,
    warningLevel: GeofenceWarningLevel.safe,
    evasiveHeadingDeg: 265.0,
  );

  bool _isRecording = false;
  bool _showPfzCourse = true;
  bool _showEvasiveCourse = false;
  String _currentLanguageCode = 'en';
  String _currentLanguageName = 'English';
  int _activeNavIndex = 0; // 0: Voyage Map, 1: Radar, 2: Alerts, 3: Offline
  int? _selectedTelemetryIndex; // 0: Wave, 1: Wind, 2: Border, null: collapsed
  ChatMessageModel? _latestAdvisory;

  @override
  void initState() {
    super.initState();
    _rebuildInitialAdvisory(_currentLanguageCode);
    _fetchLiveBackendData();
  }

  void _rebuildInitialAdvisory(String langCode) {
    final loc = AppLocalizations.of(langCode);
    _latestAdvisory = ChatMessageModel(
      id: 'init-01',
      sender: MessageSender.orca,
      textLocalized: loc['sampleAnswer'] as String? ?? 'கடல் அமைதியாக உள்ளது (அலை: 0.8மீ, காற்று: 12 நாட்ஸ்). பாதுகாப்பான மண்டலம்.',
      textEnglish: loc['sampleAnswerEn'] as String? ?? 'Sea conditions calm (Wave: 0.8m, Wind: 12 kts). Optimal fishing zone PFZ-TN-04 is loaded. Safe route active.',
      timestamp: DateTime.now(),
      quickReplies: ['Nearest Harbor', 'Hourly Swell', 'Border Distance'],
    );
  }

  /// Fetches live sea state and geofence proximity from the FastAPI backend
  Future<void> _fetchLiveBackendData() async {
    try {
      final weather = await _marineRepo.fetchLiveWeather(
        lat: _telemetry.latitude,
        lon: _telemetry.longitude,
      );
      final geofence = await _marineRepo.checkGeofence(
        lat: _telemetry.latitude,
        lon: _telemetry.longitude,
        speedKnots: _telemetry.speedKnots,
        headingDeg: _telemetry.headingDeg,
      );

      if (mounted) {
        setState(() {
          _weather = weather;
          _geofence = geofence;
        });
      }
    } catch (e) {
      debugPrint('[DashboardScreen] _fetchLiveBackendData error: $e');
    }
  }

  void _handleLanguageChanged(String code, String name) {
    setState(() {
      _currentLanguageCode = code;
      _currentLanguageName = name.split(' ')[0];
      _rebuildInitialAdvisory(code);
    });
  }

  void _handleVoiceRecordingStart() {
    HapticFeedback.heavyImpact();
    setState(() => _isRecording = true);
  }

  void _handleVoiceRecordingEnd() async {
    HapticFeedback.mediumImpact();
    setState(() => _isRecording = false);
    final loc = AppLocalizations.of(_currentLanguageCode);

    final agentReply = await _chatRepo.sendChatMessage(
      query: loc['sampleQuestion'] as String,
      telemetry: _telemetry,
      languageCode: _currentLanguageCode,
    );

    if (mounted) {
      setState(() => _latestAdvisory = agentReply);
    }
  }

  void _handleQuickPrompt(String prompt) async {
    HapticFeedback.selectionClick();

    if (prompt.contains('PFZ') || prompt.contains('மீன்பிடி')) {
      setState(() {
        _showPfzCourse = !_showPfzCourse;
        _showEvasiveCourse = false;
      });
      _showPfzDetailsModal();
    } else if (prompt.contains('Border') || prompt.contains('எல்லை')) {
      setState(() {
        _showEvasiveCourse = true;
        _showPfzCourse = false;
      });
      _showBorderDetailsModal();
    } else if (prompt.contains('Waves') || prompt.contains('அலை')) {
      _showWeatherDetailsModal();
    }

    final agentReply = await _chatRepo.sendChatMessage(
      query: prompt,
      telemetry: _telemetry,
      languageCode: _currentLanguageCode,
    );

    if (mounted) {
      setState(() => _latestAdvisory = agentReply);
    }
  }

  void _openConversationalDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConversationalSheet(
        latestAdvisory: _latestAdvisory,
        currentLanguageCode: _currentLanguageCode,
        isRecording: _isRecording,
        onRecordingStart: _handleVoiceRecordingStart,
        onRecordingEnd: _handleVoiceRecordingEnd,
        onQuickPromptTap: _handleQuickPrompt,
      ),
    );
  }

  void _showPfzDetailsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.neonLime, width: 1.5),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.eco_rounded, color: AppColors.neonLime, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'POTENTIAL FISHING ZONE (PFZ)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.neonLime.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HIGH YIELD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.neonLime,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Sector ID', 'PFZ · Sector 04 (Tamil Nadu Coast)'),
              _buildInfoRow('Target Distance', '14.2 km (Approx 55 mins at 8.4 kts)'),
              _buildInfoRow('Ocean Parameters', 'SST: 28.4°C • Chlorophyll: 1.25 mg/m³'),
              _buildInfoRow('Target Shoals', 'Pelagic shoals: Sardine, Mackerel, Tuna'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonLime,
                    foregroundColor: const Color(0xFF092238),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text(
                    _showPfzCourse ? 'Clear Plotted Route' : 'Engage Safe Route to PFZ',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _showPfzCourse = !_showPfzCourse;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.brandSurface,
                        content: Text(
                          _showPfzCourse
                              ? '🧭 Cyan Safe Route Plotted to PFZ Sector 04'
                              : 'Route cleared',
                          style: const TextStyle(color: AppColors.inkLight),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBorderDetailsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.safetyRed, width: 1.5),
      ),
      builder: (ctx) {
        final dist = _geofence.distanceToImblKm;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: AppColors.safetyRed, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'IMBL BORDER MONITOR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.safetyRed,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.safetyRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${dist.toStringAsFixed(1)} KM REMAINING',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.safetyRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Nearest IMBL Coordinate', '12.710°N, 80.830°E (Maritime Line)'),
              _buildInfoRow('Projected Time to Breach', '${(dist / (_telemetry.speedKnots * 1.852) * 60).toStringAsFixed(0)} mins at current speed'),
              _buildInfoRow('Vessel Heading', '${_telemetry.headingDeg.toStringAsFixed(0)}° (Course clear)'),
              _buildInfoRow('Recommended Evasive Heading', 'Steer 265° Westward back toward harbor'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.safetyRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.turn_left_rounded),
                  label: const Text(
                    'Plot Evasive Course (265° West)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _showEvasiveCourse = true;
                      _showPfzCourse = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.brandSurface,
                        content: Text(
                          '⚠️ Evasive course plotted: Steer 265° Westward away from IMBL boundary',
                          style: TextStyle(color: AppColors.inkLight),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWeatherDetailsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.electricCyan, width: 1.5),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.waves_rounded, color: AppColors.electricCyan, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'LIVE MARINE WEATHER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.inkLight,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.neonLime.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CALM • SAFE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.neonLime,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Wave Height', '${_weather?.waveHeightM.toStringAsFixed(1) ?? "0.8"} m (Moderate swell)'),
              _buildInfoRow('Wind Speed & Bearing', '${_weather?.windSpeedKnots.toStringAsFixed(0) ?? "12"} knots (NE · Steady)'),
              _buildInfoRow('Swell Height', '${_weather?.swellWaveHeightM.toStringAsFixed(1) ?? "0.7"} m • 5.8s period'),
              _buildInfoRow('Sea Surface Temp', '28.4°C (Favourable)'),
              _buildInfoRow('Ensemble Provider', 'INCOIS Ocean Ensemble + Open-Meteo High-Res'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.electricCyan,
                    side: const BorderSide(color: AppColors.electricCyan),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Ocean Satellite Feed'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchLiveBackendData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.brandSurface,
                        content: Text(
                          '🌊 Re-ingested latest oceanographic satellite feed',
                          style: TextStyle(color: AppColors.inkLight),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSimulationControls() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.neonLime, width: 1.5),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.science_rounded, color: AppColors.neonLime, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'TEST SCENARIO SIMULATOR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.inkLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Test how the live system reacts to different coastal & border scenarios:',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              // Scenario 1
              ListTile(
                tileColor: AppColors.cardSurfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.shield_rounded, color: AppColors.neonLime),
                title: const Text('Scenario 1: Tamil Nadu Coast / Safe Harbor (18.4 km clearance)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.inkLight)),
                subtitle: const Text('Lat 12.80°N, Lon 80.36°E • Web UI Demo Coordinates', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setScenario(lat: 12.80, lon: 80.36, heading: 82.0, speed: 8.4);
                },
              ),
              const SizedBox(height: 8),
              // Scenario 2
              ListTile(
                tileColor: AppColors.cardSurfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.warning_amber_rounded, color: AppColors.hazardAmber),
                title: const Text('Scenario 2: Palk Strait Caution (4.8 km to border)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.inkLight)),
                subtitle: const Text('Lat 9.285°N, Lon 79.312°E • 5km buffer zone', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setScenario(lat: 9.285, lon: 79.312, heading: 82.0, speed: 8.4);
                },
              ),
              const SizedBox(height: 8),
              // Scenario 3
              ListTile(
                tileColor: AppColors.cardSurfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.dangerous_rounded, color: AppColors.safetyRed),
                title: const Text('Scenario 3: Border Breach Danger (1.4 km to border!)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.safetyRed)),
                subtitle: const Text('Lat 9.345°N, Lon 79.412°E • Triggers Critical Evasive Alarm', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setScenario(lat: 9.345, lon: 79.412, heading: 90.0, speed: 11.2);
                },
              ),
              const SizedBox(height: 8),
              // Scenario 4
              ListTile(
                tileColor: AppColors.cardSurfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.thunderstorm_rounded, color: AppColors.hazardAmber),
                title: const Text('Scenario 4: High Seas Cyclone & Shelter Harbor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.hazardAmber)),
                subtitle: const Text('Wave: 3.2m • Wind: 34 kts • Emergency evasion', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setStormScenario();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _setStormScenario() {
    setState(() {
      _telemetry = TelemetryModel(
        latitude: 12.80,
        longitude: 80.36,
        speedKnots: 5.2,
        headingDeg: 240.0,
        timestamp: DateTime.now(),
      );
      _weather = WeatherModel(
        latitude: 12.80,
        longitude: 80.36,
        waveHeightM: 3.2,
        waveDirectionDeg: 90.0,
        wavePeriodSec: 7.8,
        windSpeedKnots: 34.0,
        windDirectionDeg: 85.0,
        swellWaveHeightM: 2.8,
        seaSurfaceTempCelsius: 27.2,
        seaStateCode: 5,
        isSafeForSmallCraft: false,
        advisorySummary: 'STORM WARNING: Severe wave action (3.2m, 34 kts wind). Return to shelter harbor!',
        observedAt: DateTime.now(),
      );
      _showEvasiveCourse = true;
      _showPfzCourse = false;
      _latestAdvisory = ChatMessageModel(
        id: 'storm-01',
        sender: MessageSender.orca,
        textLocalized: 'புயல் எச்சரிக்கை! அலை 3.2மீ, காற்று 34 நாட்ஸ். உடனடியாக பாதுகாப்பான துறைமுகத்திற்கு திரும்பவும்.',
        textEnglish: 'STORM WARNING! Wave height 3.2m with 34 kts squall winds. Return to harbor immediately via Safe Course 240° W.',
        timestamp: DateTime.now(),
        quickReplies: ['Shelter Harbor Route', 'Hourly Barometer', 'Mayday Alert'],
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.hazardAmber,
        content: Text(
          '⚠️ Cyclone Alert: High wave action detected (3.2m). Course plotted to shelter harbor.',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _setScenario({required double lat, required double lon, required double heading, required double speed}) async {
    setState(() {
      _telemetry = TelemetryModel(
        latitude: lat,
        longitude: lon,
        speedKnots: speed,
        headingDeg: heading,
        timestamp: DateTime.now(),
      );
    });

    await _fetchLiveBackendData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _geofence.warningLevel == GeofenceWarningLevel.critical
              ? AppColors.safetyRed
              : AppColors.brandSurface,
          content: Text(
            'Updated Vessel Position: ${lat}°N, ${lon}°E • IMBL Dist: ${_geofence.distanceToImblKm.toStringAsFixed(1)} km',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.inkLight),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waveHeight = _weather?.waveHeightM ?? 0.8;
    final windSpeed = _weather?.windSpeedKnots ?? 12.0;
    final imblDist = _geofence.distanceToImblKm;

    return Scaffold(
      backgroundColor: AppColors.brandNavy,
      body: Stack(
        children: [
          // ==================================================================
          // UPPER PANEL: LIVE MARINE MAP (OR TACTICAL RADAR CANVAS)
          // ==================================================================
          Positioned.fill(
            bottom: 240, // Leaves space for the bottom Command Deck
            child: _activeNavIndex == 1
                // Radar Mode
                ? TacticalRadarCanvas(
                    vesselHeadingDeg: _telemetry.headingDeg,
                    speedKnots: _telemetry.speedKnots,
                    imblDistanceKm: _geofence.distanceToImblKm,
                    showPfzCourse: _showPfzCourse,
                    showEvasiveCourse: _showEvasiveCourse,
                    onPfzTap: _showPfzDetailsModal,
                    onImblTap: _showBorderDetailsModal,
                    onVesselTap: _showSimulationControls,
                  )
                // Default: Live Web UI-Styled Marine Map
                : MarineMapView(
                    telemetry: _telemetry,
                    geofence: _geofence,
                    showPfzRoute: _showPfzCourse,
                    showEvasiveRoute: _showEvasiveCourse,
                    onMenuTap: _showSimulationControls,
                    onAvatarTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => LanguageSelectorSheet(
                          currentLanguageCode: _currentLanguageCode,
                          onLanguageSelected: _handleLanguageChanged,
                        ),
                      );
                    },
                    onPfzTap: _showPfzDetailsModal,
                    onImblTap: _showBorderDetailsModal,
                    onHazardsTap: _showWeatherDetailsModal,
                    onRouteChipTap: _showPfzDetailsModal,
                  ),
          ),

          // ==================================================================
          // EMERGENCY BANNER (Pops in if Warning / Critical / Lookahead Breach)
          // ==================================================================
          if (_geofence.warningLevel == GeofenceWarningLevel.critical ||
              _geofence.warningLevel == GeofenceWarningLevel.warning ||
              _geofence.lookaheadBreachProjected)
            Positioned(
              top: 104,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: EmergencyBanner(
                  geofence: _geofence,
                  onEngageEvasive: () {
                    HapticFeedback.heavyImpact();
                    setState(() {
                      _showEvasiveCourse = true;
                      _showPfzCourse = false;
                      _telemetry = TelemetryModel(
                        latitude: _telemetry.latitude,
                        longitude: _telemetry.longitude,
                        speedKnots: _telemetry.speedKnots,
                        headingDeg: _geofence.evasiveHeadingDeg ?? 265.0,
                        timestamp: DateTime.now(),
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.safetyRed,
                        content: Text(
                          '🚨 Evasive 180° course engaged (Heading ${_geofence.evasiveHeadingDeg?.toStringAsFixed(0) ?? "265"}° W back into Indian waters)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    );
                  },
                  onDismiss: () {
                    setState(() {
                      _geofence = GeofenceModel(
                        distanceToImblKm: _geofence.distanceToImblKm,
                        nearestImblPoint: _geofence.nearestImblPoint,
                        lookaheadBreachProjected: false,
                        warningLevel: GeofenceWarningLevel.safe,
                        evasiveHeadingDeg: _geofence.evasiveHeadingDeg,
                      );
                    });
                  },
                ),
              ),
            ),

          // ==================================================================
          // LOWER PANEL: WEB UI COMMAND DECK (Frosted Glass Tactical Sheet)
          // ==================================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF062033),
                    Color(0xFF061B2B),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                  color: AppColors.cardBorder.withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 24,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Deck Handle
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.brandHandle,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Greeting Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GOOD MORNING, CAPTAIN',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                      color: AppColors.inkLight,
                                    ),
                                    children: [
                                      const TextSpan(text: 'Conditions are '),
                                      TextSpan(
                                        text: waveHeight < 2.0 ? 'favourable.' : 'hazardous!',
                                        style: TextStyle(
                                          color: waveHeight < 2.0
                                              ? AppColors.neonLime
                                              : AppColors.hazardAmber,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Safety › Button (toggles quick safety overview)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedTelemetryIndex =
                                    _selectedTelemetryIndex == null ? 0 : null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF173A47),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF2C5963),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Safety',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFBDE1DF),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _selectedTelemetryIndex != null ? '▾' : '›',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.neonLime,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3-Column Interactive Telemetry Safety Bar
                      Row(
                        children: [
                          // 1. Wave Height
                          Expanded(
                            child: _buildTelemetryCard(
                              index: 0,
                              icon: '≈',
                              iconColor: AppColors.electricCyan,
                              label: 'WAVE',
                              value: waveHeight.toStringAsFixed(1),
                              unit: 'm',
                              status: waveHeight < 1.5 ? '● CALM' : '● SWELL',
                              statusColor: waveHeight < 1.5
                                  ? AppColors.neonLime
                                  : AppColors.hazardAmber,
                              isSelected: _selectedTelemetryIndex == 0,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedTelemetryIndex =
                                      _selectedTelemetryIndex == 0 ? null : 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 7),
                          // 2. Wind Speed
                          Expanded(
                            child: _buildTelemetryCard(
                              index: 1,
                              icon: '↗',
                              iconColor: AppColors.neonLime,
                              label: 'WIND',
                              value: windSpeed.toStringAsFixed(0),
                              unit: 'kt',
                              status: 'NE · STEADY',
                              statusColor: AppColors.textMuted,
                              isSelected: _selectedTelemetryIndex == 1,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedTelemetryIndex =
                                      _selectedTelemetryIndex == 1 ? null : 1;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 7),
                          // 3. Nearest Border
                          Expanded(
                            child: _buildTelemetryCard(
                              index: 2,
                              icon: '⌁',
                              iconColor: AppColors.electricTeal,
                              label: 'BORDER',
                              value: imblDist.toStringAsFixed(1),
                              unit: 'km',
                              status: imblDist > 5.0 ? '● SAFE' : '⚠️ CAUTION',
                              statusColor: imblDist > 5.0
                                  ? AppColors.neonLime
                                  : AppColors.safetyRed,
                              isSelected: _selectedTelemetryIndex == 2,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedTelemetryIndex =
                                      _selectedTelemetryIndex == 2 ? null : 2;
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      // INLINE INTERACTIVE ADVISORY (Appears instantly when tapping any of the 3 options)
                      if (_selectedTelemetryIndex != null) ...[
                        const SizedBox(height: 10),
                        _buildInlineAdvisoryCard(waveHeight, windSpeed, imblDist),
                      ],
                      const SizedBox(height: 12),

                      // Action Row (Primary CTA + Voice Mic Action)
                      Row(
                        children: [
                          // Primary Navigation Action Button
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.heavyImpact();
                                setState(() {
                                  _showPfzCourse = !_showPfzCourse;
                                });
                                _showPfzDetailsModal();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.neonLime,
                                  borderRadius: BorderRadius.circular(13),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonLime.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.explore_rounded,
                                      color: Color(0xFF092238),
                                      size: 24,
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'NAVIGATION',
                                          style: TextStyle(
                                            fontFamily: 'Courier',
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.0,
                                            color: Color(0x99092238),
                                          ),
                                        ),
                                        Text(
                                          'Start safe route',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF092238),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Spacer(),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Color(0xFF092238),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Voice Mic Action Button
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _openConversationalDrawer();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF123949),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: const Color(0xFF286070),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '⌁',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.neonLime,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Bottom Navigation Bar
                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFF183747), width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(
                              index: 0,
                              icon: '◉',
                              label: 'Voyage',
                              isActive: _activeNavIndex == 0,
                            ),
                            _buildNavItem(
                              index: 1,
                              icon: '◈',
                              label: 'Radar',
                              isActive: _activeNavIndex == 1,
                            ),
                            _buildNavItem(
                              index: 2,
                              icon: '◷',
                              label: 'Alerts',
                              isActive: _activeNavIndex == 2,
                              badge: '2',
                            ),
                            _buildNavItem(
                              index: 3,
                              icon: '◌',
                              label: 'Offline',
                              isActive: _activeNavIndex == 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineAdvisoryCard(double waveHeight, double windSpeed, double imblDist) {
    if (_selectedTelemetryIndex == 0) {
      // Wave advisory
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xCC09293A),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.electricCyan.withOpacity(0.7), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.electricCyan.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.waves_rounded, size: 17, color: AppColors.electricCyan),
                const SizedBox(width: 6),
                Text(
                  'SEA STATE · ${waveHeight < 1.5 ? "CALM & SAFE" : "MODERATE SWELL"}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.electricCyan,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedTelemetryIndex = null),
                  child: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              waveHeight < 1.5
                  ? 'Wave height is ${waveHeight.toStringAsFixed(1)} m. Safe for motorized fishing crafts. Favourable surface conditions along Tamil Nadu coast.'
                  : 'Swell height is ${waveHeight.toStringAsFixed(1)} m. Moderate waves detected. Exercise caution and maintain safe heading.',
              style: const TextStyle(fontSize: 11, color: AppColors.inkLight, height: 1.35),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Swell: ${_weather?.swellWaveHeightM.toStringAsFixed(1) ?? "0.7"} m • SST: 28.4°C',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _fetchLiveBackendData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.brandSurface,
                        content: Text('🌊 Satellite ocean feed updated', style: TextStyle(color: AppColors.inkLight)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.electricCyan.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.electricCyan.withOpacity(0.4)),
                    ),
                    child: const Text('Refresh Feed ↺', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.electricCyan)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (_selectedTelemetryIndex == 1) {
      // Wind advisory
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xCC09293A),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.neonLime.withOpacity(0.7), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonLime.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.air_rounded, size: 17, color: AppColors.neonLime),
                const SizedBox(width: 6),
                Text(
                  'WIND SPEED · ${windSpeed.toStringAsFixed(0)} KT (STEADY BREEZE)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.neonLime,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedTelemetryIndex = null),
                  child: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              windSpeed < 20
                  ? 'Steady North-East wind at ${windSpeed.toStringAsFixed(0)} knots. Well below the 25 kt small-craft squall threshold. Favourable sailing drift.'
                  : 'Strong breeze (${windSpeed.toStringAsFixed(0)} kt). Approaching squall threshold (25 kt). Secure gear and monitor course.',
              style: const TextStyle(fontSize: 11, color: AppColors.inkLight, height: 1.35),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Direction: ENE (65°) • Gusts: 15 kt',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.neonLime.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('● SAFE TO SAIL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.neonLime)),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Border advisory
      final isCaution = imblDist <= 5.0;
      final isCritical = imblDist <= 2.0;
      final statusColor = isCritical ? AppColors.safetyRed : (isCaution ? AppColors.hazardAmber : AppColors.neonLime);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xCC09293A),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: statusColor.withOpacity(0.8), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.shield_rounded, size: 17, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  'IMBL BORDER CLEARANCE · ${imblDist.toStringAsFixed(1)} KM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedTelemetryIndex = null),
                  child: const Icon(Icons.close_rounded, size: 17, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isCritical
                  ? 'CRITICAL ALERT: Only ${imblDist.toStringAsFixed(1)} km to Sri Lanka maritime boundary! Immediate course reversal required.'
                  : (isCaution
                      ? 'Caution: You are inside the 5.0 km buffer zone (${imblDist.toStringAsFixed(1)} km remaining). Maintain clearance from boundary.'
                      : 'Safe waters: ${imblDist.toStringAsFixed(1)} km clearance to Sri Lanka boundary line. Standard navigation.'),
              style: const TextStyle(fontSize: 11, color: AppColors.inkLight, height: 1.35),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCaution ? 'Heading: ${_telemetry.headingDeg.toStringAsFixed(0)}° (Eastward)' : 'Buffer: 5.0 km active',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.heavyImpact();
                    setState(() {
                      _showEvasiveCourse = true;
                      _showPfzCourse = false;
                      _telemetry = TelemetryModel(
                        latitude: _telemetry.latitude,
                        longitude: _telemetry.longitude,
                        speedKnots: _telemetry.speedKnots,
                        headingDeg: 265.0,
                        timestamp: DateTime.now(),
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.safetyRed,
                        content: Text('⚠️ Course updated: Steer 265° Westward back into Indian waters', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.safetyRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Turn 265° West →', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTelemetryCard({
    required int index,
    required String icon,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    required String status,
    required Color statusColor,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F384E) : const Color(0xFF09293A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? iconColor : const Color(0xFF173F50),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  icon,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Icon(
                  isSelected ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: isSelected ? iconColor : AppColors.textMuted.withOpacity(0.5),
                ),
              ],
            ),
            const SizedBox(height: 3),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.inkLight,
                ),
                children: [
                  TextSpan(text: value),
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String icon,
    required String label,
    required bool isActive,
    String? badge,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (index == 2) {
          // Alerts modal
          _showBorderDetailsModal();
        } else if (index == 3) {
          // Offline Screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PreVoyageScreen()),
          );
        } else {
          setState(() => _activeNavIndex = index);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                icon,
                style: TextStyle(
                  fontSize: 17,
                  color: isActive ? AppColors.neonLime : const Color(0xFF71969E),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? AppColors.neonLime : const Color(0xFF71969E),
                ),
              ),
            ],
          ),
          if (badge != null)
            Positioned(
              top: -4,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.safetyRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
