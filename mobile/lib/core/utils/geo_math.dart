import 'dart:math' as math;

/// Marine Geodesic & Navigation Math Library for ORCA Mobile (Dev 1 & Dev 6)
class GeoMath {
  static const double earthRadiusKm = 6371.0;
  static const double knotToKmh = 1.852;

  /// Great-circle Haversine distance in kilometers between two WGS84 coordinates.
  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * math.pi / 180.0;
    final p2 = lat2 * math.pi / 180.0;
    final dphi = (lat2 - lat1) * math.pi / 180.0;
    final dlambda = (lon2 - lon1) * math.pi / 180.0;

    final a = math.sin(dphi / 2.0) * math.sin(dphi / 2.0) +
        math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2.0) * math.sin(dlambda / 2.0);
    return 2.0 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
  }

  /// Initial compass bearing in degrees (0° to 360°) from point 1 to point 2.
  static double initialBearingDeg(double lat1, double lon1, double lat2, double lon2) {
    final p1 = lat1 * math.pi / 180.0;
    final p2 = lat2 * math.pi / 180.0;
    final dlambda = (lon2 - lon1) * math.pi / 180.0;

    final y = math.sin(dlambda) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dlambda);
    return (math.atan2(y, x) * 180.0 / math.pi + 360.0) % 360.0;
  }

  /// Projects a destination point given starting (lat, lon), distance in km, and bearing in degrees.
  static List<double> destinationPoint(double lat, double lon, double distanceKm, double bearingDeg) {
    final distRatio = distanceKm / earthRadiusKm;
    final bRad = bearingDeg * math.pi / 180.0;
    final latRad = lat * math.pi / 180.0;
    final lonRad = lon * math.pi / 180.0;

    final targetLat = math.asin(
      math.sin(latRad) * math.cos(distRatio) +
          math.cos(latRad) * math.sin(distRatio) * math.cos(bRad),
    );

    final targetLon = lonRad +
        math.atan2(
          math.sin(bRad) * math.sin(distRatio) * math.cos(latRad),
          math.cos(distRatio) - math.sin(latRad) * math.sin(targetLat),
        );

    return [
      targetLat * 180.0 / math.pi,
      ((targetLon * 180.0 / math.pi) + 540.0) % 360.0 - 180.0,
    ];
  }

  /// Computes the vessel's 15-minute predictive lookahead trajectory vector.
  static Map<String, dynamic> calculateLookahead({
    required double lat,
    required double lon,
    required double speedKnots,
    required double headingDeg,
    double minutes = 15.0,
  }) {
    final speedKmh = speedKnots * knotToKmh;
    final distanceKm = speedKmh * (minutes / 60.0);
    final dest = destinationPoint(lat, lon, distanceKm, headingDeg);

    return {
      'start_lat': lat,
      'start_lon': lon,
      'end_lat': dest[0],
      'end_lon': dest[1],
      'distance_km': distanceKm,
      'heading_deg': headingDeg,
      'duration_minutes': minutes,
    };
  }
}
