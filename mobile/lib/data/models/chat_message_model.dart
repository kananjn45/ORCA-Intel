enum MessageSender { user, orca }

class ChatMessageModel {
  final String id;
  final MessageSender sender;
  final String textLocalized;
  final String? textEnglish;
  final String? audioBase64;
  final String? audioLocalPath;
  final DateTime timestamp;
  final bool isEmergency;
  final List<String> quickReplies;

  const ChatMessageModel({
    required this.id,
    required this.sender,
    required this.textLocalized,
    this.textEnglish,
    this.audioBase64,
    this.audioLocalPath,
    required this.timestamp,
    this.isEmergency = false,
    this.quickReplies = const [],
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      sender: (json['sender'] as String) == 'user' 
          ? MessageSender.user 
          : MessageSender.orca,
      textLocalized: json['text_localized'] as String? ?? '',
      textEnglish: json['text_english'] as String?,
      audioBase64: json['audio_base64'] as String?,
      audioLocalPath: json['audio_local_path'] as String?,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String) 
          : DateTime.now(),
      isEmergency: json['is_emergency'] as bool? ?? false,
      quickReplies: (json['quick_replies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender == MessageSender.user ? 'user' : 'orca',
      'text_localized': textLocalized,
      'text_english': textEnglish,
      'audio_base64': audioBase64,
      'audio_local_path': audioLocalPath,
      'timestamp': timestamp.toIso8601String(),
      'is_emergency': isEmergency,
      'quick_replies': quickReplies,
    };
  }
}
