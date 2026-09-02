import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AudioWaveformVisualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;
  final double height;
  final Color primaryColor;

  const AudioWaveformVisualizer({
    super.key,
    required this.isPlaying,
    this.barCount = 24,
    this.height = 36.0,
    this.primaryColor = AppColors.radarCyan,
  });

  @override
  State<AudioWaveformVisualizer> createState() => _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final Random _random = Random(42);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    if (widget.isPlaying) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _animController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _animController.stop();
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              // Generate dynamic pseudo-random height factor modulated by animation
              final baseFactor = 0.2 + (_random.nextDouble() * 0.8);
              final animFactor = widget.isPlaying ? sin((index * 0.4) + (_animController.value * pi * 2)).abs() : 0.2;
              final barHeight = widget.height * (0.15 + (baseFactor * animFactor * 0.85));

              return Container(
                width: 3,
                height: barHeight,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: widget.isPlaying ? widget.primaryColor : AppColors.marineSurface,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.isPlaying
                      ? [
                          BoxShadow(
                            color: widget.primaryColor.withOpacity(0.35),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
