import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class MapLayerControls extends StatelessWidget {
  final bool showRoute;
  final bool showPfz;
  final bool showHazards;
  final bool showImbl;
  final VoidCallback onToggleRoute;
  final VoidCallback onTogglePfz;
  final VoidCallback onToggleHazards;
  final VoidCallback onToggleImbl;

  const MapLayerControls({
    super.key,
    required this.showRoute,
    required this.showPfz,
    required this.showHazards,
    required this.showImbl,
    required this.onToggleRoute,
    required this.onTogglePfz,
    required this.onToggleHazards,
    required this.onToggleImbl,
  });

  Widget _buildLayerChip({
    required String label,
    required Color dotColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.brandSurfaceGlass
                  : const Color(0x66082537),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? AppColors.glassBorderSubtle
                    : Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: isActive ? dotColor : dotColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: dotColor.withOpacity(0.6),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isActive
                        ? AppColors.inkLight
                        : AppColors.textMuted.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildLayerChip(
          label: 'Route',
          dotColor: AppColors.electricCyan,
          isActive: showRoute,
          onTap: onToggleRoute,
        ),
        const SizedBox(height: 6),
        _buildLayerChip(
          label: 'PFZ',
          dotColor: AppColors.neonLime,
          isActive: showPfz,
          onTap: onTogglePfz,
        ),
        const SizedBox(height: 6),
        _buildLayerChip(
          label: 'Hazards',
          dotColor: AppColors.hazardAmber,
          isActive: showHazards,
          onTap: onToggleHazards,
        ),
        const SizedBox(height: 6),
        _buildLayerChip(
          label: 'IMBL',
          dotColor: AppColors.safetyRed,
          isActive: showImbl,
          onTap: onToggleImbl,
        ),
      ],
    );
  }
}
