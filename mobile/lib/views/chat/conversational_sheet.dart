import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/chat_message_model.dart';
import 'widgets/message_card.dart';
import 'widgets/voice_mic_button.dart';

class ConversationalSheet extends StatefulWidget {
  final List<ChatMessageModel> messages;
  final String currentLanguageCode;
  final Function(String prompt)? onQuickPromptTap;
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingEnd;
  final bool isRecording;

  const ConversationalSheet({
    super.key,
    required this.messages,
    required this.currentLanguageCode,
    this.onQuickPromptTap,
    required this.onRecordingStart,
    required this.onRecordingEnd,
    required this.isRecording,
  });

  @override
  State<ConversationalSheet> createState() => _ConversationalSheetState();
}

class _ConversationalSheetState extends State<ConversationalSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;

  @override
  void didUpdateWidget(covariant ConversationalSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length > oldWidget.messages.length) {
      setState(() => _isExpanded = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(widget.currentLanguageCode);
    final quickPrompts = List<String>.from(loc['quickPrompts'] as List);

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomInset = mediaQuery.padding.bottom;

    final expandedHeight = (screenHeight * 0.58).clamp(380.0, 540.0);
    final collapsedHeight = 250.0 + bottomInset;

    final latestMessage = widget.messages.isNotEmpty ? widget.messages.last : null;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: _isExpanded ? expandedHeight : collapsedHeight,
          decoration: BoxDecoration(
            color: AppColors.abyssBlack.withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(
              top: BorderSide(color: AppColors.radarCyan.withOpacity(0.4), width: 1.2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Physical Touch Drag Handle & Header
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity! > 80) {
                      setState(() => _isExpanded = false);
                    } else if (details.primaryVelocity! < -80) {
                      setState(() => _isExpanded = true);
                    }
                  },
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: AppColors.radarCyan.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                  size: 18,
                                  color: AppColors.radarCyan,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isExpanded
                                      ? (loc['minimize'] as String).toUpperCase()
                                      : (loc['advisory'] as String).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.bioGreen.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.bioGreen.withOpacity(0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.verified, size: 11, color: AppColors.bioGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc['guardrails'] as String,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.bioGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(color: AppColors.glassBorder, height: 1),

                // 2. Body: Full Scrollable Chat OR Single Latest Advisory Teaser
                if (_isExpanded) ...[
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is OverscrollNotification && notification.overscroll < -15) {
                          setState(() => _isExpanded = false);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: widget.messages.length,
                        itemBuilder: (context, index) {
                          return MessageCard(message: widget.messages[index]);
                        },
                      ),
                    ),
                  ),
                ] else ...[
                  if (latestMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                      child: InkWell(
                        onTap: () => setState(() => _isExpanded = true),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.deepOcean,
                                AppColors.marineSurface.withOpacity(0.6),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.radarCyan.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.smart_toy_outlined, size: 14, color: AppColors.radarCyan),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  latestMessage.textLocalized,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                loc['details'] as String,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.radarCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],

                // 3. Tactically Styled Multilingual Quick Action Chips
                SizedBox(
                  height: 30,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: quickPrompts.length,
                    itemBuilder: (context, index) {
                      final prompt = quickPrompts[index];
                      Color chipAccent;
                      if (prompt.contains('PFZ')) {
                        chipAccent = AppColors.bioGreen;
                      } else if (prompt.contains('Border') || prompt.contains('எல்லை') || prompt.contains('सीमा')) {
                        chipAccent = AppColors.warningAmber;
                      } else if (prompt.contains('Wave') || prompt.contains('அலை') || prompt.contains('लहर')) {
                        chipAccent = AppColors.radarCyan;
                      } else {
                        chipAccent = AppColors.textAccent;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          backgroundColor: chipAccent.withOpacity(0.12),
                          side: BorderSide(color: chipAccent.withOpacity(0.5), width: 1.0),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          label: Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: chipAccent,
                            ),
                          ),
                          onPressed: () => widget.onQuickPromptTap?.call(prompt),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 4),

                // 4. Centered Tactile Push-to-Talk Mic
                VoiceMicButton(
                  isRecording: widget.isRecording,
                  onRecordingStart: widget.onRecordingStart,
                  onRecordingEnd: widget.onRecordingEnd,
                  currentLanguage: loc['name'] as String,
                ),

                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
