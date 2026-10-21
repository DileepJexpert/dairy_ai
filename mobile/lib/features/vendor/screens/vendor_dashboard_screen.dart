import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
    final isWide = MediaQuery.sizeOf(context).width >= 768;

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xffe2e8f0), height: 1),
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xff1e293b)),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              )
            : (isAdmin
                ? IconButton(
                    icon:
                        const Icon(Icons.arrow_back, color: Color(0xff1e293b)),
                    tooltip: 'Back to Admin Hub',
                    onPressed: () => context.go('/admin/ecommerce'),
                  )
                : null),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xffecfdf5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffa7f3d0)),
              ),
              child: const Icon(Icons.storefront,
                  color: Color(0xff059669), size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vendor Hub',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff0f172a),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Milterra Merchant & Fulfillment Center',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (isWide) ...[
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xfff1f5f9),
                    foregroundColor: const Color(0xff0f172a),
                    visualDensity: VisualDensity.compact,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => context.go('/admin/ecommerce'),
                  icon: const Icon(Icons.admin_panel_settings_outlined,
                      size: 16),
                  label: const Text('Admin Hub',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff334155),
                  side: const BorderSide(color: Color(0xffcbd5e1)),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () {
                  final profile = ref.read(vendorProfileProvider).valueOrNull;
                  if (profile != null && profile.id.isNotEmpty) {
                    context.push('/store/vendor/${profile.id}');
                  } else {
                    context.push('/store/vendor/vendor-1');
                  }
                },
                icon: const Icon(Icons.storefront_outlined, size: 16),
                label: const Text('Public Store',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff334155),
                  side: const BorderSide(color: Color(0xffcbd5e1)),
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => context.push('/vendor/coupons'),
                icon: const Icon(Icons.local_offer_outlined, size: 16),
                label: const Text('Coupons',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0d5c3a),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => context.push('/vendor/products'),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Products',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.storefront_outlined,
                  color: Color(0xff334155)),
              tooltip: 'Public Storefront',
              onPressed: () {
                final profile = ref.read(vendorProfileProvider).valueOrNull;
                if (profile != null && profile.id.isNotEmpty) {
                  context.push('/store/vendor/${profile.id}');
                } else {
                  context.push('/store/vendor/vendor-1');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.local_offer_outlined,
                  color: Color(0xff334155)),
              tooltip: 'Store Coupons',
              onPressed: () => context.push('/vendor/coupons'),
            ),
            IconButton(
              icon: const Icon(Icons.inventory_2_outlined,
                  color: Color(0xff334155)),
              tooltip: 'Products',
              onPressed: () => context.push('/vendor/products'),
            ),
          ],
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 14),
              Text('Loading merchant dashboard…',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(vendorDashboardProvider),
        ),
        data: (dashboard) => RefreshIndicator(
          color: const Color(0xff0d5c3a),
          onRefresh: () async {
            ref.invalidate(vendorDashboardProvider);
            ref.invalidate(vendorProfileProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Seller Profile Header Strip
                    _buildMerchantHeader(context, ref, dashboard),
                    const SizedBox(height: 14),

                    // 2. Low stock alert banner (compact, high-visibility)
                    if (dashboard.lowStockCount > 0) ...[
                      _buildLowStockAlert(context, dashboard),
                      const SizedBox(height: 14),
                    ],

                    // 3. Four Core Metric Cards
                    _buildKpiMetricsGrid(context, dashboard, currencyFormat),
                    const SizedBox(height: 16),

                    // 4. Two-Column Dashboard Content
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 7,
                                child: Column(
                                  children: [
                                    _buildAnalyticsCard(
                                        context, dashboard, currencyFormat),
                                    const SizedBox(height: 16),
                                    _buildRecentOrdersCard(
                                        context, dashboard, currencyFormat),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildSettlementCard(
                                        context, dashboard, currencyFormat),
                                    const SizedBox(height: 16),
                                    _buildPromotionsCard(context),
                                    const SizedBox(height: 16),
                                    _buildStoreResourceCard(context),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildAnalyticsCard(
                                  context, dashboard, currencyFormat),
                              const SizedBox(height: 16),
                              _buildRecentOrdersCard(
                                  context, dashboard, currencyFormat),
                              const SizedBox(height: 16),
                              _buildSettlementCard(
                                  context, dashboard, currencyFormat),
                              const SizedBox(height: 16),
                              _buildPromotionsCard(context),
                              const SizedBox(height: 16),
                              _buildStoreResourceCard(context),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Merchant Profile Header Banner
  // ---------------------------------------------------------------------------
  Widget _buildMerchantHeader(
      BuildContext context, WidgetRef ref, VendorDashboard dashboard) {
    final profile = ref.watch(vendorProfileProvider).valueOrNull;
    final businessName = profile?.businessName.isNotEmpty == true
        ? profile!.businessName
        : 'Milterra Central Operations';
    final district = profile?.district ?? 'Ajmer';
    final state = profile?.state ?? 'Rajasthan';
    final vendorType = profile != null
        ? VendorTypes.label(profile.vendorType)
        : 'Verified Merchant';
    final vendorId = profile?.id ?? 'vendor-1';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff0d5c3a), Color(0xff15803d)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              businessName.isNotEmpty ? businessName[0].toUpperCase() : 'M',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        businessName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff0f172a),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified,
                        color: Color(0xff059669), size: 16),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xffecfdf5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xffa7f3d0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: Color(0xff059669)),
                          SizedBox(width: 4),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff059669),
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$vendorType • $district, $state',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff64748b),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: vendorId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Merchant ID copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ID: $vendorId',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xff94a3b8),
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.copy,
                                size: 10, color: Color(0xff94a3b8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xffcbd5e1)),
              foregroundColor: const Color(0xff1e293b),
            ),
            onPressed: () => context.push('/vendor-profile'),
            icon: const Icon(Icons.tune_outlined, size: 14),
            label: const Text('Settings',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Low Stock Banner (Compact, Actionable)
  // ---------------------------------------------------------------------------
  Widget _buildLowStockAlert(
      BuildContext context, VendorDashboard dashboard) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xfffde68a)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xfffef3c7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xffb45309), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${dashboard.lowStockCount} item${dashboard.lowStockCount > 1 ? 's' : ''} low on inventory (≤ 5 units)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff92400e),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dashboard.lowStockItems
                      .map((e) =>
                          '${e.title}: ${e.isOutOfStock ? '0 units (OUT)' : '${e.availableQuantity} left'}')
                      .take(3)
                      .join('  •  '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xffb45309),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd97706),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () => context.push('/vendor/products'),
            child: const Text('Restock Now',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Metrics Strip (Row of 4 on Desktop, 2x2 on Mobile)
  // ---------------------------------------------------------------------------
  Widget _buildKpiMetricsGrid(BuildContext context, VendorDashboard dashboard,
      NumberFormat currencyFormat) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 36) / 4;

        final cards = [
          _buildCompactKpiCard(
            title: 'Total Revenue',
            value: currencyFormat.format(dashboard.totalRevenue),
            subtitle: 'Gross completed orders',
            icon: Icons.currency_rupee_rounded,
            iconColor: const Color(0xff059669),
            iconBg: const Color(0xffecfdf5),
            borderColor: const Color(0xffd1fae5),
          ),
          _buildCompactKpiCard(
            title: 'Orders Fulfilled',
            value: dashboard.totalOrders.toString(),
            subtitle:
                '${dashboard.pendingOrders} pending • ${dashboard.completedOrders} delivered',
            icon: Icons.receipt_long_outlined,
            iconColor: const Color(0xff2563eb),
            iconBg: const Color(0xffeff6ff),
            borderColor: const Color(0xffdbeafe),
          ),
          _buildCompactKpiCard(
            title: 'Store Rating',
            value: '★ ${dashboard.rating.toStringAsFixed(1)}',
            subtitle: 'Read buyer reviews ›',
            icon: Icons.star_rounded,
            iconColor: const Color(0xffd97706),
            iconBg: const Color(0xfffef3c7),
            borderColor: const Color(0xfffde68a),
            onTap: () => context.push('/vendor/reviews'),
          ),
          _buildCompactKpiCard(
            title: 'Pending Settlement',
            value: currencyFormat.format(dashboard.pendingSettlement),
            subtitle: 'Total settled: ${currencyFormat.format(dashboard.totalSettled)}',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xff7c3aed),
            iconBg: const Color(0xfff5f3ff),
            borderColor: const Color(0xffede9fe),
            onTap: () =>
                _showPayoutHistory(context, dashboard, currencyFormat),
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(width: cardWidth, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildCompactKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    final body = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff64748b),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xff0f172a),
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: onTap != null ? const Color(0xff2563eb) : const Color(0xff94a3b8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      );
    }
    return body;
  }

  // ---------------------------------------------------------------------------
  // Traffic & Insights Card (Left Primary)
  // ---------------------------------------------------------------------------
  Widget _buildAnalyticsCard(BuildContext context, VendorDashboard dashboard,
      NumberFormat currencyFormat) {
    final analytics = dashboard.analytics;
    final conversion = analytics?.conversionRate ?? 0.0;
    final views = analytics?.storefrontViews ?? 0;
    final impressions = analytics?.productImpressions ?? 0;
    final aov = analytics?.avgOrderValue ?? 0.0;
    final repeatRate = analytics?.repeatCustomerRate ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
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
                  SizedBox(width: 8),
                  Text(
                    'Traffic & Conversion Analytics',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xff0f172a),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xffeef2ff),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffc7d2fe)),
                ),
                child: Text(
                  '${conversion.toStringAsFixed(1)}% Conversion',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff4338ca),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 540) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            'Storefront Visits',
                            views.toString(),
                            Icons.visibility_outlined,
                            const Color(0xff2563eb),
                          ),
                        ),
                        Container(
                            height: 36, width: 1, color: const Color(0xfff1f5f9)),
                        Expanded(
                          child: _buildMetricItem(
                            'Impressions',
                            impressions.toString(),
                            Icons.touch_app_outlined,
                            const Color(0xff059669),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: Color(0xfff1f5f9)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricItem(
                            'Avg Order (AOV)',
                            currencyFormat.format(aov),
                            Icons.shopping_bag_outlined,
                            const Color(0xffd97706),
                          ),
                        ),
                        Container(
                            height: 36, width: 1, color: const Color(0xfff1f5f9)),
                        Expanded(
                          child: _buildMetricItem(
                            'Repeat Buyers',
                            '${repeatRate.toStringAsFixed(1)}%',
                            Icons.repeat_rounded,
                            const Color(0xff7c3aed),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Storefront Visits',
                      views.toString(),
                      Icons.visibility_outlined,
                      const Color(0xff2563eb),
                    ),
                  ),
                  Container(height: 36, width: 1, color: const Color(0xfff1f5f9)),
                  Expanded(
                    child: _buildMetricItem(
                      'Impressions',
                      impressions.toString(),
                      Icons.touch_app_outlined,
                      const Color(0xff059669),
                    ),
                  ),
                  Container(height: 36, width: 1, color: const Color(0xfff1f5f9)),
                  Expanded(
                    child: _buildMetricItem(
                      'Avg Order (AOV)',
                      currencyFormat.format(aov),
                      Icons.shopping_bag_outlined,
                      const Color(0xffd97706),
                    ),
                  ),
                  Container(height: 36, width: 1, color: const Color(0xfff1f5f9)),
                  Expanded(
                    child: _buildMetricItem(
                      'Repeat Buyers',
                      '${repeatRate.toStringAsFixed(1)}%',
                      Icons.repeat_rounded,
                      const Color(0xff7c3aed),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff64748b),
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xff0f172a),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recent Orders Card (Left Primary)
  // ---------------------------------------------------------------------------
  Widget _buildRecentOrdersCard(BuildContext context,
      VendorDashboard dashboard, NumberFormat currencyFormat) {
    final orders = dashboard.recentOrders;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 18, color: Color(0xff0f172a)),
                    const SizedBox(width: 8),
                    const Text(
                      'Recent Orders',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff0f172a),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xfff1f5f9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${orders.length}',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff475569)),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xff0d5c3a),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => context.push('/vendor-orders'),
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('View All Orders',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xfff1f5f9)),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 36, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    const Text('No orders received yet',
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xff64748b),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('New buyer orders will appear here automatically',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xfff8fafc)),
              itemBuilder: (context, index) {
                final o = orders[index];
                return InkWell(
                  onTap: () => context.push('/vendor-orders'),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xfff1f5f9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${o.orderNumber}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff334155),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.farmerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff0f172a),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                o.description.isNotEmpty
                                    ? o.description
                                    : 'Store order items',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff64748b),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormat.format(o.amount),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xff0f172a),
                              ),
                            ),
                            const SizedBox(height: 3),
                            _buildStatusPill(o.status),
                          ],
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right,
                            size: 16, color: Color(0xff94a3b8)),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Settlement & Payouts Card (Right Sidebar)
  // ---------------------------------------------------------------------------
  Widget _buildSettlementCard(BuildContext context, VendorDashboard dashboard,
      NumberFormat currencyFormat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: Color(0xff0d5c3a)),
                  SizedBox(width: 8),
                  Text(
                    'Settlement & Payouts',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff0f172a),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xff2563eb),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onPressed: () =>
                    _showPayoutHistory(context, dashboard, currencyFormat),
                icon: const Icon(Icons.history, size: 14),
                label: const Text('History',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffbbf7d0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AVAILABLE BALANCE',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff166534),
                            letterSpacing: 0.5)),
                    SizedBox(height: 2),
                    Text('Next Settlement Cycle',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xff15803d))),
                  ],
                ),
                Text(
                  currencyFormat.format(dashboard.pendingSettlement),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff166534),
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildFinancialRow('Gross Sales',
              currencyFormat.format(dashboard.grossSales), false),
          const SizedBox(height: 6),
          _buildFinancialRow(
            'Platform Fee (${dashboard.commissionRate.toStringAsFixed(1)}%)',
            '-${currencyFormat.format(dashboard.commissionAmount)}',
            false,
            color: const Color(0xffdc2626),
          ),
          const SizedBox(height: 6),
          _buildFinancialRow(
              'Net Payable', currencyFormat.format(dashboard.netPayable), true),
          const SizedBox(height: 6),
          _buildFinancialRow('Total Already Settled',
              currencyFormat.format(dashboard.totalSettled), false),
          const SizedBox(height: 12),
          if (dashboard.recentPayouts.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: Color(0xff059669)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Last payout: ${currencyFormat.format(dashboard.recentPayouts.first.amount)} (${dashboard.recentPayouts.first.status.toUpperCase()})',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff475569)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, bool isBold,
      {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? const Color(0xff0f172a) : const Color(0xff64748b),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ??
                (isBold ? const Color(0xff0f172a) : const Color(0xff334155)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Promotions & Discounts Card (Right Sidebar)
  // ---------------------------------------------------------------------------
  Widget _buildPromotionsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xfffef3c7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_offer_outlined,
                    color: Color(0xffd97706), size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Store Promotions & Deals',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff0f172a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Create instant percentage or flat discount vouchers to incentivize bulk buyers.',
            style: TextStyle(fontSize: 11, color: Color(0xff64748b)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: const BorderSide(color: Color(0xffcbd5e1)),
                foregroundColor: const Color(0xff0f172a),
              ),
              onPressed: () => context.push('/vendor/coupons'),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Manage Store Coupons',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Store Resources Card
  // ---------------------------------------------------------------------------
  Widget _buildStoreResourceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SELLER RESOURCES',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff64748b),
                  letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _buildResourceLink(
            'Manage Products & Inventory',
            Icons.inventory_2_outlined,
            () => context.push('/vendor/products'),
          ),
          _buildResourceLink(
            'Customer Reviews & Feedback',
            Icons.star_outline_rounded,
            () => context.push('/vendor/reviews'),
          ),
          _buildResourceLink(
            'Merchant Bank & KYC Profile',
            Icons.account_balance_outlined,
            () => context.push('/vendor-profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceLink(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xff0d5c3a)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff334155),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xff94a3b8)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Status Pill Widget
  // ---------------------------------------------------------------------------
  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    final st = status.toLowerCase();

    if (st == 'delivered' || st == 'completed') {
      bg = const Color(0xffecfdf5);
      fg = const Color(0xff059669);
    } else if (st == 'shipped' || st == 'out_for_delivery') {
      bg = const Color(0xffeff6ff);
      fg = const Color(0xff2563eb);
    } else if (st == 'cancelled') {
      bg = const Color(0xfffef2f2);
      fg = const Color(0xffdc2626);
    } else {
      bg = const Color(0xfffffbeb);
      fg = const Color(0xffd97706);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Payout History Modal Sheet
  // ---------------------------------------------------------------------------
  void _showPayoutHistory(BuildContext context, VendorDashboard dashboard,
      NumberFormat currencyFormat) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                const Row(
                  children: [
                    Icon(Icons.history, color: Color(0xff0d5c3a), size: 20),
                    SizedBox(width: 8),
                    Text('Payout & Remittance History',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0f172a))),
                  ],
                ),
                IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 16),
            if (dashboard.recentPayouts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No payouts recorded yet.\nPayout settlements occur automatically on order delivery.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dashboard.recentPayouts.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xfff1f5f9)),
                itemBuilder: (c, i) {
                  final p = dashboard.recentPayouts[i];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xffecfdf5),
                      child: Icon(Icons.check,
                          color: Color(0xff059669), size: 16),
                    ),
                    title: Text(currencyFormat.format(p.amount),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                        'Ref: ${p.paymentReference ?? 'N/A'} • ${p.bankName ?? 'Bank Transfer'}\n${p.createdAt}',
                        style: const TextStyle(fontSize: 10)),
                    trailing: _buildStatusPill(p.status),
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
// Clean Error View Widget
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe2e8f0)),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffef2f2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    size: 32, color: Color(0xffdc2626)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load merchant dashboard',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff0f172a)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff0d5c3a),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
