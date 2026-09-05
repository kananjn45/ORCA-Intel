import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class VesselHeadingMarker extends StatelessWidget {
  final double headingDeg;
  final double speedKnots;
  final VoidCallback? onTap;

  const VesselHeadingMarker({
    super.key,
    required this.headingDeg,
    required this.speedKnots,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Heading in radians (0 is North, clockwise)
    final headingRad = (headingDeg * math.pi) / 180.0;

    return GestureDetector(
      onTap: onTap,
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
                  color: AppColors.neonLime.withOpacity(0.12),
                  border: Border.all(
                    color: AppColors.neonLime.withOpacity(0.35),
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
                    color: AppColors.brandNavy,
                    border: Border.all(
                      color: AppColors.neonLime,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonLime.withOpacity(0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.navigation_rounded,
                      size: 16,
                      color: AppColors.neonLime,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Tooltip badge matching web .map-label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.brandSurfaceGlass,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.cardBorder,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              'Your vessel · ${speedKnots.toStringAsFixed(1)} kt',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.inkLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
