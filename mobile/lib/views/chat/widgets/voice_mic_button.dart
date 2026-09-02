import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class VoiceMicButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingEnd;
  final String currentLanguage;

  const VoiceMicButton({
    super.key,
    required this.isRecording,
    required this.onRecordingStart,
    required this.onRecordingEnd,
    required this.currentLanguage,
  });

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant VoiceMicButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat();
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handlePressDown() {
    HapticFeedback.heavyImpact();
    widget.onRecordingStart();
  }

  void _handlePressUp() {
    HapticFeedback.mediumImpact();
    widget.onRecordingEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => _handlePressDown(),
          onTapUp: (_) => _handlePressUp(),
          onTapCancel: () => _handlePressUp(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Radar Pulse Ring (Active during recording)
              if (widget.isRecording)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 76 * _pulseAnimation.value,
                      height: 76 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.criticalRed.withOpacity(1.0 - (_pulseAnimation.value - 1.0) / 0.5),
                          width: 2.0,
                        ),
                      ),
                    );
                  },
                ),

              // 2. Primary Tactical Push-to-Talk Hero Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.isRecording ? 76 : 66,
                height: widget.isRecording ? 76 : 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isRecording
                        ? [AppColors.criticalRed, const Color(0xFFC62828)]
                        : [AppColors.primaryBlue, AppColors.navyDark],
                  ),
                  border: Border.all(
                    color: widget.isRecording ? Colors.white : AppColors.accentLight.withOpacity(0.6),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isRecording ? AppColors.criticalRed : AppColors.primaryBlue)
                          .withOpacity(widget.isRecording ? 0.6 : 0.35),
                      blurRadius: widget.isRecording ? 24 : 14,
                      spreadRadius: widget.isRecording ? 4 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isRecording ? Icons.mic : Icons.mic_none_rounded,
                  size: widget.isRecording ? 36 : 32,
                  color: AppColors.iceWhite,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Text Guidance
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: widget.isRecording ? AppColors.criticalRed : AppColors.accentLight,
            letterSpacing: 0.3,
          ),
          child: Text(
            widget.isRecording
                ? '🔴 Recording voice in ${widget.currentLanguage}... Release'
                : '🎙️ Hold to Speak • ${widget.currentLanguage}',
          ),
        ),
      ],
    );
  }
}
