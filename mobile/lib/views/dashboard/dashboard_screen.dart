import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/geofence_model.dart';
import '../../data/models/chat_message_model.dart';
import 'widgets/telemetry_hud_bar.dart';
import 'widgets/sea_state_gauge.dart';
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
  String _currentLanguageCode = 'en'; // Default to clean neutral English, switchable to any regional language
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
          // 1. TACTICAL MARINE NAVIGATION CANVAS (Clean Full-Bleed Map Background)
          Positioned.fill(
            child: Container(
              color: AppColors.abyssBlack,
              child: Stack(
                children: [
                  // Subtle Nautical Range Rings & Radar Grid
                  Center(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.radarCyan.withOpacity(0.12), width: 1),
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.radarCyan.withOpacity(0.18), width: 1),
                      ),
                    ),
                  ),
                  // Own-Vessel Indicator with Course Heading Vector
                  Center(
                    child: Transform.rotate(
                      angle: (82.0 * 3.1415926535 / 180.0), // 82 deg heading
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 2,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [AppColors.radarCyan, AppColors.radarCyan.withOpacity(0.0)],
                              ),
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.deepOcean,
                              border: Border.all(color: AppColors.radarCyan, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.radarCyan.withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.navigation, size: 22, color: AppColors.radarCyan),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.36,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'PALK STRAIT • RAMESWARAM SECTOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary.withOpacity(0.6),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. TOP PERSISTENT TELEMETRY HUD BAR (Clean 2-Row Layout with Integrated Actions)
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

          // 3. FLOATING WEATHER INSTRUMENT PILL (Docked Cleanly in Top Left under HUD)
          Positioned(
            left: 14,
            top: 106,
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

          // 4. COLLAPSIBLE CONVERSATIONAL VOICE DRAWER WITH GESTURE SWIPE DISMISS
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
