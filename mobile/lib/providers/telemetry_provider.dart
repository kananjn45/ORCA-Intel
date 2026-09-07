import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/telemetry_model.dart';

class TelemetryProvider extends ChangeNotifier {
  TelemetryModel _telemetry = TelemetryModel(
    latitude: 9.2854,
    longitude: 79.3121,
    speedKnots: 8.4,
    headingDeg: 82.0,
    timestamp: DateTime.now(),
  );

  bool _isLiveGpsActive = false;
  String? _lastGpsError;
  StreamSubscription<Position>? _positionSubscription;

  TelemetryModel get telemetry => _telemetry;
  bool get isLiveGpsActive => _isLiveGpsActive;
  String? get lastGpsError => _lastGpsError;

  void updateTelemetry({
    required double latitude,
    required double longitude,
    required double speedKnots,
    required double headingDeg,
  }) {
    _telemetry = TelemetryModel(
      latitude: latitude,
      longitude: longitude,
      speedKnots: speedKnots,
      headingDeg: headingDeg,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void updateSpeedAndHeading({
    required double speedKnots,
    required double headingDeg,
  }) {
    _telemetry = TelemetryModel(
      latitude: _telemetry.latitude,
      longitude: _telemetry.longitude,
      speedKnots: speedKnots,
      headingDeg: headingDeg,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  void setScenario({
    required double latitude,
    required double longitude,
    required double headingDeg,
    required double speedKnots,
  }) {
    stopLiveGpsTracking();
    _telemetry = TelemetryModel(
      latitude: latitude,
      longitude: longitude,
      speedKnots: speedKnots,
      headingDeg: headingDeg,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }

  /// Initiates live GPS listening via device hardware GNSS sensor
  Future<bool> startLiveGpsTracking() async {
    try {
      _lastGpsError = null;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastGpsError = 'Location services are disabled on device';
        notifyListeners();
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _lastGpsError = 'Location permission denied by user';
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _lastGpsError = 'Location permissions are permanently denied';
        notifyListeners();
        return false;
      }

      await _positionSubscription?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          // Convert m/s to knots: 1 m/s = 1.94384 knots
          final speedKnots = position.speed >= 0
              ? position.speed * 1.94384
              : _telemetry.speedKnots;
          final heading = position.heading >= 0
              ? position.heading
              : _telemetry.headingDeg;

          _telemetry = TelemetryModel(
            latitude: position.latitude,
            longitude: position.longitude,
            speedKnots: speedKnots,
            headingDeg: heading,
            timestamp: position.timestamp,
          );
          notifyListeners();
        },
        onError: (err) {
          debugPrint('[TelemetryProvider] GPS Stream error: $err');
          _lastGpsError = err.toString();
          notifyListeners();
        },
      );

      _isLiveGpsActive = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[TelemetryProvider] startLiveGpsTracking error: $e');
      _lastGpsError = e.toString();
      _isLiveGpsActive = false;
      notifyListeners();
      return false;
    }
  }

  /// Cancels live GNSS stream and reverts to manual/simulated telemetry
  Future<void> stopLiveGpsTracking() async {
    if (_positionSubscription != null) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
    }
    _isLiveGpsActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
