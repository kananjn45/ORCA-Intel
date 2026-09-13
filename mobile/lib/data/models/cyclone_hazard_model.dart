import 'package:latlong2/latlong.dart';

/// Live meteorological cyclone & storm cell hazard model powered by Open-Meteo.
class CycloneHazardModel {
  final bool detected;
  final String hazardCategory;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusKm;
  final double surfacePressureHpa;
  final double maxWindSpeedKnots;
  final double maxWindGustsKnots;
  final double maxWaveHeightM;
  final double distanceToVesselKm;
  final double bearingToCenterDeg;
  final String advisory;
  final String source;
  final DateTime observedAt;

  const CycloneHazardModel({
    required this.detected,
    required this.hazardCategory,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
    required this.surfacePressureHpa,
    required this.maxWindSpeedKnots,
    required this.maxWindGustsKnots,
    required this.maxWaveHeightM,
    required this.distanceToVesselKm,
    required this.bearingToCenterDeg,
    required this.advisory,
    required this.source,
    required this.observedAt,
  });

  LatLng get centerLatLng => LatLng(centerLatitude, centerLongitude);
  double get radiusMeters => radiusKm * 1000.0;

  bool get isSevere =>
      detected ||
      maxWindSpeedKnots >= 28.0 ||
      maxWaveHeightM >= 2.5 ||
      surfacePressureHpa < 1003.0;

  String get title {
    final upper = hazardCategory.toUpperCase();
    if (upper.contains('CYCLON')) {
      return 'CYCLONE ALERT';
    } else if (upper.contains('DEPRESSION')) {
      return 'DEEP DEPRESSION';
    } else if (isSevere) {
      return 'STORM HAZARD';
    }
    return 'WEATHER WATCH';
  }

  String get subtitle {
    return '${surfacePressureHpa.toStringAsFixed(0)} hPa • ${maxWindSpeedKnots.toStringAsFixed(1)} kts • ${maxWaveHeightM.toStringAsFixed(1)}m swell';
  }

  factory CycloneHazardModel.fromJson(Map<String, dynamic> json) {
    return CycloneHazardModel(
      detected: json['detected'] as bool? ?? false,
      hazardCategory: json['hazard_category'] as String? ?? 'FAVOURABLE SEA STATE',
      centerLatitude: (json['center_latitude'] as num?)?.toDouble() ?? 12.80,
      centerLongitude: (json['center_longitude'] as num?)?.toDouble() ?? 80.36,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 15.0,
      surfacePressureHpa: (json['surface_pressure_hpa'] as num?)?.toDouble() ?? 1012.0,
      maxWindSpeedKnots: (json['max_wind_speed_knots'] as num?)?.toDouble() ?? 12.0,
      maxWindGustsKnots: (json['max_wind_gusts_knots'] as num?)?.toDouble() ?? 16.0,
      maxWaveHeightM: (json['max_wave_height_m'] as num?)?.toDouble() ?? 1.1,
      distanceToVesselKm: (json['distance_to_vessel_km'] as num?)?.toDouble() ?? 0.0,
      bearingToCenterDeg: (json['bearing_to_center_deg'] as num?)?.toDouble() ?? 0.0,
      advisory: json['advisory'] as String? ?? 'Normal sea conditions.',
      source: json['source'] as String? ?? 'open-meteo-live',
      observedAt: json['observed_at'] != null
          ? DateTime.parse(json['observed_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'detected': detected,
      'hazard_category': hazardCategory,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'radius_km': radiusKm,
      'surface_pressure_hpa': surfacePressureHpa,
      'max_wind_speed_knots': maxWindSpeedKnots,
      'max_wind_gusts_knots': maxWindGustsKnots,
      'max_wave_height_m': maxWaveHeightM,
      'distance_to_vessel_km': distanceToVesselKm,
      'bearing_to_center_deg': bearingToCenterDeg,
      'advisory': advisory,
      'source': source,
      'observed_at': observedAt.toIso8601String(),
    };
  }
}
