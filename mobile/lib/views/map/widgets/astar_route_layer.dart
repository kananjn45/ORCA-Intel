import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';

class AstarRouteLayer {
  static PolylineLayer buildPolylineLayer({
    required List<LatLng> waypoints,
    Color color = AppColors.electricCyan,
  }) {
    return PolylineLayer(
      polylines: [
        // Glow polyline underneath
        Polyline(
          points: waypoints,
          strokeWidth: 8.0,
          color: color.withOpacity(0.25),
        ),
        // Crisp core navigation polyline
        Polyline(
          points: waypoints,
          strokeWidth: 4.0,
          color: color,
        ),
      ],
    );
  }

  static MarkerLayer buildDestinationMarkerLayer({
    required LatLng destination,
    required String label,
    VoidCallback? onTap,
  }) {
    return MarkerLayer(
      markers: [
        Marker(
          point: destination,
          width: 110,
          height: 60,
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Destination tooltip label matching web UI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandSurfaceGlass,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: AppColors.neonLime,
                      width: 1,
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
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neonLime,
                      letterSpacing: 0.3,
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
                    color: AppColors.neonLime,
                    border: Border.all(
                      color: AppColors.brandNavy,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonLime.withOpacity(0.8),
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
