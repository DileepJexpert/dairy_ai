import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import '../models/collection_models.dart';
import '../providers/collection_provider.dart';

/// Dashboard screen for a single collection center.
///
/// Shows center info, today's stats, stock gauge, alerts, and quick actions.
class CenterDashboardScreen extends ConsumerWidget {
  const CenterDashboardScreen({super.key, required this.centerId});

  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(centerDashboardProvider(centerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Center Dashboard'),
      ),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorBody(
          message: err.toString(),
          onRetry: () => ref.invalidate(centerDashboardProvider(centerId)),
        ),
        data: (dashboard) {
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(centerDashboardProvider(centerId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Center info card
                _CenterInfoCard(center: dashboard.center),
                const SizedBox(height: 16),

                // Today's collection stats
                _TodayStatsCard(today: dashboard.today),
                const SizedBox(height: 16),

                // Stock gauge
                _StockGaugeCard(center: dashboard.center),
                const SizedBox(height: 16),

                // Alerts summary
                _AlertsSummaryCard(
                  alerts: dashboard.alerts,
                  onTap: () =>
                      context.push('/collection/centers/$centerId/cold-chain'),
                ),
                const SizedBox(height: 24),

                // Quick actions
                Text(
                  'Quick Actions',
                  style: context.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.water_drop,
                        label: 'Record Milk',
                        color: DairyTheme.primaryGreen,
                        onTap: () => context.push(
                            '/collection/centers/$centerId/record-milk'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.thermostat,
                        label: 'Check Temp',
                        color: DairyTheme.accentOrange,
                        onTap: () => context.push(
                            '/collection/centers/$centerId/cold-chain'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Center info card
// =============================================================================

class _CenterInfoCard extends StatelessWidget {
  const _CenterInfoCard({required this.center});

  final Map<String, dynamic> center;

  @override
  Widget build(BuildContext context) {
    final name = center['name'] as String? ?? 'Unknown';
    final code = center['code'] as String? ?? '--';
    final status = center['status'] as String? ?? 'active';

    Color statusBg;
    Color statusFg;
    switch (status) {
      case 'active':
        statusBg = DairyTheme.primaryGreen.withOpacity(0.12);
        statusFg = DairyTheme.primaryGreen;
        break;
      case 'inactive':
        statusBg = Colors.grey.shade200;
        statusFg = Colors.grey.shade700;
        break;
      case 'maintenance':
        statusBg = DairyTheme.accentOrange.withOpacity(0.12);
        statusFg = DairyTheme.accentOrange;
        break;
      default:
        statusBg = Colors.grey.shade200;
        statusFg = Colors.grey.shade700;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: DairyTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.store,
                  color: DairyTheme.primaryGreen, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Code: $code',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: context.textTheme.bodySmall?.copyWith(
                  color: statusFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Today's stats
// =============================================================================

class _TodayStatsCard extends StatelessWidget {
  const _TodayStatsCard({required this.today});

  final Map<String, dynamic> today;

  @override
  Widget build(BuildContext context) {
    final litres =
        (today['collection_litres'] as num?)?.toDouble() ?? 0;
    final farmerCount = (today['farmer_count'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Collection", style: context.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.water_drop,
                    label: 'Litres',
                    value: '${litres.toStringAsFixed(1)} L',
                    color: DairyTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.people,
                    label: 'Farmers',
                    value: '$farmerCount',
                    color: DairyTheme.accentOrange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: context.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Stock gauge
// =============================================================================

class _StockGaugeCard extends StatelessWidget {
  const _StockGaugeCard({required this.center});

  final Map<String, dynamic> center;

  @override
  Widget build(BuildContext context) {
    final current =
        (center['current_stock_litres'] as num?)?.toDouble() ?? 0;
    final capacity =
        (center['capacity_litres'] as num?)?.toDouble() ?? 1;
    final ratio = capacity > 0 ? (current / capacity).clamp(0.0, 1.0) : 0.0;

    Color barColor;
    if (ratio > 0.9) {
      barColor = DairyTheme.errorRed;
    } else if (ratio > 0.7) {
      barColor = DairyTheme.accentOrange;
    } else {
      barColor = DairyTheme.primaryGreen;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stock Level', style: context.textTheme.titleMedium),
                Text(
                  '${(ratio * 100).toStringAsFixed(0)}%',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 16,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${current.toStringAsFixed(0)} / ${capacity.toStringAsFixed(0)} litres',
              style: context.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Alerts summary
// =============================================================================

class _AlertsSummaryCard extends StatelessWidget {
  const _AlertsSummaryCard({required this.alerts, required this.onTap});

  final Map<String, dynamic> alerts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeCount = (alerts['active_count'] as num?)?.toInt() ?? 0;
    final hasAlerts = activeCount > 0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasAlerts
            ? const BorderSide(color: DairyTheme.errorRed, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasAlerts
                      ? DairyTheme.errorRed.withOpacity(0.12)
                      : DairyTheme.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasAlerts ? Icons.warning_amber : Icons.check_circle,
                  color: hasAlerts
                      ? DairyTheme.errorRed
                      : DairyTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAlerts
                          ? '$activeCount Active Alert${activeCount > 1 ? 's' : ''}'
                          : 'No Active Alerts',
                      style: context.textTheme.titleMedium?.copyWith(
                        color: hasAlerts
                            ? DairyTheme.errorRed
                            : DairyTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasAlerts
                          ? 'Tap to view cold chain alerts'
                          : 'All temperatures within safe range',
                      style: context.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Quick action button
// =============================================================================

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Error body
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
