import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';

class ImblBoundaryLayer {
  static PolylineLayer buildPolylineLayer({
    required List<LatLng> imblPoints,
  }) {
    return PolylineLayer(
      polylines: [
        Polyline(
          points: imblPoints,
          strokeWidth: 2.5,
          color: AppColors.safetyRed,
          isDotted: true,
        ),
      ],
    );
  }

  static MarkerLayer buildBorderWarningMarker({
    required LatLng markerPosition,
    VoidCallback? onTap,
    bool isDarkMode = false,
  }) {
    final cardBg = isDarkMode ? AppColors.brandSurfaceGlass : Colors.white.withOpacity(0.96);
    final borderColor = isDarkMode ? const Color(0xFFA94E4A) : const Color(0xFFEF4444);
    final textColor = isDarkMode ? const Color(0xFFFF9992) : const Color(0xFFDC2626);

    return MarkerLayer(
      markers: [
        Marker(
          point: markerPosition,
          width: 190,
          height: 38,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      size: 13,
                      color: AppColors.safetyRed,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'IMBL · Maintain clearance',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        color: textColor,
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
  }
}
