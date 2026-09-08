import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class VesselHeadingMarker extends StatelessWidget {
  final double headingDeg;
  final double speedKnots;
  final VoidCallback? onTap;
  final bool isDarkMode;

  const VesselHeadingMarker({
    super.key,
    required this.headingDeg,
    required this.speedKnots,
    this.onTap,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // Heading in radians (0 is North, clockwise)
    final headingRad = (headingDeg * math.pi) / 180.0;

    final boatColor = isDarkMode ? AppColors.brandNavy : const Color(0xFF0284C7);
    final boatBorderColor = isDarkMode ? AppColors.neonLime : Colors.white;
    final iconColor = isDarkMode ? AppColors.neonLime : Colors.white;
    final glowColor = isDarkMode ? AppColors.neonLime : const Color(0xFF0284C7);

    final tooltipBg = isDarkMode ? AppColors.brandSurfaceGlass : Colors.white.withOpacity(0.96);
    final tooltipBorder = isDarkMode ? AppColors.cardBorder : const Color(0xFFCBD5E1);
    final tooltipText = isDarkMode ? AppColors.inkLight : const Color(0xFF0F172A);

    return GestureDetector(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Rotating boat icon with glowing halo
            Stack(
              alignment: Alignment.center,
              children: [
                // Outer radar pulse glow
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor.withOpacity(0.15),
                    border: Border.all(
                      color: glowColor.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                ),
                // Directional boat arrow rotated to heading
                Transform.rotate(
                  angle: headingRad,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: boatColor,
                      border: Border.all(
                        color: boatBorderColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withOpacity(isDarkMode ? 0.6 : 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.navigation_rounded,
                        size: 16,
                        color: iconColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Tooltip badge matching web .map-label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tooltipBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tooltipBorder,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Your vessel · ${speedKnots.toStringAsFixed(1)} kt',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: tooltipText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
