import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class StitchWaveSparkline extends StatelessWidget {
  final double currentWaveHeight;
  final double peakWaveHeight;

  const StitchWaveSparkline({
    super.key,
    this.currentWaveHeight = 1.6,
    this.peakWaveHeight = 2.4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Now ${currentWaveHeight.toStringAsFixed(1)}m',
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.stitchTertiaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '18:00 Peak ${peakWaveHeight.toStringAsFixed(1)}m',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.stitchTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '22:00',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.stitchOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Progression wave curve
    final path = Path()
      ..moveTo(0, height * 0.70)
      ..cubicTo(
        width * 0.33,
        height * 0.65,
        width * 0.40,
        height * 0.25,
        width * 0.50,
        height * 0.20,
      )
      ..cubicTo(
        width * 0.65,
        height * 0.15,
        width * 0.78,
        height * 0.35,
        width,
        height * 0.55,
      );

    // Gradient fill under the wave
    final fillPath = Path.from(path)
      ..lineTo(width, height)
      ..lineTo(0, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.stitchPrimaryContainer.withOpacity(0.20),
          AppColors.stitchPrimaryFixed.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = AppColors.stitchPrimaryContainer
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Vertical dashed marker at peak (50% x)
    final peakX = width * 0.50;
    final peakY = height * 0.20;

    final dashPaint = Paint()
      ..color = AppColors.stitchTertiaryFixed
      ..strokeWidth = 1.5;
    for (double y = 0; y < height; y += 5) {
      canvas.drawLine(Offset(peakX, y), Offset(peakX, y + 2.5), dashPaint);
    }

    // Peak marker circle
    final peakCirclePaint = Paint()..color = AppColors.stitchTertiary;
    canvas.drawCircle(Offset(peakX, peakY), 4.5, peakCirclePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
