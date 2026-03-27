import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_doctor/providers/vet_doctor_provider.dart';
import 'package:dairy_ai/features/vet_doctor/screens/prescription_form_screen.dart';

/// Vet-side consultation view: patient details, AI triage, chat, prescription,
/// video call, and ability to end consultation.
class VetConsultationScreen extends ConsumerStatefulWidget {
  final int consultationId;

  const VetConsultationScreen({super.key, required this.consultationId});

  @override
  ConsumerState<VetConsultationScreen> createState() =>
      _VetConsultationScreenState();
}

class _VetConsultationScreenState
    extends ConsumerState<VetConsultationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _diagnosisController = TextEditingController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(vetConsultationProvider.notifier)
          .loadConsultation(widget.consultationId);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(vetConsultationProvider.notifier).refreshMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _diagnosisController.dispose();
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
    final state = ref.watch(vetConsultationProvider);

    ref.listen<VetConsultationState>(vetConsultationProvider, (prev, next) {
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
                    .read(vetConsultationProvider.notifier)
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
        body: const Center(child: Text('No data')),
      );
    }

    final isActive = consultation.status == ConsultationStatus.in_progress ||
        consultation.status == ConsultationStatus.accepted;

    return Scaffold(
      appBar: AppBar(
        title: Text(consultation.farmerName),
        actions: [
          if (isActive)
            IconButton(
              onPressed: () {
                context.showSnackBar('Video call feature coming soon');
              },
              icon: const Icon(Icons.videocam),
              tooltip: 'Video Call',
            ),
          if (isActive)
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'prescription':
                    _navigateToPrescription();
                    break;
                  case 'end':
                    _showEndDialog();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'prescription',
                  child: ListTile(
                    leading: Icon(Icons.medication),
                    title: Text('Write Prescription'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'end',
                  child: ListTile(
                    leading: Icon(Icons.stop_circle, color: Colors.red),
                    title: Text('End Consultation'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Patient details card (collapsible)
          _PatientDetailsCard(consultation: consultation),

          // Chat area
          Expanded(
            child: state.messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start the conversation.',
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
                        isMine: state.messages[index].senderRole == 'vet',
                      );
                    },
                  ),
          ),

          // Message input
          if (isActive) _buildMessageInput(),
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
    ref.read(vetConsultationProvider.notifier).sendMessage(text);
    _messageController.clear();
  }

  void _navigateToPrescription() {
    final consultation = ref.read(vetConsultationProvider).consultation;
    if (consultation == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrescriptionFormScreen(
          consultationId: consultation.id,
        ),
      ),
    );
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Consultation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add your diagnosis (optional):'),
            const SizedBox(height: 12),
            TextField(
              controller: _diagnosisController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Vet diagnosis...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await endConsultation(
                  ref,
                  consultationId: widget.consultationId,
                  vetDiagnosis: _diagnosisController.text.trim().isNotEmpty
                      ? _diagnosisController.text.trim()
                      : null,
                );
                if (context.mounted) {
                  context.showSnackBar('Consultation ended');
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (context.mounted) {
                  context.showSnackBar('Error: $e', isError: true);
                }
              }
            },
            child: const Text('End'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Patient details collapsible card.
// ---------------------------------------------------------------------------
class _PatientDetailsCard extends StatelessWidget {
  final dynamic consultation;

  const _PatientDetailsCard({required this.consultation});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ExpansionTile(
        leading: const Icon(Icons.pets),
        title: Text(
          consultation.cattleName ?? 'Cattle #${consultation.cattleId}',
          style: context.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          consultation.cattleBreed ?? '',
          style: context.textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (consultation.cattleTagId != null)
                  _DetailRow('Tag ID', consultation.cattleTagId!),
                _DetailRow('Farmer', consultation.farmerName),
                if (consultation.symptoms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Symptoms:',
                      style: context.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (consultation.symptoms as List<String>)
                        .map((s) => Chip(
                              label:
                                  Text(s, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              padding: EdgeInsets.zero,
                              labelPadding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                            ))
                        .toList(),
                  ),
                ],
                if (consultation.description != null &&
                    consultation.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Description:',
                      style: context.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(consultation.description!,
                      style: context.textTheme.bodySmall),
                ],
                if (consultation.aiDiagnosis != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.smart_toy,
                            size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Triage',
                                  style: context.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold)),
                              Text(consultation.aiDiagnosis!,
                                  style: context.textTheme.bodySmall),
                              if (consultation.triageSeverity != null)
                                Text(
                                  'Severity: ${consultation.triageSeverity}',
                                  style: context.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        consultation.triageSeverity == 'high'
                                            ? Colors.red
                                            : consultation.triageSeverity ==
                                                    'medium'
                                                ? Colors.orange
                                                : Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: context.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: context.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat bubble (vet side — isMine means vet sent it).
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
