import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/geo_math.dart';
import '../../data/models/coastal_sector.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/geofence_model.dart';
import '../../data/models/weather_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/pfz_model.dart';
import '../../data/models/cyclone_hazard_model.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/repositories/marine_repository.dart';
import '../../data/repositories/chat_repository.dart';
import 'widgets/emergency_banner.dart';
import '../map/marine_map_view.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/utils/audio_player_helper.dart';
import '../../data/repositories/voice_repository.dart';
import '../map/tactical_radar_canvas.dart';
import '../chat/conversational_sheet.dart';
import '../chat/widgets/language_selector_sheet.dart';
import '../offline/pre_voyage_screen.dart';
import '../common/stitch_app_header.dart';
import '../common/stitch_bottom_nav_bar.dart';
import 'widgets/stitch_compass_dial.dart';
import 'widgets/stitch_wave_sparkline.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MarineRepository _marineRepo = MarineRepository();
  final ChatRepository _chatRepo = ChatRepository();

  // Active Coastal Sector (defaults to Coromandel Coast / Chennai)
  CoastalSector _activeSector = CoastalSector.all[2];

  // Dynamic Telemetry (defaults to selected sector)
  late TelemetryModel _telemetry;
  WeatherModel? _weather;
  CycloneHazardModel? _liveCycloneHazard;
  late GeofenceModel _geofence;
  PFZModel? _activePfz;

  // Live Navigation & Simulation Modes
  bool _isLiveCruising = true; // Auto sea cruise simulation (active coordinates movement)
  bool _isLiveGpsActive = false; // Real device hardware GNSS sensor
  Timer? _cruiseTimer;
  Timer? _weatherRefreshTimer;
  double? _lastWeatherQueryLat;
  double? _lastWeatherQueryLon;
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  double _baseSpeedKnots = 8.4;

  bool _isRecording = false;
  bool _showPfzCourse = true;
  bool _showEvasiveCourse = false;
  String _currentLanguageCode = 'en';
  String _currentLanguageName = 'English';
  int _activeNavIndex = 0; // 0: Voyage Map, 1: Radar, 2: Alerts, 3: Offline
  int? _selectedTelemetryIndex; // 0: Wave, 1: Wind, 2: Border, null: collapsed
  ChatMessageModel? _latestAdvisory;

  // Interactive Voice & Query Assistant State
  String _lastCaptainQuery = 'Is there a storm alert? Where is the nearest PFZ?';
  DateTime _lastCaptainQueryTime = DateTime.now();
  final TextEditingController _queryInputController = TextEditingController();
  final VoiceRepository _voiceRepo = VoiceRepository();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayerHelper _audioPlayer = AudioPlayerHelper();
  bool _isProcessingVoice = false;
  String? _recordedAudioPath;
  String? _latestAudioBase64;
  bool _isPlayingAudio = false;
  bool _isSynthesizingAudio = false;

  @override
  void initState() {
    super.initState();
    _telemetry = _activeSector.createInitialTelemetry();
    _geofence = _activeSector.createInitialGeofence();
    _baseSpeedKnots = _activeSector.initialSpeedKnots;

    _playerStateSubscription = _audioPlayer.player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = (state == PlayerState.playing);
        });
      }
    });

    _rebuildInitialAdvisory(_currentLanguageCode);
    _fetchLiveBackendData();
    _startCruiseTimer();

    // Periodic 45s refresh of Open-Meteo live sea telemetry
    _weatherRefreshTimer = Timer.periodic(const Duration(seconds: 45), (timer) {
      if (!mounted) return;
      _fetchLiveBackendData();
    });
  }

  @override
  void dispose() {
    _cruiseTimer?.cancel();
    _weatherRefreshTimer?.cancel();
    _gpsSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _queryInputController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Starts the dynamic sea cruise movement timer (ticks every 1 second)
  void _startCruiseTimer() {
    _cruiseTimer?.cancel();
    _cruiseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isLiveCruising || _isLiveGpsActive) return;
      _stepCruiseMovement();
    });
  }

  /// Advances the vessel along its course with realistic ocean current jitter
  void _stepCruiseMovement() {
    final headingRad = _telemetry.headingDeg * (math.pi / 180.0);
    // 1 knot = ~0.00000463 degrees/second latitude displacement
    final speedDegPerSec = _telemetry.speedKnots * 0.00000463;
    final deltaLat = speedDegPerSec * math.cos(headingRad);
    final latCos = math.cos(_telemetry.latitude * (math.pi / 180.0)).abs();
    final deltaLon = speedDegPerSec * math.sin(headingRad) / (latCos > 0.01 ? latCos : 1.0);

    // Natural ocean current swell fluctuations
    final sec = DateTime.now().second;
    final speedJitter = math.sin(sec * 0.5) * 0.16;
    final dynamicSpeed = (_baseSpeedKnots + speedJitter).clamp(4.0, 16.0);

    final newLat = _telemetry.latitude + deltaLat;
    final newLon = _telemetry.longitude + deltaLon;

    // Recalculate real-time distance to nearest maritime boundary
    final nearestPoint = _geofence.nearestImblPoint ?? _activeSector.nearestBorderPoint;
    final distKm = GeoMath.haversineKm(
      newLat,
      newLon,
      nearestPoint['lat']!,
      nearestPoint['lon']!,
    );

    setState(() {
      _telemetry = TelemetryModel(
        latitude: newLat,
        longitude: newLon,
        speedKnots: dynamicSpeed,
        headingDeg: _telemetry.headingDeg,
        timestamp: DateTime.now(),
      );
      _geofence = GeofenceModel(
        distanceToImblKm: distKm,
        nearestImblPoint: nearestPoint,
        lookaheadBreachProjected: distKm < 5.0,
        warningLevel: distKm < 5.0
            ? GeofenceWarningLevel.critical
            : (distKm < 10.0 ? GeofenceWarningLevel.warning : GeofenceWarningLevel.safe),
        evasiveHeadingDeg: _geofence.evasiveHeadingDeg ?? ((_telemetry.headingDeg + 180.0) % 360.0),
      );
    });

    if (_lastWeatherQueryLat != null && _lastWeatherQueryLon != null) {
      if ((newLat - _lastWeatherQueryLat!).abs() > 0.08 || (newLon - _lastWeatherQueryLon!).abs() > 0.08) {
        _fetchLiveBackendData();
      }
    }
  }

  /// Toggles hardware device GPS on physical Android devices
  Future<void> _toggleHardwareGps() async {
    if (_isLiveGpsActive) {
      await _gpsSubscription?.cancel();
      setState(() {
        _isLiveGpsActive = false;
        _isLiveCruising = true;
      });
      _startCruiseTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0284C7),
            content: Text('🚢 Resumed Sea Cruise Simulator Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
      return;
    }

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.hazardAmber,
              content: Text('⚠️ Please enable GPS / Location on device', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.safetyRed,
                content: Text('⚠️ Location permission denied by user', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          }
          return;
        }
      }

      _cruiseTimer?.cancel();
      setState(() {
        _isLiveGpsActive = true;
        _isLiveCruising = false;
      });

      final initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _onGpsPositionReceived(initialPos);

      _gpsSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
      ).listen(_onGpsPositionReceived);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF16A34A),
            content: Text('📍 Hardware GPS Active — Receiving device GNSS coordinates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[DashboardScreen] GPS error: $e');
    }
  }

  void _onGpsPositionReceived(Position position) {
    final speedKnots = position.speed >= 0 ? position.speed * 1.94384 : _telemetry.speedKnots;
    final heading = position.heading >= 0 ? position.heading : _telemetry.headingDeg;
    final nearestPoint = _geofence.nearestImblPoint ?? _activeSector.nearestBorderPoint;
    final distKm = GeoMath.haversineKm(
      position.latitude,
      position.longitude,
      nearestPoint['lat']!,
      nearestPoint['lon']!,
    );

    setState(() {
      _telemetry = TelemetryModel(
        latitude: position.latitude,
        longitude: position.longitude,
        speedKnots: speedKnots,
        headingDeg: heading,
        timestamp: DateTime.now(),
      );
      _geofence = GeofenceModel(
        distanceToImblKm: distKm,
        nearestImblPoint: nearestPoint,
        lookaheadBreachProjected: distKm < 5.0,
        warningLevel: distKm < 5.0
            ? GeofenceWarningLevel.critical
            : (distKm < 10.0 ? GeofenceWarningLevel.warning : GeofenceWarningLevel.safe),
        evasiveHeadingDeg: _geofence.evasiveHeadingDeg,
      );
    });

    if (_lastWeatherQueryLat != null && _lastWeatherQueryLon != null) {
      if ((position.latitude - _lastWeatherQueryLat!).abs() > 0.08 || (position.longitude - _lastWeatherQueryLon!).abs() > 0.08) {
        _fetchLiveBackendData();
      }
    }
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

  /// Fetches live sea state and geofence proximity from the FastAPI backend / Direct Open-Meteo
  Future<void> _fetchLiveBackendData() async {
    try {
      _lastWeatherQueryLat = _telemetry.latitude;
      _lastWeatherQueryLon = _telemetry.longitude;
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
      final pfzs = await _marineRepo.fetchPFZAdvisories(
        lat: _telemetry.latitude,
        lon: _telemetry.longitude,
      );
      final cycloneHazard = await _marineRepo.fetchLiveCycloneHazard(
        lat: _telemetry.latitude,
        lon: _telemetry.longitude,
      );

      if (mounted) {
        setState(() {
          _weather = weather;
          _geofence = geofence;
          _liveCycloneHazard = cycloneHazard;
          if (pfzs.isNotEmpty) {
            _activePfz = pfzs.first;
          }
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

  Future<void> _handleVoiceRecordingStart() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = true;
      _isProcessingVoice = false;
    });

    try {
      if (await _audioRecorder.hasPermission()) {
        String recordPath = '';
        if (!kIsWeb) {
          try {
            final tempDir = await getTemporaryDirectory();
            recordPath = p.join(
              tempDir.path,
              'orca_voice_${DateTime.now().millisecondsSinceEpoch}.wav',
            );
            _recordedAudioPath = recordPath;
          } catch (_) {}
        }

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
          ),
          path: recordPath,
        );
      }
    } catch (e) {
      debugPrint('[DashboardScreen] voice record start error: $e');
    }
  }

  Future<void> _handleVoiceRecordingEnd() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRecording = false;
      _isProcessingVoice = true;
    });

    String queryText = '';
    try {
      final path = await _audioRecorder.stop();
      final filePath = path ?? _recordedAudioPath;
      if (filePath != null && filePath.isNotEmpty && !kIsWeb) {
        final file = File(filePath);
        if (await file.exists()) {
          final audioBytes = await file.readAsBytes();
          try { await file.delete(); } catch (_) {}

          if (audioBytes.length > 500) {
            // Live speech-to-text via Bhashini ASR endpoint
            final transcript = await _voiceRepo.transcribeAudio(
              audioBytes: audioBytes,
              languageCode: _currentLanguageCode,
            );
            if (transcript != null && transcript.trim().isNotEmpty) {
              queryText = transcript.trim();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[DashboardScreen] voice record stop error: $e');
    }

    if (queryText.isEmpty) {
      final typed = _queryInputController.text.trim();
      if (typed.isNotEmpty) {
        queryText = typed;
      } else {
        final loc = AppLocalizations.of(_currentLanguageCode);
        queryText = loc['sampleQuestion'] as String? ?? 'Is there a storm alert? Where is the nearest PFZ?';
      }
    }

    await _submitCaptainQuery(queryText);
  }

  Future<void> _submitCaptainQuery(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    HapticFeedback.selectionClick();
    _queryInputController.clear();

    setState(() {
      _lastCaptainQuery = cleanQuery;
      _lastCaptainQueryTime = DateTime.now();
      _isProcessingVoice = true;
    });

    try {
      final agentReply = await _chatRepo.sendChatMessage(
        query: cleanQuery,
        telemetry: _telemetry,
        languageCode: _currentLanguageCode,
      );

      if (mounted) {
        setState(() {
          _latestAdvisory = agentReply;
          _isProcessingVoice = false;
        });

        if (agentReply.audioBase64 != null && agentReply.audioBase64!.isNotEmpty) {
          _latestAudioBase64 = agentReply.audioBase64;
          await _audioPlayer.playBytesBase64(agentReply.audioBase64!);
          if (mounted) {
            setState(() => _isPlayingAudio = true);
          }
        } else {
          // Fallback synthesize spoken voice response using live Bhashini TTS
          _synthesizeAndPlayAdvisory(agentReply.textLocalized);
        }
      }
    } catch (e) {
      debugPrint('[DashboardScreen] _submitCaptainQuery error: $e');
      if (mounted) {
        setState(() => _isProcessingVoice = false);
      }
    }
  }

  Future<void> _synthesizeAndPlayAdvisory(String text) async {
    if (text.isEmpty) return;
    try {
      setState(() => _isSynthesizingAudio = true);
      final audioB64 = await _voiceRepo.synthesizeSpeech(
        text: text,
        languageCode: _currentLanguageCode,
      );
      if (audioB64 != null && audioB64.isNotEmpty) {
        _latestAudioBase64 = audioB64;
        await _audioPlayer.playBytesBase64(audioB64);
        if (mounted) {
          setState(() {
            _isPlayingAudio = true;
            _isSynthesizingAudio = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isSynthesizingAudio = false);
        }
      }
    } catch (e) {
      debugPrint('[DashboardScreen] _synthesizeAndPlayAdvisory error: $e');
      if (mounted) {
        setState(() => _isSynthesizingAudio = false);
      }
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

    await _submitCaptainQuery(prompt);
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
    final pfzLat = _activePfz?.centroidLat ?? (_telemetry.latitude > 20.0 ? 21.5200 : _activeSector.centerLat);
    final pfzLon = _activePfz?.centroidLon ?? (_telemetry.latitude > 20.0 ? 69.4100 : _activeSector.centerLon);
    final distKm = GeoMath.haversineKm(_telemetry.latitude, _telemetry.longitude, pfzLat, pfzLon);
    final chl = _activePfz?.chlorophyll ?? (_telemetry.latitude > 20.0 ? 2.35 : 1.45);
    final sstGrad = _activePfz?.sstGradient ?? (_telemetry.latitude > 20.0 ? 1.35 : 0.95);
    final sectorTitle = _activePfz?.sectorName ?? (_telemetry.latitude > 20.0 ? 'Porbandar Offshore Bank' : _activeSector.name);
    final speciesText = _activePfz != null && _activePfz!.targetSpecies.isNotEmpty
        ? _activePfz!.targetSpecies.join(', ')
        : (_telemetry.latitude > 20.0
            ? 'Silver Pomfret, Ribbonfish, Spanish Mackerel'
            : 'Pelagic shoals: Sardine, Mackerel, Tuna');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      Icon(Icons.eco_rounded, color: Color(0xFF16A34A), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'POTENTIAL FISHING ZONE (PFZ)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'HIGH YIELD',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildInfoRow('Sector ID', 'PFZ · $sectorTitle'),
              _buildInfoRow(
                'Target Distance',
                '${distKm.toStringAsFixed(1)} km (Approx ${((distKm / ((_telemetry.speedKnots > 0.5 ? _telemetry.speedKnots : 8.4) * 1.852)) * 60).round()} mins at ${(_telemetry.speedKnots > 0.5 ? _telemetry.speedKnots : 8.4).toStringAsFixed(1)} kts)',
              ),
              _buildInfoRow('Ocean Parameters', 'SST Gradient: ${sstGrad.toStringAsFixed(2)}°C • Chlorophyll: ${chl.toStringAsFixed(2)} mg/m³'),
              _buildInfoRow('Target Shoals', speciesText),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
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
                        backgroundColor: const Color(0xFF16A34A),
                        content: Text(
                          _showPfzCourse
                              ? '🧭 Safe Route Plotted to $sectorTitle'
                              : 'Route cleared',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                      Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'IMBL BORDER MONITOR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${dist.toStringAsFixed(1)} KM REMAINING',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFDC2626),
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
                    backgroundColor: const Color(0xFFDC2626),
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
                        backgroundColor: Color(0xFFDC2626),
                        content: Text(
                          '⚠️ Evasive course plotted: Steer 265° Westward away from IMBL boundary',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    final hazard = _liveCycloneHazard;
    final isSevere = hazard?.isSevere ?? false;
    final category = hazard?.hazardCategory ?? 'CALM • SAFE';
    final primaryColor = isSevere ? const Color(0xFFDC2626) : const Color(0xFF0284C7);
    final badgeBg = isSevere ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7);
    final badgeColor = isSevere ? const Color(0xFFDC2626) : const Color(0xFF16A34A);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          isSevere ? Icons.warning_amber_rounded : Icons.waves_rounded,
                          color: primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isSevere ? 'CYCLONE & MET HAZARD RADAR' : 'LIVE MARINE WEATHER',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (hazard != null) ...[
                _buildInfoRow(
                  'Cyclone/Storm Status',
                  '${hazard.hazardCategory} (${hazard.detected ? "Live Cell Tracked" : "Monitored"})',
                ),
                _buildInfoRow(
                  'Central Barometer',
                  '${hazard.surfacePressureHpa.toStringAsFixed(1)} hPa (Sea-level pressure)',
                ),
                _buildInfoRow(
                  'Tracked Cell Center',
                  '${hazard.centerLatitude.toStringAsFixed(4)}°N, ${hazard.centerLongitude.toStringAsFixed(4)}°E',
                ),
                _buildInfoRow(
                  'Danger Perimeter',
                  '${hazard.radiusKm.toStringAsFixed(1)} km dynamic radial zone',
                ),
                _buildInfoRow(
                  'Distance to Vessel',
                  '${hazard.distanceToVesselKm.toStringAsFixed(1)} km (Bearing ${hazard.bearingToCenterDeg.toStringAsFixed(0)}°)',
                ),
                _buildInfoRow(
                  'Max Sustained Wind',
                  '${hazard.maxWindSpeedKnots.toStringAsFixed(1)} kts (Gusts: ${hazard.maxWindGustsKnots.toStringAsFixed(1)} kts)',
                ),
                _buildInfoRow(
                  'Significant Wave (Hs)',
                  '${hazard.maxWaveHeightM.toStringAsFixed(2)} m (${_weather?.swellWaveHeightM.toStringAsFixed(1) ?? "0.7"}m swell)',
                ),
                _buildInfoRow(
                  'Advisory Notice',
                  hazard.advisory,
                ),
              ] else ...[
                _buildInfoRow('Wave Height', '${_weather?.waveHeightM.toStringAsFixed(1) ?? "0.8"} m (Moderate swell)'),
                _buildInfoRow('Wind Speed & Bearing', '${_weather?.windSpeedKnots.toStringAsFixed(0) ?? "12"} knots (NE · Steady)'),
                _buildInfoRow('Swell Height', '${_weather?.swellWaveHeightM.toStringAsFixed(1) ?? "0.7"} m • 5.8s period'),
              ],
              _buildInfoRow('Sea Surface Temp', '${_weather?.seaSurfaceTempCelsius.toStringAsFixed(1) ?? "28.4"}°C (Favourable)'),
              _buildInfoRow(
                'Data Engine',
                'Open-Meteo High-Res Spatial Multi-Grid (${hazard?.source ?? "open-meteo-live"})',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Ocean Satellite & Meteo Grid'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchLiveBackendData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: primaryColor,
                        content: const Text(
                          '🌊 Re-ingested latest Open-Meteo spatial grid & cyclone radar feed',
                          style: TextStyle(color: Colors.white),
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
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.navigation_rounded, color: Color(0xFF0284C7), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'NAVIGATION & SEA CRUISE SIMULATOR',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Control dynamic boat cruising, switch to hardware phone GPS, or simulate maritime border scenarios:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),

                  // 1. LIVE NAVIGATION MODE CONTROLLERS
                  const Text(
                    'LIVE NAVIGATION CONTROLS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Cruise Simulation Toggle
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _isLiveCruising = !_isLiveCruising;
                              if (_isLiveCruising) {
                                _isLiveGpsActive = false;
                                _startCruiseTimer();
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: _isLiveCruising ? const Color(0xFF16A34A) : AppColors.hazardAmber,
                                content: Text(
                                  _isLiveCruising ? '🚢 Auto-Cruise Dynamic Movement: RESUMED' : '⏸️ Sea Cruise: PAUSED',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isLiveCruising && !_isLiveGpsActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isLiveCruising && !_isLiveGpsActive ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _isLiveCruising && !_isLiveGpsActive ? Icons.directions_boat_rounded : Icons.pause_circle_rounded,
                                  color: _isLiveCruising && !_isLiveGpsActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isLiveCruising && !_isLiveGpsActive ? 'CRUISE: ON' : 'CRUISE: PAUSED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _isLiveCruising && !_isLiveGpsActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isLiveCruising && !_isLiveGpsActive ? 'Coords ticking live' : 'Tap to resume',
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Hardware GPS Toggle
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _toggleHardwareGps();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: _isLiveGpsActive ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isLiveGpsActive ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.gps_fixed_rounded,
                                  color: _isLiveGpsActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isLiveGpsActive ? 'DEVICE GPS: ON' : 'DEVICE GPS: OFF',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _isLiveGpsActive ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isLiveGpsActive ? 'Using GNSS sensor' : 'Tap to use phone GPS',
                                  style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 2. FIVE COASTAL DEPARTURE SECTORS
                  const Text(
                    'QUICK JUMP TO COASTAL SECTOR',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CoastalSector.all.map((sector) {
                      final isSelected = _activeSector.name == sector.name;
                      return ChoiceChip(
                        label: Text(sector.name),
                        selected: isSelected,
                        selectedColor: const Color(0xFFE0F2FE),
                        backgroundColor: const Color(0xFFF8FAFC),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155),
                        ),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            Navigator.pop(ctx);
                            setState(() {
                              _activeSector = sector;
                              _telemetry = sector.createInitialTelemetry();
                              _geofence = sector.createInitialGeofence();
                              _baseSpeedKnots = sector.initialSpeedKnots;
                              _isLiveCruising = true;
                              _isLiveGpsActive = false;
                            });
                            _startCruiseTimer();
                            _fetchLiveBackendData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF0284C7),
                                content: Text(
                                  '🚢 Cruising in ${sector.name} (${sector.centerLat}°N, ${sector.centerLon}°E)',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 3. TEST SCENARIOS
                  const Text(
                    'EMERGENCY & BORDER BREACH SCENARIOS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 8),

                  // Scenario 1
                  ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    leading: const Icon(Icons.shield_rounded, color: Color(0xFF16A34A)),
                    title: const Text('Safe Navigation / Offshore Harbor (18.4 km clearance)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    subtitle: const Text('Lat 12.80°N, Lon 80.36°E • Standard deep-sea fishing', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    onTap: () {
                      Navigator.pop(ctx);
                      _setScenario(lat: 12.80, lon: 80.36, heading: 82.0, speed: 8.4);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Scenario 2
                  ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
                    title: const Text('Palk Strait Caution (4.8 km to border)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    subtitle: const Text('Lat 9.285°N, Lon 79.312°E • 5km buffer zone', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    onTap: () {
                      Navigator.pop(ctx);
                      _setScenario(lat: 9.285, lon: 79.312, heading: 82.0, speed: 8.4);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Scenario 3
                  ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    leading: const Icon(Icons.dangerous_rounded, color: Color(0xFFDC2626)),
                    title: const Text('Border Breach Danger (1.4 km to border!)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                    subtitle: const Text('Lat 9.345°N, Lon 79.412°E • Triggers Critical Evasive Alarm', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    onTap: () {
                      Navigator.pop(ctx);
                      _setScenario(lat: 9.345, lon: 79.412, heading: 90.0, speed: 11.2);
                    },
                  ),
                  const SizedBox(height: 8),
                  // Scenario 4
                  ListTile(
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    leading: const Icon(Icons.thunderstorm_rounded, color: Color(0xFFD97706)),
                    title: const Text('High Seas Cyclone & Shelter Harbor', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    subtitle: const Text('Wave: 3.2m • Wind: 34 kts • Emergency evasion', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeController.isDarkMode,
      builder: (context, isDark, _) {
        final waveHeight = _weather?.waveHeightM ?? 0.8;
        final windSpeed = _weather?.windSpeedKnots ?? 12.0;
        final imblDist = _geofence.distanceToImblKm;

        return Scaffold(
          backgroundColor: isDark ? AppColors.brandNavy : const Color(0xFFF1F5F9),
          body: Stack(
            children: [
              // ==================================================================
              // ACTIVE TAB CONTENT (FULL SCREEN)
              // ==================================================================
              Positioned.fill(
                bottom: 60, // Slim clearance for bottom navigation bar
                child: _buildActiveTabContent(isDark, waveHeight, windSpeed, imblDist),
              ),

              // ==================================================================
              // EMERGENCY BANNER (Pops in if Warning / Critical / Lookahead Breach)
              // ==================================================================
              if (_geofence.warningLevel == GeofenceWarningLevel.critical ||
                  _geofence.warningLevel == GeofenceWarningLevel.warning ||
                  _geofence.lookaheadBreachProjected)
                Positioned(
                  top: 96,
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
              // FLOATING BOTTOM NAVIGATION BAR (Clean, Tactile, 5 Tabs)
              // ==================================================================
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBottomNavBar(isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveTabContent(bool isDark, double waveHeight, double windSpeed, double imblDist) {
    switch (_activeNavIndex) {
      case 1:
        return _buildSafetyTab(isDark, waveHeight, windSpeed, imblDist);
      case 2:
        return _buildVoiceAITab(isDark);
      case 3:
        return _buildRadarTab(isDark);
      case 4:
        return _buildOfflineTab(isDark);
      case 0:
      default:
        return _buildMapTab(isDark);
    }
  }

  /// TAB 0: 100% Fullscreen Marine Map Canvas
  Widget _buildMapTab(bool isDark) {
    return MarineMapView(
      telemetry: _telemetry,
      geofence: _geofence,
      activePfz: _activePfz,
      liveHazard: _liveCycloneHazard,
      showPfzRoute: _showPfzCourse,
      showEvasiveRoute: _showEvasiveCourse,
      isDarkMode: isDark,
      currentLanguageName: _currentLanguageName,
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
    );
  }

  /// TAB 1: Dedicated Safety & Telemetry Screen (Stitch Screen 1: Safety Nav & Marine Met)
  Widget _buildSafetyTab(bool isDark, double waveHeight, double windSpeed, double imblDist) {
    final isCaution = _geofence.warningLevel == GeofenceWarningLevel.warning || waveHeight >= 2.0;
    final isCritical = _geofence.warningLevel == GeofenceWarningLevel.critical || imblDist <= 2.0;

    return Column(
      children: [
        // Fixed Top StitchAppHeader
        StitchAppHeader(
          screenTitle: 'Safety & Met',
          activePortName: _activeSector.name.split('(').last.replaceAll(')', '').trim(),
          latitude: _telemetry.latitude,
          longitude: _telemetry.longitude,
          currentLanguageCode: _currentLanguageCode,
          isGpsHardwareActive: _isLiveGpsActive,
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
          onAvatarTap: _showSimulationControls,
          onSyncTap: _fetchLiveBackendData,
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
            children: [
              // Header Row with Test Invariant: 'SAFETY & TELEMETRY'
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAFETY & TELEMETRY',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                          ),
                        ),
                        Text(
                          '${_activeSector.name} · Live INCOIS Satellite Telemetry',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.stitchPrimary,
                      side: const BorderSide(color: AppColors.stitchOutlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.science_rounded, size: 15),
                    label: const Text('Simulator', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: _showSimulationControls,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Tactical Sea State Condition Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCritical
                        ? AppColors.stitchError
                        : (isCaution ? AppColors.stitchTertiary : AppColors.stitchOutlineVariant),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isCritical
                          ? AppColors.stitchError
                          : (isCaution ? AppColors.stitchTertiary : AppColors.stitchPrimary)).withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Chip & Assessment Title
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isCritical
                                  ? AppColors.stitchErrorContainer
                                  : (isCaution ? AppColors.stitchTertiaryContainer : AppColors.stitchSecondaryContainer)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isCritical
                                      ? Icons.warning_rounded
                                      : (isCaution ? Icons.warning_amber_rounded : Icons.check_circle_rounded),
                                  size: 14,
                                  color: isCritical
                                      ? AppColors.stitchOnErrorContainer
                                      : (isCaution ? AppColors.stitchOnTertiaryContainer : AppColors.stitchOnSecondaryContainer),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    isCritical
                                        ? 'CRITICAL ALERT: TURN BACK'
                                        : (isCaution ? 'CAUTION: ROUGH SEAS / SWELL ADVISORY' : 'SAFE HARBOR TRANSIT / NORMAL CONDITIONS'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                      color: isCritical
                                          ? AppColors.stitchOnErrorContainer
                                          : (isCaution ? AppColors.stitchOnTertiaryContainer : AppColors.stitchOnSecondaryContainer),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _weather?.source == 'open-meteo-live'
                                ? 'LIVE METEO SST ${_weather!.seaSurfaceTempCelsius.toStringAsFixed(1)}°C'
                                : 'INCOIS SST ${_weather?.seaSurfaceTempCelsius.toStringAsFixed(1) ?? "28.4"}°C',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Primary Metric (Significant Wave Height Hs)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          waveHeight.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: isCritical
                                ? AppColors.stitchError
                                : (isCaution ? AppColors.stitchTertiary : AppColors.stitchPrimary),
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'M',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SIGNIFICANT WAVE HEIGHT (Hs)',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                _weather?.advisorySummary ?? '+0.2m vs 3h ago • Swell Period 7.8s',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Assessment Chips
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 14, color: AppColors.stitchPrimary),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Swell Window: Next 14h Favourable',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 14, color: AppColors.stitchSecondary),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    'Advisory: Drift Netting Permitted',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // GPS & Vessel Telemetry Bar
                    InkWell(
                      onTap: _showSimulationControls,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.stitchSurfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isLiveGpsActive
                                        ? AppColors.stitchSecondary
                                        : (_isLiveCruising ? const Color(0xFF16A34A) : AppColors.stitchTertiary),
                                  ),
                                ),
                                Text(
                                  'GPS: ${_telemetry.latitude.toStringAsFixed(4)}°N, ${_telemetry.longitude.toStringAsFixed(4)}°E',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                            Text(
                              '${_telemetry.speedKnots.toStringAsFixed(1)} kt • ${_telemetry.headingDeg.toStringAsFixed(0)}°',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 1.5 Cyclone & Storm Cell Radar Card (Live Open-Meteo Multi-Point Tracking)
              if (_liveCycloneHazard != null) ...[
                _buildLiveCycloneCard(isDark),
                const SizedBox(height: 12),
              ],

              // 2. Swell Window Countdown Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_rounded, size: 16, color: AppColors.stitchPrimary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'SAFE PASSAGE WINDOW (NEXT 18 HOURS)',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                    color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.stitchSecondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '12h 45m REMAINING',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.stitchOnSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Linear Progress Bar (72% favorable, 28% caution)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 72,
                              child: Container(color: AppColors.stitchSecondary),
                            ),
                            Expanded(
                              flex: 28,
                              child: Container(color: AppColors.stitchTertiaryContainer),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 4 Timeline Checkpoints
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimelineCheckpoint('12:00', '0.8m', 'Calm', AppColors.stitchSecondary),
                        _buildTimelineCheckpoint('16:00', '1.1m', 'Mod', AppColors.stitchSecondary),
                        _buildTimelineCheckpoint('20:00', '1.4m', 'Rising', AppColors.stitchTertiary),
                        _buildTimelineCheckpoint('02:00', '2.2m', 'Rough', AppColors.stitchError),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Tactile Cards Header & 3 Cards (WAVE, WIND, BORDER)
              Text(
                'TAP METRIC FOR DETAILED ADVISORY',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _buildTelemetryCard(
                      index: 0,
                      icon: '≈',
                      iconColor: isDark ? AppColors.electricCyan : AppColors.stitchPrimary,
                      label: 'WAVE',
                      value: waveHeight.toStringAsFixed(1),
                      unit: 'm',
                      status: waveHeight < 1.5 ? '● CALM' : '● SWELL',
                      statusColor: waveHeight < 1.5 ? AppColors.stitchSecondary : AppColors.stitchTertiary,
                      isSelected: _selectedTelemetryIndex == 0,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTelemetryIndex = _selectedTelemetryIndex == 0 ? null : 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTelemetryCard(
                      index: 1,
                      icon: '↗',
                      iconColor: isDark ? AppColors.neonLime : AppColors.stitchSecondary,
                      label: 'WIND',
                      value: windSpeed.toStringAsFixed(0),
                      unit: 'kt',
                      status: 'NE · STEADY',
                      statusColor: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                      isSelected: _selectedTelemetryIndex == 1,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTelemetryIndex = _selectedTelemetryIndex == 1 ? null : 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTelemetryCard(
                      index: 2,
                      icon: '⌁',
                      iconColor: isDark ? AppColors.electricTeal : AppColors.stitchTertiary,
                      label: 'BORDER',
                      value: imblDist.toStringAsFixed(1),
                      unit: 'km',
                      status: imblDist > 5.0 ? '● SAFE' : '⚠️ CAUTION',
                      statusColor: imblDist > 5.0 ? AppColors.stitchSecondary : AppColors.stitchError,
                      isSelected: _selectedTelemetryIndex == 2,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedTelemetryIndex = _selectedTelemetryIndex == 2 ? null : 2;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Inline Advisory Card if selected
              _buildInlineAdvisoryCard(waveHeight, windSpeed, imblDist),
              const SizedBox(height: 14),

              // 4. Stitch 2x2 Bento Metric Grid
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'METEOROLOGICAL TELEMETRY MATRIX',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Top-Left: Wind Speed & Vector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'WIND & VECTOR',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                                    ),
                                  ),
                                  const Icon(Icons.air_rounded, size: 14, color: AppColors.stitchPrimary),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: StitchCompassDial(
                                  bearingDeg: _telemetry.headingDeg,
                                  size: 70,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${windSpeed.toStringAsFixed(1)} KTS',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Gusts: ${(windSpeed + 3.4).toStringAsFixed(1)} kt • ESE (115°)',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Top-Right: Significant Wave & Swell Sparkline
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'WAVE FORECAST',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                                    ),
                                  ),
                                  const Icon(Icons.waves_rounded, size: 14, color: AppColors.stitchSecondary),
                                ],
                              ),
                              const SizedBox(height: 6),
                              StitchWaveSparkline(
                                currentWaveHeight: waveHeight,
                                peakWaveHeight: waveHeight + 0.6,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${waveHeight.toStringAsFixed(1)}M Hs',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Peak ${(waveHeight + 0.6).toStringAsFixed(1)}m @ 22:00 • 8.2s',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Bottom-Left: Tidal Stream & Drift
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TIDAL STREAM',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                                    ),
                                  ),
                                  const Icon(Icons.water_rounded, size: 14, color: AppColors.stitchPrimary),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '1.2 KTS',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                '045° NE • Drift 0.4 m/s',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.stitchSurfaceContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'EBB TIDE (-0.4M)',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.stitchPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bottom-Right: Barometric Pressure
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'BAROMETER',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                                    ),
                                  ),
                                  const Icon(Icons.speed_rounded, size: 14, color: AppColors.stitchTertiary),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '1012.4 hPa',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                              Text(
                                'Steady (+0.2 hPa / 3h)',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.stitchSurfaceContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'VISIBILITY: 9.2 NM',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.stitchSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5. Stitch Geo-Shield & Border Proximity Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: imblDist < 5.0 ? AppColors.stitchError : AppColors.stitchOutlineVariant,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              imblDist < 5.0 ? Icons.gpp_bad_rounded : Icons.shield_rounded,
                              size: 16,
                              color: imblDist < 5.0 ? AppColors.stitchError : AppColors.stitchPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'BORDER PROXIMITY ADVISORY',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: imblDist < 5.0 ? AppColors.stitchErrorContainer : AppColors.stitchSecondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            imblDist < 5.0 ? 'CAUTION' : 'RADAR ACTIVE',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: imblDist < 5.0 ? AppColors.stitchOnErrorContainer : AppColors.stitchOnSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(imblDist * 0.539957).toStringAsFixed(1)} NM BUFFER',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: imblDist < 5.0 ? AppColors.stitchError : AppColors.stitchTertiary,
                                ),
                              ),
                              const Text(
                                'INSIDE EXCLUSIVE ECONOMIC ZONE (EEZ)',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOutline,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.stitchPrimary,
                            side: const BorderSide(color: AppColors.stitchOutlineVariant),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: _showBorderDetailsModal,
                          child: const Text('View Corridor', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 6. Operational Maritime Action Deck
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.stitchSurfaceContainerHigh,
                        foregroundColor: AppColors.stitchOnSurface,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.stitchOutlineVariant),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.stitchPrimary),
                      label: const Text(
                        'Fog Horn / Test',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.stitchPrimary,
                            duration: Duration(seconds: 2),
                            content: Text('🔊 2-Blast Fog Horn Audio Beacon Triggered', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.stitchPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text(
                        'Refresh Met Feed',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _fetchLiveBackendData();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.stitchSecondary,
                            duration: Duration(seconds: 2),
                            content: Text('🛰️ Fetching Live INCOIS Satellite Telemetry...', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCheckpoint(String time, String wave, String condition, Color color) {
    return Column(
      children: [
        Text(
          time,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.stitchOutline),
        ),
        const SizedBox(height: 2),
        Text(
          wave,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color),
        ),
        Text(
          condition,
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildLiveCycloneCard(bool isDark) {
    final hazard = _liveCycloneHazard!;
    final isSevere = hazard.isSevere;
    final primaryColor = isSevere ? const Color(0xFFDC2626) : const Color(0xFF0284C7);
    final bgColor = isSevere
        ? (isDark ? const Color(0xFF3B1212) : const Color(0xFFFEF2F2))
        : (isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest);
    final borderColor = isSevere ? const Color(0xFFDC2626) : AppColors.stitchOutlineVariant;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isSevere ? 1.5 : 0.8),
        boxShadow: [
          if (isSevere)
            BoxShadow(
              color: const Color(0xFFDC2626).withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSevere ? Icons.warning_amber_rounded : Icons.cyclone_rounded,
                size: 16,
                color: primaryColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'METEOROLOGICAL CYCLONE & SWELL RADAR',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSevere ? const Color(0xFFFEE2E2) : AppColors.stitchSecondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hazard.hazardCategory,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: isSevere ? const Color(0xFFDC2626) : AppColors.stitchOnSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CENTRAL PRESSURE',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? AppColors.textMuted : AppColors.stitchOutline),
                      ),
                      Text(
                        '${hazard.surfacePressureHpa.toStringAsFixed(1)} hPa',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CELL DISTANCE',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? AppColors.textMuted : AppColors.stitchOutline),
                      ),
                      Text(
                        '${hazard.distanceToVesselKm.toStringAsFixed(1)} km @ ${hazard.bearingToCenterDeg.toStringAsFixed(0)}°',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GUSTS / WAVE',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? AppColors.textMuted : AppColors.stitchOutline),
                      ),
                      Text(
                        '${hazard.maxWindGustsKnots.toStringAsFixed(0)} kts · ${hazard.maxWaveHeightM.toStringAsFixed(1)}m',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Center: ${hazard.centerLatitude.toStringAsFixed(3)}°N, ${hazard.centerLongitude.toStringAsFixed(3)}°E • Radius: ${hazard.radiusKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.inkLight.withOpacity(0.7) : const Color(0xFF64748B),
                  ),
                ),
              ),
              InkWell(
                onTap: _showWeatherDetailsModal,
                child: Text(
                  'Open Meteo Details →',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// TAB 2: Dedicated Voice AI Assistant Screen (Stitch Screen 3: AI Voice Assistant)
  Widget _buildVoiceAITab(bool isDark) {
    final loc = AppLocalizations.of(_currentLanguageCode);
    final quickPrompts = List<String>.from(loc['quickPrompts'] as List? ?? ['Wave Swell', 'Border Distance', 'PFZ Route', 'Harbor Return']);
    final advisoryTa = _latestAdvisory?.textLocalized ??
        (loc['weatherStatus'] as String? ?? 'கடல் அமைதியாக உள்ளது (அலை: 0.8மீ, காற்று: 12 நாட்ஸ்). பாதுகாப்பான மண்டலம்.');
    final advisoryEn = _latestAdvisory?.textEnglish ??
        (loc['weatherStatusEn'] as String? ?? 'Sea conditions calm (Wave: 0.8m, Wind: 12 kts). Safe fishing zone.');
    final imblDist = _geofence.distanceToImblKm;

    return Column(
      children: [
        // Fixed Top StitchAppHeader
        StitchAppHeader(
          screenTitle: 'Voice AI Copilot',
          activePortName: _activeSector.name.split('(').last.replaceAll(')', '').trim(),
          latitude: _telemetry.latitude,
          longitude: _telemetry.longitude,
          currentLanguageCode: _currentLanguageCode,
          isGpsHardwareActive: _isLiveGpsActive,
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
          onAvatarTap: _showSimulationControls,
          onSyncTap: _fetchLiveBackendData,
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
            children: [
              // Top Title Header (Required for tests: 'VOICE AI ADVISORY')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VOICE AI ADVISORY',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                          ),
                        ),
                        Text(
                          'Bhashini Multilingual Speech Assistant • NavIC Synced',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.stitchSecondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.stitchSecondary,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'SATELLITE LINK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.stitchOnSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Captain Query Bubble
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.stitchPrimaryFixed.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: AppColors.stitchPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.person_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'CAPTAIN QUERY',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.stitchPrimary,
                                ),
                              ),
                              Text(
                                '${_lastCaptainQueryTime.hour.toString().padLeft(2, '0')}:${_lastCaptainQueryTime.minute.toString().padLeft(2, '0')} IST',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _lastCaptainQuery,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // AI Advisory Synthesis Card (Required for tests: 'ORCA INTELLIGENCE AGENT')
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.stitchOutlineVariant, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.stitchSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'ORCA INTELLIGENCE AGENT',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: AppColors.stitchPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '00:00 / 00:14',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.stitchOnSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Audio Player Controller Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.stitchSurfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            iconSize: 22,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            icon: Icon(
                              _isPlayingAudio ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: AppColors.stitchPrimary,
                            ),
                            onPressed: () async {
                              HapticFeedback.selectionClick();
                              if (_isPlayingAudio) {
                                await _audioPlayer.stop();
                                setState(() => _isPlayingAudio = false);
                              } else {
                                if (_latestAudioBase64 != null && _latestAudioBase64!.isNotEmpty) {
                                  await _audioPlayer.playBytesBase64(_latestAudioBase64!);
                                  setState(() => _isPlayingAudio = true);
                                } else {
                                  await _synthesizeAndPlayAdvisory(advisoryTa);
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: SizedBox(
                                height: 6,
                                child: LinearProgressIndicator(
                                  value: 0.35,
                                  backgroundColor: AppColors.stitchOutlineVariant.withOpacity(0.5),
                                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.stitchPrimary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '1.0x',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: AppColors.stitchOnSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Verbatim Advisory Text
                    Text(
                      advisoryTa,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      advisoryEn,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: isDark ? AppColors.textMuted : AppColors.stitchOnSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Citations Bento
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'INCOIS Wave Model v4.2',
                              style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.stitchOutline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.stitchSurfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'IMBL Buffer: ${imblDist.toStringAsFixed(1)} km',
                              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: AppColors.stitchSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // IMBL Warning Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.stitchTertiaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.stitchTertiary.withOpacity(0.5), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.stitchTertiary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'IMBL ADVISORY: Maintain heading < 130° SE to prevent international boundary drift.',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Interactive Captain Query Bar (Type or Speak)
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF09293A) : AppColors.stitchSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stitchOutlineVariant, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.stitchPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _queryInputController,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Ask anything... (e.g., Weather in Mumbai, Waves)',
                          hintStyle: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (val) => _submitCaptainQuery(val),
                      ),
                    ),
                    _isProcessingVoice
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.stitchPrimary),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded, size: 20, color: AppColors.stitchPrimary),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => _submitCaptainQuery(_queryInputController.text),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Mic Console with Real-Time Waveform Graphic
              Center(
                child: Column(
                  children: [
                    // Visualizer Bars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(15, (index) {
                        final heights = [10.0, 16.0, 24.0, 32.0, 18.0, 28.0, 36.0, 42.0, 30.0, 22.0, 34.0, 26.0, 14.0, 20.0, 12.0];
                        return Container(
                          width: 3.5,
                          height: (_isRecording || _isProcessingVoice) ? heights[index % heights.length] : 8.0,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: _isRecording ? AppColors.stitchError : AppColors.stitchPrimary.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),

                    // Pulsing Tactical Mic Button
                    GestureDetector(
                      onLongPressStart: (_) => _handleVoiceRecordingStart(),
                      onLongPressEnd: (_) => _handleVoiceRecordingEnd(),
                      onTap: () {
                        // Also support tap for instant prompt / conversational drawer
                        _openConversationalDrawer();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _isRecording ? 90 : 78,
                        height: _isRecording ? 90 : 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording ? AppColors.stitchError : AppColors.stitchPrimary,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? AppColors.stitchError : AppColors.stitchPrimary).withOpacity(0.35),
                              blurRadius: _isRecording ? 24 : 12,
                              spreadRadius: _isRecording ? 4 : 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isProcessingVoice
                          ? '● PROCESSING WITH BHASHINI AI...'
                          : (_isRecording ? '● LISTENING... / கேட்கிறது...' : 'HOLD TO SPEAK / பேச அழுத்திப் பிடிக்கவும்'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: _isProcessingVoice
                            ? AppColors.stitchSecondary
                            : (_isRecording ? AppColors.stitchError : AppColors.stitchPrimary),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tamil • Hindi • English • Telugu • Bengali',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Quick Inquiries Chips
              Text(
                'QUICK VOICE INQUIRIES / உடனடி கேள்விகள்',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.textMuted : AppColors.stitchOutline,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickPrompts.map((prompt) {
                  return ActionChip(
                    backgroundColor: AppColors.stitchSurfaceContainerLow,
                    side: const BorderSide(color: AppColors.stitchOutlineVariant, width: 0.8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    label: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.inkLight : AppColors.stitchOnSurface,
                      ),
                    ),
                    onPressed: () => _handleQuickPrompt(prompt),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// TAB 3: Tactical Marine Radar Canvas (Stitch Screen 4: Wave & Hazard Radar)
  Widget _buildRadarTab(bool isDark) {
    return Column(
      children: [
        StitchAppHeader(
          screenTitle: 'Hazard Radar',
          activePortName: _activeSector.name.split('(').last.replaceAll(')', '').trim(),
          latitude: _telemetry.latitude,
          longitude: _telemetry.longitude,
          currentLanguageCode: _currentLanguageCode,
          isGpsHardwareActive: _isLiveGpsActive,
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
          onAvatarTap: _showSimulationControls,
          onSyncTap: _fetchLiveBackendData,
        ),
        Expanded(
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
      ],
    );
  }

  /// TAB 4: Pre-Voyage High Seas Offline Sync Screen
  Widget _buildOfflineTab(bool isDark) {
    return PreVoyageScreen(
      currentSectorName: _activeSector.name,
      isCurrentVesselSector: (_telemetry.latitude - _activeSector.centerLat).abs() < 0.3 &&
          (_telemetry.longitude - _activeSector.centerLon).abs() < 0.3,
      onSectorChanged: (sector) {
        setState(() {
          _activeSector = sector;
          _telemetry = sector.createInitialTelemetry();
          _geofence = sector.createInitialGeofence();
          _baseSpeedKnots = sector.initialSpeedKnots;
          _isLiveCruising = true;
          _isLiveGpsActive = false;
        });
        _startCruiseTimer();
        _fetchLiveBackendData();
      },
      onDeployToSector: () {
        setState(() {
          _telemetry = _activeSector.createInitialTelemetry();
          _geofence = _activeSector.createInitialGeofence();
          _baseSpeedKnots = _activeSector.initialSpeedKnots;
          _isLiveCruising = true;
          _isLiveGpsActive = false;
        });
        _startCruiseTimer();
        _fetchLiveBackendData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0284C7),
            content: Text(
              '📍 Vessel deployed to ${_activeSector.name} (${_activeSector.centerLat}°N, ${_activeSector.centerLon}°E)',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        );
      },
      onBack: () => setState(() => _activeNavIndex = 0),
    );
  }

  /// Tactical Marine Bottom Navigation Bar (Stitch M3 Tactical 5 Tabs)
  Widget _buildBottomNavBar(bool isDark) {
    return StitchBottomNavBar(
      activeIndex: _activeNavIndex,
      onTabSelected: (index) {
        setState(() => _activeNavIndex = index);
      },
      hasAlert: _geofence.warningLevel == GeofenceWarningLevel.critical ||
          _geofence.warningLevel == GeofenceWarningLevel.warning,
    );
  }

  Widget _buildInlineAdvisoryCard(double waveHeight, double windSpeed, double imblDist) {
    final isDark = ThemeController.isDarkMode.value;
    final cardBg = isDark ? const Color(0xCC09293A) : Colors.white;
    final primaryTextColor = isDark ? AppColors.inkLight : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppColors.textMuted : const Color(0xFF475569);
    final closeIconColor = isDark ? AppColors.textMuted : const Color(0xFF64748B);

    if (_selectedTelemetryIndex == 0) {
      // Wave advisory
      final waveBorderColor = isDark ? AppColors.electricCyan.withOpacity(0.7) : const Color(0xFF0284C7);
      final waveAccentColor = isDark ? AppColors.electricCyan : const Color(0xFF0284C7);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: waveBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: waveAccentColor.withOpacity(isDark ? 0.12 : 0.08),
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
                Icon(Icons.waves_rounded, size: 17, color: waveAccentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SEA STATE · ${waveHeight < 1.5 ? "CALM & SAFE" : "MODERATE SWELL"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: waveAccentColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _selectedTelemetryIndex = null),
                  child: Icon(Icons.close_rounded, size: 17, color: closeIconColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              waveHeight < 1.5
                  ? 'Wave height is ${waveHeight.toStringAsFixed(1)} m. Safe for motorized fishing crafts. Favourable surface conditions along Tamil Nadu coast.'
                  : 'Swell height is ${waveHeight.toStringAsFixed(1)} m. Moderate waves detected. Exercise caution and maintain safe heading.',
              style: TextStyle(fontSize: 11, color: primaryTextColor, height: 1.35),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Swell: ${_weather?.swellWaveHeightM.toStringAsFixed(1) ?? "0.7"} m • SST: 28.4°C',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: secondaryTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _fetchLiveBackendData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: isDark ? AppColors.brandSurface : const Color(0xFFE2E8F0),
                        content: Text(
                          '🌊 Satellite ocean feed updated',
                          style: TextStyle(color: primaryTextColor),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: waveAccentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: waveAccentColor.withOpacity(0.4)),
                    ),
                    child: Text('Refresh Feed ↺', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: waveAccentColor)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (_selectedTelemetryIndex == 1) {
      // Wind advisory
      final windBorderColor = isDark ? AppColors.neonLime.withOpacity(0.7) : const Color(0xFF16A34A);
      final windAccentColor = isDark ? AppColors.neonLime : const Color(0xFF16A34A);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: windBorderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: windAccentColor.withOpacity(isDark ? 0.12 : 0.08),
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
                Icon(Icons.air_rounded, size: 17, color: windAccentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'WIND SPEED · ${windSpeed.toStringAsFixed(0)} KT (STEADY BREEZE)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: windAccentColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _selectedTelemetryIndex = null),
                  child: Icon(Icons.close_rounded, size: 17, color: closeIconColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              windSpeed < 20
                  ? 'Steady North-East wind at ${windSpeed.toStringAsFixed(0)} knots. Well below the 25 kt small-craft squall threshold. Favourable sailing drift.'
                  : 'Strong breeze (${windSpeed.toStringAsFixed(0)} kt). Approaching squall threshold (25 kt). Secure gear and monitor course.',
              style: TextStyle(fontSize: 11, color: primaryTextColor, height: 1.35),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Direction: ENE (65°) • Gusts: 15 kt',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: secondaryTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: windAccentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('● SAFE TO SAIL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: windAccentColor)),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Border clearance advisory
      final isCritical = imblDist < 2.0;
      final isCaution = imblDist < 5.0;
      final statusColor = isCritical
          ? AppColors.safetyRed
          : (isCaution ? AppColors.stitchTertiary : AppColors.stitchSecondary);
      final borderColor = isCritical
          ? AppColors.safetyRed
          : (isCaution ? AppColors.stitchTertiary : AppColors.stitchSecondary);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(isDark ? 0.15 : 0.08),
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
                Expanded(
                  child: Text(
                    'IMBL BORDER CLEARANCE · ${imblDist.toStringAsFixed(1)} KM',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: statusColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _selectedTelemetryIndex = null),
                  child: Icon(Icons.close_rounded, size: 17, color: closeIconColor),
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
              style: TextStyle(fontSize: 11, color: primaryTextColor, height: 1.35),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCaution ? 'Heading: ${_telemetry.headingDeg.toStringAsFixed(0)}° (Eastward)' : 'Buffer: 5.0 km active',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: secondaryTextColor),
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
    final isDark = ThemeController.isDarkMode.value;
    final cardBg = isSelected
        ? (isDark ? const Color(0xFF0F384E) : const Color(0xFFE0F2FE))
        : (isDark ? const Color(0xFF09293A) : const Color(0xFFF8FAFC));
    final cardBorder = isSelected
        ? iconColor
        : (isDark ? const Color(0xFF173F50) : const Color(0xFFCBD5E1));

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cardBorder,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: iconColor.withOpacity(isDark ? 0.25 : 0.15),
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
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: isDark ? AppColors.textMuted : const Color(0xFF475569),
                  ),
                ),
                const Spacer(),
                Icon(
                  isSelected ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  size: 13,
                  color: isSelected ? iconColor : (isDark ? AppColors.textMuted.withOpacity(0.5) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
            const SizedBox(height: 3),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? AppColors.inkLight : const Color(0xFF0F172A),
                ),
                children: [
                  TextSpan(text: value),
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
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
}
