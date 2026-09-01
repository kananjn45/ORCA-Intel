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

    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = (screenHeight * 0.58).clamp(380.0, 520.0);
    final collapsedHeight = 225.0;

    final latestMessage = widget.messages.isNotEmpty ? widget.messages.last : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: _isExpanded ? expandedHeight : collapsedHeight,
      decoration: BoxDecoration(
        color: AppColors.abyssBlack.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(
          top: BorderSide(color: AppColors.glassBorder, width: 1.2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 1. Physical Touch Drag Handle & Header (Listens to both Tap AND Vertical Drag)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! > 100) {
                  // Dragged down -> Collapse!
                  setState(() => _isExpanded = false);
                } else if (details.primaryVelocity! < -100) {
                  // Dragged up -> Expand!
                  setState(() => _isExpanded = true);
                }
              },
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Physical Pill Drag Bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.4),
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
                              _isExpanded ? (loc['minimize'] as String).toUpperCase() : (loc['advisory'] as String).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bioGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 10, color: AppColors.bioGreen),
                              const SizedBox(width: 4),
                              Text(
                                loc['guardrails'] as String,
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.bioGreen),
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

            // 2. Body: Scrollable message history or compact single preview
            if (_isExpanded) ...[
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // If user overscrolls downward at the top of the chat, collapse it!
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
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
                  child: InkWell(
                    onTap: () => setState(() => _isExpanded = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.deepOcean.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 13, color: AppColors.radarCyan),
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

            // 3. Multilingual Quick Action Chips
            SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: quickPrompts.length,
                itemBuilder: (context, index) {
                  final prompt = quickPrompts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      backgroundColor: AppColors.deepOcean,
                      side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      label: Text(
                        prompt,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      onPressed: () => widget.onQuickPromptTap?.call(prompt),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 6),

            // 4. Centered Tactile Push-to-Talk Mic
            VoiceMicButton(
              isRecording: widget.isRecording,
              onRecordingStart: widget.onRecordingStart,
              onRecordingEnd: widget.onRecordingEnd,
              currentLanguage: loc['name'] as String,
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
