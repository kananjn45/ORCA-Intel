import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/telemetry_model.dart';
import '../../../../data/models/geofence_model.dart';

class TelemetryHudBar extends StatelessWidget {
  final TelemetryModel telemetry;
  final GeofenceModel geofence;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onOfflinePackTap;
  final String currentLanguage;

  const TelemetryHudBar({
    super.key,
    required this.telemetry,
    required this.geofence,
    this.onLanguageTap,
    this.onOfflinePackTap,
    this.currentLanguage = 'தமிழ்',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.abyssBlack.withOpacity(0.92),
        border: const Border(
          bottom: BorderSide(color: AppColors.glassBorder, width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Brand Identifier & Action Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Title & Problem Statement Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.radarCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.radarCyan.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'ORCA',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: AppColors.radarCyan,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ISRO 26176',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  // Actions: Offline Pack Pill + Language Chip
                  Row(
                    children: [
                      // Offline Pack Button
                      InkWell(
                        onTap: onOfflinePackTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.marineSurface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.download_for_offline, color: AppColors.radarCyan, size: 14),
                              SizedBox(width: 5),
                              Text(
                                '24h Pack',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Language Selector Chip
                      InkWell(
                        onTap: onLanguageTap,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.marineSurface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Row(
                            children: [
                              Text(
                                currentLanguage,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: AppColors.radarCyan, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Row 2: Clean Telemetry Strip (GPS, Speed, Heading, IMBL Alert)
              Row(
                children: [
                  // GPS Coordinates
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: AppColors.radarCyan),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${telemetry.latitude.toStringAsFixed(3)}°N, ${telemetry.longitude.toStringAsFixed(3)}°E',
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Speed Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.navigation, size: 11, color: AppColors.bioGreen),
                        const SizedBox(width: 4),
                        Text(
                          '${telemetry.speedKnots.toStringAsFixed(1)} kts',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Heading Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.deepOcean,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.explore_outlined, size: 11, color: AppColors.textAccent),
                        const SizedBox(width: 4),
                        Text(
                          '${telemetry.headingDeg.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // IMBL Distance Pill
                  _buildImblPill(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImblPill() {
    Color pillColor;
    String statusText;
    IconData icon;

    final dist = geofence.distanceToImblKm;

    if (dist <= 2.0) {
      pillColor = AppColors.criticalRed;
      statusText = '${dist.toStringAsFixed(1)} km DANGER';
      icon = Icons.warning_rounded;
    } else if (dist <= 5.0) {
      pillColor = AppColors.warningAmber;
      statusText = '${dist.toStringAsFixed(1)} km CAUTION';
      icon = Icons.shield_outlined;
    } else {
      pillColor = AppColors.bioGreen;
      statusText = '${dist.toStringAsFixed(1)} km SAFE';
      icon = Icons.shield;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: pillColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pillColor, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: pillColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: pillColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
