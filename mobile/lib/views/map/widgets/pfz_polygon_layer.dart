import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';

class PfzPolygonLayer {
  static PolygonLayer buildPolygonLayer({
    required List<LatLng> boundaryPoints,
  }) {
    return PolygonLayer(
      polygons: [
        Polygon(
          points: boundaryPoints,
          color: AppColors.neonLime.withOpacity(0.16),
          borderColor: AppColors.neonLime,
          borderStrokeWidth: 2.0,
          isDotted: true,
        ),
      ],
    );
  }

  static MarkerLayer buildCenterLabelMarker({
    required LatLng center,
    VoidCallback? onTap,
  }) {
    return MarkerLayer(
      markers: [
        Marker(
          point: center,
          width: 140,
          height: 44,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brandSurfaceGlass,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.neonLime.withOpacity(0.8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.eco_rounded,
                    size: 13,
                    color: AppColors.neonLime,
                  ),
                  SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PFZ · SECTOR 04',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonLime,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Chlorophyll front · Active',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: AppColors.inkLight,
                        ),
                      ),
                    ],
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
