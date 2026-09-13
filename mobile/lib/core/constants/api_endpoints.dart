import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  /// Allows setting a custom backend URL at runtime (e.g., LAN IP http://192.168.0.107:8000)
  static String customBaseUrl = '';

  // Production Render Cloud Backend
  static const String defaultProductionUrl = 'https://orca-intel.onrender.com';

  static String get baseUrl {
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    const envUrl = String.fromEnvironment('BACKEND_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }
    return defaultProductionUrl;
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
