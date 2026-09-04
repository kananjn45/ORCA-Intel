import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class OfflineCacheManager {
  final DatabaseHelper _dbHelper;

  OfflineCacheManager({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // ============================================================================
  // Full Offline Pack Ingestion
  // ============================================================================

  Future<void> ingestFullOfflinePack(Map<String, dynamic> packData) async {
    final db = await _dbHelper.database;
    final batch = db.batch();

    // 1. Ingest IMBL boundary points if present in GeoJSON or fallback points
    final boundaryGeoJson = packData['imbl_boundary_geojson'] as Map<String, dynamic>?;
    final features = (boundaryGeoJson?['features'] as List?) ?? [];

    List<Map<String, dynamic>> pointsToCache = [];
    if (features.isNotEmpty) {
      for (final f in features) {
        final geom = f['geometry'] as Map<String, dynamic>?;
        final coords = geom?['coordinates'];
        if (coords is List) {
          for (int i = 0; i < coords.length; i++) {
            final pt = coords[i];
            if (pt is List && pt.length >= 2) {
              pointsToCache.add({
                'name': f['properties']?['name'] ?? 'IMBL Point $i',
                'countries': 'IND-LKA',
                'lat': (pt[1] as num).toDouble(),
                'lon': (pt[0] as num).toDouble(),
              });
            }
          }
        }
      }
    }

    // Default Palk Strait IMBL coords if empty
    if (pointsToCache.isEmpty) {
      pointsToCache = [
        {'name': 'Palk Strait Pt 1', 'countries': 'IND-LKA', 'lat': 10.0833, 'lon': 79.0733},
        {'name': 'Palk Strait Pt 2', 'countries': 'IND-LKA', 'lat': 9.7167, 'lon': 79.3767},
        {'name': 'Palk Strait Pt 3', 'countries': 'IND-LKA', 'lat': 9.4833, 'lon': 79.5333},
        {'name': 'Palk Strait Pt 4', 'countries': 'IND-LKA', 'lat': 9.1000, 'lon': 79.5300},
        {'name': 'Palk Strait Pt 5', 'countries': 'IND-LKA', 'lat': 8.8667, 'lon': 79.4867},
      ];
    }

    batch.delete('cached_imbl_boundaries');
    for (int i = 0; i < pointsToCache.length; i++) {
      batch.insert('cached_imbl_boundaries', {
        'boundary_name': pointsToCache[i]['name'],
        'country_pair': pointsToCache[i]['countries'],
        'latitude': pointsToCache[i]['lat'],
        'longitude': pointsToCache[i]['lon'],
        'sequence_order': i,
      });
    }

    // 2. Ingest Weather Grid
    final weatherList = (packData['weather_grid'] as List?) ?? [];
    batch.delete('cached_weather_grid');
    final expiresAt = (packData['expires_at'] as String?) ??
        DateTime.now().add(const Duration(hours: 24)).toIso8601String();

    for (final w in weatherList) {
      if (w is Map) {
        batch.insert('cached_weather_grid', {
          'latitude': (w['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (w['longitude'] as num?)?.toDouble() ?? 0.0,
          'wave_height_m': (w['wave_height_m'] as num?)?.toDouble() ?? 1.2,
          'wind_speed_knots': (w['wind_speed_knots'] as num?)?.toDouble() ?? 12.0,
          'forecast_hour': w['observed_at']?.toString() ?? DateTime.now().toIso8601String(),
          'expires_at': expiresAt,
        });
      }
    }

    // 3. Ingest PFZ Advisories
    final pfzList = (packData['pfz_advisories'] as List?) ?? [];
    batch.delete('cached_pfz_advisories');
    for (final pfz in pfzList) {
      if (pfz is Map) {
        final centroid = pfz['centroid'] as Map? ?? {};
        batch.insert('cached_pfz_advisories', {
          'pfz_id': pfz['pfz_id']?.toString() ?? 'PFZ-${DateTime.now().millisecondsSinceEpoch}',
          'sector_name': pfz['sector_name']?.toString() ?? 'Palk Strait',
          'centroid_lat': (centroid['lat'] as num?)?.toDouble() ?? 9.35,
          'centroid_lon': (centroid['lon'] as num?)?.toDouble() ?? 79.45,
          'chlorophyll': (pfz['chlorophyll_mg_m3'] as num?)?.toDouble() ?? 1.2,
          'geojson_polygon': jsonEncode(pfz['geojson_geometry'] ?? {}),
          'valid_until': pfz['valid_until']?.toString() ?? expiresAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    await batch.commit(noResult: true);
  }

  // ============================================================================
  // IMBL Boundary Cache Operations
  // ============================================================================

  Future<void> cacheImblPoints(List<Map<String, dynamic>> points) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.delete('cached_imbl_boundaries');

    for (int i = 0; i < points.length; i++) {
      batch.insert('cached_imbl_boundaries', {
        'boundary_name': points[i]['name'] ?? 'India-Sri Lanka IMBL',
        'country_pair': points[i]['countries'] ?? 'IND-LKA',
        'latitude': points[i]['lat'],
        'longitude': points[i]['lon'],
        'sequence_order': i,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, double>>> getCachedImblPoints() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> results = await db.query(
      'cached_imbl_boundaries',
      orderBy: 'sequence_order ASC',
    );

    return results.map((row) {
      return {
        'lat': row['latitude'] as double,
        'lon': row['longitude'] as double,
      };
    }).toList();
  }

  /// Computes distance to nearest boundary point entirely offline using local SQLite records
  Future<double?> calculateOfflineImblDistance(double lat, double lon) async {
    final points = await getCachedImblPoints();
    if (points.isEmpty) return null;

    double minDistance = double.infinity;
    for (final pt in points) {
      final d = _haversineKm(lat, lon, pt['lat']!, pt['lon']!);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  // ============================================================================
  // Weather Grid Cache Operations
  // ============================================================================

  Future<Map<String, dynamic>?> getNearestCachedWeather(double lat, double lon) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> rows = await db.query('cached_weather_grid');
    if (rows.isEmpty) return null;

    Map<String, dynamic>? closest;
    double minD = double.infinity;

    for (final r in rows) {
      final rLat = r['latitude'] as double;
      final rLon = r['longitude'] as double;
      final d = _haversineKm(lat, lon, rLat, rLon);
      if (d < minD) {
        minD = d;
        closest = r;
      }
    }
    return closest;
  }

  // ============================================================================
  // PFZ Advisories Cache Operations
  // ============================================================================

  Future<List<Map<String, dynamic>>> getCachedPfzAdvisories() async {
    final db = await _dbHelper.database;
    return await db.query('cached_pfz_advisories');
  }

  Future<bool> hasActiveOfflinePack() async {
    final db = await _dbHelper.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM cached_imbl_boundaries'),
    );
    return (count ?? 0) > 0;
  }

  Future<int> getCachedWeatherCount() async {
    final db = await _dbHelper.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM cached_weather_grid'),
    );
    return count ?? 0;
  }

  // Haversine formula helper
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final p1 = lat1 * pi / 180.0;
    final p2 = lat2 * pi / 180.0;
    final dphi = (lat2 - lat1) * pi / 180.0;
    final dlambda = (lon2 - lon1) * pi / 180.0;

    final a = sin(dphi / 2) * sin(dphi / 2) +
        cos(p1) * cos(p2) * sin(dlambda / 2) * sin(dlambda / 2);
    return 2 * r * asin(min(1.0, sqrt(a)));
  }
}
