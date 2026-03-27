import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/admin/models/admin_models.dart';
import 'package:dairy_ai/features/admin/providers/admin_provider.dart';

/// Consultation monitoring screen with status filters.
class AdminConsultationsScreen extends ConsumerWidget {
  const AdminConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(adminConsultationsProvider);
    final statusFilter = ref.watch(consultationStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Consultations')),
      body: Column(
        children: [
          // ---------- Status filter ----------
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatusFilterChip(
                  label: 'All',
                  value: 'all',
                  current: statusFilter,
                  onTap: () => ref
                      .read(consultationStatusFilterProvider.notifier)
                      .state = 'all',
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Requested',
                  value: 'requested',
                  current: statusFilter,
                  color: Colors.orange,
                  onTap: () => ref
                      .read(consultationStatusFilterProvider.notifier)
                      .state = 'requested',
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'In Progress',
                  value: 'in_progress',
                  current: statusFilter,
                  color: Colors.blue,
                  onTap: () => ref
                      .read(consultationStatusFilterProvider.notifier)
                      .state = 'in_progress',
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Completed',
                  value: 'completed',
                  current: statusFilter,
                  color: DairyTheme.primaryGreen,
                  onTap: () => ref
                      .read(consultationStatusFilterProvider.notifier)
                      .state = 'completed',
                ),
                const SizedBox(width: 8),
                _StatusFilterChip(
                  label: 'Cancelled',
                  value: 'cancelled',
                  current: statusFilter,
                  color: Colors.red,
                  onTap: () => ref
                      .read(consultationStatusFilterProvider.notifier)
                      .state = 'cancelled',
                ),
              ],
            ),
          ),

          // ---------- Consultation list ----------
          Expanded(
            child: consultationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load consultations',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(adminConsultationsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (consultations) {
                if (consultations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64, color: DairyTheme.subtleGrey),
                        const SizedBox(height: 12),
                        Text(
                          'No consultations found',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: DairyTheme.subtleGrey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(adminConsultationsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: consultations.length,
                    itemBuilder: (context, index) =>
                        _ConsultationCard(
                            consultation: consultations[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status filter chip.
// ---------------------------------------------------------------------------
class _StatusFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final Color? color;
  final VoidCallback onTap;

  const _StatusFilterChip({
    required this.label,
    required this.value,
    required this.current,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    final chipColor = color ?? Theme.of(context).colorScheme.primary;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: chipColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: isSelected ? chipColor : DairyTheme.subtleGrey,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : Colors.grey.shade300,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consultation card.
// ---------------------------------------------------------------------------
class _ConsultationCard extends StatelessWidget {
  final AdminConsultation consultation;

  const _ConsultationCard({required this.consultation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: ID + status badge.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#${consultation.id}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _StatusBadge(status: consultation.status),
                ],
              ),
              const SizedBox(height: 10),

              // Farmer & vet.
              Row(
                children: [
                  Expanded(
                    child: _infoColumn(
                      theme,
                      'Farmer',
                      consultation.farmerName,
                      Icons.person,
                    ),
                  ),
                  Expanded(
                    child: _infoColumn(
                      theme,
                      'Vet',
                      consultation.vetName ?? 'Unassigned',
                      Icons.medical_services,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Type, severity, date.
              Row(
                children: [
                  _TypeChip(type: consultation.type),
                  const SizedBox(width: 8),
                  _SeverityChip(severity: consultation.severity),
                  const Spacer(),
                  Text(
                    _formatDate(consultation.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),

              // Cattle name if present.
              if (consultation.cattleName != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.pets, size: 14, color: DairyTheme.subtleGrey),
                    const SizedBox(width: 4),
                    Text(
                      consultation.cattleName!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoColumn(
      ThemeData theme, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DairyTheme.subtleGrey),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontSize: 10)),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConsultationDetailSheet(consultation: consultation),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge.
// ---------------------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  final ConsultationStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    final label = _statusLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (status) {
      case ConsultationStatus.requested:
        return Colors.orange;
      case ConsultationStatus.in_progress:
        return Colors.blue;
      case ConsultationStatus.completed:
        return DairyTheme.primaryGreen;
      case ConsultationStatus.cancelled:
        return Colors.red;
    }
  }

  String get _statusLabel {
    switch (status) {
      case ConsultationStatus.requested:
        return 'Requested';
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
// Type chip.
// ---------------------------------------------------------------------------
class _TypeChip extends StatelessWidget {
  final String type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case 'video':
        icon = Icons.videocam;
        break;
      case 'in_person':
        icon = Icons.person;
        break;
      default:
        icon = Icons.chat;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: DairyTheme.subtleGrey),
          const SizedBox(width: 4),
          Text(
            type.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: DairyTheme.subtleGrey),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Severity chip.
// ---------------------------------------------------------------------------
class _SeverityChip extends StatelessWidget {
  final String severity;

  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (severity) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = DairyTheme.primaryGreen;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        severity.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consultation detail bottom sheet.
// ---------------------------------------------------------------------------
class _ConsultationDetailSheet extends StatelessWidget {
  final AdminConsultation consultation;

  const _ConsultationDetailSheet({required this.consultation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Consultation #${consultation.id}',
                  style: theme.textTheme.titleLarge),
              _StatusBadge(status: consultation.status),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow(Icons.person, 'Farmer', consultation.farmerName),
          _detailRow(Icons.medical_services, 'Vet',
              consultation.vetName ?? 'Unassigned'),
          if (consultation.cattleName != null)
            _detailRow(Icons.pets, 'Cattle', consultation.cattleName!),
          _detailRow(Icons.category, 'Type',
              consultation.type.replaceAll('_', ' ')),
          _detailRow(Icons.warning, 'Severity', consultation.severity),
          _detailRow(
            Icons.calendar_today,
            'Date',
            '${consultation.createdAt.day}/${consultation.createdAt.month}/${consultation.createdAt.year}',
          ),
          if (consultation.fee != null)
            _detailRow(Icons.currency_rupee, 'Fee',
                consultation.fee!.toStringAsFixed(0)),
          if (consultation.aiDiagnosis != null) ...[
            const SizedBox(height: 12),
            Text('AI Diagnosis',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Text(
                consultation.aiDiagnosis!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DairyTheme.subtleGrey),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: DairyTheme.subtleGrey, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
