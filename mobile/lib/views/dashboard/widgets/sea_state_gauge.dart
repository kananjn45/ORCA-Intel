import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SeaStateGauge extends StatelessWidget {
  final double waveHeightM;
  final double swellHeightM;
  final double windSpeedKnots;
  final bool isSafe;

  const SeaStateGauge({
    super.key,
    required this.waveHeightM,
    required this.swellHeightM,
    required this.windSpeedKnots,
    required this.isSafe,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
          decoration: BoxDecoration(
            color: AppColors.abyssBlack.withOpacity(0.78),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSafe ? AppColors.radarCyan.withOpacity(0.35) : AppColors.criticalRed.withOpacity(0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSafe ? AppColors.radarCyan : AppColors.criticalRed).withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Wave Metric
              _buildPillItem(
                icon: Icons.waves,
                color: AppColors.radarCyan,
                label: '${waveHeightM.toStringAsFixed(1)}m Wave',
                status: 'Calm',
                statusColor: AppColors.bioGreen,
              ),
              _buildDivider(),

              // Wind Metric with Direction
              _buildPillItem(
                icon: Icons.air,
                color: windSpeedKnots > 20 ? AppColors.warningAmber : AppColors.bioGreen,
                label: '${windSpeedKnots.toStringAsFixed(0)} kts',
                status: 'ENE',
                statusColor: AppColors.textSecondary,
              ),
              _buildDivider(),

              // Swell & Sea Surface Temp
              _buildPillItem(
                icon: Icons.water_drop,
                color: AppColors.textAccent,
                label: '${swellHeightM.toStringAsFixed(1)}m Swell',
                status: '28°C',
                statusColor: AppColors.radarCyan,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillItem({
    required IconData icon,
    required Color color,
    required String label,
    required String status,
    required Color statusColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 12,
      width: 1,
      color: AppColors.glassBorder.withOpacity(0.8),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
