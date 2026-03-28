import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vendor/models/vendor_models.dart';
import 'package:dairy_ai/features/vendor/providers/vendor_provider.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(vendorDashboardProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Dashboard')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(vendorDashboardProvider),
        ),
        data: (dashboard) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(vendorDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---- Summary cards ----
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Revenue',
                      value: currencyFormat.format(dashboard.totalRevenue),
                      icon: Icons.currency_rupee,
                      color: DairyTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Orders',
                      value: dashboard.totalOrders.toString(),
                      icon: Icons.receipt_long,
                      color: DairyTheme.accentOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Rating',
                      value: dashboard.rating.toStringAsFixed(1),
                      icon: Icons.star,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending',
                      value: dashboard.pendingOrders.toString(),
                      icon: Icons.pending_actions,
                      color: DairyTheme.errorRed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ---- Recent orders ----
              Text('Recent Orders', style: context.textTheme.titleLarge),
              const SizedBox(height: 12),
              if (dashboard.recentOrders.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No orders yet',
                        style: context.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                ...dashboard.recentOrders
                    .map((order) => _OrderCard(
                          order: order,
                          currencyFormat: currencyFormat,
                        ))
                    ,
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

class _OrderCard extends StatelessWidget {
  final VendorOrder order;
  final NumberFormat currencyFormat;

  const _OrderCard({
    required this.order,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.farmerName,
                    style: context.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.description,
                    style: context.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(order.amount),
                  style: context.textTheme.titleMedium?.copyWith(
                    color: DairyTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                _StatusChip(status: order.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'completed':
        bg = DairyTheme.lightGreen;
        fg = DairyTheme.primaryGreen;
        break;
      case 'pending':
        bg = const Color(0xFFFFF3E0);
        fg = DairyTheme.accentOrange;
        break;
      case 'cancelled':
        bg = const Color(0xFFFFEBEE);
        fg = DairyTheme.errorRed;
        break;
      default:
        bg = const Color(0xFFE0E0E0);
        fg = DairyTheme.subtleGrey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: context.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 10,
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
            Icon(Icons.error_outline, size: 64, color: context.colorScheme.error),
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
