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
    final activeColor = widget.isRecording ? AppColors.criticalRed : AppColors.radarCyan;

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
                      width: 80 * _pulseAnimation.value,
                      height: 80 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activeColor.withOpacity(1.0 - (_pulseAnimation.value - 1.0) / 0.5),
                          width: 2.5,
                        ),
                      ),
                    );
                  },
                ),

              // 2. Primary Tactile Push-to-Talk Hero Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.isRecording ? 82 : 72,
                height: widget.isRecording ? 82 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor,
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withOpacity(widget.isRecording ? 0.6 : 0.35),
                      blurRadius: widget.isRecording ? 30 : 16,
                      spreadRadius: widget.isRecording ? 5 : 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isRecording ? Icons.mic : Icons.mic_none,
                  size: widget.isRecording ? 40 : 36,
                  color: widget.isRecording ? Colors.white : AppColors.abyssBlack,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Text Guidance
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: widget.isRecording ? AppColors.criticalRed : AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
          child: Text(
            widget.isRecording
                ? '🔴 Listening in ${widget.currentLanguage}... Release to Send'
                : '🎙️ Hold to Speak in ${widget.currentLanguage}',
          ),
        ),
      ],
    );
  }
}
