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
import 'widgets/telemetry_hud_bar.dart';
import 'widgets/sea_state_gauge.dart';
import 'widgets/emergency_banner.dart';
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

  // Dynamic Telemetry Fix
  TelemetryModel _telemetry = TelemetryModel(
    latitude: 9.2854,
    longitude: 79.3121,
    speedKnots: 8.4,
    headingDeg: 82.0,
    timestamp: DateTime.now(),
  );

  WeatherModel? _weather;
  GeofenceModel _geofence = const GeofenceModel(
    distanceToImblKm: 4.82,
    nearestImblPoint: {'lat': 9.35, 'lon': 79.42},
    lookaheadBreachProjected: false,
    warningLevel: GeofenceWarningLevel.advisory,
    evasiveHeadingDeg: 265.0,
  );

  bool _isRecording = false;
  bool _showPfzCourse = false;
  bool _showEvasiveCourse = false;
  String _currentLanguageCode = 'en';
  String _currentLanguageName = 'English';

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
      textLocalized: loc['sampleAnswer'] as String? ?? 'கடல் அமைதியாக உள்ளது (அலை: 1.3மீ, காற்று: 12.5 நாட்ஸ்). பாதுகாப்பான மண்டலம்.',
      textEnglish: loc['sampleAnswerEn'] as String? ?? 'Sea conditions calm (Wave: 1.3m, Wind: 12.5 kts). Optimal fishing zone PFZ-TN-04 is 14.2 km away. Safe route loaded.',
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

  // ===========================================================================
  // INTERACTIVE MODAL SHEETS (PFZ, BORDER GEOFENCE, WEATHER & SIMULATION)
  // ===========================================================================

  void _showPfzDetailsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: AppColors.bioGreen, width: 1.5),
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
                      Text('🐟', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 8),
                      Text(
                        'INCOIS PFZ-TN-04',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.bioGreen,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.bioGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HIGH YIELD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.bioGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Location', '9.412°N, 79.450°E (Rameswaram East)'),
              _buildInfoRow('Target Distance', '14.2 km (Approx 55 mins at 8.4 kts)'),
              _buildInfoRow('Ocean Parameters', 'SST: 28.4°C • Chlorophyll: 1.25 mg/m³'),
              _buildInfoRow('Likely Species', 'Pelagic shoals: Sardine, Mackerel, Tuna'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bioGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.navigation_rounded),
                  label: Text(_showPfzCourse ? 'Clear Plotted Route' : 'Engage Course to PFZ'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _showPfzCourse = !_showPfzCourse;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.navyDark,
                        content: Text(
                          _showPfzCourse ? '🧭 Green Course Vector Plotted to PFZ-04' : 'Route cleared',
                          style: const TextStyle(color: AppColors.iceWhite),
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
        side: BorderSide(color: AppColors.criticalRed, width: 1.5),
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
                      Icon(Icons.shield_rounded, color: AppColors.criticalRed, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'IMBL BORDER MONITOR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.criticalRed,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.criticalRed.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${dist.toStringAsFixed(1)} KM REMAINING',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.criticalRed,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Nearest IMBL Coordinate', '9.350°N, 79.420°E (Sri Lanka Boundary)'),
              _buildInfoRow('Projected Time to Breach', '${(dist / (_telemetry.speedKnots * 1.852) * 60).toStringAsFixed(0)} mins at current speed'),
              _buildInfoRow('Vessel Heading', '${_telemetry.headingDeg.toStringAsFixed(0)}° Eastward (Approaching boundary)'),
              _buildInfoRow('Recommended Evasive Course', 'Steer 265° Westward back into Indian waters'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.criticalRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.turn_left_rounded),
                  label: const Text('Plot Evasive Course (265° West)'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _showEvasiveCourse = true;
                      _showPfzCourse = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.navyDark,
                        content: Text(
                          '⚠️ Evasive course plotted: Steer 265° Westward away from Sri Lanka IMBL',
                          style: TextStyle(color: AppColors.iceWhite),
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
        side: BorderSide(color: AppColors.navyDark, width: 1.5),
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
                      Icon(Icons.waves_rounded, color: AppColors.primaryBlue, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'OPEN-METEO SEA STATE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.iceWhite,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.bioGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CALM • SAFE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.bioGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Significant Wave Height', '${_weather?.waveHeightM.toStringAsFixed(1) ?? "1.3"} meters'),
              _buildInfoRow('Swell Height & Period', '${_weather?.swellWaveHeightM.toStringAsFixed(1) ?? "1.1"} m • 6.2 seconds'),
              _buildInfoRow('Wind Speed & Bearing', '${_weather?.windSpeedKnots.toStringAsFixed(0) ?? "13"} knots (Direction: ENE / 65°)'),
              _buildInfoRow('Sea Surface Temperature', '28.4°C (Optimal for motorized fishing)'),
              _buildInfoRow('Source Data', 'Open-Meteo High-Resolution Satellite Ensemble'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Live Satellite Data'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchLiveBackendData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.navyDark,
                        content: Text(
                          '🌊 Re-ingested latest Open-Meteo satellite feed',
                          style: TextStyle(color: AppColors.iceWhite),
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
        side: BorderSide(color: AppColors.primaryBlue, width: 1.5),
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
                  Icon(Icons.science_rounded, color: AppColors.primaryBlue, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'TEST SCENARIO SIMULATOR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.iceWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Test how the live system reacts to different vessel positions in the Palk Strait:',
                style: TextStyle(fontSize: 12, color: AppColors.accentLight),
              ),
              const SizedBox(height: 14),
              // Scenario 1
              ListTile(
                tileColor: AppColors.cardSurfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.shield_rounded, color: AppColors.bioGreen),
                title: const Text('Scenario 1: Safe Harbor (12 km to border)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.iceWhite)),
                subtitle: const Text('Lat 9.22°N, Lon 79.25°E • Harbor waters', style: TextStyle(fontSize: 10, color: AppColors.accentLight)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setScenario(lat: 9.220, lon: 79.250, heading: 45.0, speed: 6.0);
                },
              ),
              const SizedBox(height: 8),
              // Scenario 2
              ListTile(
                tileColor: AppColors.cardSurfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warningAmber),
                title: const Text('Scenario 2: Palk Strait Caution (4.8 km to border)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.iceWhite)),
                subtitle: const Text('Lat 9.285°N, Lon 79.312°E • 5km buffer zone', style: TextStyle(fontSize: 10, color: AppColors.accentLight)),
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
                leading: const Icon(Icons.dangerous_rounded, color: AppColors.criticalRed),
                title: const Text('Scenario 3: Border Breach Danger (1.4 km to border!)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.criticalRed)),
                subtitle: const Text('Lat 9.345°N, Lon 79.412°E • Triggers Critical Evasive Alarm', style: TextStyle(fontSize: 10, color: AppColors.accentLight)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setScenario(lat: 9.345, lon: 79.412, heading: 90.0, speed: 11.2);
                },
              ),
              const SizedBox(height: 8),
              // Scenario 4 (ISRO Golden Scenario 3: Storm Cell & Offline Safe Harbor)
              ListTile(
                tileColor: AppColors.cardSurfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.thunderstorm_rounded, color: AppColors.warningAmber),
                title: const Text('Scenario 4: High Seas Cyclone & Shelter Harbor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warningAmber)),
                subtitle: const Text('Wave: 3.2m • Wind: 34 kts • Pre-cached shelter route', style: TextStyle(fontSize: 10, color: AppColors.accentLight)),
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
        latitude: 9.350,
        longitude: 79.250,
        speedKnots: 5.2,
        headingDeg: 240.0,
        timestamp: DateTime.now(),
      );
      _weather = WeatherModel(
        latitude: 9.350,
        longitude: 79.250,
        waveHeightM: 3.2,
        waveDirectionDeg: 90.0,
        wavePeriodSec: 7.8,
        windSpeedKnots: 34.0,
        windDirectionDeg: 85.0,
        swellWaveHeightM: 2.8,
        seaSurfaceTempCelsius: 27.2,
        seaStateCode: 5,
        isSafeForSmallCraft: false,
        advisorySummary: 'STORM WARNING: Severe wave action (3.2m, 34 kts wind). All small crafts seek immediate harbor refuge!',
        observedAt: DateTime.now(),
      );
      _showEvasiveCourse = true;
      _showPfzCourse = false;
      _latestAdvisory = ChatMessageModel(
        id: 'storm-01',
        sender: MessageSender.orca,
        textLocalized: 'புயல் எச்சரிக்கை! அலை 3.2மீ, காற்று 34 நாட்ஸ். உடனடியாக ராமேஸ்வரம் துறைமுகத்திற்கு திரும்பவும்.',
        textEnglish: 'STORM WARNING! Wave height 3.2m with 34 kts squall winds. Return to Rameswaram shelter harbor immediately via Safe Course 240° W.',
        timestamp: DateTime.now(),
        quickReplies: ['Rameswaram Harbor Route', 'Hourly Barometer', 'Mayday Alert'],
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppColors.warningAmber,
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
              ? AppColors.criticalRed
              : AppColors.navyDark,
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accentLight),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.iceWhite),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMidnight,
      body: Stack(
        children: [
          // 1. TACTICAL RADAR CANVAS (Oceanic Bathymetry, Range Rings, IMBL Border & PFZ)
          Positioned.fill(
            child: TacticalRadarCanvas(
              vesselHeadingDeg: _telemetry.headingDeg,
              speedKnots: _telemetry.speedKnots,
              imblDistanceKm: _geofence.distanceToImblKm,
              showPfzCourse: _showPfzCourse,
              showEvasiveCourse: _showEvasiveCourse,
              onPfzTap: _showPfzDetailsModal,
              onImblTap: _showBorderDetailsModal,
              onVesselTap: _showSimulationControls,
            ),
          ),

          // 2. TOP PERSISTENT TELEMETRY HUD BAR (Clean 2-Row Layout with GNSS & Actions)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TelemetryHudBar(
              telemetry: _telemetry,
              geofence: _geofence,
              currentLanguage: _currentLanguageName,
              onImblTap: _showBorderDetailsModal,
              onSimulateTap: _showSimulationControls,
              onOfflinePackTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PreVoyageScreen()),
                );
              },
              onLanguageTap: () {
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
            ),
          ),

          // 2.5 EMERGENCY ALERT BANNER (Active during Warning / Critical / Lookahead breach)
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
                        backgroundColor: AppColors.criticalRed,
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
                        warningLevel: GeofenceWarningLevel.advisory,
                        evasiveHeadingDeg: _geofence.evasiveHeadingDeg,
                      );
                    });
                  },
                ),
              ),
            ),

          // 3. FLOATING GLASSMORHPIC WEATHER INSTRUMENT (LIVE OPEN-METEO DATA - INTERACTIVE!)
          Positioned(
            left: 14,
            top: (_geofence.warningLevel == GeofenceWarningLevel.critical ||
                    _geofence.warningLevel == GeofenceWarningLevel.warning ||
                    _geofence.lookaheadBreachProjected)
                ? 270
                : 104,
            child: SafeArea(
              bottom: false,
              child: SeaStateGauge(
                waveHeightM: _weather?.waveHeightM ?? 1.3,
                swellHeightM: _weather?.swellWaveHeightM ?? 1.1,
                windSpeedKnots: _weather?.windSpeedKnots ?? 12.5,
                isSafe: _weather?.isSafeForSmallCraft ?? true,
                onTap: _showWeatherDetailsModal,
              ),
            ),
          ),

          // 4. EXECUTIVE MARINE ASSISTANT & TACTICAL CONTROL DRAWER (NO CHAT SIMULATOR)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConversationalSheet(
              latestAdvisory: _latestAdvisory,
              currentLanguageCode: _currentLanguageCode,
              isRecording: _isRecording,
              onRecordingStart: _handleVoiceRecordingStart,
              onRecordingEnd: _handleVoiceRecordingEnd,
              onQuickPromptTap: _handleQuickPrompt,
            ),
          ),
        ],
      ),
    );
  }
}
