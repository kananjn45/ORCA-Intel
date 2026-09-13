import '../models/telemetry_model.dart';
import '../models/geofence_model.dart';
import '../../core/utils/geo_math.dart';

class CoastalSector {
  final String id;
  final String name;
  final String region;
  final double centerLat;
  final double centerLon;
  final Map<String, double> bounds;
  final String nearestBorderName;
  final Map<String, double> nearestBorderPoint;
  final double initialHeadingDeg;
  final double initialSpeedKnots;
  final String description;
  final String packSize;

  const CoastalSector({
    required this.id,
    required this.name,
    required this.region,
    required this.centerLat,
    required this.centerLon,
    required this.bounds,
    required this.nearestBorderName,
    required this.nearestBorderPoint,
    required this.initialHeadingDeg,
    required this.initialSpeedKnots,
    required this.description,
    required this.packSize,
  });

  double get distanceToBorderKm => GeoMath.haversineKm(
        centerLat,
        centerLon,
        nearestBorderPoint['lat']!,
        nearestBorderPoint['lon']!,
      );

  TelemetryModel createInitialTelemetry() {
    return TelemetryModel(
      latitude: centerLat,
      longitude: centerLon,
      speedKnots: initialSpeedKnots,
      headingDeg: initialHeadingDeg,
      timestamp: DateTime.now(),
    );
  }

  GeofenceModel createInitialGeofence() {
    final dist = distanceToBorderKm;
    return GeofenceModel(
      distanceToImblKm: dist,
      nearestImblPoint: nearestBorderPoint,
      lookaheadBreachProjected: dist < 5.0,
      warningLevel: dist < 5.0
          ? GeofenceWarningLevel.critical
          : (dist < 10.0 ? GeofenceWarningLevel.warning : GeofenceWarningLevel.safe),
      evasiveHeadingDeg: (initialHeadingDeg + 180.0) % 360.0,
    );
  }

  static const List<CoastalSector> all = [
    CoastalSector(
      id: 'palk_strait',
      name: 'Palk Strait (Rameswaram)',
      region: 'Tamil Nadu / Sri Lanka Border',
      centerLat: 9.2854,
      centerLon: 79.3121,
      bounds: {'min_lat': 9.0, 'max_lat': 9.6, 'min_lon': 79.0, 'max_lon': 79.8},
      nearestBorderName: 'Indo-Sri Lanka IMBL (Palk Strait)',
      nearestBorderPoint: {'lat': 9.380, 'lon': 79.520},
      initialHeadingDeg: 82.0,
      initialSpeedKnots: 8.4,
      description: 'High maritime sensitivity zone; 14.2 km to Sri Lanka territorial waters.',
      packSize: '5.8 MB',
    ),
    CoastalSector(
      id: 'gulf_of_mannar',
      name: 'Gulf of Mannar (Mandapam)',
      region: 'Tamil Nadu South / Biosphere Reserve',
      centerLat: 9.1520,
      centerLon: 79.1240,
      bounds: {'min_lat': 8.7, 'max_lat': 9.3, 'min_lon': 78.8, 'max_lon': 79.5},
      nearestBorderName: 'Gulf of Mannar Marine Biosphere & IMBL',
      nearestBorderPoint: {'lat': 8.920, 'lon': 79.350},
      initialHeadingDeg: 115.0,
      initialSpeedKnots: 7.8,
      description: 'Protected marine coral reefs and southern island navigation channel.',
      packSize: '4.9 MB',
    ),
    CoastalSector(
      id: 'coromandel_coast',
      name: 'Coromandel Coast (Chennai)',
      region: 'Tamil Nadu North / Bay of Bengal',
      centerLat: 12.8020,
      centerLon: 80.3610,
      bounds: {'min_lat': 12.8, 'max_lat': 13.4, 'min_lon': 80.1, 'max_lon': 80.7},
      nearestBorderName: 'Northern Bay of Bengal Deep Sea Boundary',
      nearestBorderPoint: {'lat': 12.710, 'lon': 80.830},
      initialHeadingDeg: 85.0,
      initialSpeedKnots: 9.1,
      description: 'Deep-water commercial and artisanal fishing corridor outside Chennai port.',
      packSize: '6.2 MB',
    ),
    CoastalSector(
      id: 'andhra_coast',
      name: 'Andhra Coast (Visakhapatnam)',
      region: 'Andhra Pradesh / Central Bay of Bengal',
      centerLat: 17.6868,
      centerLon: 83.3030,
      bounds: {'min_lat': 17.4, 'max_lat': 18.0, 'min_lon': 83.1, 'max_lon': 83.7},
      nearestBorderName: 'Central Bay of Bengal Deep Sea Trench',
      nearestBorderPoint: {'lat': 17.500, 'lon': 83.850},
      initialHeadingDeg: 95.0,
      initialSpeedKnots: 10.2,
      description: 'High swell offshore fishing zone with rapid depth drop-off.',
      packSize: '5.4 MB',
    ),
    CoastalSector(
      id: 'gujarat_offshore',
      name: 'Gujarat Offshore (Porbandar)',
      region: 'Gujarat / Arabian Sea',
      centerLat: 21.6417,
      centerLon: 69.6293,
      bounds: {'min_lat': 21.4, 'max_lat': 22.0, 'min_lon': 69.4, 'max_lon': 70.0},
      nearestBorderName: 'India-Pakistan Notional Border (Sir Creek)',
      nearestBorderPoint: {'lat': 22.100, 'lon': 68.800},
      initialHeadingDeg: 290.0,
      initialSpeedKnots: 8.8,
      description: 'Arabian Sea border corridor; extreme proximity alerts to Sir Creek buffer.',
      packSize: '6.5 MB',
    ),
  ];

  static CoastalSector findByName(String name) {
    return all.firstWhere(
      (s) => s.name == name || s.name.contains(name) || name.contains(s.name),
      orElse: () => all[2], // Default to Coromandel Coast (Chennai)
    );
  }
}
