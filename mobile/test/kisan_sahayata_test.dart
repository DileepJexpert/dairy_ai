import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';

void main() {
  group('Kisan Sahayata Kendra & Chat Models Tests', () {
    test('ChatMessage JSON serialization and deserialization', () {
      final msg = ChatMessage(
        id: 'msg-101',
        role: ChatRole.user,
        content: 'KCC yojana loan kitna milta hai?',
        timestamp: DateTime(2026, 10, 27, 12, 0, 0),
        language: 'hi',
      );

      final json = msg.toJson();
      expect(json['id'], 'msg-101');
      expect(json['role'], 'user');
      expect(json['content'], 'KCC yojana loan kitna milta hai?');
      expect(json['language'], 'hi');

      final deserialized = ChatMessage.fromJson(json);
      expect(deserialized.id, msg.id);
      expect(deserialized.role, ChatRole.user);
      expect(deserialized.content, msg.content);
      expect(deserialized.language, 'hi');
    });

    test('Conversation serialization with multiple messages', () {
      final conv = Conversation(
        id: 'conv-555',
        farmerId: 'farmer-123',
        channel: 'app',
        messages: [
          ChatMessage(
            id: 'm1',
            role: ChatRole.user,
            content: 'थनैला रोग का उपचार बताएं',
            timestamp: DateTime.now(),
            language: 'hi',
          ),
          ChatMessage(
            id: 'm2',
            role: ChatRole.assistant,
            content: 'थनैला में पोटैशियम परमैंगनेट से थन धोएं और तुरंत डॉक्टर से संपर्क करें।',
            timestamp: DateTime.now(),
            language: 'hi',
          ),
        ],
        createdAt: DateTime.now(),
      );

      final json = conv.toJson();
      expect(json['id'], 'conv-555');
      expect((json['messages'] as List).length, 2);

      final restored = Conversation.fromJson(json);
      expect(restored.messages.length, 2);
      expect(restored.messages.first.role, ChatRole.user);
      expect(restored.messages.last.role, ChatRole.assistant);
    });

    test('Supported ChatLanguages include Hindi, English, Gujarati, and Marathi', () {
      final codes = ChatLanguage.supported.map((l) => l.code).toList();
      expect(codes.contains('hi'), isTrue);
      expect(codes.contains('en'), isTrue);
      expect(codes.contains('gu'), isTrue);
      expect(codes.contains('mr'), isTrue);
    });
  });
}
