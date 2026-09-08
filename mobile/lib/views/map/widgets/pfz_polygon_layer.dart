import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';

class PfzPolygonLayer {
  static PolygonLayer buildPolygonLayer({
    required List<LatLng> boundaryPoints,
    bool isDarkMode = false,
  }) {
    final strokeColor = isDarkMode ? AppColors.neonLime : const Color(0xFF16A34A);
    return PolygonLayer(
      polygons: [
        Polygon(
          points: boundaryPoints,
          color: strokeColor.withOpacity(0.14),
          borderColor: strokeColor,
          borderStrokeWidth: 2.0,
          isDotted: true,
        ),
      ],
    );
  }

  static MarkerLayer buildCenterLabelMarker({
    required LatLng center,
    VoidCallback? onTap,
    bool isDarkMode = false,
  }) {
    final cardBg = isDarkMode ? AppColors.brandSurfaceGlass : Colors.white.withOpacity(0.96);
    final borderColor = isDarkMode ? AppColors.neonLime.withOpacity(0.8) : const Color(0xFF16A34A);
    final iconColor = isDarkMode ? AppColors.neonLime : const Color(0xFF16A34A);
    final titleColor = isDarkMode ? AppColors.neonLime : const Color(0xFF15803D);
    final subtitleColor = isDarkMode ? AppColors.inkLight : const Color(0xFF334155);

    return MarkerLayer(
      markers: [
        Marker(
          point: center,
          width: 190,
          height: 48,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(8),
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
                    Icon(
                      Icons.eco_rounded,
                      size: 13,
                      color: iconColor,
                    ),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PFZ · SECTOR 04',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Chlorophyll front · Active',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                      ],
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
