import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_doctor/models/vet_doctor_models.dart';
import 'package:dairy_ai/features/vet_doctor/providers/vet_doctor_provider.dart';
import 'package:dairy_ai/features/vet_doctor/screens/vet_consultation_screen.dart';

/// Vet-side dashboard showing queue, active consultations, earnings, and rating.
class VetDashboardScreen extends ConsumerWidget {
  const VetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(vetDashboardProvider);
    final queueAsync = ref.watch(vetQueueProvider);
    final activeAsync = ref.watch(activeConsultationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vet Dashboard'),
        actions: [
          // Availability toggle
          dashboardAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stats.isAvailable ? 'Online' : 'Offline',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Switch(
                    value: stats.isAvailable,
                    onChanged: (val) async {
                      try {
                        await toggleVetAvailability(ref, isAvailable: val);
                      } catch (e) {
                        if (context.mounted) {
                          context.showSnackBar('Error: $e', isError: true);
                        }
                      }
                    },
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green.shade300,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(vetDashboardProvider);
          ref.invalidate(vetQueueProvider);
          ref.invalidate(activeConsultationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Stats cards ---
            dashboardAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator.adaptive(),
              )),
              error: (e, _) => Card(
                color: context.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading dashboard: $e'),
                ),
              ),
              data: (stats) => _StatsSection(stats: stats),
            ),
            const SizedBox(height: 24),

            // --- Pending requests ---
            Text(
              'Pending Requests',
              style: context.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            queueAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator.adaptive(),
              )),
              error: (e, _) => Card(
                color: context.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e'),
                ),
              ),
              data: (queue) {
                if (queue.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text('No pending requests',
                                style: context.textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: queue
                      .map((item) => _ConsultationRequestCard(
                            item: item,
                            onAccept: () async {
                              try {
                                await acceptConsultation(ref,
                                    consultationId: item.id);
                                await startConsultation(ref,
                                    consultationId: item.id);
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          VetConsultationScreen(
                                              consultationId: item.id),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  context.showSnackBar('Error: $e',
                                      isError: true);
                                }
                              }
                            },
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // --- Active consultations ---
            Text(
              'Active Consultations',
              style: context.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            activeAsync.when(
              loading: () => const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator.adaptive(),
              )),
              error: (e, _) => Card(
                color: context.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e'),
                ),
              ),
              data: (active) {
                if (active.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No active consultations',
                            style: context.textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey)),
                      ),
                    ),
                  );
                }
                return Column(
                  children: active
                      .map((item) => _ActiveConsultationCard(
                            item: item,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => VetConsultationScreen(
                                      consultationId: item.id),
                                ),
                              );
                            },
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row.
// ---------------------------------------------------------------------------
class _StatsSection extends StatelessWidget {
  final VetDashboardStats stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.pending_actions,
                label: 'Pending',
                value: '${stats.pendingRequests}',
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.chat,
                label: 'Active',
                value: '${stats.activeConsultations}',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.currency_rupee,
                label: "Today's Earnings",
                value: 'Rs ${stats.todayEarnings.toStringAsFixed(0)}',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.star,
                label: 'Rating',
                value: stats.overallRating.toStringAsFixed(1),
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: context.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, style: context.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending consultation request card.
// ---------------------------------------------------------------------------
class _ConsultationRequestCard extends StatelessWidget {
  final ConsultationQueueItem item;
  final VoidCallback onAccept;

  const _ConsultationRequestCard({
    required this.item,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final Color severityColor;
    if (item.triageSeverity == 'high') {
      severityColor = Colors.red;
    } else if (item.triageSeverity == 'medium') {
      severityColor = Colors.orange;
    } else {
      severityColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.farmerName,
                        style: context.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.cattleName ?? 'Cattle'} ${item.cattleTagId != null ? '(${item.cattleTagId})' : ''} - ${item.cattleBreed ?? ''}',
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (item.triageSeverity != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: severityColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      item.triageSeverity!.toUpperCase(),
                      style: TextStyle(
                        color: severityColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Symptoms
            if (item.symptoms.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.symptoms
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 6),
                        ))
                    .toList(),
              ),

            if (item.description != null && item.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description!,
                style: context.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (item.aiDiagnosis != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.smart_toy, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'AI: ${item.aiDiagnosis}',
                      style: context.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(_typeIcon(item.type), size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _typeLabel(item.type),
                  style: context.textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  _timeAgo(item.createdAt),
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(ConsultationType type) {
    switch (type) {
      case ConsultationType.chat:
        return Icons.chat;
      case ConsultationType.video:
        return Icons.videocam;
      case ConsultationType.in_person:
        return Icons.location_on;
    }
  }

  String _typeLabel(ConsultationType type) {
    switch (type) {
      case ConsultationType.chat:
        return 'Chat';
      case ConsultationType.video:
        return 'Video';
      case ConsultationType.in_person:
        return 'In Person';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Active consultation card.
// ---------------------------------------------------------------------------
class _ActiveConsultationCard extends StatelessWidget {
  final ConsultationQueueItem item;
  final VoidCallback onTap;

  const _ActiveConsultationCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.chat, color: Colors.blue),
        ),
        title: Text(item.farmerName),
        subtitle: Text(
          '${item.cattleName ?? 'Cattle'} - ${item.symptoms.take(2).join(', ')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
