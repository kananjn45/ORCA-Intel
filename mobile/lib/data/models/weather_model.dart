class WeatherModel {
  final double latitude;
  final double longitude;
  final double waveHeightM;
  final double waveDirectionDeg;
  final double wavePeriodSec;
  final double windSpeedKnots;
  final double windDirectionDeg;
  final double swellWaveHeightM;
  final double seaSurfaceTempCelsius;
  final int seaStateCode;
  final bool isSafeForSmallCraft;
  final String advisorySummary;
  final DateTime observedAt;
  final String source;

  const WeatherModel({
    required this.latitude,
    required this.longitude,
    required this.waveHeightM,
    required this.waveDirectionDeg,
    required this.wavePeriodSec,
    required this.windSpeedKnots,
    required this.windDirectionDeg,
    required this.swellWaveHeightM,
    required this.seaSurfaceTempCelsius,
    required this.seaStateCode,
    required this.isSafeForSmallCraft,
    required this.advisorySummary,
    required this.observedAt,
    this.source = 'open-meteo',
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 9.285,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 79.312,
      waveHeightM: (json['wave_height_m'] as num?)?.toDouble() ?? 1.3,
      waveDirectionDeg: (json['wave_direction_deg'] as num?)?.toDouble() ?? 180.0,
      wavePeriodSec: (json['wave_period_sec'] as num?)?.toDouble() ?? 6.0,
      windSpeedKnots: (json['wind_speed_knots'] as num?)?.toDouble() ?? 12.5,
      windDirectionDeg: (json['wind_direction_deg'] as num?)?.toDouble() ?? 80.0,
      swellWaveHeightM: (json['swell_wave_height_m'] as num?)?.toDouble() ?? 1.1,
      seaSurfaceTempCelsius: (json['sea_surface_temp_celsius'] as num?)?.toDouble() ?? 28.4,
      seaStateCode: (json['sea_state_code'] as num?)?.toInt() ?? 3,
      isSafeForSmallCraft: json['is_safe_for_small_craft'] as bool? ?? true,
      advisorySummary: json['advisory_summary'] as String? ?? 'Moderate breeze, safe for mechanized crafts.',
      observedAt: json['observed_at'] != null ? DateTime.parse(json['observed_at'] as String) : DateTime.now(),
      source: json['source'] as String? ?? 'open-meteo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'wave_height_m': waveHeightM,
      'wave_direction_deg': waveDirectionDeg,
      'wave_period_sec': wavePeriodSec,
      'wind_speed_knots': windSpeedKnots,
      'wind_direction_deg': windDirectionDeg,
      'swell_wave_height_m': swellWaveHeightM,
      'sea_surface_temp_celsius': seaSurfaceTempCelsius,
      'sea_state_code': seaStateCode,
      'is_safe_for_small_craft': isSafeForSmallCraft,
      'advisory_summary': advisorySummary,
      'observed_at': observedAt.toIso8601String(),
      'source': source,
    };
  }

  String get windDirectionCompass {
    final deg = (windDirectionDeg % 360);
    if (deg >= 337.5 || deg < 22.5) return 'N';
    if (deg >= 22.5 && deg < 67.5) return 'NE';
    if (deg >= 67.5 && deg < 112.5) return 'E';
    if (deg >= 112.5 && deg < 157.5) return 'ESE';
    if (deg >= 157.5 && deg < 202.5) return 'S';
    if (deg >= 202.5 && deg < 247.5) return 'SW';
    if (deg >= 247.5 && deg < 292.5) return 'W';
    return 'NW';
  }
}
