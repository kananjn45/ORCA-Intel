class TelemetryModel {
  final String vesselId;
  final double latitude;
  final double longitude;
  final double speedKnots;
  final double headingDeg;
  final DateTime timestamp;

  const TelemetryModel({
    this.vesselId = 'VESSEL-IND-01',
    required this.latitude,
    required this.longitude,
    required this.speedKnots,
    required this.headingDeg,
    required this.timestamp,
  });

  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    return TelemetryModel(
      vesselId: json['vessel_id'] as String? ?? 'VESSEL-IND-01',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedKnots: (json['speed_knots'] as num?)?.toDouble() ?? 0.0,
      headingDeg: (json['heading_deg'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vessel_id': vesselId,
      'latitude': latitude,
      'longitude': longitude,
      'speed_knots': speedKnots,
      'heading_deg': headingDeg,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  TelemetryModel copyWith({
    String? vesselId,
    double? latitude,
    double? longitude,
    double? speedKnots,
    double? headingDeg,
    DateTime? timestamp,
  }) {
    return TelemetryModel(
      vesselId: vesselId ?? this.vesselId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speedKnots: speedKnots ?? this.speedKnots,
      headingDeg: headingDeg ?? this.headingDeg,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
