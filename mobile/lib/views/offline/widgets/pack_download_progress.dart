import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PackDownloadProgress extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String currentStep;
  final bool isCompleted;

  const PackDownloadProgress({
    super.key,
    required this.progress,
    required this.currentStep,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.deepOcean,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? AppColors.bioGreen : AppColors.radarCyan.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.cloud_download_outlined,
                    color: isCompleted ? AppColors.bioGreen : AppColors.radarCyan,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCompleted ? 'OFFLINE PACK READY' : 'DOWNLOADING 24H PACK',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? AppColors.bioGreen : AppColors.textPrimary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isCompleted ? AppColors.bioGreen : AppColors.radarCyan,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.abyssBlack,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? AppColors.bioGreen : AppColors.radarCyan,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),

          // Status Step Text
          Text(
            currentStep,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
