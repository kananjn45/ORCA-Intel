import 'package:flutter_test/flutter_test.dart';
import 'package:orca_mobile/core/utils/geo_math.dart';
import 'package:orca_mobile/data/models/route_model.dart';
import 'package:orca_mobile/data/models/pfz_model.dart';

void main() {
  group('Marine Geo Math Tests', () {
    test('Haversine distance between known coordinates', () {
      // Mandapam to Rameswaram (~18 km)
      final dist = GeoMath.haversineKm(9.2800, 79.1200, 9.2881, 79.3129);
      expect(dist, greaterThan(15.0));
      expect(dist, lessThan(25.0));
    });

    test('Identical points return zero distance', () {
      final dist = GeoMath.haversineKm(9.2854, 79.3121, 9.2854, 79.3121);
      expect(dist, closeTo(0.0, 0.001));
    });

    test('Palk Strait IMBL proximity calculation', () {
      // Craft at 9.345 N, 79.412 E vs nearest IMBL at 9.350 N, 79.420 E
      final dist = GeoMath.haversineKm(9.345, 79.412, 9.350, 79.420);
      expect(dist, lessThan(2.0)); // In critical breach zone
    });

    test('15-Minute Lookahead Vector Calculation', () {
      final lookahead = GeoMath.calculateLookahead(
        lat: 9.30,
        lon: 79.30,
        speedKnots: 10.0,
        headingDeg: 90.0,
        minutes: 15.0,
      );
      expect(lookahead['distance_km'], closeTo(4.63, 0.1));
      expect(lookahead['end_lon'], greaterThan(79.30));
    });
  });

  group('Dev 1 & Dev 3 Model Serialization Tests', () {
    test('RouteModel fromJson and toJson', () {
      final json = {
        'route_id': 'route-test-01',
        'total_distance_km': 14.8,
        'total_distance_nautical_miles': 8.0,
        'estimated_duration_hours': 1.0,
        'waypoints_count': 2,
        'is_safe': true,
        'min_distance_to_imbl_along_route_km': 4.8,
        'has_weather_penalties': false,
        'route_geojson': {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [79.31, 9.28],
              [79.55, 9.42],
            ],
          },
        },
      };

      final model = RouteModel.fromJson(json);
      expect(model.routeId, 'route-test-01');
      expect(model.totalDistanceKm, 14.8);
      expect(model.waypoints.length, 2);
      expect(model.isSafe, true);

      final outJson = model.toJson();
      expect(outJson['route_id'], 'route-test-01');
    });

    test('PFZModel fromJson and toJson', () {
      final json = {
        'pfz_id': 'PFZ-TN-20260904-001',
        'sector_name': 'Palk Bay South',
        'centroid': {'lat': 9.42, 'lon': 79.55},
        'distance_km': 14.2,
        'bearing_deg': 65.0,
        'chlorophyll_mg_m3': 1.45,
        'sst_gradient_celsius': 0.95,
        'depth_m': 18.5,
        'valid_until': '2026-09-07T12:00:00Z',
        'target_species': ['Oil Sardine', 'Indian Mackerel'],
        'geojson_geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [79.51, 9.40],
              [79.59, 9.41],
              [79.60, 9.45],
              [79.51, 9.40],
            ]
          ]
        },
        'source': 'INCOIS-MOSDAC',
      };

      final model = PFZModel.fromJson(json);
      expect(model.pfzId, 'PFZ-TN-20260904-001');
      expect(model.chlorophyll, 1.45);
      expect(model.centroidLat, 9.42);
      expect(model.polygonCoordinates.length, 4);

      final outJson = model.toJson();
      expect(outJson['sector_name'], 'Palk Bay South');
    });
  });
}
