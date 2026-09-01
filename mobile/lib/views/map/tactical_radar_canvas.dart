import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TacticalRadarCanvas extends StatefulWidget {
  final double vesselHeadingDeg;
  final double speedKnots;
  final double imblDistanceKm;

  const TacticalRadarCanvas({
    super.key,
    required this.vesselHeadingDeg,
    required this.speedKnots,
    required this.imblDistanceKm,
  });

  @override
  State<TacticalRadarCanvas> createState() => _TacticalRadarCanvasState();
}

class _TacticalRadarCanvasState extends State<TacticalRadarCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.44);

        return Stack(
          children: [
            // 1. Radar Grid & Sweep Painter
            AnimatedBuilder(
              animation: _sweepController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _RadarBackgroundPainter(
                    center: center,
                    sweepAngle: _sweepController.value * 2 * math.pi,
                  ),
                );
              },
            ),

            // 2. IMBL Border Vector (Red Ribbon Line in upper right)
            Positioned(
              top: constraints.maxHeight * 0.19,
              right: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.criticalRed.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.criticalRed, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.criticalRed.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.criticalRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'IMBL SRI LANKA • 4.8 KM',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.criticalRed,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Potential Fishing Zone (PFZ-04 Emerald Indicator)
            Positioned(
              top: constraints.maxHeight * 0.48,
              left: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.bioGreen.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.bioGreen, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bioGreen.withOpacity(0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🐟', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PFZ-TN-04 (HIGH YIELD)',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.bioGreen,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '14.2 km • SST 28.4°C • Chl-a 1.3',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 4. Center Own-Vessel Indicator with Course Line
            Positioned(
              left: center.dx - 32,
              top: center.dy - 32,
              child: Transform.rotate(
                angle: widget.vesselHeadingDeg * math.pi / 180,
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Projected Course Line
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 2.5,
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.radarCyan,
                                AppColors.radarCyan.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Glowing Vessel Reticle
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.deepOcean,
                          border: Border.all(color: AppColors.radarCyan, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.radarCyan.withOpacity(0.55),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.navigation, size: 20, color: AppColors.radarCyan),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Sector Label Bar
            Positioned(
              top: center.dy - 120,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.abyssBlack.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder.withOpacity(0.5)),
                  ),
                  child: Text(
                    'PALK STRAIT • RAMESWARAM SECTOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary.withOpacity(0.8),
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RadarBackgroundPainter extends CustomPainter {
  final Offset center;
  final double sweepAngle;

  _RadarBackgroundPainter({
    required this.center,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle coordinate grid
    final gridPaint = Paint()
      ..color = AppColors.glassBorder.withOpacity(0.25)
      ..strokeWidth = 0.6;

    const gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Nautical Range Rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rings = [
      {'r': 60.0, 'alpha': 0.18, 'label': '1.0 NM'},
      {'r': 115.0, 'alpha': 0.14, 'label': '2.5 NM'},
      {'r': 165.0, 'alpha': 0.10, 'label': '5.0 NM'},
    ];

    for (final ring in rings) {
      final r = ring['r'] as double;
      final alpha = ring['alpha'] as double;
      final label = ring['label'] as String;

      ringPaint.color = AppColors.radarCyan.withOpacity(alpha);
      canvas.drawCircle(center, r, ringPaint);

      // Label on ring
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: AppColors.radarCyan.withOpacity(0.4),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(center.dx + 4, center.dy - r - 10));
    }

    // 3. Rotating Radar Sweep Gradient Cone
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset(center.dx / size.width, center.dy / size.height),
        startAngle: sweepAngle - 0.5,
        endAngle: sweepAngle,
        colors: [
          Colors.transparent,
          AppColors.radarCyan.withOpacity(0.08),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 175));

    canvas.drawCircle(center, 175, sweepPaint);

    // 4. Subtle Crosshair lines through vessel
    final crossPaint = Paint()
      ..color = AppColors.radarCyan.withOpacity(0.2)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(center.dx - 175, center.dy), Offset(center.dx + 175, center.dy), crossPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 175), Offset(center.dx, center.dy + 175), crossPaint);

    // 5. IMBL Boundary Vector Line (Crimson Dashed Line)
    final imblPaint = Paint()
      ..color = AppColors.criticalRed.withOpacity(0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.4, 0);
    path.lineTo(size.width, size.height * 0.42);
    canvas.drawPath(path, imblPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarBackgroundPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}
