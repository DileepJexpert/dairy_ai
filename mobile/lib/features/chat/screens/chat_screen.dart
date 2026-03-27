import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';
import 'package:dairy_ai/features/chat/providers/chat_provider.dart';
import 'package:dairy_ai/features/chat/widgets/chat_bubble.dart';
import 'package:dairy_ai/features/chat/widgets/quick_action_chips.dart';
import 'package:dairy_ai/features/chat/widgets/typing_indicator.dart';

/// Main AI chat screen with text input, voice placeholder, and quick actions.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _showQuickActions = true;

  @override
  void initState() {
    super.initState();
    // Load conversation history on first open.
    Future.microtask(() {
      ref.read(chatProvider.notifier).loadConversationHistory();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    setState(() => _showQuickActions = false);
    _scrollToBottom();
  }

  void _handleQuickAction(QuickAction action) {
    ref.read(chatProvider.notifier).sendMessage(action.prompt);
    setState(() => _showQuickActions = false);
    _scrollToBottom();
  }

  void _openVoiceChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _VoiceChatRouteProxy(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final isSending = chatState.isSending;

    // Auto-scroll when new messages arrive.
    ref.listen<ChatState>(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          // Language selector.
          _LanguageSelector(
            selectedCode: chatState.selectedLanguage,
            onChanged: (code) {
              ref.read(chatProvider.notifier).setLanguage(code);
            },
          ),
          // New chat.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New conversation',
            onPressed: () {
              ref.read(chatProvider.notifier).clearConversation();
              setState(() => _showQuickActions = true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Error banner.
          if (chatState.error != null)
            MaterialBanner(
              content: Text(chatState.error!),
              backgroundColor: DairyTheme.errorRed.withOpacity(0.1),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(chatProvider.notifier).clearError(),
                  child: const Text('DISMISS'),
                ),
              ],
            ),

          // Messages list.
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? _EmptyState(
                        onQuickAction: _handleQuickAction,
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: messages.length + (isSending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && isSending) {
                            return const TypingIndicator();
                          }
                          return ChatBubble(message: messages[index]);
                        },
                      ),
          ),

          // Quick action chips.
          if (_showQuickActions && messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: QuickActionChips(onActionTap: _handleQuickAction),
            ),

          // Input bar.
          _ChatInputBar(
            controller: _textController,
            focusNode: _focusNode,
            isSending: isSending,
            onSend: _handleSend,
            onVoice: _openVoiceChat,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state with welcome message and quick actions.
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final ValueChanged<QuickAction> onQuickAction;

  const _EmptyState({required this.onQuickAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: DairyTheme.primaryGreen.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Namaste! I am your DairyAI assistant.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about dairy farming — milk prices, cattle health, feed plans, or connect with a vet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: DairyTheme.subtleGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              'Quick actions',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: QuickAction.values.map((action) {
                return ActionChip(
                  label: Text(action.label),
                  backgroundColor: DairyTheme.creamWhite,
                  side: BorderSide(color: DairyTheme.lightGreen),
                  onPressed: () => onQuickAction(action),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat input bar with text field, send, and voice buttons.
// ---------------------------------------------------------------------------
class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onVoice;

  const _ChatInputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Voice input button.
          IconButton(
            icon: const Icon(Icons.mic_outlined),
            color: DairyTheme.primaryGreen,
            tooltip: 'Voice input',
            onPressed: onVoice,
          ),
          // Text field.
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: TextStyle(color: DairyTheme.subtleGrey),
                filled: true,
                fillColor: DairyTheme.backgroundWhite,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          // Send button.
          IconButton(
            icon: isSending
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: DairyTheme.primaryGreen,
                    ),
                  )
                : const Icon(Icons.send),
            color: DairyTheme.primaryGreen,
            tooltip: 'Send',
            onPressed: isSending ? null : onSend,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Language selector popup.
// ---------------------------------------------------------------------------
class _LanguageSelector extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String> onChanged;

  const _LanguageSelector({
    required this.selectedCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = ChatLanguage.supported.firstWhere(
      (l) => l.code == selectedCode,
      orElse: () => ChatLanguage.supported.first,
    );

    return PopupMenuButton<String>(
      tooltip: 'Language',
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.language, size: 20),
          const SizedBox(width: 2),
          Text(
            current.code.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
      onSelected: onChanged,
      itemBuilder: (context) => ChatLanguage.supported
          .map((lang) => PopupMenuItem<String>(
                value: lang.code,
                child: Row(
                  children: [
                    if (lang.code == selectedCode)
                      Icon(Icons.check, size: 16, color: DairyTheme.primaryGreen)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(lang.nativeName),
                    const SizedBox(width: 8),
                    Text(
                      '(${lang.name})',
                      style: TextStyle(
                        color: DairyTheme.subtleGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Proxy to lazily import voice chat screen to avoid circular deps.
// ---------------------------------------------------------------------------
class _VoiceChatRouteProxy extends StatelessWidget {
  const _VoiceChatRouteProxy();

  @override
  Widget build(BuildContext context) {
    // Lazy import to avoid circular dependency at compile time.
    return const _VoiceChatPlaceholder();
  }
}

class _VoiceChatPlaceholder extends ConsumerWidget {
  const _VoiceChatPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Navigate to the actual voice chat screen via import.
    // This is a placeholder — the real import is in the router.
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Chat')),
      body: const Center(child: Text('Loading voice chat...')),
    );
  }
}
