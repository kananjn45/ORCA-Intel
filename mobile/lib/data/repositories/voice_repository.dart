import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

/// Repository interacting with Dev 4 Bhashini Voice Pipeline endpoints.
class VoiceRepository {
  final ApiClient _apiClient;

  VoiceRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Transcribe recorded audio bytes into text via /api/v1/voice/transcribe.
  Future<String?> transcribeAudio({
    required Uint8List audioBytes,
    required String languageCode,
    String audioFormat = 'wav',
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': MultipartFile.fromBytes(
          audioBytes,
          filename: 'recording.$audioFormat',
        ),
        'language': languageCode,
        'audio_format': audioFormat,
      });

      final response = await _apiClient.post(
        '/api/v1/voice/transcribe',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        return data['text'] as String?;
      }
    } catch (e) {
      debugPrint('[VoiceRepository] transcribeAudio error: $e');
    }
    return null;
  }

  /// Synthesize speech from localized text via /api/v1/voice/synthesise.
  Future<String?> synthesizeSpeech({
    required String text,
    required String languageCode,
    String gender = 'female',
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/voice/synthesise',
        data: FormData.fromMap({
          'text': text,
          'language': languageCode,
          'gender': gender,
        }),
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        return data['audio_content'] as String?;
      }
    } catch (e) {
      debugPrint('[VoiceRepository] synthesizeSpeech error: $e');
    }
    return null;
  }

  /// Fetch supported languages from /api/v1/voice/languages.
  Future<Map<String, String>> getSupportedLanguages() async {
    try {
      final response = await _apiClient.get('/api/v1/voice/languages');
      if (response.statusCode == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final langs = Map<String, dynamic>.from(data['languages'] as Map? ?? {});
        return langs.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (e) {
      debugPrint('[VoiceRepository] getSupportedLanguages error: $e');
    }
    return {
      'hi': 'Hindi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'bn': 'Bengali',
      'gu': 'Gujarati',
      'kn': 'Kannada',
      'ml': 'Malayalam',
      'mr': 'Marathi',
      'or': 'Odia',
      'pa': 'Punjabi',
      'en': 'English',
    };
  }
}
