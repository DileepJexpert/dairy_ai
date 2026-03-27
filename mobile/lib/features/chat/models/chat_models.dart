/// Data models for the AI chat feature.

enum ChatRole { user, assistant }

/// Represents a single chat message.
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final String? language;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.language,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      role: (json['role'] as String?) == 'user' ? ChatRole.user : ChatRole.assistant,
      content: json['content'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      language: json['language'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (language != null) 'language': language,
      };

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    String? language,
  }) =>
      ChatMessage(
        id: id ?? this.id,
        role: role ?? this.role,
        content: content ?? this.content,
        timestamp: timestamp ?? this.timestamp,
        language: language ?? this.language,
      );
}

/// A full conversation session.
class Conversation {
  final String id;
  final String farmerId;
  final String channel;
  final List<ChatMessage> messages;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.farmerId,
    required this.channel,
    required this.messages,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] ?? json['messages_json'] ?? [];
    final messages = (rawMessages as List<dynamic>)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
    return Conversation(
      id: json['id'] as String? ?? '',
      farmerId: json['farmer_id'] as String? ?? '',
      channel: json['channel'] as String? ?? 'app',
      messages: messages,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmer_id': farmerId,
        'channel': channel,
        'messages': messages.map((m) => m.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
      };
}

/// Supported languages for the chat.
class ChatLanguage {
  final String code;
  final String name;
  final String nativeName;

  const ChatLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  static const List<ChatLanguage> supported = [
    ChatLanguage(code: 'en', name: 'English', nativeName: 'English'),
    ChatLanguage(code: 'hi', name: 'Hindi', nativeName: '\u0939\u093F\u0902\u0926\u0940'),
    ChatLanguage(code: 'gu', name: 'Gujarati', nativeName: '\u0A97\u0AC1\u0A9C\u0AB0\u0ABE\u0AA4\u0AC0'),
    ChatLanguage(code: 'mr', name: 'Marathi', nativeName: '\u092E\u0930\u093E\u0920\u0940'),
    ChatLanguage(code: 'ta', name: 'Tamil', nativeName: '\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD'),
    ChatLanguage(code: 'te', name: 'Telugu', nativeName: '\u0C24\u0C46\u0C32\u0C41\u0C17\u0C41'),
    ChatLanguage(code: 'kn', name: 'Kannada', nativeName: '\u0C95\u0CA8\u0CCD\u0CA8\u0CA1'),
  ];
}

/// Quick action types for the chat.
enum QuickAction {
  checkMilkPrice('Check milk price', 'What is the current milk price in my district?'),
  healthAdvice('Health advice', 'My cattle is showing some symptoms, can you help?'),
  feedPlan('Feed plan', 'Suggest an optimal feed plan for my cattle.'),
  callVet('Call vet', 'I need to consult a veterinarian.');

  final String label;
  final String prompt;

  const QuickAction(this.label, this.prompt);
}
