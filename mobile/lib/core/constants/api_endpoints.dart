import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiEndpoints {
  // In Android Emulator, 10.0.2.2 points directly to the host development PC.
  // For Web or Windows desktop, localhost:8000 is used.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
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
