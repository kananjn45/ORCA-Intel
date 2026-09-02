import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/telemetry_model.dart';
import '../../../../data/models/geofence_model.dart';

class TelemetryHudBar extends StatelessWidget {
  final TelemetryModel telemetry;
  final GeofenceModel geofence;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onOfflinePackTap;
  final VoidCallback? onImblTap;
  final VoidCallback? onSimulateTap;
  final String currentLanguage;

  const TelemetryHudBar({
    super.key,
    required this.telemetry,
    required this.geofence,
    this.onLanguageTap,
    this.onOfflinePackTap,
    this.onImblTap,
    this.onSimulateTap,
    this.currentLanguage = 'English',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withOpacity(0.96),
        border: const Border(
          bottom: BorderSide(color: AppColors.navyDark, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
              // Row 1: Brand Identifier, GNSS Status & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Title & ISRO Tag
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.navyDark, AppColors.primaryBlue],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.accentLight.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'ORCA',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.iceWhite,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: AppColors.navyDark.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.navyDark.withOpacity(0.6)),
                        ),
                        child: const Text(
                          'ISRO',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Satellite status
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppColors.bioGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),

                  // Actions: Test, Offline Pack & Language
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Test Scenario Simulator Button
                      InkWell(
                        onTap: onSimulateTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.navyDark.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.science_rounded, color: AppColors.accentLight, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'Test',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.iceWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 5),

                      // Offline Pack Button
                      InkWell(
                        onTap: onOfflinePackTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.navyDark.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_rounded, color: AppColors.accentLight, size: 12),
                              SizedBox(width: 3),
                              Text(
                                'Pack',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.iceWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 5),

                      // Language Selector Chip
                      InkWell(
                        onTap: onLanguageTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.navyDark.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentLanguage.length > 4 ? currentLanguage.substring(0, 2).toUpperCase() : currentLanguage,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.iceWhite,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down_rounded, color: AppColors.accentLight, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Row 2: Clean Telemetry Ribbon (GPS, Speed, Heading, IMBL Alert)
              Row(
                children: [
                  // GPS Coordinates
                  Expanded(
                    flex: 11,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.navyDark),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location_rounded, size: 12, color: AppColors.primaryBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${telemetry.latitude.toStringAsFixed(3)}°N  ${telemetry.longitude.toStringAsFixed(3)}°E',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.iceWhite,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Speed Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.navyDark),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.speed_rounded, size: 12, color: AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          '${telemetry.speedKnots.toStringAsFixed(1)} kts',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: AppColors.iceWhite,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Heading Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.navyDark),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.explore_rounded, size: 12, color: AppColors.accentLight),
                        const SizedBox(width: 4),
                        Text(
                          '${telemetry.headingDeg.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: AppColors.iceWhite,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // IMBL Distance Pill (Interactive with tap!)
                  InkWell(
                    onTap: onImblTap,
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImblPill(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImblPill() {
    Color pillBg;
    Color pillBorder;
    Color pillText;
    String statusText;
    IconData icon;

    final dist = geofence.distanceToImblKm;

    if (dist <= 2.0) {
      pillBg = AppColors.criticalRed.withOpacity(0.2);
      pillBorder = AppColors.criticalRed;
      pillText = AppColors.criticalRed;
      statusText = '${dist.toStringAsFixed(1)} km DANGER';
      icon = Icons.warning_rounded;
    } else if (dist <= 5.0) {
      pillBg = AppColors.warningAmber.withOpacity(0.18);
      pillBorder = AppColors.warningAmber;
      pillText = AppColors.warningAmber;
      statusText = '${dist.toStringAsFixed(1)} km CAUTION';
      icon = Icons.shield_outlined;
    } else {
      pillBg = AppColors.bioGreen.withOpacity(0.18);
      pillBorder = AppColors.bioGreen;
      pillText = AppColors.bioGreen;
      statusText = '${dist.toStringAsFixed(1)} km SAFE';
      icon = Icons.shield_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pillBorder, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: pillText),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: pillText,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
