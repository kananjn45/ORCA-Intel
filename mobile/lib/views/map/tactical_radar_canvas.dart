import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _radarOrientation = 'HEAD-UP'; // 'HEAD-UP' or 'N-UP'
  double _radarRangeNm = 2.0; // 1.0, 2.0, 5.0
  bool _chimeEnabled = true;
  bool _isDiversionEngaged = false;
  bool _isAlarmMuted = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
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
          return Container(color: AppColors.stitchSurface);
        }

        final radarRadius = math.min(constraints.maxWidth * 0.44, 175.0);
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight * 0.38);

        return Stack(
          children: [
            // 1. Radar Scope Base & Custom Paint
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                    painter: _StitchRadarPainter(
                      center: center,
                      radius: radarRadius,
                      sweepAngle: _radarController.value * 2 * math.pi,
                      rangeNm: _radarRangeNm,
                      orientation: _radarOrientation,
                      headingDeg: widget.vesselHeadingDeg,
                      showPfzCourse: widget.showPfzCourse,
                      showEvasiveCourse: widget.showEvasiveCourse || _isDiversionEngaged,
                    ),
                  );
                },
              ),
            ),

            // 2. Top Tactical Sea State Warning Banner
            Positioned(
              top: 8,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.stitchTertiary, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.stitchTertiary.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.stitchTertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: AppColors.stitchOnTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SEA STATE 4 · MODERATELY ROUGH',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.stitchTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Wave Radar Pulse Scan Active • 3.2 GHz S-Band',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.stitchOutline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.stitchTertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'MAX SWELL 2.2M @ 140°',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.stitchOnTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Tactical Radar Mode & Range Strip
            Positioned(
              top: 58,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Head-Up vs North-Up Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeChip('HEAD-UP', _radarOrientation == 'HEAD-UP', () {
                          HapticFeedback.selectionClick();
                          setState(() => _radarOrientation = 'HEAD-UP');
                        }),
                        _buildModeChip('N-UP', _radarOrientation == 'N-UP', () {
                          HapticFeedback.selectionClick();
                          setState(() => _radarOrientation = 'N-UP');
                        }),
                      ],
                    ),
                  ),

                  // Range Selector (1NM, 2NM, 5NM)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.stitchSurfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.stitchOutlineVariant, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildRangeChip('1 NM', _radarRangeNm == 1.0, () {
                          HapticFeedback.selectionClick();
                          setState(() => _radarRangeNm = 1.0);
                        }),
                        _buildRangeChip('2 NM', _radarRangeNm == 2.0, () {
                          HapticFeedback.selectionClick();
                          setState(() => _radarRangeNm = 2.0);
                        }),
                        _buildRangeChip('5 NM', _radarRangeNm == 5.0, () {
                          HapticFeedback.selectionClick();
                          setState(() => _radarRangeNm = 5.0);
                        }),
                      ],
                    ),
                  ),

                  // Audio Chime Toggle
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _chimeEnabled = !_chimeEnabled);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _chimeEnabled ? AppColors.stitchSecondaryContainer : AppColors.stitchSurfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _chimeEnabled ? AppColors.stitchSecondary : AppColors.stitchOutlineVariant,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _chimeEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            size: 13,
                            color: _chimeEnabled ? AppColors.stitchSecondary : AppColors.stitchOutline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _chimeEnabled ? 'CHIME ON' : 'MUTED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _chimeEnabled ? AppColors.stitchSecondary : AppColors.stitchOutline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 4. AIS Target 1: Trawler Meenakshi (Interactive Pill)
            Positioned(
              top: center.dy - 65,
              left: center.dx + 48,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceContainerLowest.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.stitchPrimary, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_boat_filled_rounded, size: 10, color: AppColors.stitchPrimary),
                    SizedBox(width: 4),
                    Text(
                      'AIS: MEENAKSHI · 0.8 NM · 6.2 KT',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: AppColors.stitchPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. Shoal Hazard Blip
            Positioned(
              top: center.dy + 45,
              left: center.dx + 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AppColors.stitchTertiaryContainer.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.stitchTertiary, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dangerous_rounded, size: 10, color: AppColors.stitchOnTertiaryContainer),
                    SizedBox(width: 3),
                    Text(
                      'SHOAL 1.8M DEPTH',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: AppColors.stitchOnTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 6. Sri Lanka IMBL Border Pill
            Positioned(
              top: center.dy - 95,
              right: 18,
              child: GestureDetector(
                onTap: widget.onImblTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainerLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.stitchError, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.stitchError.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.stitchError,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'IMBL · ${widget.imblDistanceKm.toStringAsFixed(1)} KM',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.stitchError,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 7. Center Vessel Marker
            Positioned(
              left: center.dx - 22,
              top: center.dy - 22,
              child: GestureDetector(
                onTap: widget.onVesselTap,
                child: Transform.rotate(
                  angle: (_radarOrientation == 'HEAD-UP' ? 0.0 : widget.vesselHeadingDeg) * math.pi / 180,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.stitchSecondary,
                      border: Border.all(color: Colors.white, width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.stitchSecondary.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 8. Bottom Interactive Hazard Alert Deck Card
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.stitchSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isDiversionEngaged ? AppColors.stitchSecondary : AppColors.stitchTertiary,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isDiversionEngaged ? Icons.verified_rounded : Icons.waves_rounded,
                              size: 16,
                              color: _isDiversionEngaged ? AppColors.stitchSecondary : AppColors.stitchTertiary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isDiversionEngaged
                                  ? 'AUTO-DIVERSION ROUTE ACTIVE'
                                  : 'ALERT: SWELL CLUSTER 1.2 NM AHEAD',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                color: _isDiversionEngaged ? AppColors.stitchSecondary : AppColors.stitchTertiary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SWELL: 2.2M',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: _isDiversionEngaged ? AppColors.stitchSecondary : AppColors.stitchTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isDiversionEngaged
                                ? 'Steering 085° ESE to skirt northern shoal fringe. Safe sea state cleared.'
                                : 'Wave cluster bearing 140° SE. Estimated pitch rolling +12°. Safe speed advised: 6 kt.',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.stitchOnSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isDiversionEngaged ? AppColors.stitchSecondary : AppColors.stitchTertiary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: Icon(
                              _isDiversionEngaged ? Icons.check_circle_rounded : Icons.alt_route_rounded,
                              size: 15,
                            ),
                            label: Text(
                              _isDiversionEngaged ? 'Diversion Engaged' : 'Auto-Plot Diversion (+8m)',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                            ),
                            onPressed: () {
                              HapticFeedback.heavyImpact();
                              setState(() => _isDiversionEngaged = !_isDiversionEngaged);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: _isDiversionEngaged ? AppColors.stitchSecondary : AppColors.stitchPrimary,
                                  duration: const Duration(seconds: 2),
                                  content: Text(
                                    _isDiversionEngaged
                                        ? '🧭 Swell Evasive Course Plotted: Steer 085° ESE'
                                        : 'Resumed Direct PFZ Waypoint',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.stitchOnSurfaceVariant,
                            side: const BorderSide(color: AppColors.stitchOutlineVariant),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _isAlarmMuted = !_isAlarmMuted);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.stitchPrimary,
                                duration: const Duration(seconds: 1),
                                content: Text(_isAlarmMuted ? '🔕 Radar hazard chime muted for 15m' : '🔔 Radar chime enabled', style: const TextStyle(color: Colors.white)),
                              ),
                            );
                          },
                          child: Text(
                            _isAlarmMuted ? 'Muted (15m)' : 'Mute Chime',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.stitchPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.stitchOnSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildRangeChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.stitchPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.stitchOnSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _StitchRadarPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final double sweepAngle;
  final double rangeNm;
  final String orientation;
  final double headingDeg;
  final bool showPfzCourse;
  final bool showEvasiveCourse;

  _StitchRadarPainter({
    required this.center,
    required this.radius,
    required this.sweepAngle,
    required this.rangeNm,
    required this.orientation,
    required this.headingDeg,
    required this.showPfzCourse,
    required this.showEvasiveCourse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final safeCenter = Offset(
      (center.dx.isNaN || center.dx.isInfinite) ? size.width / 2 : center.dx,
      (center.dy.isNaN || center.dy.isInfinite) ? size.height * 0.38 : center.dy,
    );

    // 1. Radar Scope Background Disk
    final bgPaint = Paint()..color = const Color(0xFFF0F5F8);
    canvas.drawCircle(safeCenter, radius, bgPaint);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.stitchOutlineVariant
      ..strokeWidth = 1.4;
    canvas.drawCircle(safeCenter, radius, borderPaint);

    // 2. Concentric Range Rings (4 equidistant rings)
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = AppColors.stitchOutlineVariant.withOpacity(0.65);

    for (int i = 1; i <= 4; i++) {
      final r = radius * (i / 4.0);
      canvas.drawCircle(safeCenter, r, ringPaint);

      // Distance tag on ring
      final distLabel = '${(rangeNm * (i / 4.0)).toStringAsFixed(1)}NM';
      final tp = TextPainter(
        text: TextSpan(
          text: distLabel,
          style: const TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            color: AppColors.stitchOutline,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(safeCenter.dx + 3, safeCenter.dy - r - 9));
    }

    // 3. Radial Crosshairs & Degree Marks
    final crossPaint = Paint()
      ..color = AppColors.stitchOutlineVariant.withOpacity(0.5)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(safeCenter.dx - radius, safeCenter.dy), Offset(safeCenter.dx + radius, safeCenter.dy), crossPaint);
    canvas.drawLine(Offset(safeCenter.dx, safeCenter.dy - radius), Offset(safeCenter.dx, safeCenter.dy + radius), crossPaint);

    // Cardinal Labels
    final double rotOffset = orientation == 'HEAD-UP' ? -(headingDeg * math.pi / 180) : 0.0;
    _drawCardinal(canvas, safeCenter, radius - 14, 0 + rotOffset, 'N');
    _drawCardinal(canvas, safeCenter, radius - 14, math.pi / 2 + rotOffset, 'E');
    _drawCardinal(canvas, safeCenter, radius - 14, math.pi + rotOffset, 'S');
    _drawCardinal(canvas, safeCenter, radius - 14, 3 * math.pi / 2 + rotOffset, 'W');

    // 4. Radar Sweep Sector Cone (Rotating phosphor beam)
    final sweepNormX = (safeCenter.dx / size.width).clamp(0.0, 1.0);
    final sweepNormY = (safeCenter.dy / size.height).clamp(0.0, 1.0);

    final double safeSweep = sweepAngle.clamp(0.0, 2 * math.pi);
    final double start = math.max(0.0, safeSweep - 0.5);
    final double end = math.max(start + 0.01, safeSweep);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset(sweepNormX, sweepNormY),
        startAngle: start,
        endAngle: end,
        colors: [
          Colors.transparent,
          AppColors.stitchPrimary.withOpacity(0.16),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: safeCenter, radius: radius));

    canvas.drawCircle(safeCenter, radius, sweepPaint);

    // Sweep leading edge line
    final sweepEdgePaint = Paint()
      ..color = AppColors.stitchPrimary.withOpacity(0.6)
      ..strokeWidth = 1.2;
    final edgeX = safeCenter.dx + radius * math.cos(safeSweep);
    final edgeY = safeCenter.dy + radius * math.sin(safeSweep);
    canvas.drawLine(safeCenter, Offset(edgeX, edgeY), sweepEdgePaint);

    // 5. Swell Arc Clusters (Hazard Swell at bearing 140° SE, approx 1.2 NM)
    final swellPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = AppColors.stitchTertiary;

    final swellCenter = Offset(safeCenter.dx + radius * 0.58 * math.cos(140 * math.pi / 180),
        safeCenter.dy + radius * 0.58 * math.sin(140 * math.pi / 180));

    canvas.drawArc(
      Rect.fromCircle(center: swellCenter, radius: 14),
      -math.pi / 3,
      2 * math.pi / 3,
      false,
      swellPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: swellCenter, radius: 20),
      -math.pi / 3,
      2 * math.pi / 3,
      false,
      swellPaint,
    );

    // 6. Navigation Route Vectors (PFZ or Evasive Diversion)
    if (showPfzCourse) {
      final pfzPaint = Paint()
        ..color = AppColors.stitchSecondary
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      final pfzTarget = Offset(safeCenter.dx - radius * 0.55, safeCenter.dy + radius * 0.35);
      canvas.drawLine(safeCenter, pfzTarget, pfzPaint);

      final pfzDot = Paint()..color = AppColors.stitchSecondary;
      canvas.drawCircle(pfzTarget, 4.5, pfzDot);
    }

    if (showEvasiveCourse) {
      final evasivePaint = Paint()
        ..color = AppColors.stitchPrimary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final evasiveTarget = Offset(safeCenter.dx - radius * 0.70, safeCenter.dy - radius * 0.15);
      canvas.drawLine(safeCenter, evasiveTarget, evasivePaint);

      final evasiveDot = Paint()..color = AppColors.stitchPrimary;
      canvas.drawCircle(evasiveTarget, 5.0, evasiveDot);
    }

    // 7. IMBL Maritime Line
    final imblPaint = Paint()
      ..color = AppColors.stitchError.withOpacity(0.8)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final borderPath = Path();
    borderPath.moveTo(safeCenter.dx + radius * 0.35, safeCenter.dy - radius * 0.95);
    borderPath.lineTo(safeCenter.dx + radius * 0.95, safeCenter.dy - radius * 0.20);
    canvas.drawPath(borderPath, imblPaint);
  }

  void _drawCardinal(Canvas canvas, Offset center, double dist, double angleRad, String label) {
    final x = center.dx + dist * math.sin(angleRad);
    final y = center.dy - dist * math.cos(angleRad);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.stitchPrimary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _StitchRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.rangeNm != rangeNm ||
        oldDelegate.orientation != orientation ||
        oldDelegate.showPfzCourse != showPfzCourse ||
        oldDelegate.showEvasiveCourse != showEvasiveCourse;
  }
}
