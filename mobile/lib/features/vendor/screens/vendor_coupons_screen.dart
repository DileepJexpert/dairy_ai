import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/models/marketplace_models.dart';
import 'package:dairy_ai/features/marketplace/widgets/store_design.dart';
import 'package:dairy_ai/features/vendor/providers/vendor_provider.dart';

class VendorCouponsScreen extends ConsumerStatefulWidget {
  const VendorCouponsScreen({super.key});

  @override
  ConsumerState<VendorCouponsScreen> createState() =>
      _VendorCouponsScreenState();
}

class _VendorCouponsScreenState extends ConsumerState<VendorCouponsScreen> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  bool _isActionLoading = false;

  Future<void> _toggleCoupon(PlatformCoupon coupon) async {
    setState(() => _isActionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.patch(
        '/vendor/commerce/coupons/${coupon.id}',
        data: {'is_active': !coupon.isActive},
      );
      final body = res.data as Map<String, dynamic>;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(body['message'] ?? 'Coupon updated'),
            backgroundColor: storeGreen,
          ),
        );
        ref.invalidate(vendorCouponsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update coupon: $e'),
            backgroundColor: storeError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _deleteCoupon(PlatformCoupon coupon) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Coupon?'),
        content: Text(
          'Are you sure you want to delete "${coupon.code}"? Customers will no longer be able to use it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeError),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionLoading = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/vendor/commerce/coupons/${coupon.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coupon "${coupon.code}" removed'),
            backgroundColor: storeGreen,
          ),
        );
        ref.invalidate(vendorCouponsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete coupon: $e'),
            backgroundColor: storeError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showCreateCouponDialog() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    final minOrderCtrl = TextEditingController(text: '0');
    final maxCapCtrl = TextEditingController();
    var discountType = CouponType.percentage;
    DateTime? selectedExpiry;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Create Store Coupon',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: storeGreen,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Text(
                  'Offer exclusive discounts funded by your store to attract repeat buyers.',
                  style: TextStyle(fontSize: 12, color: storeMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Coupon Code *',
                    hintText: 'e.g. ORGANIC10, DIWALI50',
                    prefixIcon: Icon(Icons.tag, color: storeGreen),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Short Description *',
                    hintText: 'e.g. 10% off on all organic farm products',
                    prefixIcon: Icon(Icons.description_outlined, color: storeGreen),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<CouponType>(
                        segments: const [
                          ButtonSegment(
                            value: CouponType.percentage,
                            label: Text('Percentage %'),
                            icon: Icon(Icons.percent),
                          ),
                          ButtonSegment(
                            value: CouponType.flat,
                            label: Text('Flat \u20B9'),
                            icon: Icon(Icons.currency_rupee),
                          ),
                        ],
                        selected: {discountType},
                        onSelectionChanged: (set) =>
                            setSheetState(() => discountType = set.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valueCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: discountType == CouponType.percentage
                              ? 'Discount Percentage *'
                              : 'Discount Amount (\u20B9) *',
                          hintText: discountType == CouponType.percentage
                              ? 'e.g. 15'
                              : 'e.g. 100',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minOrderCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Min Order (\u20B9)',
                          hintText: 'e.g. 500',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (discountType == CouponType.percentage) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxCapCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Max Discount Cap (\u20B9 optional)',
                      hintText: 'e.g. 250 (leave blank for no cap)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today, color: storeGreen),
                  title: Text(
                    selectedExpiry == null
                        ? 'No Expiration (Ongoing)'
                        : 'Expires on: ${DateFormat('dd MMM yyyy').format(selectedExpiry!)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedExpiry = picked);
                      }
                    },
                    child: Text(selectedExpiry == null ? 'Set Date' : 'Change'),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: storeGreen),
                    onPressed: () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      final desc = descCtrl.text.trim();
                      final val = double.tryParse(valueCtrl.text.trim());
                      final minOrder =
                          double.tryParse(minOrderCtrl.text.trim()) ?? 0.0;
                      final cap = double.tryParse(maxCapCtrl.text.trim());

                      if (code.length < 3) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Code must be at least 3 characters'),
                          ),
                        );
                        return;
                      }
                      if (desc.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a description'),
                          ),
                        );
                        return;
                      }
                      if (val == null || val <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid discount value'),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      setState(() => _isActionLoading = true);

                      try {
                        final dio = ref.read(dioProvider);
                        final payload = {
                          'code': code,
                          'description': desc,
                          'discount_type': discountType.name,
                          'discount_value': val,
                          'min_order_value': minOrder,
                          if (cap != null) 'max_discount_cap': cap,
                          if (selectedExpiry != null)
                            'valid_until': selectedExpiry!.toUtc().toIso8601String(),
                          'is_active': true,
                        };

                        final res = await dio.post(
                          '/vendor/commerce/coupons',
                          data: payload,
                        );
                        final body = res.data as Map<String, dynamic>;

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                body['message'] ?? 'Coupon created successfully!',
                              ),
                              backgroundColor: storeGreen,
                            ),
                          );
                          ref.invalidate(vendorCouponsProvider);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to create coupon: $e'),
                              backgroundColor: storeError,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isActionLoading = false);
                      }
                    },
                    child: const Text(
                      'Create Coupon',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final couponsAsync = ref.watch(vendorCouponsProvider);

    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        title: const Text(
          'Store Coupons & Deals',
          style: TextStyle(fontWeight: FontWeight.bold, color: storeGreen),
        ),
        backgroundColor: storeWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: storeGreen),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh coupons',
            onPressed: () => ref.invalidate(vendorCouponsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: storeAmber,
        foregroundColor: storeGreen,
        onPressed: _showCreateCouponDialog,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Coupon',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          couponsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: storeError),
                  const SizedBox(height: 12),
                  Text('Failed to load coupons: $err'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.invalidate(vendorCouponsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (coupons) {
              final activeCount = coupons.where((c) => c.isActive).length;
              final totalUsage = coupons.fold<int>(0, (sum, c) => sum + c.usageCount);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Metric cards
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          title: 'Total Coupons',
                          value: '${coupons.length}',
                          icon: Icons.confirmation_number_outlined,
                          color: storeGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'Active Now',
                          value: '$activeCount',
                          icon: Icons.check_circle_outline,
                          color: const Color(0xff059669),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          title: 'Redemptions',
                          value: '$totalUsage',
                          icon: Icons.shopping_bag_outlined,
                          color: const Color(0xff4338ca),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (coupons.isEmpty)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: storeBorder),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.local_offer_outlined,
                              size: 56,
                              color: storeMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No Coupons Yet',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: storeGreen,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Create promotional discount codes for your customers to increase cart size and drive repeat orders.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: storeMuted),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: storeGreen,
                              ),
                              onPressed: _showCreateCouponDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Coupon'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...coupons.map((coupon) => _buildCouponCard(coupon)),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
          if (_isActionLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(PlatformCoupon coupon) {
    final isPercent = coupon.discountType == CouponType.percentage;
    final discountStr = isPercent
        ? '${coupon.discountValue.toStringAsFixed(0)}% OFF'
        : '\u20B9${coupon.discountValue.toStringAsFixed(0)} FLAT';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: coupon.isActive
              ? storeGreen.withValues(alpha: 0.3)
              : storeBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: coupon.isActive ? storeSage : const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tag,
                        size: 16,
                        color: coupon.isActive ? storeGreen : storeMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        coupon.code,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.0,
                          color: coupon.isActive ? storeGreen : storeMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: coupon.isActive
                        ? const Color(0xffdcfce7)
                        : const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    discountStr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: coupon.isActive
                          ? const Color(0xff15803d)
                          : storeMuted,
                    ),
                  ),
                ),
                const Spacer(),
                Switch(
                  value: coupon.isActive,
                  activeThumbColor: storeGreen,
                  onChanged: (_) => _toggleCoupon(coupon),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: storeError),
                  tooltip: 'Delete Coupon',
                  onPressed: () => _deleteCoupon(coupon),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              coupon.description,
              style: const TextStyle(fontSize: 13, color: Color(0xff334155)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Min: ${_currencyFormat.format(coupon.minOrderValue)}',
                ),
                if (coupon.maxDiscountCap != null)
                  _InfoChip(
                    icon: Icons.shield_outlined,
                    label: 'Max Cap: ${_currencyFormat.format(coupon.maxDiscountCap)}',
                  ),
                _InfoChip(
                  icon: Icons.people_outline,
                  label: '${coupon.usageCount} Redeemed',
                ),
                if (coupon.validUntil != null)
                  _InfoChip(
                    icon: Icons.event,
                    label: 'Until: ${DateFormat('dd MMM yyyy').format(coupon.validUntil!)}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(10),
        border: const BorderSide(color: storeBorder).toBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: storeMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: storeMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xff475569)),
          ),
        ],
      ),
    );
  }
}

extension on BorderSide {
  BoxBorder toBorder() => Border.fromBorderSide(this);
}
