import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class MapLayerControls extends StatefulWidget {
  final bool showRoute;
  final bool showPfz;
  final bool showHazards;
  final bool showImbl;
  final VoidCallback onToggleRoute;
  final VoidCallback onTogglePfz;
  final VoidCallback onToggleHazards;
  final VoidCallback onToggleImbl;
  final bool isDarkMode;
  final bool initiallyExpanded;

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
    this.isDarkMode = true,
    this.initiallyExpanded = true,
  });

  @override
  State<MapLayerControls> createState() => _MapLayerControlsState();
}

class _MapLayerControlsState extends State<MapLayerControls> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  Widget _buildLayerChip({
    required String label,
    required Color dotColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDarkMode;
    final activeBg = isDark
        ? AppColors.brandSurfaceGlass
        : Colors.white.withOpacity(0.95);
    final inactiveBg = isDark
        ? const Color(0x66082537)
        : const Color(0xB3E2E8F0);
    final activeText = isDark ? AppColors.inkLight : const Color(0xFF0F172A);
    final inactiveText = isDark
        ? AppColors.textMuted.withOpacity(0.6)
        : const Color(0xFF64748B);

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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive
                    ? (isDark ? AppColors.glassBorderSubtle : const Color(0xFF94A3B8))
                    : Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                        blurRadius: 6,
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
                    color: isActive ? dotColor : dotColor.withOpacity(0.35),
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
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: isActive ? activeText : inactiveText,
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
    final isDark = widget.isDarkMode;
    final activeCount = [
      widget.showRoute,
      widget.showPfz,
      widget.showHazards,
      widget.showImbl
    ].where((e) => e).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Collapsible Header Button
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isExpanded = !_isExpanded);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xD9041926)
                      : Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? AppColors.cardBorder.withOpacity(0.5)
                        : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.layers_rounded,
                      size: 13,
                      color: isDark ? AppColors.neonLime : const Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Layers ($activeCount)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.inkLight : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Expanded Layer Chips
        if (_isExpanded) ...[
          const SizedBox(height: 6),
          _buildLayerChip(
            label: 'Route',
            dotColor: AppColors.electricCyan,
            isActive: widget.showRoute,
            onTap: widget.onToggleRoute,
          ),
          const SizedBox(height: 5),
          _buildLayerChip(
            label: 'PFZ',
            dotColor: AppColors.neonLime,
            isActive: widget.showPfz,
            onTap: widget.onTogglePfz,
          ),
          const SizedBox(height: 5),
          _buildLayerChip(
            label: 'Hazards',
            dotColor: AppColors.hazardAmber,
            isActive: widget.showHazards,
            onTap: widget.onToggleHazards,
          ),
          const SizedBox(height: 5),
          _buildLayerChip(
            label: 'IMBL',
            dotColor: AppColors.safetyRed,
            isActive: widget.showImbl,
            onTap: widget.onToggleImbl,
          ),
        ],
      ],
    );
  }
}
