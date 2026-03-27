import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/admin/models/admin_models.dart';
import 'package:dairy_ai/features/admin/providers/admin_provider.dart';

/// Vet management screen with verification filter and verify action.
class AdminVetsScreen extends ConsumerWidget {
  const AdminVetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vetsAsync = ref.watch(adminVetsProvider);
    final currentFilter = ref.watch(vetFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Vets')),
      body: Column(
        children: [
          // ---------- Filter chips ----------
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: currentFilter == VetFilter.all,
                  onTap: () =>
                      ref.read(vetFilterProvider.notifier).state =
                          VetFilter.all,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Verified',
                  selected: currentFilter == VetFilter.verified,
                  onTap: () =>
                      ref.read(vetFilterProvider.notifier).state =
                          VetFilter.verified,
                  color: DairyTheme.primaryGreen,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unverified',
                  selected: currentFilter == VetFilter.unverified,
                  onTap: () =>
                      ref.read(vetFilterProvider.notifier).state =
                          VetFilter.unverified,
                  color: DairyTheme.accentOrange,
                ),
              ],
            ),
          ),

          // ---------- Vet list ----------
          Expanded(
            child: vetsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load vets',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(adminVetsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (vets) {
                if (vets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_services_outlined,
                            size: 64, color: DairyTheme.subtleGrey),
                        const SizedBox(height: 12),
                        Text(
                          'No vets found',
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
                      ref.invalidate(adminVetsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: vets.length,
                    itemBuilder: (context, index) =>
                        _VetCard(vet: vets[index]),
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
// Filter chip widget.
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: chipColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color: selected ? chipColor : DairyTheme.subtleGrey,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? chipColor : Colors.grey.shade300,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vet card with details and verify button.
// ---------------------------------------------------------------------------
class _VetCard extends ConsumerWidget {
  final AdminVet vet;

  const _VetCard({required this.vet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row.
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: vet.isVerified
                      ? DairyTheme.primaryGreen.withOpacity(0.1)
                      : DairyTheme.accentOrange.withOpacity(0.1),
                  child: Icon(
                    Icons.medical_services,
                    color: vet.isVerified
                        ? DairyTheme.primaryGreen
                        : DairyTheme.accentOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vet.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: vet.isVerified
                                  ? DairyTheme.primaryGreen
                                      .withOpacity(0.1)
                                  : DairyTheme.accentOrange
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              vet.isVerified ? 'Verified' : 'Unverified',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: vet.isVerified
                                    ? DairyTheme.primaryGreen
                                    : DairyTheme.accentOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(vet.qualification,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Detail rows.
            _infoRow(Icons.badge, 'License', vet.licenseNo),
            const SizedBox(height: 6),
            _infoRow(Icons.star, 'Rating',
                '${vet.rating.toStringAsFixed(1)} / 5.0'),
            const SizedBox(height: 6),
            _infoRow(Icons.assignment, 'Consultations',
                '${vet.totalConsultations}'),
            const SizedBox(height: 6),
            _infoRow(Icons.currency_rupee, 'Fee',
                vet.fee.toStringAsFixed(0)),

            if (vet.specializations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: vet.specializations
                    .map((s) => Chip(
                          label: Text(s, style: const TextStyle(fontSize: 11)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              Colors.blue.withOpacity(0.08),
                          side: BorderSide.none,
                        ))
                    .toList(),
              ),
            ],

            // Verify button for unverified vets.
            if (!vet.isVerified) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _onVerify(context, ref),
                  icon: const Icon(Icons.verified, size: 18),
                  label: const Text('Verify Vet'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: DairyTheme.subtleGrey),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        Text(value,
            style:
                TextStyle(fontSize: 13, color: DairyTheme.subtleGrey)),
      ],
    );
  }

  Future<void> _onVerify(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Vet'),
        content: Text(
            'Are you sure you want to verify ${vet.name} (License: ${vet.licenseNo})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await verifyVet(ref, vet.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vet.name} has been verified'),
            backgroundColor: DairyTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: DairyTheme.errorRed,
          ),
        );
      }
    }
  }
}
