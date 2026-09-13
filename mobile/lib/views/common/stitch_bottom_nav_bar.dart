import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

class StitchBottomNavBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final bool hasAlert;

  const StitchBottomNavBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    this.hasAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.stitchSurface.withOpacity(0.95),
            border: const Border(
              top: BorderSide(color: AppColors.stitchOutlineVariant, width: 1.0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 58,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabItem(
                    index: 0,
                    icon: Icons.explore_rounded,
                    label: 'Map',
                    isActive: activeIndex == 0,
                  ),
                  _buildTabItem(
                    index: 1,
                    icon: Icons.shield_rounded,
                    label: 'Safety',
                    isActive: activeIndex == 1,
                    showDot: hasAlert,
                  ),
                  _buildTabItem(
                    index: 2,
                    icon: Icons.smart_toy_rounded,
                    label: 'Voice AI',
                    isActive: activeIndex == 2,
                  ),
                  _buildTabItem(
                    index: 3,
                    icon: Icons.radar_rounded,
                    label: 'Radar',
                    isActive: activeIndex == 3,
                  ),
                  _buildTabItem(
                    index: 4,
                    icon: Icons.offline_pin_rounded,
                    label: 'Offline',
                    isActive: activeIndex == 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isActive,
    bool showDot = false,
  }) {
    final activeColor = AppColors.stitchPrimary;
    final inactiveColor = AppColors.stitchOnSurfaceVariant;
    final activeBg = AppColors.stitchPrimaryFixed.withOpacity(0.35);

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTabSelected(index);
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive ? activeColor : inactiveColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                if (showDot)
                  Positioned(
                    top: -2,
                    right: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.stitchError,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
