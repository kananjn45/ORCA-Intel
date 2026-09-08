import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/chat_message_model.dart';
import 'widgets/voice_mic_button.dart';

class ConversationalSheet extends StatelessWidget {
  final ChatMessageModel? latestAdvisory;
  final String currentLanguageCode;
  final Function(String prompt)? onQuickPromptTap;
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingEnd;
  final bool isRecording;

  const ConversationalSheet({
    super.key,
    required this.latestAdvisory,
    required this.currentLanguageCode,
    this.onQuickPromptTap,
    required this.onRecordingStart,
    required this.onRecordingEnd,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(currentLanguageCode);
    final quickPrompts = List<String>.from(loc['quickPrompts'] as List);
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.padding.bottom;

    final advisoryText = latestAdvisory?.textLocalized ??
        (loc['weatherStatus'] as String? ?? 'கடல் அமைதியாக உள்ளது (அலை: 1.3மீ, காற்று: 12.5 நாட்ஸ்). பாதுகாப்பான மண்டலம்.');
    final englishText = latestAdvisory?.textEnglish ??
        (loc['weatherStatusEn'] as String? ?? 'Sea conditions calm (Wave: 1.3m, Wind: 12.5 kts). Sovereign waters safe.');

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottomInset),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 2. Console Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0284C7),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'MARINE INTELLIGENCE ADVISOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF16A34A)),
                        const SizedBox(width: 4),
                        Text(
                          loc['guardrails'] as String,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 3. Executive Marine Intelligence Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Localized Advisory
                    Text(
                      advisoryText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // English Audit Subtitle
                    Text(
                      englishText,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. Tactical Quick Inquiries
              SizedBox(
                height: 32,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  itemCount: quickPrompts.length,
                  itemBuilder: (context, index) {
                    final prompt = quickPrompts[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: const BorderSide(
                          color: Color(0xFFCBD5E1),
                          width: 1.0,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        label: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        onPressed: () => onQuickPromptTap?.call(prompt),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),

              // 5. Tactical Push-to-Talk Controller
              VoiceMicButton(
                isRecording: isRecording,
                onRecordingStart: onRecordingStart,
                onRecordingEnd: onRecordingEnd,
                currentLanguage: loc['name'] as String,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
