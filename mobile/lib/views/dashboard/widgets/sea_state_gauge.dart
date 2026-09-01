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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.abyssBlack.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSafe ? AppColors.glassBorder : AppColors.criticalRed.withOpacity(0.6),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Wave metric
          _buildPillItem(
            icon: Icons.waves,
            color: AppColors.radarCyan,
            text: '${waveHeightM.toStringAsFixed(1)}m Wave',
          ),
          _buildDivider(),

          // Wind metric
          _buildPillItem(
            icon: Icons.air,
            color: windSpeedKnots > 20 ? AppColors.warningAmber : AppColors.bioGreen,
            text: '${windSpeedKnots.toStringAsFixed(0)} kts Wind',
          ),
          _buildDivider(),

          // Swell metric
          _buildPillItem(
            icon: Icons.water_drop_outlined,
            color: AppColors.textAccent,
            text: '${swellHeightM.toStringAsFixed(1)}m Swell',
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 12,
      width: 1,
      color: AppColors.glassBorder,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
