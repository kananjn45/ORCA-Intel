import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StitchAppHeader extends StatelessWidget {
  final String screenTitle;
  final String activePortName;
  final double latitude;
  final double longitude;
  final String currentLanguageCode;
  final VoidCallback? onLanguageTap;
  final VoidCallback? onSyncTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onPortTap;
  final VoidCallback? onBack;
  final bool isGpsHardwareActive;
  final bool showCoordinatesTicker;

  const StitchAppHeader({
    super.key,
    required this.screenTitle,
    this.activePortName = 'Rameswaram',
    required this.latitude,
    required this.longitude,
    this.currentLanguageCode = 'en',
    this.onLanguageTap,
    this.onSyncTap,
    this.onAvatarTap,
    this.onPortTap,
    this.onBack,
    this.isGpsHardwareActive = false,
    this.showCoordinatesTicker = true,
  });

  @override
  Widget build(BuildContext context) {
    final latFormatted = '${latitude.abs().toStringAsFixed(3)}°${latitude >= 0 ? 'N' : 'S'}';
    final lonFormatted = '${longitude.abs().toStringAsFixed(3)}°${longitude >= 0 ? 'E' : 'W'}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.stitchSurface.withOpacity(0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
        border: const Border(
          bottom: BorderSide(color: Color(0x1FBDC8CE), width: 1.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Brand + Status Chip + Subtitle | Language + Sync + Avatar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Brand Logo + GNSS Badge + Screen Title
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onBack != null) ...[
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.stitchOnSurface, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: onBack,
                          ),
                          const SizedBox(width: 4),
                        ],
                        // Tactical Marine Icon Badge
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.stitchPrimary, AppColors.stitchPrimaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.stitchPrimary.withOpacity(0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.directions_boat_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'ORCA',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.stitchPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: AppColors.stitchSecondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isGpsHardwareActive ? 'GNSS HARDWARE' : 'GNSS LOCK',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.stitchOnSecondaryContainer,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                screenTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOnSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: Language Switcher + Sync Badge + Profile Avatar
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Language Switcher Pill (EN / HI / TA)
                      InkWell(
                        onTap: onLanguageTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLangCode('EN', currentLanguageCode == 'en'),
                              const Text('/', style: TextStyle(fontSize: 10, color: AppColors.stitchOutline)),
                              _buildLangCode('HI', currentLanguageCode == 'hi'),
                              const Text('/', style: TextStyle(fontSize: 10, color: AppColors.stitchOutline)),
                              _buildLangCode('TA', currentLanguageCode == 'ta'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // SYNC Status Pill
                      InkWell(
                        onTap: onSyncTap,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.stitchSurfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_done_rounded,
                                size: 14,
                                color: AppColors.stitchSecondary,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'SYNC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.stitchSecondary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Avatar circle
                      InkWell(
                        onTap: onAvatarTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.stitchPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.stitchOnPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 5),

              // Row 2 Sub-banner: Port info & live telemetry coordinate banner
              InkWell(
                onTap: onPortTap,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.stitchSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.anchor_rounded,
                              size: 14,
                              color: AppColors.stitchPrimary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Port: $activePortName • ${isGpsHardwareActive ? "Device GPS" : "GPS Auto"}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.stitchOnSurfaceVariant,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (showCoordinatesTicker)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.stitchSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$latFormatted  $lonFormatted',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.stitchOnSurface,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.stitchSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'OFFLINE READY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.stitchSecondary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangCode(String code, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
          color: isActive ? AppColors.stitchPrimary : AppColors.stitchOnSurfaceVariant,
        ),
      ),
    );
  }
}
