import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/payments/models/payment_models.dart';
import 'package:dairy_ai/features/payments/providers/payment_provider.dart';
import 'package:dairy_ai/features/payments/screens/create_cycle_screen.dart';

class PaymentCyclesScreen extends ConsumerWidget {
  const PaymentCyclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(paymentCyclesProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Cycles'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateCycleScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New Cycle'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(paymentCyclesProvider);
        },
        child: cyclesAsync.when(
          data: (cycles) {
            if (cycles.isEmpty) {
              return const Center(child: Text('No payment cycles yet'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cycles.length + 1, // +1 for bottom spacer
              itemBuilder: (context, index) {
                if (index == cycles.length) {
                  return const SizedBox(height: 80);
                }
                final cycle = cycles[index];
                return _CycleCard(
                  cycle: cycle,
                  currencyFormat: currencyFormat,
                  onProcess: cycle.status == 'pending'
                      ? () => _confirmProcess(context, ref, cycle)
                      : null,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Future<void> _confirmProcess(
      BuildContext context, WidgetRef ref, PaymentCycle cycle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Process Payment Cycle'),
        content: Text(
          'Are you sure you want to process the ${cycle.cycleType} cycle '
          '(${cycle.periodStart} to ${cycle.periodEnd})? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Process'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success =
          await ref.read(paymentActionProvider.notifier).processCycle(cycle.id);
      if (context.mounted) {
        if (success) {
          context.showSnackBar('Payment cycle processed successfully!');
        } else {
          final error = ref.read(paymentActionProvider).error;
          context.showSnackBar(error ?? 'Failed to process cycle',
              isError: true);
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Cycle Card
// ---------------------------------------------------------------------------
class _CycleCard extends StatelessWidget {
  final PaymentCycle cycle;
  final NumberFormat currencyFormat;
  final VoidCallback? onProcess;

  const _CycleCard({
    required this.cycle,
    required this.currencyFormat,
    this.onProcess,
  });

  Color get _statusColor {
    switch (cycle.status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${_cycleTypeLabel(cycle.cycleType)} Cycle',
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(
                  label: cycle.status,
                  color: _statusColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${cycle.periodStart}  to  ${cycle.periodEnd}',
              style: context.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (cycle.farmersCount != null) ...[
                  Icon(Icons.people, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('${cycle.farmersCount} farmers'),
                  const SizedBox(width: 16),
                ],
                if (cycle.netPayout != null) ...[
                  Icon(Icons.currency_rupee,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    currencyFormat.format(cycle.netPayout),
                    style: context.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            if (onProcess != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onProcess,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Process'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _cycleTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'weekly':
        return 'Weekly';
      case 'fortnightly':
        return 'Fortnightly';
      case 'monthly':
        return 'Monthly';
      default:
        return type;
    }
  }
}

// ---------------------------------------------------------------------------
// Status Chip
// ---------------------------------------------------------------------------
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        style: context.textTheme.labelSmall?.copyWith(
          color: color.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

extension on Color {
  Color get shade700 {
    // Darken the color slightly for text legibility.
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0))
        .toColor();
  }
}
