import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/chat/models/chat_models.dart';

/// A chat bubble widget that renders differently for user and AI messages.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  bool get _isUser => message.role == ChatRole.user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showCopyMenu(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: EdgeInsets.only(
            left: _isUser ? 48 : 8,
            right: _isUser ? 8 : 48,
            top: 4,
            bottom: 4,
          ),
          child: Column(
            crossAxisAlignment:
                _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isUser
                      ? DairyTheme.primaryGreen
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(_isUser ? 16 : 4),
                    bottomRight: Radius.circular(_isUser ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.smart_toy_outlined,
                              size: 14,
                              color: DairyTheme.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DairyAI',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: DairyTheme.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildMessageContent(theme),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.only(top: 2, left: 4, right: 4),
                child: Text(
                  _formatTimestamp(message.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: DairyTheme.subtleGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(ThemeData theme) {
    // For AI messages, render with basic markdown-like formatting.
    if (!_isUser) {
      return _MarkdownText(
        text: message.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: DairyTheme.darkText,
          height: 1.4,
        ),
      );
    }

    return Text(
      message.content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: Colors.white,
        height: 1.4,
      ),
    );
  }

  void _showCopyMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return time;
    }
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month $time';
  }
}

/// Lightweight markdown-like text renderer for AI responses.
/// Handles **bold**, *italic*, `code`, and newlines.
class _MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _MarkdownText({required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final spans = _parseMarkdown(text, style ?? const TextStyle());
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  List<TextSpan> _parseMarkdown(String input, TextStyle baseStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(
      r'(\*\*(.+?)\*\*)|(\*(.+?)\*)|(`(.+?)`)|([^*`]+)',
      dotAll: true,
    );

    for (final match in regex.allMatches(input)) {
      if (match.group(2) != null) {
        // Bold: **text**
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(4) != null) {
        // Italic: *text*
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (match.group(6) != null) {
        // Code: `text`
        spans.add(TextSpan(
          text: match.group(6),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.shade200,
          ),
        ));
      } else if (match.group(7) != null) {
        // Plain text
        spans.add(TextSpan(text: match.group(7), style: baseStyle));
      }
    }

    return spans;
  }
}
