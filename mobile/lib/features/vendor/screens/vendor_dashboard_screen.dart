import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/vendor/models/vendor_models.dart';
import 'package:dairy_ai/features/vendor/providers/vendor_provider.dart';

class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(vendorDashboardProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userRole = (currentUser?.role ?? '').toLowerCase();
    final isAdmin = userRole == 'admin' || userRole == 'super_admin';
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : (isAdmin
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to Admin Hub',
                    onPressed: () => context.go('/admin/ecommerce'),
                  )
                : null),
        title: const Text('Vendor Dashboard'),
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: () => context.go('/admin/ecommerce'),
              icon: const Icon(Icons.admin_panel_settings, size: 18),
              label: const Text('Admin Panel'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          IconButton(
            onPressed: () {
            final profile = ref.read(vendorProfileProvider).valueOrNull;
            if (profile != null && profile.id.isNotEmpty) {
              context.push('/store/vendor/${profile.id}');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Loading seller profile…')),
              );
            }
          },
          icon: const Icon(Icons.storefront_outlined),
          tooltip: 'View My Public Storefront',
        ),
        IconButton(
          onPressed: () => context.push('/vendor/coupons'),
          icon: const Icon(Icons.local_offer_outlined),
          tooltip: 'Store Coupons & Deals',
        ),
        IconButton(
            onPressed: () => context.push('/vendor/products'),
            icon: const Icon(Icons.inventory_2),
            tooltip: 'My products')
      ]),
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
              // ---- Low stock alert banner ----
              if (dashboard.lowStockCount > 0) ...[
                Card(
                  color: const Color(0xfffff7ed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xfffdba74)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Color(0xffc2410c), size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${dashboard.lowStockCount} Product${dashboard.lowStockCount > 1 ? 's' : ''} Low in Stock!',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xff9a3412)),
                              ),
                            ),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xffea580c),
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () =>
                                  context.push('/vendor/products'),
                              child: const Text('Restock',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dashboard.lowStockItems
                              .map((item) =>
                                  '${item.title} (${item.isOutOfStock ? 'OUT OF STOCK' : '${item.availableQuantity} left'})')
                              .join(' • '),
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xff7c2d12)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
                      title: 'Rating & Reviews ›',
                      value: '★ ${dashboard.rating.toStringAsFixed(1)}',
                      icon: Icons.rate_review_outlined,
                      color: Colors.amber.shade700,
                      onTap: () => context.push('/vendor/reviews'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending Orders',
                      value: dashboard.pendingOrders.toString(),
                      icon: Icons.pending_actions,
                      color: DairyTheme.errorRed,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ---- Settlements & Payouts Card ----
              Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet_outlined,
                                  color: DairyTheme.primaryGreen),
                              const SizedBox(width: 8),
                              Text('Payouts & Settlement',
                                  style: context.textTheme.titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                            ],
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.history, size: 16),
                            label: const Text('History',
                                style: TextStyle(fontSize: 12)),
                            onPressed: () => _showPayoutHistory(
                                context, dashboard, currencyFormat),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Pending Payout',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: DairyTheme.subtleGrey)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat
                                      .format(dashboard.pendingSettlement),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: DairyTheme.primaryGreen),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Settled',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: DairyTheme.subtleGrey)),
                                const SizedBox(height: 2),
                                Text(
                                  currencyFormat
                                      .format(dashboard.totalSettled),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xfff1f5f9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Gross: ${currencyFormat.format(dashboard.grossSales)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xff475569)),
                            ),
                            Text(
                              'Fee (${dashboard.commissionRate.toStringAsFixed(1)}%): -${currencyFormat.format(dashboard.commissionAmount)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xff64748b)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Store Traffic & Insights ----
              if (dashboard.analytics != null) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.insights_rounded,
                                    size: 18, color: Color(0xff4338ca)),
                                SizedBox(width: 6),
                                Text(
                                  'Traffic & Store Insights',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xff312e81),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xffeef2ff),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${dashboard.analytics!.conversionRate.toStringAsFixed(1)}% Conversion',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff4338ca),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Storefront Visits',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: DairyTheme.subtleGrey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${dashboard.analytics!.storefrontViews}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Product Impressions',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: DairyTheme.subtleGrey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${dashboard.analytics!.productImpressions}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Avg Order Value',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: DairyTheme.subtleGrey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormat.format(
                                        dashboard.analytics!.avgOrderValue),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.repeat_rounded,
                                size: 14, color: Color(0xff059669)),
                            const SizedBox(width: 4),
                            Text(
                              '${dashboard.analytics!.repeatCustomerRate.toStringAsFixed(1)}% Repeat Buyers Rate',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xff059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ---- Store Promotions & Coupons Card ----
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xffecfdf5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.local_offer_outlined,
                        color: DairyTheme.primaryGreen),
                  ),
                  title: const Text('Store Coupons & Special Offers',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text(
                      'Create percentage or flat discount vouchers for your buyers',
                      style:
                          TextStyle(fontSize: 12, color: DairyTheme.subtleGrey)),
                  trailing: const Icon(Icons.chevron_right,
                      color: DairyTheme.subtleGrey),
                  onTap: () => context.push('/vendor/coupons'),
                ),
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
                ...dashboard.recentOrders.map((order) => _OrderCard(
                      order: order,
                      currencyFormat: currencyFormat,
                    )),
            ],
          ),
        ),
      ),
    );
  }

  void _showPayoutHistory(BuildContext context, VendorDashboard dashboard,
      NumberFormat currencyFormat) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Payout History',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            if (dashboard.recentPayouts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                      'No payouts recorded yet. Payouts are processed by admin upon order delivery.'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dashboard.recentPayouts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final p = dashboard.recentPayouts[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xffdcfce7),
                      child:
                          Icon(Icons.check, color: DairyTheme.primaryGreen),
                    ),
                    title: Text(currencyFormat.format(p.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Ref: ${p.paymentReference ?? 'N/A'} • ${p.bankName ?? ''}\n${p.createdAt}'),
                    trailing: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(p.status.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: DairyTheme.primaryGreen)),
                      backgroundColor: const Color(0xffecfdf5),
                    ),
                  );
                },
              ),
          ],
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
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
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
    );

    return Card(
      child: onTap != null
          ? InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: content,
            )
          : content,
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
