import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class StitchCompassDial extends StatelessWidget {
  final double bearingDeg;
  final double size;

  const StitchCompassDial({
    super.key,
    required this.bearingDeg,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.stitchSurfaceContainerLow,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _StitchCompassPainter(bearingDeg: bearingDeg),
          ),
          Positioned(
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.stitchSurfaceContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${bearingDeg.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.stitchOnSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StitchCompassPainter extends CustomPainter {
  final double bearingDeg;

  _StitchCompassPainter({required this.bearingDeg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // 1. Outer dashed boundary ring
    final ringPaint = Paint()
      ..color = AppColors.stitchOutlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);

    // 2. Cardinal Labels
    _drawText(canvas, 'N', center.dx, center.dy - radius + 3, AppColors.stitchPrimary, isBold: true);
    _drawText(canvas, 'E', center.dx + radius - 7, center.dy - 6, AppColors.stitchOnSurfaceVariant);
    _drawText(canvas, 'S', center.dx, center.dy + radius - 15, AppColors.stitchOnSurfaceVariant);
    _drawText(canvas, 'W', center.dx - radius + 7, center.dy - 6, AppColors.stitchOnSurfaceVariant);

    // 3. Rotatable Needle
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(bearingDeg * math.pi / 180.0);

    // North Needle (Red)
    final redPath = Path()
      ..moveTo(0, -radius * 0.75)
      ..lineTo(4, -2)
      ..lineTo(0, 0)
      ..lineTo(-4, -2)
      ..close();
    final redPaint = Paint()..color = AppColors.stitchError;
    canvas.drawPath(redPath, redPaint);

    // South Needle (Navy)
    final navyPath = Path()
      ..moveTo(0, radius * 0.70)
      ..lineTo(4, 2)
      ..lineTo(0, 0)
      ..lineTo(-4, 2)
      ..close();
    final navyPaint = Paint()..color = AppColors.stitchOnSurface;
    canvas.drawPath(navyPath, navyPaint);

    // Center Pivot Dot
    final pivotPaint = Paint()..color = AppColors.stitchPrimary;
    canvas.drawCircle(Offset.zero, 3.5, pivotPaint);

    canvas.restore();
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color, {bool isBold = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: 9,
        fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
        color: color,
        fontFamily: 'monospace',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x - (textPainter.width / 2), y));
  }

  @override
  bool shouldRepaint(covariant _StitchCompassPainter oldDelegate) {
    return oldDelegate.bearingDeg != bearingDeg;
  }
}
