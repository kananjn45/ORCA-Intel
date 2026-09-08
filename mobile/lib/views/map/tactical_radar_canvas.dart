import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TacticalRadarCanvas extends StatefulWidget {
  final double vesselHeadingDeg;
  final double speedKnots;
  final double imblDistanceKm;
  final bool showPfzCourse;
  final bool showEvasiveCourse;
  final VoidCallback? onPfzTap;
  final VoidCallback? onImblTap;
  final VoidCallback? onVesselTap;

  const TacticalRadarCanvas({
    super.key,
    required this.vesselHeadingDeg,
    required this.speedKnots,
    required this.imblDistanceKm,
    this.showPfzCourse = false,
    this.showEvasiveCourse = false,
    this.onPfzTap,
    this.onImblTap,
    this.onVesselTap,
  });

  @override
  State<TacticalRadarCanvas> createState() => _TacticalRadarCanvasState();
}

class _TacticalRadarCanvasState extends State<TacticalRadarCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return Container(color: const Color(0xFFF8FAFC));
        }

        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.40);

        return Stack(
          children: [
            // 1. Light Ocean Bathymetric Base & Chart Grid
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _MarineChartPainter(
                      center: center,
                      sweepAngle: _radarController.value * 2 * math.pi,
                      showPfzCourse: widget.showPfzCourse,
                      showEvasiveCourse: widget.showEvasiveCourse,
                    ),
                  );
                },
              ),
            ),

            // 2. Cardinal Compass Directions
            Positioned(
              top: center.dy - 170,
              left: center.dx - 12,
              child: const Text(
                'N',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0369A1),
                  letterSpacing: 1.5,
                ),
              ),
            ),
            Positioned(
              top: center.dy + 155,
              left: center.dx - 10,
              child: const Text(
                'S',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0369A1),
                ),
              ),
            ),
            Positioned(
              top: center.dy - 8,
              left: center.dx + 160,
              child: const Text(
                'E',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0369A1),
                ),
              ),
            ),
            Positioned(
              top: center.dy - 8,
              left: center.dx - 172,
              child: const Text(
                'W',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0369A1),
                ),
              ),
            ),

            // 3. Sector Header Tag
            Positioned(
              top: center.dy - 125,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'PALK STRAIT • RAMESWARAM SECTOR',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            // 4. IMBL Sri Lanka Boundary Line Pill (Interactive with tap!)
            Positioned(
              top: constraints.maxHeight * 0.23,
              right: 16,
              child: GestureDetector(
                onTap: widget.onImblTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                          color: Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'IMBL SRI LANKA • ${widget.imblDistanceKm.toStringAsFixed(1)} KM',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFDC2626),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.touch_app_rounded, size: 10, color: Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Potential Fishing Zone (PFZ-04 High Catch - Interactive with tap!)
            Positioned(
              top: center.dy + 35,
              left: 20,
              child: GestureDetector(
                onTap: widget.onPfzTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.showPfzCourse ? const Color(0xFF16A34A) : const Color(0xFF22C55E),
                      width: widget.showPfzCourse ? 2.0 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.showPfzCourse ? const Color(0xFF16A34A).withOpacity(0.25) : Colors.black.withOpacity(0.08),
                        blurRadius: widget.showPfzCourse ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🐟', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PFZ-TN-04 (HIGH YIELD)',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF15803D),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            widget.showPfzCourse ? '🧭 Course Plotted • 14.2 km' : '14.2 km • SST 28.4°C • Tap to Plot',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: widget.showPfzCourse ? const Color(0xFF0F172A) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.touch_app_rounded, size: 10, color: Color(0xFF15803D)),
                    ],
                  ),
                ),
              ),
            ),

            // 6. Center Own-Vessel Indicator with Course Projection (Interactive!)
            Positioned(
              left: center.dx - 30,
              top: center.dy - 30,
              child: GestureDetector(
                onTap: widget.onVesselTap,
                child: Transform.rotate(
                  angle: widget.vesselHeadingDeg * math.pi / 180,
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Forward Course Vector
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 2.5,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  const Color(0xFF0284C7),
                                  const Color(0xFF0284C7).withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Vessel Navigational Marker
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0284C7),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.navigation_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

class _MarineChartPainter extends CustomPainter {
  final Offset center;
  final double sweepAngle;
  final bool showPfzCourse;
  final bool showEvasiveCourse;

  _MarineChartPainter({
    required this.center,
    required this.sweepAngle,
    required this.showPfzCourse,
    required this.showEvasiveCourse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final safeCenter = Offset(
      (center.dx.isNaN || center.dx.isInfinite) ? size.width / 2 : center.dx,
      (center.dy.isNaN || center.dy.isInfinite) ? size.height * 0.40 : center.dy,
    );

    // 1. Light Coastal Bathymetric Radial Gradient
    final normX = ((safeCenter.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final normY = ((safeCenter.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);

    final oceanGrad = RadialGradient(
      center: Alignment(normX, normY),
      radius: 0.65,
      colors: const [
        Color(0xFFE0F2FE), // Light sky coastal blue
        Color(0xFFF0F9FF), // Ice blue wash
        Color(0xFFF8FAFC), // Off-white clean background
      ],
      stops: const [0.0, 0.55, 1.0],
    );
    final bgPaint = Paint()..shader = oceanGrad.createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Subtle Nautical Grid Lines
    final gridPaint = Paint()
      ..color = const Color(0xFFBAE6FD).withOpacity(0.5)
      ..strokeWidth = 0.8;

    const gridStep = 44.0;
    for (double x = 0; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 3. Concentric Nautical Distance Rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final rings = [
      {'r': 55.0, 'alpha': 0.35, 'label': '1.0 NM'},
      {'r': 105.0, 'alpha': 0.25, 'label': '2.5 NM'},
      {'r': 155.0, 'alpha': 0.18, 'label': '5.0 NM'},
    ];

    for (final ring in rings) {
      final r = ring['r'] as double;
      final alpha = ring['alpha'] as double;
      final label = ring['label'] as String;

      ringPaint.color = const Color(0xFF0284C7).withOpacity(alpha * 1.5);
      canvas.drawCircle(safeCenter, r, ringPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0369A1),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(safeCenter.dx + 4, safeCenter.dy - r - 11));
    }

    // 4. Subtle Radar Sweep Cone
    final sweepNormX = (safeCenter.dx / size.width).clamp(0.0, 1.0);
    final sweepNormY = (safeCenter.dy / size.height).clamp(0.0, 1.0);

    final double safeSweep = sweepAngle.clamp(0.0, 2 * math.pi);
    final double start = math.max(0.0, safeSweep - 0.4);
    final double end = math.max(start + 0.01, safeSweep);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset(sweepNormX, sweepNormY),
        startAngle: start,
        endAngle: end,
        colors: [
          Colors.transparent,
          const Color(0xFF0284C7).withOpacity(0.12),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: safeCenter, radius: 160));

    canvas.drawCircle(safeCenter, 160, sweepPaint);

    // 5. Crosshair Ticks
    final crossPaint = Paint()
      ..color = const Color(0xFF0284C7).withOpacity(0.25)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(safeCenter.dx - 160, safeCenter.dy), Offset(safeCenter.dx + 160, safeCenter.dy), crossPaint);
    canvas.drawLine(Offset(safeCenter.dx, safeCenter.dy - 160), Offset(safeCenter.dx, safeCenter.dy + 160), crossPaint);

    // 6. Active PFZ Navigation Vector (If active)
    if (showPfzCourse) {
      final pfzCoursePaint = Paint()
        ..color = AppColors.bioGreen
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      
      final pfzTarget = Offset(safeCenter.dx - 80, safeCenter.dy + 55);
      canvas.drawLine(safeCenter, pfzTarget, pfzCoursePaint);

      final pfzDot = Paint()..color = AppColors.bioGreen;
      canvas.drawCircle(pfzTarget, 5.0, pfzDot);
    }

    // 7. Active Evasive Heading Vector (265° West)
    if (showEvasiveCourse) {
      final evasivePaint = Paint()
        ..color = AppColors.warningAmber
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final evasiveTarget = Offset(safeCenter.dx - 110, safeCenter.dy + 10);
      canvas.drawLine(safeCenter, evasiveTarget, evasivePaint);

      final evasiveDot = Paint()..color = AppColors.warningAmber;
      canvas.drawCircle(evasiveTarget, 5.0, evasiveDot);
    }

    // 8. Sri Lanka IMBL Border Vector (Clean Crimson Solid Line)
    final imblPaint = Paint()
      ..color = AppColors.criticalRed.withOpacity(0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final borderPath = Path();
    borderPath.moveTo(size.width * 0.42, 0);
    borderPath.lineTo(size.width, size.height * 0.38);
    canvas.drawPath(borderPath, imblPaint);
  }

  @override
  bool shouldRepaint(covariant _MarineChartPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.showPfzCourse != showPfzCourse ||
        oldDelegate.showEvasiveCourse != showEvasiveCourse;
  }
}
