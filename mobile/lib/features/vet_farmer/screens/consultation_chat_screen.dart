import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_farmer/providers/vet_farmer_provider.dart';

/// Live consultation chat screen for the farmer side.
/// Shows messages, video call button, AI diagnosis, prescription, and rating.
class ConsultationChatScreen extends ConsumerStatefulWidget {
  final int consultationId;

  const ConsultationChatScreen({super.key, required this.consultationId});

  @override
  ConsumerState<ConsultationChatScreen> createState() =>
      _ConsultationChatScreenState();
}

class _ConsultationChatScreenState
    extends ConsumerState<ConsultationChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Load consultation data.
    Future.microtask(() {
      ref
          .read(consultationProvider.notifier)
          .loadConsultation(widget.consultationId);
    });
    // Poll for new messages every 5 seconds.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(consultationProvider.notifier).refreshMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(consultationProvider);

    // Auto-scroll when new messages arrive.
    ref.listen<ConsultationState>(consultationProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consultation')),
        body: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consultation')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: context.colorScheme.error),
              const SizedBox(height: 12),
              Text(state.error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => ref
                    .read(consultationProvider.notifier)
                    .loadConsultation(widget.consultationId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final consultation = state.consultation;
    if (consultation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consultation')),
        body: const Center(child: Text('No consultation data')),
      );
    }

    final isCompleted = consultation.status == ConsultationStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dr. ${consultation.vetName ?? 'Vet'}',
                style: const TextStyle(fontSize: 16)),
            Text(
              _statusLabel(consultation.status),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          // Video call button
          if (!isCompleted)
            IconButton(
              onPressed: () {
                context.showSnackBar('Video call feature coming soon');
              },
              icon: const Icon(Icons.videocam),
              tooltip: 'Video Call',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'end') _showEndConsultationDialog();
            },
            itemBuilder: (_) => [
              if (!isCompleted)
                const PopupMenuItem(
                  value: 'end',
                  child: Text('End Consultation'),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // AI diagnosis banner
          if (consultation.aiDiagnosis != null)
            _AiDiagnosisBanner(
              diagnosis: consultation.aiDiagnosis!,
              severity: consultation.triageSeverity,
            ),

          // Prescription card if available
          if (consultation.prescription != null)
            _PrescriptionCard(prescription: consultation.prescription!),

          // Chat messages
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: Text(
                      isCompleted
                          ? 'Consultation ended'
                          : 'Waiting for vet to respond...',
                      style: context.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) {
                      return _ChatBubble(
                        message: state.messages[index],
                        isMine: state.messages[index].senderRole == 'farmer',
                      );
                    },
                  ),
          ),

          // Rating prompt when consultation is completed
          if (isCompleted && consultation.rating == null)
            _RatingBar(
              onRate: (rating) async {
                await ref
                    .read(consultationProvider.notifier)
                    .rateConsultation(rating);
                if (context.mounted) {
                  context.showSnackBar('Thank you for your rating!');
                }
              },
            ),

          // Message input
          if (!isCompleted) _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              onPressed: _sendMessage,
              icon: Icon(Icons.send, color: context.colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    ref.read(consultationProvider.notifier).sendMessage(text);
    _messageController.clear();
  }

  void _showEndConsultationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Consultation'),
        content:
            const Text('Are you sure you want to end this consultation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('End'),
          ),
        ],
      ),
    );
  }

  String _statusLabel(ConsultationStatus status) {
    switch (status) {
      case ConsultationStatus.requested:
        return 'Waiting for vet...';
      case ConsultationStatus.accepted:
        return 'Accepted';
      case ConsultationStatus.in_progress:
        return 'In Progress';
      case ConsultationStatus.completed:
        return 'Completed';
      case ConsultationStatus.cancelled:
        return 'Cancelled';
    }
  }
}

// ---------------------------------------------------------------------------
// AI Diagnosis banner at the top of chat.
// ---------------------------------------------------------------------------
class _AiDiagnosisBanner extends StatelessWidget {
  final String diagnosis;
  final String? severity;

  const _AiDiagnosisBanner({required this.diagnosis, this.severity});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    if (severity == 'high') {
      bgColor = Colors.red.shade50;
    } else if (severity == 'medium') {
      bgColor = Colors.orange.shade50;
    } else {
      bgColor = Colors.green.shade50;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.smart_toy, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Diagnosis',
                  style: context.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(diagnosis, style: context.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Prescription card shown in the chat view.
// ---------------------------------------------------------------------------
class _PrescriptionCard extends StatelessWidget {
  final Prescription prescription;

  const _PrescriptionCard({required this.prescription});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        color: Colors.blue.shade50,
        child: ExpansionTile(
          leading: const Icon(Icons.medication, color: Colors.blue),
          title: const Text('Prescription'),
          subtitle: Text(
            '${prescription.medicines.length} medicine(s)',
            style: context.textTheme.bodySmall,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...prescription.medicines.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('\u2022 '),
                            Expanded(
                              child: Text(
                                '${m.name} - ${m.dosage}, ${m.frequency} for ${m.duration}',
                                style: context.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      )),
                  if (prescription.instructions.isNotEmpty) ...[
                    const Divider(),
                    Text('Instructions:',
                        style: context.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(prescription.instructions,
                        style: context.textTheme.bodySmall),
                  ],
                  if (prescription.followUpDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          'Follow-up: ${_formatDate(prescription.followUpDate!)}',
                          style: context.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// Chat bubble.
// ---------------------------------------------------------------------------
class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  const _ChatBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: context.screenWidth * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? context.colorScheme.primary
              : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.message,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.sentAt),
              style: TextStyle(
                color: isMine
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ---------------------------------------------------------------------------
// Rating bar shown after consultation ends.
// ---------------------------------------------------------------------------
class _RatingBar extends StatefulWidget {
  final Future<void> Function(double rating) onRate;

  const _RatingBar({required this.onRate});

  @override
  State<_RatingBar> createState() => _RatingBarState();
}

class _RatingBarState extends State<_RatingBar> {
  int _selectedStars = 0;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(top: BorderSide(color: Colors.amber.shade200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Rate this consultation',
              style: context.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () => setState(() => _selectedStars = index + 1),
                icon: Icon(
                  index < _selectedStars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              );
            }),
          ),
          if (_selectedStars > 0)
            FilledButton(
              onPressed: () async {
                await widget.onRate(_selectedStars.toDouble());
                setState(() => _submitted = true);
              },
              child: const Text('Submit Rating'),
            ),
        ],
      ),
    );
  }
}
