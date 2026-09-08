import 'package:flutter/material.dart';

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
    const successGreen = Color(0xFF16A34A);
    const primaryBlue = Color(0xFF0284C7);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? successGreen : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? successGreen.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
                    isCompleted ? Icons.check_circle_rounded : Icons.cloud_download_rounded,
                    color: isCompleted ? successGreen : primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCompleted ? 'OFFLINE PACK READY' : 'DOWNLOADING 24H PACK',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: isCompleted ? successGreen : const Color(0xFF0F172A),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: isCompleted ? successGreen : primaryBlue,
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
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? successGreen : primaryBlue,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),

          // Status Step Text
          Text(
            currentStep,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
