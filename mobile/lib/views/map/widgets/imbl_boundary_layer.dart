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
  }) {
    return MarkerLayer(
      markers: [
        Marker(
          point: markerPosition,
          width: 145,
          height: 32,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandSurfaceGlass,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: const Color(0xFFA94E4A),
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 12,
                    color: AppColors.safetyRed,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'IMBL · Maintain clearance',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF9992),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
