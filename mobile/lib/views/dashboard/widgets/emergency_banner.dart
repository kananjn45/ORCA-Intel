import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/geofence_model.dart';

class EmergencyBanner extends StatefulWidget {
  final GeofenceModel geofence;
  final VoidCallback? onEngageEvasive;
  final VoidCallback? onDismiss;

  const EmergencyBanner({
    super.key,
    required this.geofence,
    this.onEngageEvasive,
    this.onDismiss,
  });

  @override
  State<EmergencyBanner> createState() => _EmergencyBannerState();
}

class _EmergencyBannerState extends State<EmergencyBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.35, end: 0.95).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCritical =
        widget.geofence.warningLevel == GeofenceWarningLevel.critical ||
        widget.geofence.lookaheadBreachProjected;

    final bannerColor = isCritical ? AppColors.criticalRed : AppColors.warningAmber;
    final evasive = widget.geofence.evasiveHeadingDeg ?? 265.0;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: bannerColor.withOpacity(_glowAnimation.value),
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withOpacity(_glowAnimation.value * 0.45),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Header + Flashing Icon + Dismiss
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bannerColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCritical
                          ? Icons.warning_rounded
                          : Icons.warning_amber_rounded,
                      color: bannerColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCritical
                              ? '🚨 CRITICAL IMBL PROXIMITY ALERT'
                              : '⚠️ IMBL CAUTION BUFFER (5 KM)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: bannerColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.geofence.lookaheadBreachProjected
                              ? '15-min vessel trajectory intersects international boundary'
                              : 'Vessel approaching sovereign maritime border',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.accentLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onDismiss != null)
                    InkWell(
                      onTap: widget.onDismiss,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurfaceLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.accentLight,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 2: Metrics chips
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'BORDER DIST',
                      value: '${widget.geofence.distanceToImblKm.toStringAsFixed(2)} KM',
                      highlightColor: bannerColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'TIME TO BREACH',
                      value: widget.geofence.timeToBreachMinutes != null
                          ? '~${widget.geofence.timeToBreachMinutes!.toStringAsFixed(1)} MIN'
                          : '< 10 MIN',
                      highlightColor: bannerColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'EVASIVE HEADING',
                      value: '${evasive.toStringAsFixed(0)}° W',
                      highlightColor: AppColors.iceWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Action Button
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bannerColor,
                    foregroundColor: isCritical ? Colors.white : AppColors.abyssBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.turn_left_rounded, size: 18),
                  label: Text(
                    'ENGAGE 180° RETURN VECTOR (${evasive.toStringAsFixed(0)}°)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  onPressed: widget.onEngageEvasive,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color highlightColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.accentLight,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: highlightColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
