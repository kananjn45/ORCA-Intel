import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/geofence_model.dart';
import '../../data/models/chat_message_model.dart';
import 'widgets/telemetry_hud_bar.dart';
import 'widgets/sea_state_gauge.dart';
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
  // Live Telemetry Fix (Palk Strait)
  final TelemetryModel _telemetry = TelemetryModel(
    latitude: 9.2854,
    longitude: 79.3121,
    speedKnots: 8.4,
    headingDeg: 82.0,
    timestamp: DateTime.now(),
  );

  final GeofenceModel _geofence = const GeofenceModel(
    distanceToImblKm: 4.82,
    nearestImblPoint: {'lat': 9.35, 'lon': 79.42},
    lookaheadBreachProjected: false,
    warningLevel: GeofenceWarningLevel.advisory,
    evasiveHeadingDeg: 265.0,
  );

  bool _isRecording = false;
  String _currentLanguageCode = 'en';
  String _currentLanguageName = 'English';

  late List<ChatMessageModel> _messages;

  @override
  void initState() {
    super.initState();
    _rebuildMessagesForLanguage(_currentLanguageCode);
  }

  void _rebuildMessagesForLanguage(String langCode) {
    final loc = AppLocalizations.of(langCode);
    _messages = [
      ChatMessageModel(
        id: 'msg-01',
        sender: MessageSender.user,
        textLocalized: loc['sampleQuestion'] as String,
        textEnglish: loc['sampleQuestionEn'] as String,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
      ChatMessageModel(
        id: 'msg-02',
        sender: MessageSender.orca,
        textLocalized: loc['sampleAnswer'] as String,
        textEnglish: loc['sampleAnswerEn'] as String,
        timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        quickReplies: ['Nearest Harbor', 'Hourly Swell', 'Border Distance'],
      ),
    ];
  }

  void _handleLanguageChanged(String code, String name) {
    setState(() {
      _currentLanguageCode = code;
      _currentLanguageName = name.split(' ')[0];
      _rebuildMessagesForLanguage(code);
    });
  }

  void _handleVoiceRecordingStart() {
    setState(() => _isRecording = true);
  }

  void _handleVoiceRecordingEnd() {
    setState(() => _isRecording = false);
    final loc = AppLocalizations.of(_currentLanguageCode);
    final newMsg = ChatMessageModel(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.orca,
      textLocalized: loc['borderStatus'] as String,
      textEnglish: loc['borderStatusEn'] as String,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(newMsg);
    });
  }

  void _handleQuickPrompt(String prompt) {
    final loc = AppLocalizations.of(_currentLanguageCode);
    final userMsg = ChatMessageModel(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.user,
      textLocalized: prompt,
      timestamp: DateTime.now(),
    );

    ChatMessageModel replyMsg;
    if (prompt.contains('Border') || prompt.contains('எல்லை') || prompt.contains('సరిహద్దు') || prompt.contains('सीमा') || prompt.contains('সীমানা') || prompt.contains('સરહદ')) {
      replyMsg = ChatMessageModel(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.orca,
        textLocalized: loc['borderStatus'] as String,
        textEnglish: loc['borderStatusEn'] as String,
        timestamp: DateTime.now(),
      );
    } else {
      replyMsg = ChatMessageModel(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        sender: MessageSender.orca,
        textLocalized: loc['weatherStatus'] as String,
        textEnglish: loc['weatherStatusEn'] as String,
        timestamp: DateTime.now(),
      );
    }

    setState(() {
      _messages.add(userMsg);
      _messages.add(replyMsg);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyssBlack,
      body: Stack(
        children: [
          // 1. TACTICAL RADAR CANVAS (Animated Sweep, Range Rings, IMBL Border & PFZ)
          Positioned.fill(
            child: TacticalRadarCanvas(
              vesselHeadingDeg: _telemetry.headingDeg,
              speedKnots: _telemetry.speedKnots,
              imblDistanceKm: _geofence.distanceToImblKm,
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

          // 3. FLOATING GLASSMORHPIC WEATHER INSTRUMENT
          Positioned(
            left: 14,
            top: 104,
            child: const SafeArea(
              bottom: false,
              child: SeaStateGauge(
                waveHeightM: 1.3,
                swellHeightM: 1.1,
                windSpeedKnots: 12.5,
                isSafe: true,
              ),
            ),
          ),

          // 4. COLLAPSIBLE CONVERSATIONAL VOICE DRAWER WITH GESTURE SWIPE
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ConversationalSheet(
              messages: _messages,
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
