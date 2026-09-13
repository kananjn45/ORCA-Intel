import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  /// Allows setting a custom backend URL at runtime (e.g., LAN IP http://192.168.0.107:8000)
  static String customBaseUrl = '';

  // In Android Emulator, 10.0.2.2 points to host.
  // On physical Android devices connected via USB or adb reverse, 127.0.0.1:8000 forwards to host.
  // For Web or Windows desktop, localhost:8000 is used.
  static String get baseUrl {
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      return 'http://127.0.0.1:8000';
    }
    return 'http://localhost:8000';
  }

  // REST API Endpoints
  static String get chatMessage => '$baseUrl/api/v1/chat/message';
  static String get calculateRoute => '$baseUrl/api/v1/navigation/route';
  static String get weather => '$baseUrl/api/v1/marine/weather';
  static String get pfz => '$baseUrl/api/v1/marine/pfz';
  static String get geofenceCheck => '$baseUrl/api/v1/geofence/check';
  static String get offlinePack => '$baseUrl/api/v1/marine/offline-pack';
  static String get voiceTranscribe => '$baseUrl/api/v1/voice/transcribe';
  static String get voiceSynthesize => '$baseUrl/api/v1/voice/synthesize';
}
