class PFZModel {
  final String pfzId;
  final String sectorName;
  final double centroidLat;
  final double centroidLon;
  final double distanceKm;
  final double bearingDeg;
  final double chlorophyll;
  final double sstGradient;
  final double depthM;
  final DateTime validUntil;
  final List<List<double>> polygonCoordinates;
  final List<String> targetSpecies;
  final String source;

  const PFZModel({
    required this.pfzId,
    required this.sectorName,
    required this.centroidLat,
    required this.centroidLon,
    required this.distanceKm,
    required this.bearingDeg,
    required this.chlorophyll,
    required this.sstGradient,
    required this.depthM,
    required this.validUntil,
    required this.polygonCoordinates,
    this.targetSpecies = const ['Sardine', 'Mackerel'],
    this.source = 'INCOIS-MOSDAC',
  });

  factory PFZModel.fromJson(Map<String, dynamic> json) {
    final centroid = json['centroid'] as Map<String, dynamic>? ?? {};
    final lat = (centroid['lat'] as num?)?.toDouble() ?? 9.35;
    final lon = (centroid['lon'] as num?)?.toDouble() ?? 79.45;

    List<List<double>> parsedPolygon = [];
    final geojson = json['geojson_geometry'] as Map<String, dynamic>?;
    if (geojson != null && geojson['coordinates'] != null) {
      final rings = geojson['coordinates'] as List<dynamic>?;
      if (rings != null && rings.isNotEmpty) {
        final outerRing = rings[0] as List<dynamic>;
        parsedPolygon = outerRing.map((c) {
          final pt = c as List<dynamic>;
          return [
            (pt[0] as num).toDouble(),
            (pt[1] as num).toDouble(),
          ];
        }).toList();
      }
    }

    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['valid_until']?.toString() ?? '');
    } catch (_) {
      parsedDate = DateTime.now().add(const Duration(hours: 24));
    }

    List<String> species = [];
    if (json['target_species'] is List) {
      species = (json['target_species'] as List).map((e) => e.toString()).toList();
    } else {
      species = ['Sardinella longiceps (Oil Sardine)', 'Rastrelliger kanagurta (Indian Mackerel)'];
    }

    return PFZModel(
      pfzId: json['pfz_id']?.toString() ?? 'PFZ-DEFAULT',
      sectorName: json['sector_name']?.toString() ?? 'Palk Bay South',
      centroidLat: lat,
      centroidLon: lon,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 14.0,
      bearingDeg: (json['bearing_deg'] as num?)?.toDouble() ?? 65.0,
      chlorophyll: (json['chlorophyll_mg_m3'] as num?)?.toDouble() ?? 1.25,
      sstGradient: (json['sst_gradient_celsius'] as num?)?.toDouble() ?? 0.85,
      depthM: (json['depth_m'] as num?)?.toDouble() ?? 22.0,
      validUntil: parsedDate,
      polygonCoordinates: parsedPolygon,
      targetSpecies: species,
      source: json['source']?.toString() ?? 'INCOIS-MOSDAC',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pfz_id': pfzId,
      'sector_name': sectorName,
      'centroid': {'lat': centroidLat, 'lon': centroidLon},
      'distance_km': distanceKm,
      'bearing_deg': bearingDeg,
      'chlorophyll_mg_m3': chlorophyll,
      'sst_gradient_celsius': sstGradient,
      'depth_m': depthM,
      'valid_until': validUntil.toIso8601String(),
      'geojson_geometry': {
        'type': 'Polygon',
        'coordinates': [polygonCoordinates],
      },
      'target_species': targetSpecies,
      'source': source,
    };
  }
}
