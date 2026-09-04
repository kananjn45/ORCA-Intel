import 'package:flutter/foundation.dart';
import '../data/models/geofence_model.dart';
import '../data/repositories/marine_repository.dart';
import '../data/local/offline_cache_manager.dart';

class GeofenceAlertProvider extends ChangeNotifier {
  final MarineRepository _repository = MarineRepository();
  final OfflineCacheManager _cacheManager = OfflineCacheManager();

  GeofenceModel? _currentStatus;
  bool _isChecking = false;
  bool _isEmergencyAlarmActive = false;

  GeofenceModel? get currentStatus => _currentStatus;
  bool get isChecking => _isChecking;
  bool get isEmergencyAlarmActive => _isEmergencyAlarmActive;

  GeofenceWarningLevel get warningLevel =>
      _currentStatus?.warningLevel ?? GeofenceWarningLevel.safe;

  double get distanceToImblKm => _currentStatus?.distanceToImblKm ?? 8.5;
  double get evasiveHeadingDeg => _currentStatus?.evasiveHeadingDeg ?? 270.0;
  bool get isBreachImminent =>
      _currentStatus?.lookaheadBreachProjected ?? false;

  /// Evaluates vessel position against IMBL. Automatically fails over to local SQLite when offline.
  Future<void> updateVesselPosition({
    required double lat,
    required double lon,
    required double speedKnots,
    required double headingDeg,
    bool isOffline = false,
  }) async {
    _isChecking = true;
    notifyListeners();

    try {
      if (isOffline) {
        // Zero-internet local SQLite Haversine evaluation
        final localDist = await _cacheManager.calculateOfflineImblDistance(lat, lon);
        final breachProjected = (headingDeg >= 45.0 && headingDeg <= 135.0) &&
            (speedKnots * 1.852 * 0.25 >= (localDist - 1.0));

        GeofenceWarningLevel level;
        if (localDist < 2.0 || breachProjected) {
          level = GeofenceWarningLevel.critical;
        } else if (localDist < 5.0) {
          level = GeofenceWarningLevel.warning;
        } else if (localDist < 10.0) {
          level = GeofenceWarningLevel.advisory;
        } else {
          level = GeofenceWarningLevel.safe;
        }

        _currentStatus = GeofenceModel(
          distanceToImblKm: localDist,
          nearestImblPoint: {'lat': 9.35, 'lon': 79.42},
          lookaheadBreachProjected: breachProjected,
          timeToBreachMinutes: breachProjected ? 12.0 : null,
          warningLevel: level,
          evasiveHeadingDeg: (headingDeg + 180.0) % 360.0,
        );
      } else {
        // Live FastAPI endpoint evaluation
        _currentStatus = await _repository.checkGeofence(
          lat: lat,
          lon: lon,
          speedKnots: speedKnots,
          headingDeg: headingDeg,
        );
      }

      if (_currentStatus?.warningLevel == GeofenceWarningLevel.critical) {
        _isEmergencyAlarmActive = true;
      } else {
        _isEmergencyAlarmActive = false;
      }
    } catch (e) {
      debugPrint('[GeofenceAlertProvider] evaluation error: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Manually dismiss or acknowledge active emergency siren
  void acknowledgeEmergency() {
    _isEmergencyAlarmActive = false;
    notifyListeners();
  }

  /// Sets manual simulated critical breach state for Golden Scenario testing
  void setSimulatedCriticalState({
    required double distanceKm,
    required double evasiveHeading,
    double? timeToBreach,
  }) {
    _currentStatus = GeofenceModel(
      distanceToImblKm: distanceKm,
      nearestImblPoint: const {'lat': 9.35, 'lon': 79.45},
      lookaheadBreachProjected: true,
      timeToBreachMinutes: timeToBreach ?? 4.2,
      warningLevel: GeofenceWarningLevel.critical,
      evasiveHeadingDeg: evasiveHeading,
    );
    _isEmergencyAlarmActive = true;
    notifyListeners();
  }

  /// Resets to standard safe navigation state
  void resetToSafeState() {
    _currentStatus = const GeofenceModel(
      distanceToImblKm: 8.5,
      nearestImblPoint: {'lat': 9.35, 'lon': 79.42},
      lookaheadBreachProjected: false,
      warningLevel: GeofenceWarningLevel.safe,
      evasiveHeadingDeg: 270.0,
    );
    _isEmergencyAlarmActive = false;
    notifyListeners();
  }
}
