import 'package:flutter/foundation.dart';
import '../data/models/telemetry_model.dart';

class TelemetryProvider extends ChangeNotifier {
  TelemetryModel _telemetry = TelemetryModel(
    latitude: 9.2854,
    longitude: 79.3121,
    speedKnots: 8.4,
    headingDeg: 82.0,
    timestamp: DateTime.now(),
  );

  TelemetryModel get telemetry => _telemetry;

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
    _telemetry = TelemetryModel(
      latitude: latitude,
      longitude: longitude,
      speedKnots: speedKnots,
      headingDeg: headingDeg,
      timestamp: DateTime.now(),
    );
    notifyListeners();
  }
}
