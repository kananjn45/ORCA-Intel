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
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 10 + bottomInset),
          decoration: BoxDecoration(
            color: AppColors.cardSurface.withOpacity(0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: const Border(
              top: BorderSide(color: AppColors.navyDark, width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 24,
                offset: const Offset(0, -6),
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
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withOpacity(0.3),
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
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'MARINE INTELLIGENCE ADVISOR',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.iceWhite,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.navyDark.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, size: 11, color: AppColors.bioGreen),
                        const SizedBox(width: 4),
                        Text(
                          loc['guardrails'] as String,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 3. Executive Marine Intelligence Card (No fake chat bubbles)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.cardSurfaceLight,
                      AppColors.cardSurface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.navyDark, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Localized Advisory
                    Text(
                      advisoryText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.iceWhite,
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
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentLight,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

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
                        backgroundColor: AppColors.cardSurfaceLight,
                        side: BorderSide(
                          color: AppColors.navyDark,
                          width: 1.0,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        label: Text(
                          prompt,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.iceWhite,
                          ),
                        ),
                        onPressed: () => onQuickPromptTap?.call(prompt),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),

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
