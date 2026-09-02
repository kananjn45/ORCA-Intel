import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static const String _databaseName = 'orca_marine_offline.db';
  static const int _databaseVersion = 1;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Cached IMBL Boundary Points
    await db.execute('''
      CREATE TABLE cached_imbl_boundaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        boundary_name TEXT NOT NULL,
        country_pair TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sequence_order INTEGER NOT NULL
      )
    ''');

    // 2. Cached Hourly Marine Weather Grid
    await db.execute('''
      CREATE TABLE cached_weather_grid (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        wave_height_m REAL NOT NULL,
        wind_speed_knots REAL NOT NULL,
        forecast_hour TEXT NOT NULL,
        expires_at TEXT NOT NULL
      )
    ''');

    // 3. Cached PFZ Polygons & Coordinates
    await db.execute('''
      CREATE TABLE cached_pfz_advisories (
        pfz_id TEXT PRIMARY KEY,
        sector_name TEXT NOT NULL,
        centroid_lat REAL NOT NULL,
        centroid_lon REAL NOT NULL,
        chlorophyll REAL NOT NULL,
        geojson_polygon TEXT NOT NULL,
        valid_until TEXT NOT NULL
      )
    ''');

    // 4. Local Offline Chat & Voice Messages
    await db.execute('''
      CREATE TABLE local_chat_history (
        id TEXT PRIMARY KEY,
        sender TEXT NOT NULL,
        text_localized TEXT NOT NULL,
        text_english TEXT,
        audio_local_path TEXT,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete('cached_imbl_boundaries');
    await db.delete('cached_weather_grid');
    await db.delete('cached_pfz_advisories');
  }
}
