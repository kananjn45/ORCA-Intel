import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SeaStateGauge extends StatelessWidget {
  final double waveHeightM;
  final double swellHeightM;
  final double windSpeedKnots;
  final bool isSafe;
  final VoidCallback? onTap;

  const SeaStateGauge({
    super.key,
    required this.waveHeightM,
    required this.swellHeightM,
    required this.windSpeedKnots,
    required this.isSafe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardSurface.withOpacity(0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSafe ? AppColors.navyDark : AppColors.criticalRed,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Wave Metric
                _buildMetric(
                  icon: Icons.waves_rounded,
                  color: AppColors.primaryBlue,
                  value: '${waveHeightM.toStringAsFixed(1)}m Wave',
                  tag: 'Calm',
                  tagColor: AppColors.bioGreen,
                ),
                _buildDivider(),

                // Wind Metric
                _buildMetric(
                  icon: Icons.air_rounded,
                  color: windSpeedKnots > 20 ? AppColors.warningAmber : AppColors.accentLight,
                  value: '${windSpeedKnots.toStringAsFixed(0)} kts',
                  tag: 'ENE',
                  tagColor: AppColors.accentLight,
                ),
                _buildDivider(),

                // Sea Surface Temp & Swell
                _buildMetric(
                  icon: Icons.thermostat_rounded,
                  color: AppColors.primaryBlue,
                  value: '28°C SST',
                  tag: '${swellHeightM.toStringAsFixed(1)}m Swell',
                  tagColor: AppColors.iceWhite,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.info_outline_rounded, size: 12, color: AppColors.accentLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required Color color,
    required String value,
    required String tag,
    required Color tagColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: AppColors.iceWhite,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: AppColors.navyDark.withOpacity(0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              color: tagColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 14,
      width: 1,
      color: AppColors.navyDark,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }
}
