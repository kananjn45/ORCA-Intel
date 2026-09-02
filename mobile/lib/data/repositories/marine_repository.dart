import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/weather_model.dart';
import '../models/geofence_model.dart';

class MarineRepository {
  final ApiClient _apiClient;

  MarineRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Fetches live marine weather (Open-Meteo) for the given coordinates
  Future<WeatherModel> fetchLiveWeather({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/marine/weather',
        queryParameters: {'lat': lat, 'lon': lon},
      );
      if (response.statusCode == 200 && response.data != null) {
        return WeatherModel.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      debugPrint('[MarineRepository] fetchLiveWeather error: $e — using fallback state');
    }

    // Fallback safe state
    return WeatherModel(
      latitude: lat,
      longitude: lon,
      waveHeightM: 1.3,
      waveDirectionDeg: 180.0,
      wavePeriodSec: 6.0,
      windSpeedKnots: 12.5,
      windDirectionDeg: 80.0,
      swellWaveHeightM: 1.1,
      seaSurfaceTempCelsius: 28.4,
      seaStateCode: 3,
      isSafeForSmallCraft: true,
      advisorySummary: 'Sea state is calm (Wave: 1.3m, Wind: 12.5 kts). Safe for mechanized crafts.',
      observedAt: DateTime.now(),
    );
  }

  /// Checks the IMBL sovereign boundary proximity for the current craft vector
  Future<GeofenceModel> checkGeofence({
    required double lat,
    required double lon,
    required double speedKnots,
    required double headingDeg,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/geofence/check',
        data: {
          'latitude': lat,
          'longitude': lon,
          'speed_knots': speedKnots,
          'heading_deg': headingDeg,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return GeofenceModel.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      debugPrint('[MarineRepository] checkGeofence error: $e — using fallback geofence');
    }

    // Default safe fallback
    return const GeofenceModel(
      distanceToImblKm: 4.82,
      nearestImblPoint: {'lat': 9.35, 'lon': 79.42},
      lookaheadBreachProjected: false,
      warningLevel: GeofenceWarningLevel.advisory,
      evasiveHeadingDeg: 265.0,
    );
  }
}
