import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';

// ---------------------------------------------------------------------------
// Dio provider for chat feature.
// ---------------------------------------------------------------------------
final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));
  return dio;
});

// ---------------------------------------------------------------------------
// Chat state.
// ---------------------------------------------------------------------------
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final String selectedLanguage;
  final String? conversationId;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.selectedLanguage = 'en',
    this.conversationId,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    String? selectedLanguage,
    String? conversationId,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        error: error,
        selectedLanguage: selectedLanguage ?? this.selectedLanguage,
        conversationId: conversationId ?? this.conversationId,
      );
}

// ---------------------------------------------------------------------------
// Chat notifier — manages messages, sending, and conversation history.
// ---------------------------------------------------------------------------
class ChatNotifier extends StateNotifier<ChatState> {
  final Dio _dio;

  ChatNotifier(this._dio) : super(const ChatState());

  /// Load conversation history from the server.
  Future<void> loadConversationHistory() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _dio.get('/conversations', queryParameters: {
        'channel': 'app',
        'limit': 1,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'];
        if (data is List && data.isNotEmpty) {
          final conversation =
              Conversation.fromJson(data.first as Map<String, dynamic>);
          state = state.copyWith(
            messages: conversation.messages,
            conversationId: conversation.id,
            isLoading: false,
          );
          return;
        }
      }
      state = state.copyWith(isLoading: false);
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.response?.data?['message'] as String? ??
            'Failed to load chat history',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Send a message to the AI chat endpoint.
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    // Add the user message to the list immediately.
    final userMessage = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.user,
      content: content.trim(),
      timestamp: DateTime.now(),
      language: state.selectedLanguage,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      error: null,
    );

    try {
      final response = await _dio.post('/chat/message', data: {
        'content': content.trim(),
        'language': state.selectedLanguage,
        if (state.conversationId != null)
          'conversation_id': state.conversationId,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final aiMessage = ChatMessage(
          id: data['message_id'] as String? ??
              'ai_${DateTime.now().millisecondsSinceEpoch}',
          role: ChatRole.assistant,
          content: data['response'] as String? ?? '',
          timestamp: DateTime.now(),
          language: state.selectedLanguage,
        );
        state = state.copyWith(
          messages: [...state.messages, aiMessage],
          isSending: false,
          conversationId:
              data['conversation_id'] as String? ?? state.conversationId,
        );
      } else {
        state = state.copyWith(
          isSending: false,
          error: body['message'] as String? ?? 'Failed to get response',
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.response?.data?['message'] as String? ??
            'Network error. Please try again.',
      );
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  /// Change the selected language.
  void setLanguage(String languageCode) {
    state = state.copyWith(selectedLanguage: languageCode);
  }

  /// Clear error.
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Clear the conversation and start fresh.
  void clearConversation() {
    state = const ChatState();
  }
}

// ---------------------------------------------------------------------------
// Providers.
// ---------------------------------------------------------------------------

/// Main chat state provider.
final chatProvider =
    StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(_dioProvider));
});

/// Convenience provider for the message list.
final messagesProvider = Provider.autoDispose<List<ChatMessage>>((ref) {
  return ref.watch(chatProvider).messages;
});

/// Convenience provider for the sending state (typing indicator).
final isSendingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(chatProvider).isSending;
});

/// Conversation history provider — loads on first access.
final conversationHistoryProvider = FutureProvider.autoDispose<void>((ref) async {
  final notifier = ref.read(chatProvider.notifier);
  await notifier.loadConversationHistory();
});

/// Selected language provider.
final selectedLanguageProvider = Provider.autoDispose<String>((ref) {
  return ref.watch(chatProvider).selectedLanguage;
});
