import 'package:flutter_test/flutter_test.dart';
import 'package:orca_mobile/data/models/telemetry_model.dart';
import 'package:orca_mobile/data/models/geofence_model.dart';
import 'package:orca_mobile/data/models/chat_message_model.dart';
import 'package:orca_mobile/data/models/weather_model.dart';

void main() {
  group('Dev 6 Day 1 & Day 2 Models Test Suite', () {
    test('TelemetryModel serialization and deserialization', () {
      final now = DateTime.now();
      final model = TelemetryModel(
        latitude: 9.285,
        longitude: 79.312,
        speedKnots: 8.4,
        headingDeg: 82.0,
        timestamp: now,
      );

      final json = model.toJson();
      final fromJson = TelemetryModel.fromJson(json);

      expect(fromJson.latitude, 9.285);
      expect(fromJson.longitude, 79.312);
      expect(fromJson.speedKnots, 8.4);
      expect(fromJson.headingDeg, 82.0);
    });

    test('GeofenceModel critical warning level parsing', () {
      final json = {
        'distance_to_imbl_km': 1.45,
        'nearest_imbl_point': {'lat': 9.35, 'lon': 79.42},
        'lookahead_breach_projected': true,
        'time_to_breach_minutes': 4.5,
        'warning_level': 'CRITICAL',
        'evasive_heading_deg': 270.0,
      };

      final model = GeofenceModel.fromJson(json);

      expect(model.distanceToImblKm, 1.45);
      expect(model.warningLevel, GeofenceWarningLevel.critical);
      expect(model.lookaheadBreachProjected, true);
      expect(model.timeToBreachMinutes, 4.5);
      expect(model.evasiveHeadingDeg, 270.0);
    });

    test('ChatMessageModel dual-language and emergency serialization', () {
      final msg = ChatMessageModel(
        id: 'test-emergency-01',
        sender: MessageSender.orca,
        textLocalized: 'எச்சரிக்கை! நீங்கள் எல்லைக்கு அருகில் உள்ளீர்கள்.',
        textEnglish: 'Warning! You are near the boundary.',
        timestamp: DateTime.now(),
        isEmergency: true,
        quickReplies: ['Steer 270°', 'Nearest Harbor'],
      );

      final json = msg.toJson();
      final fromJson = ChatMessageModel.fromJson(json);

      expect(fromJson.id, 'test-emergency-01');
      expect(fromJson.sender, MessageSender.orca);
      expect(fromJson.textLocalized, 'எச்சரிக்கை! நீங்கள் எல்லைக்கு அருகில் உள்ளீர்கள்.');
      expect(fromJson.textEnglish, 'Warning! You are near the boundary.');
      expect(fromJson.isEmergency, true);
      expect(fromJson.quickReplies.length, 2);
    });

    test('WeatherModel serialization and compass bearing conversion', () {
      final json = {
        'latitude': 9.285,
        'longitude': 79.312,
        'wave_height_m': 1.4,
        'wave_direction_deg': 180.0,
        'wave_period_sec': 6.2,
        'wind_speed_knots': 22.5,
        'wind_direction_deg': 65.0,
        'swell_wave_height_m': 0.8,
        'sea_surface_temp_celsius': 29.2,
        'sea_state_code': 3,
        'is_safe_for_small_craft': true,
        'advisory_summary': 'Safe conditions for motorized craft.',
        'observed_at': '2026-09-02T12:00:00.000Z',
        'source': 'open-meteo',
      };

      final model = WeatherModel.fromJson(json);
      expect(model.waveHeightM, 1.4);
      expect(model.windSpeedKnots, 22.5);
      expect(model.windDirectionCompass, 'NE');
      expect(model.isSafeForSmallCraft, true);
    });
  });
}
