enum GeofenceWarningLevel { safe, advisory, warning, critical }

class GeofenceModel {
  final double distanceToImblKm;
  final Map<String, double> nearestImblPoint;
  final bool lookaheadBreachProjected;
  final double? timeToBreachMinutes;
  final GeofenceWarningLevel warningLevel;
  final double? evasiveHeadingDeg;

  const GeofenceModel({
    required this.distanceToImblKm,
    required this.nearestImblPoint,
    required this.lookaheadBreachProjected,
    this.timeToBreachMinutes,
    required this.warningLevel,
    this.evasiveHeadingDeg,
  });

  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    GeofenceWarningLevel level;
    final levelStr = (json['warning_level'] as String? ?? 'SAFE').toUpperCase();
    switch (levelStr) {
      case 'CRITICAL':
        level = GeofenceWarningLevel.critical;
        break;
      case 'WARNING':
        level = GeofenceWarningLevel.warning;
        break;
      case 'ADVISORY':
        level = GeofenceWarningLevel.advisory;
        break;
      default:
        level = GeofenceWarningLevel.safe;
    }

    final pt = json['nearest_imbl_point'] as Map<String, dynamic>? ?? {};

    return GeofenceModel(
      distanceToImblKm: (json['distance_to_imbl_km'] as num).toDouble(),
      nearestImblPoint: {
        'lat': (pt['lat'] as num?)?.toDouble() ?? 0.0,
        'lon': (pt['lon'] as num?)?.toDouble() ?? 0.0,
      },
      lookaheadBreachProjected: json['lookahead_breach_projected'] as bool? ?? false,
      timeToBreachMinutes: (json['time_to_breach_minutes'] as num?)?.toDouble(),
      warningLevel: level,
      evasiveHeadingDeg: (json['evasive_heading_deg'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance_to_imbl_km': distanceToImblKm,
      'nearest_imbl_point': nearestImblPoint,
      'lookahead_breach_projected': lookaheadBreachProjected,
      'time_to_breach_minutes': timeToBreachMinutes,
      'warning_level': warningLevel.name.toUpperCase(),
      'evasive_heading_deg': evasiveHeadingDeg,
    };
  }
}
