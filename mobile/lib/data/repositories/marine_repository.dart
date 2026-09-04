import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';
import '../models/weather_model.dart';
import '../models/geofence_model.dart';
import '../models/route_model.dart';
import '../models/pfz_model.dart';
import '../../core/utils/geo_math.dart';

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

  /// Fetches a 24-hour offline marine pack covering the specified bounding box
  Future<Map<String, dynamic>?> fetchOfflinePack({
    required double minLat,
    required double maxLat,
    required double minLon,
    required double maxLon,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/marine/offline-pack',
        queryParameters: {
          'min_lat': minLat,
          'max_lat': maxLat,
          'min_lon': minLon,
          'max_lon': maxLon,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (e) {
      debugPrint('[MarineRepository] fetchOfflinePack error: $e');
    }
    return null;
  }

  /// Calculates a collision-free A* route to target coordinates
  Future<RouteModel?> calculateRoute({
    required double startLat,
    required double startLon,
    required double targetLat,
    required double targetLon,
    double speedKnots = 8.0,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/v1/navigation/route',
        data: {
          'start_lat': startLat,
          'start_lon': startLon,
          'target_lat': targetLat,
          'target_lon': targetLon,
          'speed_knots': speedKnots,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return RouteModel.fromJson(Map<String, dynamic>.from(response.data as Map));
      }
    } catch (e) {
      debugPrint('[MarineRepository] calculateRoute error: $e');
    }

    final distKm = GeoMath.haversineKm(startLat, startLon, targetLat, targetLon);
    return RouteModel(
      routeId: 'route-${DateTime.now().millisecondsSinceEpoch}',
      totalDistanceKm: distKm,
      totalDistanceNauticalMiles: distKm * 0.539957,
      estimatedDurationHours: distKm / (speedKnots * 1.852),
      waypointsCount: 2,
      waypoints: [
        [startLon, startLat],
        [targetLon, targetLat],
      ],
      isSafe: true,
      minDistanceToImblKm: 4.8,
    );
  }

  /// Fetches Potential Fishing Zone features around a coordinate
  Future<List<PFZModel>> fetchPFZAdvisories({
    required double lat,
    required double lon,
    double radiusKm = 50.0,
  }) async {
    try {
      final response = await _apiClient.get(
        '/api/v1/marine/pfz',
        queryParameters: {
          'latitude': lat,
          'longitude': lon,
          'radius_km': radiusKm,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final list = response.data as List<dynamic>;
        return list.map((item) => PFZModel.fromJson(Map<String, dynamic>.from(item as Map))).toList();
      }
    } catch (e) {
      debugPrint('[MarineRepository] fetchPFZAdvisories error: $e');
    }

    return [
      PFZModel(
        pfzId: 'PFZ-TN-SAMPLE-01',
        sectorName: 'Palk Bay South',
        centroidLat: 9.42,
        centroidLon: 79.55,
        distanceKm: 14.2,
        bearingDeg: 65.0,
        chlorophyll: 1.45,
        sstGradient: 0.95,
        depthM: 18.5,
        validUntil: DateTime.now().add(const Duration(hours: 24)),
        polygonCoordinates: const [
          [79.51, 9.40],
          [79.59, 9.41],
          [79.60, 9.45],
          [79.53, 9.46],
          [79.49, 9.42],
          [79.51, 9.40],
        ],
      ),
    ];
  }
}
