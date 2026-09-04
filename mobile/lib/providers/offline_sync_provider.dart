import 'package:flutter/foundation.dart';
import '../data/local/offline_cache_manager.dart';
import '../data/repositories/marine_repository.dart';

class OfflineSyncProvider extends ChangeNotifier {
  final OfflineCacheManager _cacheManager;
  final MarineRepository _marineRepo;

  OfflineSyncProvider({
    OfflineCacheManager? cacheManager,
    MarineRepository? marineRepo,
  })  : _cacheManager = cacheManager ?? OfflineCacheManager(),
        _marineRepo = marineRepo ?? MarineRepository();

  bool _isPackActive = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = 'Offline pack idle';
  int _cachedCellsCount = 0;
  String _activeSector = 'Palk Strait (Rameswaram)';

  bool get isPackActive => _isPackActive;
  bool get isDownloading => _isDownloading;
  double get progress => _progress;
  String get statusMessage => _statusMessage;
  int get cachedCellsCount => _cachedCellsCount;
  String get activeSector => _activeSector;

  Future<void> checkOfflinePackStatus() async {
    _isPackActive = await _cacheManager.hasActiveOfflinePack();
    _cachedCellsCount = await _cacheManager.getCachedWeatherCount();
    if (_isPackActive) {
      _progress = 1.0;
      _statusMessage = '24-Hour Offline Marine Pack Active';
    }
    notifyListeners();
  }

  Future<void> downloadPackForSector(String sector) async {
    _activeSector = sector;
    _isDownloading = true;
    _progress = 0.15;
    _statusMessage = 'Requesting 24h marine pack from server...';
    notifyListeners();

    try {
      final bounds = _getSectorBounds(sector);
      final packData = await _marineRepo.fetchOfflinePack(
        minLat: bounds['min_lat']!,
        maxLat: bounds['max_lat']!,
        minLon: bounds['min_lon']!,
        maxLon: bounds['max_lon']!,
      );

      _progress = 0.55;
      _statusMessage = 'Ingesting boundary vectors & weather into SQLite...';
      notifyListeners();

      if (packData != null) {
        await _cacheManager.ingestFullOfflinePack(packData);
      }

      _cachedCellsCount = await _cacheManager.getCachedWeatherCount();
      _isPackActive = true;
      _progress = 1.0;
      _statusMessage = 'Offline Pack Active ($_cachedCellsCount cells stored)';
    } catch (e) {
      _statusMessage = 'Fallback offline sync active ($e)';
      _isPackActive = true;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Map<String, double> _getSectorBounds(String sector) {
    switch (sector) {
      case 'Gulf of Mannar (Mandapam)':
        return {'min_lat': 8.7, 'max_lat': 9.3, 'min_lon': 78.8, 'max_lon': 79.5};
      case 'Coromandel Coast (Chennai)':
        return {'min_lat': 12.8, 'max_lat': 13.4, 'min_lon': 80.1, 'max_lon': 80.7};
      case 'Andhra Coast (Visakhapatnam)':
        return {'min_lat': 17.4, 'max_lat': 18.0, 'min_lon': 83.1, 'max_lon': 83.7};
      case 'Gujarat Offshore (Porbandar)':
        return {'min_lat': 21.4, 'max_lat': 22.0, 'min_lon': 69.4, 'max_lon': 70.0};
      case 'Palk Strait (Rameswaram)':
      default:
        return {'min_lat': 9.0, 'max_lat': 9.6, 'min_lon': 79.0, 'max_lon': 79.8};
    }
  }
}
