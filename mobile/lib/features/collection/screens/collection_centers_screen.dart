import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import '../models/collection_models.dart';
import '../providers/collection_provider.dart';

/// Lists all milk collection centers with summary cards.
class CollectionCentersScreen extends ConsumerWidget {
  const CollectionCentersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centersAsync = ref.watch(collectionCentersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection Centers'),
      ),
      body: centersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorBody(
          message: err.toString(),
          onRetry: () => ref.invalidate(collectionCentersProvider),
        ),
        data: (centers) {
          if (centers.isEmpty) {
            return const _EmptyCenters();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(collectionCentersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 80, left: 16, right: 16),
              itemCount: centers.length,
              itemBuilder: (context, index) {
                return _CenterCard(
                  center: centers[index],
                  onTap: () => context
                      .push('/collection/centers/${centers[index].id}'),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/collection/centers/create'),
        icon: const Icon(Icons.add),
        label: const Text('Add Center'),
      ),
    );
  }
}

// =============================================================================
// Center card
// =============================================================================

class _CenterCard extends StatelessWidget {
  const _CenterCard({required this.center, required this.onTap});

  final CollectionCenter center;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stockPct = center.stockRatio;
    final stockColor = _stockColor(stockPct);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: name + status chip
              Row(
                children: [
                  Expanded(
                    child: Text(
                      center.name,
                      style: context.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(status: center.status),
                ],
              ),
              const SizedBox(height: 4),

              // Code and district
              Row(
                children: [
                  Icon(Icons.qr_code, size: 14, color: DairyTheme.subtleGrey),
                  const SizedBox(width: 4),
                  Text(
                    center.code,
                    style: context.textTheme.bodySmall,
                  ),
                  if (center.district != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.location_on,
                        size: 14, color: DairyTheme.subtleGrey),
                    const SizedBox(width: 4),
                    Text(
                      center.district!,
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Stock gauge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Stock',
                              style: context.textTheme.bodySmall,
                            ),
                            Text(
                              '${center.currentStockLitres.toStringAsFixed(0)} / ${center.capacityLitres.toStringAsFixed(0)} L',
                              style: context.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: stockPct.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(stockColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Temperature badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DairyTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.thermostat,
                            size: 16, color: DairyTheme.primaryGreen),
                        const SizedBox(width: 2),
                        Text(
                          '${center.chillingTempCelsius.toStringAsFixed(1)}\u00B0C',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: DairyTheme.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _stockColor(double ratio) {
    if (ratio > 0.9) return DairyTheme.errorRed;
    if (ratio > 0.7) return DairyTheme.accentOrange;
    return DairyTheme.primaryGreen;
  }
}

// =============================================================================
// Status chip
// =============================================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'active':
        bg = DairyTheme.primaryGreen.withOpacity(0.12);
        fg = DairyTheme.primaryGreen;
        break;
      case 'inactive':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        break;
      case 'maintenance':
        bg = DairyTheme.accentOrange.withOpacity(0.12);
        fg = DairyTheme.accentOrange;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: context.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyCenters extends StatelessWidget {
  const _EmptyCenters();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No collection centers',
            style: context.textTheme.titleMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first center.',
            style: context.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Error state
// =============================================================================

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: context.colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
