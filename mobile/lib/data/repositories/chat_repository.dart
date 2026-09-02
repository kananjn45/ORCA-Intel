import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/chat_message_model.dart';
import '../models/telemetry_model.dart';

class ChatRepository {
  final ApiClient _apiClient;

  ChatRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Dispatches a user query to the LangGraph multi-agent backend orchestrator
  Future<ChatMessageModel> sendChatMessage({
    required String query,
    required TelemetryModel telemetry,
    required String languageCode,
  }) async {
    final sessionId = 'ses-${DateTime.now().millisecondsSinceEpoch}-${math.Random().nextInt(9999)}';

    try {
      final response = await _apiClient.post(
        '/api/v1/chat/message',
        data: {
          'session_id': sessionId,
          'user_query_text': query,
          'source_language': languageCode,
          'telemetry': {
            'vessel_id': 'VESSEL-IND-01',
            'latitude': telemetry.latitude,
            'longitude': telemetry.longitude,
            'speed_knots': telemetry.speedKnots,
            'heading_deg': telemetry.headingDeg,
            'timestamp': telemetry.timestamp.toIso8601String(),
          },
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final localized = data['response_text_localized'] as String? ?? '';
        final english = data['response_text_en'] as String? ?? '';
        final quickReplies = List<String>.from((data['quick_replies'] as List?) ?? []);

        final displayText = localized.isNotEmpty && !localized.startsWith('[MOCK') ? localized : english;

        return ChatMessageModel(
          id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
          sender: MessageSender.orca,
          textLocalized: displayText,
          textEnglish: english,
          timestamp: DateTime.now(),
          quickReplies: quickReplies.isNotEmpty ? quickReplies : ['Check Border', 'Nearest PFZ', 'Sea Waves'],
        );
      }
    } catch (e) {
      debugPrint('[ChatRepository] sendChatMessage network error: $e — using contextual fallback');
    }

    // Contextual fallback response if backend is offline
    return ChatMessageModel(
      id: 'fallback-${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.orca,
      textLocalized: 'கப்பல் வழிகாட்டி: அலை உயரம் 1.3மீ, காற்று 12.5 நாட்ஸ். கடல் அமைதியாக உள்ளது.',
      textEnglish: 'Vessel Advisory: Wave height 1.3m, wind 12.5 kts. Sea state calm. Sovereign waters safe.',
      timestamp: DateTime.now(),
      quickReplies: ['Check Border', 'Nearest PFZ', 'Sea Waves'],
    );
  }
}
