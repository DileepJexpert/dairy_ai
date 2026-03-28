import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/cooperative/models/cooperative_models.dart';
import 'package:dairy_ai/features/cooperative/providers/cooperative_provider.dart';

class CooperativeDashboardScreen extends ConsumerWidget {
  const CooperativeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(cooperativeDashboardProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return Scaffold(
      appBar: AppBar(title: const Text('Cooperative Dashboard')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(cooperativeDashboardProvider),
        ),
        data: (dashboard) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(cooperativeDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Summary cards row 1 ----
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Members',
                      value: dashboard.totalMembers.toString(),
                      icon: Icons.groups,
                      color: DairyTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Total Milk',
                      value:
                          '${NumberFormat.compact().format(dashboard.totalMilkCollected)} L',
                      icon: Icons.local_drink,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ---- Summary cards row 2 ----
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Payouts',
                      value: currencyFormat.format(dashboard.totalPayouts),
                      icon: Icons.payments,
                      color: DairyTheme.accentOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Active Centers',
                      value: dashboard.activeCenters.toString(),
                      icon: Icons.store,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ---- Today's snapshot ----
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's Collection",
                                style: context.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              '${dashboard.todayCollection.toStringAsFixed(1)} L',
                              style: context.textTheme.titleLarge?.copyWith(
                                color: DairyTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Avg Fat %',
                                style: context.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              '${dashboard.avgFatPercent.toStringAsFixed(1)}%',
                              style: context.textTheme.titleLarge?.copyWith(
                                color: DairyTheme.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Collection centers ----
              Text('Collection Centers', style: context.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (dashboard.recentCenters.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No collection centers yet',
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                ...dashboard.recentCenters
                    .map((center) => _CenterCard(center: center)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
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
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: context.textTheme.titleLarge?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(title, style: context.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CenterCard extends StatelessWidget {
  final CollectionCenter center;

  const _CenterCard({required this.center});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: center.isActive
                    ? DairyTheme.primaryGreen
                    : DairyTheme.subtleGrey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(center.name, style: context.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(center.village, style: context.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${center.todayLitres.toStringAsFixed(1)} L',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: DairyTheme.primaryGreen,
                  ),
                ),
                Text(
                  '${center.memberCount} members',
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: context.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
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
