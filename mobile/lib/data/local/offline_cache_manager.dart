import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class OfflineCacheManager {
  final DatabaseHelper _dbHelper;

  OfflineCacheManager({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

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

  // ============================================================================
  // Weather Grid Cache Operations
  // ============================================================================

  Future<void> cacheWeatherSlice(List<Map<String, dynamic>> hourlySlice) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.delete('cached_weather_grid');

    for (final item in hourlySlice) {
      batch.insert('cached_weather_grid', {
        'latitude': item['lat'],
        'longitude': item['lon'],
        'wave_height_m': item['wave_height_m'],
        'wind_speed_knots': item['wind_speed_knots'],
        'forecast_hour': item['time'],
        'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  // ============================================================================
  // PFZ Advisories Cache Operations
  // ============================================================================

  Future<void> cachePfzAdvisories(List<Map<String, dynamic>> pfzs) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.delete('cached_pfz_advisories');

    for (final pfz in pfzs) {
      batch.insert('cached_pfz_advisories', {
        'pfz_id': pfz['pfz_id'],
        'sector_name': pfz['sector_name'],
        'centroid_lat': pfz['centroid']['lat'],
        'centroid_lon': pfz['centroid']['lon'],
        'chlorophyll': pfz['chlorophyll_mg_m3'],
        'geojson_polygon': pfz['geojson_geometry']?.toString() ?? '',
        'valid_until': pfz['valid_until'] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<bool> hasActiveOfflinePack() async {
    final db = await _dbHelper.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM cached_imbl_boundaries'),
    );
    return (count ?? 0) > 0;
  }
}
