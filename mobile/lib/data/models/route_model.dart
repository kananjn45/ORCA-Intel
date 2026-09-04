class RouteModel {
  final String routeId;
  final double totalDistanceKm;
  final double totalDistanceNauticalMiles;
  final double estimatedDurationHours;
  final int waypointsCount;
  final List<List<double>> waypoints; // [[lon, lat], ...]
  final bool isSafe;
  final double minDistanceToImblKm;
  final bool hasWeatherPenalties;

  const RouteModel({
    required this.routeId,
    required this.totalDistanceKm,
    required this.totalDistanceNauticalMiles,
    required this.estimatedDurationHours,
    required this.waypointsCount,
    required this.waypoints,
    this.isSafe = true,
    this.minDistanceToImblKm = 5.0,
    this.hasWeatherPenalties = false,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    List<List<double>> parsedWaypoints = [];
    final geojson = json['route_geojson'] as Map<String, dynamic>?;
    if (geojson != null && geojson['geometry'] != null) {
      final coords = geojson['geometry']['coordinates'] as List<dynamic>?;
      if (coords != null) {
        parsedWaypoints = coords.map((c) {
          final list = c as List<dynamic>;
          return [
            (list[0] as num).toDouble(),
            (list[1] as num).toDouble(),
          ];
        }).toList();
      }
    }

    final distKm = (json['total_distance_km'] as num?)?.toDouble() ?? 0.0;
    final distNm = (json['total_distance_nautical_miles'] as num?)?.toDouble() ?? (distKm * 0.539957);

    return RouteModel(
      routeId: json['route_id']?.toString() ?? 'route-default',
      totalDistanceKm: distKm,
      totalDistanceNauticalMiles: distNm,
      estimatedDurationHours: (json['estimated_duration_hours'] as num?)?.toDouble() ?? 0.0,
      waypointsCount: (json['waypoints_count'] as num?)?.toInt() ?? parsedWaypoints.length,
      waypoints: parsedWaypoints,
      isSafe: json['is_safe'] as bool? ?? true,
      minDistanceToImblKm: (json['min_distance_to_imbl_along_route_km'] as num?)?.toDouble() ?? 5.0,
      hasWeatherPenalties: json['has_weather_penalties'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'total_distance_km': totalDistanceKm,
      'total_distance_nautical_miles': totalDistanceNauticalMiles,
      'estimated_duration_hours': estimatedDurationHours,
      'waypoints_count': waypointsCount,
      'is_safe': isSafe,
      'min_distance_to_imbl_along_route_km': minDistanceToImblKm,
      'has_weather_penalties': hasWeatherPenalties,
      'route_geojson': {
        'type': 'Feature',
        'geometry': {
          'type': 'LineString',
          'coordinates': waypoints,
        }
      }
    };
  }
}
