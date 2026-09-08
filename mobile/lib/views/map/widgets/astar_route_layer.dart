import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';

class AstarRouteLayer {
  static PolylineLayer buildPolylineLayer({
    required List<LatLng> waypoints,
    Color? color,
    bool isDarkMode = false,
  }) {
    final routeColor = color ?? (isDarkMode ? AppColors.electricCyan : const Color(0xFF0284C7));
    return PolylineLayer(
      polylines: [
        // Glow polyline underneath
        Polyline(
          points: waypoints,
          strokeWidth: 8.0,
          color: routeColor.withOpacity(0.25),
        ),
        // Crisp core navigation polyline
        Polyline(
          points: waypoints,
          strokeWidth: 4.0,
          color: routeColor,
        ),
      ],
    );
  }

  static MarkerLayer buildDestinationMarkerLayer({
    required LatLng destination,
    required String label,
    VoidCallback? onTap,
    bool isDarkMode = false,
  }) {
    final cardBg = isDarkMode ? AppColors.brandSurfaceGlass : Colors.white.withOpacity(0.96);
    final borderColor = isDarkMode ? AppColors.neonLime : const Color(0xFF16A34A);
    final textColor = isDarkMode ? AppColors.neonLime : const Color(0xFF15803D);
    final beaconColor = isDarkMode ? AppColors.neonLime : const Color(0xFF16A34A);
    final beaconBorder = isDarkMode ? AppColors.brandNavy : Colors.white;

    return MarkerLayer(
      markers: [
        Marker(
          point: destination,
          width: 140,
          height: 60,
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Destination tooltip label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                // Glowing circular destination beacon
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: beaconColor,
                    border: Border.all(
                      color: beaconBorder,
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: beaconColor.withOpacity(isDarkMode ? 0.8 : 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
