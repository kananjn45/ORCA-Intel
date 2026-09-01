import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/chat_message_model.dart';
import 'audio_waveform_visualizer.dart';

class MessageCard extends StatefulWidget {
  final ChatMessageModel message;
  final VoidCallback? onPlayAudio;

  const MessageCard({
    super.key,
    required this.message,
    this.onPlayAudio,
  });

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool _isPlayingAudio = false;

  void _toggleAudio() {
    setState(() {
      _isPlayingAudio = !_isPlayingAudio;
    });
    widget.onPlayAudio?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.sender == MessageSender.user;
    final isEmergency = widget.message.isEmergency;

    Color cardBg;
    Color borderColor;

    if (isEmergency) {
      cardBg = AppColors.glassDanger;
      borderColor = AppColors.criticalRed;
    } else if (isUser) {
      cardBg = AppColors.marineSurface.withOpacity(0.65);
      borderColor = AppColors.radarCyan.withOpacity(0.3);
    } else {
      cardBg = AppColors.deepOcean.withOpacity(0.85);
      borderColor = AppColors.bioGreen.withOpacity(0.35);
    }

    return Container(
      margin: EdgeInsets.only(
        top: 6,
        bottom: 6,
        left: isUser ? 40 : 0,
        right: isUser ? 0 : 40,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: isEmergency ? 1.5 : 1),
        boxShadow: isEmergency
            ? [
                BoxShadow(
                  color: AppColors.criticalRed.withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sender Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isUser
                        ? Icons.person_pin_outlined
                        : (isEmergency ? Icons.warning_amber_rounded : Icons.smart_toy_outlined),
                    size: 14,
                    color: isEmergency
                        ? AppColors.criticalRed
                        : (isUser ? AppColors.radarCyan : AppColors.bioGreen),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isUser ? 'YOU (VOICE)' : (isEmergency ? 'SAFETY OVERRIDE' : 'ORCA MARINE AI'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isEmergency
                          ? AppColors.criticalRed
                          : (isUser ? AppColors.radarCyan : AppColors.bioGreen),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '${widget.message.timestamp.hour.toString().padLeft(2, '0')}:${widget.message.timestamp.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 2. High-Contrast Regional Language Spoken Advice
          Text(
            widget.message.textLocalized,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isEmergency ? AppColors.criticalRed : AppColors.textPrimary,
              height: 1.4,
            ),
          ),

          // 3. English Translated Subtitle (for verification & debug)
          if (widget.message.textEnglish != null && widget.message.textEnglish!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${widget.message.textEnglish}"',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],

          // 4. Playable Audio Strip (For ORCA Spoken Responses)
          if (!isUser) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.abyssBlack.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder.withOpacity(0.5), width: 0.8),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: _toggleAudio,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isEmergency ? AppColors.criticalRed : AppColors.radarCyan,
                      ),
                      child: Icon(
                        _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                        size: 16,
                        color: AppColors.abyssBlack,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AudioWaveformVisualizer(
                      isPlaying: _isPlayingAudio,
                      height: 20,
                      barCount: 18,
                      primaryColor: isEmergency ? AppColors.criticalRed : AppColors.radarCyan,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isPlayingAudio ? 'Playing...' : 'Voice Advice',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
