import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/merchandising_provider.dart';
import '../providers/admin_marketplace_provider.dart';
import '../models/analytics_models.dart';
import '../providers/admin_analytics_provider.dart';
import '../../marketplace/widgets/support_panel.dart';
import '../../marketplace/widgets/product_media_manager.dart';

final adminCatalogProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final response = await ref.watch(dioProvider).get('/vendor/products');
  final body = response.data;
  if (body is! Map || body['data'] is! List) {
    throw const FormatException('Admin catalogue response was invalid');
  }
  return (body['data'] as List)
      .whereType<Map>()
      .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
      .toList();
});

final adminPurchaseInterestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/marketplace/orders/admin/interests');
  final body = response.data;
  if (body is! Map || body['data'] is! List) {
    throw const FormatException('Purchase interest response was invalid');
  }
  return (body['data'] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
});

final adminCancellationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/marketplace/orders/admin/cancellations');
  final body = response.data;
  if (body is! Map || body['data'] is! List) {
    throw const FormatException('Cancellations response was invalid');
  }
  return (body['data'] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
});

final adminVendorSettlementsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/admin/commerce/vendors/settlements');
  final body = response.data;
  if (body is! Map || body['data'] is! List) {
    throw const FormatException('Vendor settlements response was invalid');
  }
  return (body['data'] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
});

final adminConceptFeedbackProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/admin/marketplace/concept-feedback');
  final body = response.data;
  if (body is! Map || body['data'] is! List) {
    throw const FormatException('Concept feedback response was invalid');
  }
  return (body['data'] as List)
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
});

final adminNutritionConceptsProvider =
    FutureProvider.autoDispose<List<ProductFamily>>((ref) async {
  final response = await ref.watch(dioProvider).get('/vendor/families');
  final body = response.data;
  if (body is! Map || body['data'] is! List) {
    throw const FormatException('Product-family response was invalid');
  }
  return (body['data'] as List)
      .whereType<Map>()
      .map((item) => ProductFamily.fromJson(Map<String, dynamic>.from(item)))
      .where((family) => family.isConcept)
      .toList();
});

class EcommerceAdminPanelScreen extends ConsumerStatefulWidget {
  const EcommerceAdminPanelScreen({super.key});

  @override
  ConsumerState<EcommerceAdminPanelScreen> createState() =>
      _EcommerceAdminPanelScreenState();
}

class _EcommerceAdminPanelScreenState
    extends ConsumerState<EcommerceAdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _adminSaving = false;
  String _catalogFilter = 'all';

  Future<void> _editInterest(Map<String, dynamic> interest) async {
    final notes = TextEditingController(
        text: interest['followup_notes']?.toString() ?? '');
    var status = interest['interest_status']?.toString() ?? 'NEW';
    var saving = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: const Text('Customer follow-up'),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            initialValue: status,
                            isExpanded: true,
                            items: ['NEW', 'CONTACTED', 'WAITLISTED', 'CLOSED']
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: saving
                                ? null
                                : (value) => setDialog(() => status = value!)),
                        TextField(
                            controller: notes,
                            maxLength: 4000,
                            maxLines: 5,
                            decoration: const InputDecoration(
                                labelText: 'Internal contact notes')),
                        const Text(
                            'Saves notes only; no automated call, SMS or email is sent.'),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setDialog(() => saving = true);
                                try {
                                  await ref.read(dioProvider).patch(
                                      '/marketplace/orders/admin/interests/${interest['id']}',
                                      data: {
                                        'interest_status': status,
                                        'notes': notes.text
                                      });
                                  ref.invalidate(
                                      adminPurchaseInterestsProvider);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    setDialog(() => saving = false);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(commerceError(e))));
                                  }
                                }
                              },
                        child: Text(saving ? 'Saving…' : 'Save follow-up'))
                  ],
                )));
    notes.dispose();
  }

  Future<void> _processRefundDialog(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString() ?? '';
    final orderNumber = order['order_number']?.toString() ?? orderId;
    final total = double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
    final refCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String action = 'approve';
    bool restockInventory = true;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Review Cancellation: #$orderNumber'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8fafc),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Order Total: ${storeMoney(total)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Customer: ${order['contact_phone'] ?? 'N/A'}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xff64748b))),
                        if (order['cancel_reason'] != null &&
                            order['cancel_reason'].toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Reason: ${order['cancel_reason']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: storeError,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Moderation Action',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'approve',
                          label: Text('Approve & Refund'),
                          icon: Icon(Icons.check_circle_outline)),
                      ButtonSegment(
                          value: 'reject',
                          label: Text('Reject Request'),
                          icon: Icon(Icons.cancel_outlined)),
                    ],
                    selected: {action},
                    onSelectionChanged: saving
                        ? null
                        : (val) => setDialog(() => action = val.first),
                  ),
                  const SizedBox(height: 14),
                  if (action == 'approve') ...[
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Payment Gateway / Bank Reference (UTR)',
                        hintText: 'e.g. UPI-REF-98765432 or RAZORPAY_REF',
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: restockInventory,
                      onChanged: saving
                          ? null
                          : (v) => setDialog(() => restockInventory = v ?? true),
                      title: const Text('Restock inventory quantities',
                          style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                          'Adds items back to vendor inventory automatically',
                          style: TextStyle(fontSize: 11)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    controller: remarksCtrl,
                    maxLength: 800,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: action == 'approve'
                          ? 'Admin remarks (Optional)'
                          : 'Rejection explanation (Required)',
                      hintText: action == 'approve'
                          ? 'Refund processed via UPI'
                          : 'e.g. Package already dispatched with courier',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    action == 'approve' ? storeGreen : storeError,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (action == 'reject' &&
                          remarksCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please enter an explanation for rejecting this request.')),
                        );
                        return;
                      }
                      setDialog(() => saving = true);
                      try {
                        await ref.read(dioProvider).post(
                          '/marketplace/orders/admin/refunds/$orderId',
                          data: {
                            'action': action,
                            'refund_reference': refCtrl.text.trim(),
                            'remarks': remarksCtrl.text.trim(),
                            'restock_inventory': restockInventory,
                          },
                        );
                        ref.invalidate(adminCancellationsProvider);
                        ref.read(adminMarketplaceProvider.notifier).refresh();
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(action == 'approve'
                                  ? 'Refund approved and order cancelled.'
                                  : 'Cancellation request rejected.'),
                              backgroundColor:
                                  action == 'approve' ? storeGreen : Colors.orange,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialog(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(commerceError(e)),
                                backgroundColor: storeError),
                          );
                        }
                      }
                    },
              child: Text(saving
                  ? 'Processing…'
                  : (action == 'approve'
                      ? 'Confirm Refund'
                      : 'Reject Request')),
            ),
          ],
        ),
      ),
    );
    refCtrl.dispose();
    remarksCtrl.dispose();
  }

  Future<void> _disbursePayoutDialog(Map<String, dynamic> settlement) async {
    final vendorId = settlement['vendor_id']?.toString() ?? '';
    final businessName = settlement['business_name']?.toString() ?? 'Vendor';
    final pendingBalance =
        double.tryParse(settlement['pending_balance']?.toString() ?? '') ?? 0.0;
    final grossSales =
        double.tryParse(settlement['gross_sales']?.toString() ?? '') ?? 0.0;
    final commissionAmt =
        double.tryParse(settlement['commission_amount']?.toString() ?? '') ??
            0.0;
    final bankName = settlement['bank_name']?.toString() ?? '';
    final accNo = settlement['account_number']?.toString() ?? '';
    final ifsc = settlement['ifsc_code']?.toString() ?? '';
    final upi = settlement['upi_id']?.toString() ?? '';

    final amountCtrl =
        TextEditingController(text: pendingBalance.toStringAsFixed(2));
    final refCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Disburse Payout: $businessName'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff0fdf4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffbbf7d0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pending Balance:',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xff166534))),
                            Text(storeMoney(pendingBalance),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: storeGreen)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Gross Sales: ${storeMoney(grossSales)} · Platform Fee: -${storeMoney(commissionAmt)}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xff15803d))),
                        const Divider(height: 12),
                        Text(
                            'Bank: ${bankName.isEmpty ? 'Not Provided' : bankName} · A/C: ${accNo.isEmpty ? 'N/A' : accNo}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff14532d))),
                        if (ifsc.isNotEmpty || upi.isNotEmpty)
                          Text(
                              'IFSC: ${ifsc.isEmpty ? 'N/A' : ifsc} · UPI: ${upi.isEmpty ? 'N/A' : upi}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xff166534))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Disbursal Amount (₹)',
                      hintText: 'e.g. 5000.00',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bank Reference / UTR Number',
                      hintText: 'e.g. UTR-20260919-897612 or IMPS-9021',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    maxLength: 400,
                    decoration: const InputDecoration(
                      labelText: 'Disbursement Remarks',
                      hintText: 'e.g. Settled weekly orders via NEFT',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: saving
                  ? null
                  : () async {
                      final amt =
                          double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please enter a valid payout amount greater than 0.')),
                        );
                        return;
                      }
                      if (refCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please enter a bank reference or UTR number.')),
                        );
                        return;
                      }
                      setDialog(() => saving = true);
                      try {
                        await ref.read(dioProvider).post(
                          '/admin/commerce/vendors/$vendorId/payouts',
                          data: {
                            'amount': amt,
                            'gross_amount': grossSales,
                            'commission_amount': commissionAmt,
                            'payment_reference': refCtrl.text.trim(),
                            'remarks': remarksCtrl.text.trim(),
                            'bank_name': bankName,
                            'account_number': accNo,
                          },
                        );
                        ref.invalidate(adminVendorSettlementsProvider);
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Payout of ${storeMoney(amt)} recorded for $businessName.'),
                              backgroundColor: storeGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialog(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(commerceError(e)),
                                backgroundColor: storeError),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Disbursing…' : 'Confirm Payout'),
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    refCtrl.dispose();
    remarksCtrl.dispose();
  }

  Future<void> _editCommissionDialog(SellerAccount seller) async {
    final rateCtrl = TextEditingController(
        text: seller.commissionRatePercent.toStringAsFixed(1));
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Platform Commission: ${seller.businessName}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Set the platform commission percentage deducted from delivered orders:',
                    style: TextStyle(fontSize: 13, color: storeMuted)),
                const SizedBox(height: 16),
                TextField(
                  controller: rateCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Commission Rate (%)',
                    suffixText: '%',
                    hintText: 'e.g. 5.0 or 10.0',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: saving
                  ? null
                  : () async {
                      final rate = double.tryParse(rateCtrl.text.trim());
                      if (rate == null || rate < 0 || rate > 100) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Please enter a valid rate between 0% and 100%.')),
                        );
                        return;
                      }
                      setDialog(() => saving = true);
                      try {
                        await ref
                            .read(adminMarketplaceProvider.notifier)
                            .updateSellerCommission(seller.id, rate);
                        ref.invalidate(adminVendorSettlementsProvider);
                        if (context.mounted) Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Updated commission rate to $rate% for ${seller.businessName}.'),
                              backgroundColor: storeGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialog(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(commerceError(e)),
                                backgroundColor: storeError),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Save Rate'),
            ),
          ],
        ),
      ),
    );
    rateCtrl.dispose();
  }

  Future<void> _saveAdminAction(Future<void> Function() action,
      {BuildContext? dialog}) async {
    if (_adminSaving) return;
    setState(() => _adminSaving = true);
    try {
      await action();
      ref.invalidate(adminCatalogProductsProvider);
      if (dialog != null && dialog.mounted) Navigator.pop(dialog);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Saved to the backend.'),
            backgroundColor: storeGreen));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(commerceError(error)), backgroundColor: storeError));
      }
    } finally {
      if (mounted) setState(() => _adminSaving = false);
    }
  }

  Future<void> _approveProduct(Product product) async {
    await _saveAdminAction(() async {
      await ref.read(dioProvider).patch(
        '/admin/commerce/products/${product.id}/moderation',
        data: {'status': 'published'},
      );
    });
  }

  Future<void> _rejectProduct(Product product) async {
    final reasonCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Reject Product: ${product.title}'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Incomplete FSSAI compliance, low image quality',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeError),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _saveAdminAction(() async {
                await ref.read(dioProvider).patch(
                  '/admin/commerce/products/${product.id}/moderation',
                  data: {
                    'status': 'rejected',
                    'reason': reasonCtrl.text.trim(),
                  },
                );
              });
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
    reasonCtrl.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 13, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminMarketplaceProvider);
    final adminUser = ref.watch(currentUserProvider);
    final adminLabel = adminUser?.name?.trim().isNotEmpty == true
        ? adminUser!.name!.trim()
        : 'Administrator';

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),
      appBar: AppBar(
        backgroundColor: const Color(0xff0d1b15),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: storeGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('ADMIN',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(width: 10),
            const Text('Milterra Enterprise Ecommerce Control Panel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
              tooltip: 'Help content & enquiries',
              icon: const Icon(Icons.support_agent),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const StoreHelpAdminScreen()))),
          IconButton(
              tooltip: 'Reload backend data',
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(adminMarketplaceProvider.notifier).refresh()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: storeGreen,
                  child:
                      Icon(Icons.person_outline, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      adminUser?.phone ?? '',
                      style: const TextStyle(
                        color: Color(0xff94a3b8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'View Customer Storefront',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/shop'),
          ),
          IconButton(
            tooltip: 'Seller Portal',
            icon: const Icon(Icons.business_outlined),
            onPressed: () => context.push('/seller/dashboard'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/admin/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xffff9900),
          unselectedLabelColor: const Color(0xff94a3b8),
          indicatorColor: const Color(0xffff9900),
          indicatorWeight: 3,
          tabs: const [
            Tab(
                icon: Icon(Icons.inventory_2_outlined, size: 18),
                text: 'Products'),
            Tab(
                icon: Icon(Icons.science_outlined, size: 18),
                text: 'Animal Nutrition'),
            Tab(
                icon: Icon(Icons.shopping_cart_checkout_outlined, size: 18),
                text: 'Live Carts'),
            Tab(
                icon: Icon(Icons.public_outlined, size: 18),
                text: 'Traffic & Geo'),
            Tab(
                icon: Icon(Icons.ads_click_outlined, size: 18),
                text: 'User Clickstream'),
            Tab(
                icon: Icon(Icons.local_shipping_outlined, size: 18),
                text: 'Shipments & Logistics'),
            Tab(
                icon: Icon(Icons.verified_outlined, size: 18),
                text: 'Batch Certificates'),
            Tab(
                icon: Icon(Icons.verified_user_outlined, size: 18),
                text: 'Sellers & KYC'),
            Tab(
                icon: Icon(Icons.local_offer_outlined, size: 18),
                text: 'Seller Offers'),
            Tab(
                icon: Icon(Icons.bolt_outlined, size: 18),
                text: 'Deals Engine'),
            Tab(
                icon: Icon(Icons.confirmation_number_outlined, size: 18),
                text: 'Coupons'),
            Tab(
                icon: Icon(Icons.warehouse_outlined, size: 18),
                text: 'Inventory'),
            Tab(
                icon: Icon(Icons.history_edu_outlined, size: 18),
                text: 'Audit Trail'),
          ],
        ),
      ),
      body: Column(children: [
        if (adminState.loading || _adminSaving) const LinearProgressIndicator(),
        if (adminState.error != null)
          MaterialBanner(content: Text(adminState.error!), actions: [
            TextButton(
                onPressed: () =>
                    ref.read(adminMarketplaceProvider.notifier).refresh(),
                child: const Text('Retry'))
          ]),
        Expanded(
            child: TabBarView(
          controller: _tabController,
          children: [
            _buildProductsTab(),
            _buildAnimalNutritionTab(),
            _buildLiveCartsTab(),
            _buildTrafficGeoTab(),
            _buildClickstreamTab(),
            _buildShipmentsTab(),
            _buildCertificatesTab(adminState),
            _buildSellersTab(adminState),
            _buildSellerOffersTab(adminState),
            _buildDealsTab(),
            _buildCouponsTab(adminState),
            _buildInventoryTab(adminState),
            _buildAuditLogsTab(adminState),
          ],
        )),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Products & Catalog
  // ---------------------------------------------------------------------------
  Widget _buildProductsTab() {
    final catalogState = ref.watch(adminCatalogProductsProvider);
    final allProducts = catalogState.valueOrNull ?? const <Product>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Canonical Product Catalog (${allProducts.length} Items)',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: storeGreen),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create New Product'),
                onPressed: () => context.go('/admin/commerce/products'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('All (${allProducts.length})'),
                selected: _catalogFilter == 'all',
                onSelected: (_) => setState(() => _catalogFilter = 'all'),
              ),
              ChoiceChip(
                label: Text(
                  'Pending Review (${allProducts.where((p) => p.isPendingApproval).length})',
                  style: TextStyle(
                    color: allProducts.any((p) => p.isPendingApproval)
                        ? storeAmberDark
                        : null,
                    fontWeight: allProducts.any((p) => p.isPendingApproval)
                        ? FontWeight.bold
                        : null,
                  ),
                ),
                selected: _catalogFilter == 'pending',
                onSelected: (_) => setState(() => _catalogFilter = 'pending'),
              ),
              ChoiceChip(
                label: Text(
                    'Published (${allProducts.where((p) => p.isPublished).length})'),
                selected: _catalogFilter == 'published',
                onSelected: (_) => setState(() => _catalogFilter = 'published'),
              ),
              ChoiceChip(
                label: Text(
                    'Rejected (${allProducts.where((p) => p.isRejected).length})'),
                selected: _catalogFilter == 'rejected',
                onSelected: (_) => setState(() => _catalogFilter = 'rejected'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (catalogState.isLoading)
            const LinearProgressIndicator(color: storeGold),
          if (catalogState.hasError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: storeError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: storeError.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'The live backend catalogue could not be loaded. No demonstration products are shown in admin.',
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(adminCatalogProductsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (!catalogState.isLoading &&
              !catalogState.hasError &&
              allProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No backend products have been published yet.'),
            ),
          if (allProducts.isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allProducts.where((p) {
                  if (_catalogFilter == 'pending') return p.isPendingApproval;
                  if (_catalogFilter == 'published') return p.isPublished;
                  if (_catalogFilter == 'rejected') return p.isRejected;
                  return true;
                }).length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final filtered = allProducts.where((p) {
                    if (_catalogFilter == 'pending') return p.isPendingApproval;
                    if (_catalogFilter == 'published') return p.isPublished;
                    if (_catalogFilter == 'rejected') return p.isRejected;
                    return true;
                  }).toList();
                  final p = filtered[i];
                  final isConcept = p.isConcept;
                  final isPending = p.isPendingApproval;
                  final isRejected = p.isRejected;
                  final status = isConcept
                      ? 'Concept Preview'
                      : isPending
                          ? 'Pending Approval'
                          : isRejected
                              ? 'Rejected'
                              : p.taxonomy?['status']?.toString() ??
                                  'Active Commercial';
                  final pricing = isConcept
                      ? 'Price not announced · Not for sale'
                      : 'Base MRP: ${storeMoney(p.price)}';

                  return ListTile(
                    leading: SizedBox(
                      width: 48,
                      height: 48,
                      child: ProductArtwork(product: p),
                    ),
                    title: Text(p.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      'Category: ${storeCategory(p)} · ${p.packSize ?? p.unit} · $pricing',
                      style: const TextStyle(fontSize: 12, color: storeMuted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isConcept
                                ? const Color(0xffe8f5e9)
                                : isPending
                                    ? const Color(0xfffff8e1)
                                    : isRejected
                                        ? const Color(0xffffebee)
                                        : const Color(0xffe3f2fd),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: isConcept
                                    ? storeGreen
                                    : isPending
                                        ? storeAmberDark
                                        : isRejected
                                            ? storeError
                                            : const Color(0xff90caf9)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isConcept
                                  ? storeGreen
                                  : isPending
                                      ? storeAmberDark
                                      : isRejected
                                          ? storeError
                                          : const Color(0xff1565c0),
                            ),
                          ),
                        ),
                        if (isPending) ...[
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: storeGreen,
                                minimumSize: const Size(70, 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () => _approveProduct(p),
                            child: const Text('Approve',
                                style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(64, 32),
                                side: const BorderSide(color: storeError),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () => _rejectProduct(p),
                            child: const Text('Reject',
                                style: TextStyle(
                                    fontSize: 11, color: storeError)),
                          ),
                        ],
                        if (isRejected) ...[
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(80, 32),
                                side: const BorderSide(color: storeGreen),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: () => _approveProduct(p),
                            child: const Text('Re-approve',
                                style: TextStyle(
                                    fontSize: 11, color: storeGreen)),
                          ),
                        ],
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.photo_library_outlined),
                          tooltip: 'Manage product images',
                          onPressed: () async {
                            await showDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => ProductMediaManager(
                                    productId: p.id, title: p.title));
                            ref.invalidate(adminCatalogProductsProvider);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              size: 18, color: storeGreen),
                          tooltip: 'Edit Catalog Metadata',
                          onPressed: () =>
                              context.go('/admin/commerce/products'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddNutritionConceptDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    List<Map<String, String>> vendors;
    try {
      final response =
          await ref.read(dioProvider).get('/admin/marketplace/vendors');
      final body = response.data;
      if (body is! Map || body['data'] is! List) {
        throw const FormatException('Vendor response was invalid');
      }
      vendors = (body['data'] as List)
          .whereType<Map>()
          .map((item) => {
                'id': item['id']?.toString() ?? '',
                'name': item['business_name']?.toString() ?? 'Vendor',
              })
          .where((item) => item['id']!.isNotEmpty)
          .toList();
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not load active vendors: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (vendors.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('Create and activate a vendor before staging a concept.'),
        ),
      );
      return;
    }

    final titleCtrl =
        TextEditingController(text: 'MILTERRA RUMEN-PRO Rumen Support Concept');
    final subcatCtrl = TextEditingController(text: 'Bypass Nutrients');
    final descriptionCtrl =
        TextEditingController(text: Product.conceptExplanation);
    String vendorId = vendors.first['id']!;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.all(16),
          title: const Text('Add Nutrition Concept Formulation'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: vendorId,
                  decoration: const InputDecoration(
                    labelText: 'Responsible Vendor',
                    border: OutlineInputBorder(),
                  ),
                  items: vendors
                      .map((vendor) => DropdownMenuItem(
                            value: vendor['id'],
                            child: Text(vendor['name']!),
                          ))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) =>
                          setDialogState(() => vendorId = value ?? vendorId),
                ),
                const SizedBox(height: 10),
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Formulation Title',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                    controller: subcatCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nutritional Subcategory',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(
                  controller: descriptionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Concept purpose',
                    hintText:
                        'Describe the proposed purpose without unverified performance claims',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Concepts have no price, stock, cart, or checkout. A sellable variant can be created only after the family is changed from concept status.',
                  style: TextStyle(fontSize: 11, color: storeMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: saving
                  ? null
                  : () async {
                      final title = titleCtrl.text.trim();
                      final subcategory = subcatCtrl.text.trim();
                      final description = descriptionCtrl.text.trim();
                      if (title.length < 2 || subcategory.length < 2) {
                        messenger.showSnackBar(const SnackBar(
                          content: Text(
                              'Enter a title and nutritional subcategory.'),
                        ));
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ref.read(dioProvider).post(
                          '/vendor/families',
                          data: {
                            'vendor_id': vendorId,
                            'title': title,
                            'brand': 'MILTERRA',
                            'department': 'Farm Essentials',
                            'collection': 'Animal Nutrition',
                            'description': description.isEmpty
                                ? Product.conceptExplanation
                                : description,
                            'production_method':
                                'Proposed formulation; composition and claims require validation before launch.',
                            'is_published': true,
                            'is_concept': true,
                            'supporting_documents': {
                              'subcategory': subcategory,
                              'status': 'concept_preview',
                            },
                          },
                        );
                        ref.invalidate(adminNutritionConceptsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(SnackBar(
                            backgroundColor: storeGreen,
                            content: Text(
                                'Nutrition concept "$title" saved to the backend.'),
                          ));
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          messenger.showSnackBar(SnackBar(
                            content: Text('Concept was not saved: $error'),
                          ));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Stage Concept'),
            ),
          ],
        ),
      ),
    );
    titleCtrl.dispose();
    subcatCtrl.dispose();
    descriptionCtrl.dispose();
  }

  // TAB 2: Animal Nutrition Hub
  // ---------------------------------------------------------------------------
  Widget _buildAnimalNutritionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MILTERRA CATTLE NUTRITION SOLUTIONS',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: storeGreen),
                  ),
                  Text(
                    'Concept catalogue and formulation lifecycle management.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.biotech_outlined, size: 18),
                label: const Text('Add Nutrition Concept SKU'),
                onPressed: () => _showAddNutritionConceptDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Lifecycle Staging Guide
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: storeWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: storeBorder),
            ),
            child: Row(
              children: [
                _stagePill('1. Concept Preview', 'Proposed formulation',
                    const Color(0xffe8f5e9), storeGreen),
                const Icon(Icons.arrow_forward, size: 16, color: storeMuted),
                _stagePill(
                    '2. Feedback Registration',
                    'Register interest and feedback',
                    const Color(0xfffff8e1),
                    storeAmberDark),
                const Icon(Icons.arrow_forward, size: 16, color: storeMuted),
                _stagePill(
                    '3. Validation',
                    'Requires recorded validation evidence',
                    const Color(0xffe0f2f1),
                    const Color(0xff00695c)),
                const Icon(Icons.arrow_forward, size: 16, color: storeMuted),
                _stagePill(
                    '4. Commercial Launch',
                    'Full cart & checkout unlock',
                    const Color(0xffe3f2fd),
                    const Color(0xff1565c0)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Nutrition Concepts Table
          const Text('Active Nutrition Formulations & Stages',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ref.watch(adminNutritionConceptsProvider).when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load nutrition concepts: $error'),
                  ),
                ),
                data: (families) => Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: families.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                              'No backend concepts yet. Use Add Nutrition Concept SKU to stage one.'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: families.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final family = families[index];
                            return _nutritionConceptRow(
                              title: family.title,
                              subcategory:
                                  family.collection ?? 'Animal Nutrition',
                              stage: family.isPublished
                                  ? 'Concept Preview'
                                  : 'Draft Concept',
                              tagline: family.description.isEmpty
                                  ? Product.conceptExplanation
                                  : family.description,
                            );
                          },
                        ),
                ),
              ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Saved Visitor Feedback & Update Requests',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              IconButton(
                tooltip: 'Refresh feedback',
                onPressed: () => ref.invalidate(adminConceptFeedbackProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ref.watch(adminConceptFeedbackProvider).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Could not load concept feedback: $error'),
                  ),
                ),
                data: (items) => Card(
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No concept responses received yet.'),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final contact =
                                item['email'] ?? item['phone'] ?? '';
                            return ListTile(
                              leading: Icon(
                                item['wants_updates'] == true
                                    ? Icons.notifications_active_outlined
                                    : Icons.rate_review_outlined,
                                color: storeGreen,
                              ),
                              title: Text(
                                '${item['concept_title']} · ${item['visitor_name']}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${item['message'] ?? 'Update registration'}\n$contact',
                                style: const TextStyle(
                                    fontSize: 11, color: storeMuted),
                              ),
                              isThreeLine: true,
                            );
                          },
                        ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _stagePill(String title, String desc, Color bg, Color text) =>
      Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(fontSize: 10, color: storeMuted)),
            ],
          ),
        ),
      );

  Widget _nutritionConceptRow({
    required String title,
    required String subcategory,
    required String stage,
    required String tagline,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: storeSage.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.science_outlined, color: storeGreen),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('Subcategory: $subcategory · "$tagline"',
          style: const TextStyle(fontSize: 11, color: storeMuted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xffe8f5e9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: storeGreen),
            ),
            child: Text(stage,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: storeGreen)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Sellers & KYC Approvals
  // ---------------------------------------------------------------------------
  Widget _buildSellersTab(AdminMarketplaceState state) {
    final settlements = ref.watch(adminVendorSettlementsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seller Accounts & KYC Moderation (${state.sellers.length} Registered)',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen),
          ),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.sellers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = state.sellers[i];
                final isApproved = s.status == SellerStatus.approved;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: CircleAvatar(
                    backgroundColor: isApproved ? storeGreen : storeAmber,
                    child: Text(s.businessName.substring(0, 1),
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(s.businessName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isApproved
                              ? const Color(0xffe8f5e9)
                              : const Color(0xfffff8e1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.status.name.toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    isApproved ? storeGreen : storeAmberDark)),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.percent, size: 12),
                        label: Text(
                            'Fee: ${s.commissionRatePercent.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 11)),
                        onPressed: () => _editCommissionDialog(s),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'GSTIN: ${s.gstin ?? "N/A"} · FSSAI: ${s.fssaiLicense ?? "N/A"} · City: ${s.warehouseCity ?? "N/A"}',
                        style: const TextStyle(fontSize: 12, color: storeMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bank: ${s.bankAccountNumber != null ? "A/C ••••" + (s.bankAccountNumber!.length > 4 ? s.bankAccountNumber!.substring(s.bankAccountNumber!.length - 4) : s.bankAccountNumber!) : "Not Added"} · IFSC: ${s.ifscCode ?? "N/A"} · UPI: ${s.upiId ?? "N/A"}',
                        style: const TextStyle(fontSize: 11, color: storeMuted),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isApproved) ...[
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: storeGreen,
                              minimumSize: const Size(80, 32)),
                          onPressed: () => _saveAdminAction(() => ref
                              .read(adminMarketplaceProvider.notifier)
                              .approveSeller(s.id)),
                          child: const Text('Approve KYC',
                              style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isApproved) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(80, 32),
                              side: const BorderSide(color: storeError)),
                          onPressed: () => _saveAdminAction(() => ref
                              .read(adminMarketplaceProvider.notifier)
                              .suspendSeller(
                                  s.id, 'Suspended by administrator')),
                          child: const Text('Suspend',
                              style:
                                  TextStyle(fontSize: 11, color: storeError)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),

          // -----------------------------------------------------------------
          // Vendor Settlements & Payouts Console
          // -----------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vendor Financial Settlements & Payouts',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: storeGreen),
                  ),
                  Text(
                    'Net payable earnings from fulfilled customer orders minus platform commission.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh balances'),
                onPressed: () =>
                    ref.invalidate(adminVendorSettlementsProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          settlements.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('Could not load vendor settlements: $err')),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(adminVendorSettlementsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text('No registered vendors found.'),
                    ),
                  ),
                );
              }
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = rows[idx];
                    final name = item['business_name']?.toString() ?? 'Vendor';
                    final gross = double.tryParse(
                            item['gross_sales']?.toString() ?? '') ??
                        0.0;
                    final commAmt = double.tryParse(
                            item['commission_amount']?.toString() ?? '') ??
                        0.0;
                    final commRate = double.tryParse(
                            item['commission_rate']?.toString() ?? '') ??
                        5.0;
                    final netPayable = double.tryParse(
                            item['net_payable']?.toString() ?? '') ??
                        0.0;
                    final totalSettled = double.tryParse(
                            item['total_settled']?.toString() ?? '') ??
                        0.0;
                    final pending = double.tryParse(
                            item['pending_balance']?.toString() ?? '') ??
                        0.0;
                    final acc = item['account_number']?.toString() ?? '';
                    final bank = item['bank_name']?.toString() ?? '';
                    final recentPayouts = item['recent_payouts'] is List
                        ? (item['recent_payouts'] as List)
                            .whereType<Map>()
                            .toList()
                        : [];

                    final hasPending = pending > 0;

                    return ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: hasPending
                              ? const Color(0xfffef3c7)
                              : const Color(0xfff0fdf4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: hasPending
                              ? const Color(0xffb45309)
                              : storeGreen,
                        ),
                      ),
                      title: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasPending
                                  ? const Color(0xfffff7ed)
                                  : const Color(0xffecfdf5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: hasPending
                                      ? const Color(0xfffdba74)
                                      : const Color(0xffa7f3d0)),
                            ),
                            child: Text(
                              hasPending
                                  ? 'PENDING: ${storeMoney(pending)}'
                                  : 'ALL SETTLED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: hasPending
                                    ? const Color(0xffc2410c)
                                    : storeGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Gross: ${storeMoney(gross)} · Fee (${commRate.toStringAsFixed(1)}%): -${storeMoney(commAmt)} · Net: ${storeMoney(netPayable)} · Settled: ${storeMoney(totalSettled)}\nBank: ${bank.isEmpty ? 'Not added' : bank} ${acc.isNotEmpty ? '(••••${acc.length > 4 ? acc.substring(acc.length - 4) : acc})' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xff475569)),
                        ),
                      ),
                      trailing: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: hasPending
                              ? storeGreen.withValues(alpha: 0.12)
                              : const Color(0xfff1f5f9),
                          foregroundColor:
                              hasPending ? storeGreen : storeMuted,
                        ),
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Disburse Payout'),
                        onPressed: hasPending
                            ? () => _disbursePayoutDialog(
                                Map<String, dynamic>.from(item))
                            : null,
                      ),
                      children: [
                        if (recentPayouts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: Text('No historical payouts recorded yet.',
                                  style: TextStyle(
                                      fontSize: 12, color: storeMuted)),
                            ),
                          )
                        else ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Recent Disbursements',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: storeMuted)),
                            ),
                          ),
                          ...recentPayouts.map((p) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle_outline,
                                    color: storeGreen, size: 18),
                                title: Text(
                                    '${storeMoney(double.tryParse(p['amount']?.toString() ?? '') ?? 0.0)} · Ref: ${p['payment_reference'] ?? 'N/A'}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                    '${p['processed_at'] ?? p['created_at'] ?? ''} ${p['remarks'] != null && p['remarks'].toString().isNotEmpty ? '· ' + p['remarks'].toString() : ''}',
                                    style: const TextStyle(fontSize: 11)),
                                trailing: Text(
                                    (p['status'] ?? 'PAID')
                                        .toString()
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen)),
                              )),
                        ],
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Seller Offers
  // ---------------------------------------------------------------------------
  Widget _buildSellerOffersTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Marketplace Seller SKU Offers',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: storeGreen)),
          const SizedBox(height: 6),
          const Text(
              'Compare prices and inventory across sellers for the same canonical catalog SKU.',
              style: TextStyle(fontSize: 12, color: storeMuted)),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.offers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final o = state.offers[i];
                return ListTile(
                  leading: Icon(
                    o.isBuyBoxWinner ? Icons.star : Icons.store_outlined,
                    color: o.isBuyBoxWinner ? storeGold : storeGreen,
                  ),
                  title: Row(
                    children: [
                      Text('${o.sellerName} · SKU: ${o.sellerSku}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      if (o.isBuyBoxWinner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xff232f3e),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('BUY BOX WINNER',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xffff9900),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Price: ${storeMoney(o.sellingPrice)} (MRP ${storeMoney(o.mrp)}) · Available Stock: ${o.availableStock} units · ${o.deliveryPromise}',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.price_change_outlined,
                            size: 18, color: storeGreen),
                        tooltip: 'Adjust Offer Price',
                        onPressed: () => _showEditOfferPriceDialog(o),
                      ),
                      IconButton(
                        icon: const Icon(Icons.inventory_outlined,
                            size: 18, color: storeAmberDark),
                        tooltip: 'Adjust Stock Level',
                        onPressed: () => _showEditOfferStockDialog(o),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 5: Deals Engine
  // ---------------------------------------------------------------------------
  Widget _buildDealsTab() {
    final placements = ref.watch(adminStorefrontPlacementsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Promotions & Lightning Deals',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: storeGreen)),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule New Deal'),
                onPressed: () => _showCreateDealDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          placements.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(child: Text('Could not load promotions: $error')),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(adminStorefrontPlacementsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (items) => Column(
              children: [
                if (items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No storefront placement is published. Schedule one to show the highlighted product strip.',
                      ),
                    ),
                  ),
                for (final placement in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xfffff3e0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bolt,
                                color: storeOrange, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(placement.headline,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  '${placement.product.title} · ${storeMoney(placement.product.price)} · ${placement.placementType.replaceAll('_', ' ')}',
                                  style: const TextStyle(
                                      fontSize: 12, color: storeMuted),
                                ),
                                if (placement.endsAt != null)
                                  Text(
                                    'Runs until: ${placement.endsAt!.toLocal()}',
                                    style: const TextStyle(
                                        fontSize: 11, color: storeGreen),
                                  ),
                              ],
                            ),
                          ),
                          Switch(
                            value: placement.isActive,
                            onChanged: (active) async {
                              await ref
                                  .read(merchandisingRepositoryProvider)
                                  .setActive(placement.id, active);
                              ref.invalidate(adminStorefrontPlacementsProvider);
                              ref.invalidate(storefrontPlacementsProvider);
                            },
                          ),
                          Text(
                            placement.isActive ? 'ACTIVE' : 'PAUSED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  placement.isActive ? storeGreen : storeMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 6: Coupons
  // ---------------------------------------------------------------------------
  Widget _buildCouponsTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Platform Coupons & Discount Rules',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: storeGreen)),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Coupon'),
                onPressed: () => _showCreateCouponDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final c in state.coupons) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: storeSage, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.confirmation_number_outlined,
                      color: storeGreen),
                ),
                title: Text(c.code,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1.0,
                        color: storeGreen)),
                subtitle: Text(
                    '${c.description} · Min Order: ${storeMoney(c.minOrderValue)} · Redemptions: ${c.usageCount}',
                    style: const TextStyle(fontSize: 12, color: storeMuted)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: 'Edit coupon',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showCreateCouponDialog(existing: c)),
                  Switch(
                      value: c.isActive,
                      onChanged: (_) => _saveAdminAction(() => ref
                          .read(adminMarketplaceProvider.notifier)
                          .toggleCoupon(c))),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 7: Inventory
  // ---------------------------------------------------------------------------
  Widget _buildInventoryTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Warehouse Stock & Reorder Levels',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: storeGreen)),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.offers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final o = state.offers[i];
                final isLow = o.availableStock <= o.lowStockThreshold;

                return ListTile(
                  leading: Icon(Icons.inventory,
                      color: isLow ? storeError : storeGreen),
                  title: Text('${o.sellerSku} (${o.sellerName})',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                      'Available: ${o.availableStock} units · Threshold: ${o.lowStockThreshold} units',
                      style: const TextStyle(fontSize: 12, color: storeMuted)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLow
                          ? const Color(0xffffebee)
                          : const Color(0xffe8f5e9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isLow ? 'LOW STOCK ALERT' : 'HEALTHY STOCK',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isLow ? storeError : storeGreen),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 8: Audit Trail
  // ---------------------------------------------------------------------------
  Widget _buildAuditLogsTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Immutable Marketplace Audit Trail',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: storeGreen)),
          const SizedBox(height: 6),
          const Text(
              'Tracks who modified prices, inventory, seller approvals, or promotions.',
              style: TextStyle(fontSize: 12, color: storeMuted)),
          const SizedBox(height: 16),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.auditLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final log = state.auditLogs[i];
                return ListTile(
                  leading: const Icon(Icons.shield_outlined, color: storeGreen),
                  title: Text(
                      '${log.action.name.toUpperCase()} on ${log.entityType}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                      '${log.details}\nBy ${log.userIdentifier} (${log.userRole}) · ${log.timestamp}',
                      style: const TextStyle(
                          fontSize: 11, color: storeMuted, height: 1.3)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog Helpers
  // ---------------------------------------------------------------------------

  void _showEditOfferPriceDialog(SellerOffer o) {
    final priceCtrl =
        TextEditingController(text: o.sellingPrice.toStringAsFixed(0));
    final mrpCtrl = TextEditingController(text: o.mrp.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Price for ${o.sellerSku}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(
                    labelText: 'Selling Price (₹)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: mrpCtrl,
                decoration: const InputDecoration(
                    labelText: 'MRP (₹)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              _saveAdminAction(() async {
                final np = double.tryParse(priceCtrl.text);
                final nm = double.tryParse(mrpCtrl.text);
                if (np == null || nm == null) {
                  throw StateError('Enter valid selling price and MRP values.');
                }
                await ref
                    .read(adminMarketplaceProvider.notifier)
                    .updateOfferPrice(o.id, np, nm);
              }, dialog: ctx);
            },
            child: const Text('Update Price'),
          ),
        ],
      ),
    );
  }

  void _showEditOfferStockDialog(SellerOffer o) {
    final stockCtrl = TextEditingController(text: o.availableStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock for ${o.sellerSku}'),
        content: TextField(
            controller: stockCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Available Units', border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              _saveAdminAction(() async {
                final ns = int.tryParse(stockCtrl.text);
                if (ns == null) {
                  throw StateError('Enter a whole number of stock units.');
                }
                await ref
                    .read(adminMarketplaceProvider.notifier)
                    .updateOfferStock(o.id, ns);
              }, dialog: ctx);
            },
            child: const Text('Save Stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateDealDialog() async {
    List<Product> products;
    try {
      products = await ref.read(adminCatalogProductsProvider.future);
      products = products
          .where((product) => product.isPublished && !product.isConcept)
          .toList();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load products: $error')),
      );
      return;
    }
    if (products.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Create a backend product before scheduling a placement.'),
        ),
      );
      return;
    }

    final titleCtrl =
        TextEditingController(text: 'Discover ${products.first.title}');
    final subtitleCtrl = TextEditingController(
        text: 'Featured by Milterra · Tap to explore the product');
    final badgeCtrl = TextEditingController(text: 'NEW LAUNCH');
    String productId = products.first.id;
    String placementType = 'new_launch';
    double durationHours = 24;
    bool saving = false;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Publish Storefront Highlight'),
          scrollable: true,
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: productId,
                  decoration: const InputDecoration(
                      labelText: 'Canonical Product',
                      border: OutlineInputBorder()),
                  items: products
                      .map((product) => DropdownMenuItem(
                          value: product.id,
                          child: Text(product.title,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) =>
                          setDialogState(() => productId = value ?? productId),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: placementType,
                  decoration: const InputDecoration(
                      labelText: 'Placement Type',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'highlight', child: Text('Highlighted Product')),
                    DropdownMenuItem(
                        value: 'deal', child: Text('Deal / Offer')),
                    DropdownMenuItem(
                        value: 'new_launch', child: Text('New Launch')),
                    DropdownMenuItem(
                        value: 'festival_offer', child: Text('Festival Offer')),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(
                          () => placementType = value ?? placementType),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Headline', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Supporting Line',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: badgeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Badge (e.g. NEW LAUNCH)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: durationHours,
                  decoration: const InputDecoration(
                      labelText: 'Display Duration',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 12, child: Text('12 hours')),
                    DropdownMenuItem(value: 24, child: Text('24 hours')),
                    DropdownMenuItem(value: 72, child: Text('3 days')),
                    DropdownMenuItem(value: 168, child: Text('7 days')),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setDialogState(
                          () => durationHours = value ?? durationHours),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Price and MRP come from the canonical backend product. Update the product first so cards, cart, and this highlight remain consistent.',
                  style: TextStyle(fontSize: 11, color: storeMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: saving
                  ? null
                  : () async {
                      final headline = titleCtrl.text.trim();
                      if (headline.length < 3) return;
                      final messenger = ScaffoldMessenger.of(this.context);
                      setDialogState(() => saving = true);
                      try {
                        final now = DateTime.now();
                        await ref.read(merchandisingRepositoryProvider).create(
                              productId: productId,
                              placementType: placementType,
                              headline: headline,
                              subheadline: subtitleCtrl.text.trim(),
                              badge: badgeCtrl.text.trim(),
                              startsAt: now,
                              endsAt: now
                                  .add(Duration(hours: durationHours.round())),
                              priority: 200,
                            );
                        ref.invalidate(adminStorefrontPlacementsProvider);
                        ref.invalidate(storefrontPlacementsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Storefront highlight published.')),
                          );
                        }
                      } catch (error) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text('Could not publish: $error')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Publish Highlight'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showCreateCouponDialog({PlatformCoupon? existing}) async {
    final code = TextEditingController(text: existing?.code ?? '');
    final description =
        TextEditingController(text: existing?.description ?? '');
    final discount =
        TextEditingController(text: existing?.discountValue.toString() ?? '');
    final minimum =
        TextEditingController(text: existing?.minOrderValue.toString() ?? '0');
    final cap =
        TextEditingController(text: existing?.maxDiscountCap?.toString() ?? '');
    final expiry = TextEditingController(
        text: existing?.validUntil?.toUtc().toIso8601String() ?? '');
    var type = existing?.discountType ?? CouponType.percentage;
    var active = existing?.isActive ?? true;
    Widget field(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label)));
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                  title:
                      Text(existing == null ? 'Create Coupon' : 'Edit Coupon'),
                  scrollable: true,
                  content: SizedBox(
                      width: 480,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        field(code, 'Coupon code'),
                        field(description, 'Offer description'),
                        DropdownButtonFormField<CouponType>(
                            initialValue: type,
                            isExpanded: true,
                            items: CouponType.values
                                .map((t) => DropdownMenuItem(
                                    value: t, child: Text(t.name)))
                                .toList(),
                            onChanged: (v) => update(() => type = v!),
                            decoration: const InputDecoration(
                                labelText: 'Discount type')),
                        field(discount, 'Discount value'),
                        field(minimum, 'Minimum order value (₹)'),
                        field(cap, 'Maximum discount (₹, optional)'),
                        field(expiry, 'Expiry UTC (ISO date/time, optional)'),
                        SwitchListTile(
                            title: const Text('Active'),
                            value: active,
                            onChanged: (v) => update(() => active = v)),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => _saveAdminAction(() async {
                              final value = double.tryParse(discount.text);
                              final min = double.tryParse(minimum.text);
                              final max = cap.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(cap.text);
                              final until = expiry.text.trim().isEmpty
                                  ? null
                                  : DateTime.tryParse(expiry.text);
                              if (value == null ||
                                  min == null ||
                                  (cap.text.isNotEmpty && max == null) ||
                                  (expiry.text.isNotEmpty && until == null)) {
                                throw StateError(
                                    'Enter valid numbers and an ISO expiry date.');
                              }
                              await ref
                                  .read(adminMarketplaceProvider.notifier)
                                  .saveCoupon(PlatformCoupon(
                                      id: existing?.id ?? '',
                                      code: code.text.trim().toUpperCase(),
                                      description: description.text.trim(),
                                      discountType: type,
                                      discountValue: value,
                                      minOrderValue: min,
                                      maxDiscountCap: max,
                                      validUntil: until,
                                      isActive: active));
                            }, dialog: ctx),
                        child: const Text('Save Coupon')),
                  ],
                )));
    for (final c in [code, description, discount, minimum, cap, expiry]) {
      c.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Shipments & Logistics
  // ---------------------------------------------------------------------------
  Widget _buildShipmentsTab() {
    final interests = ref.watch(adminPurchaseInterestsProvider);
    final cancellations = ref.watch(adminCancellationsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cancellation & Refund Requests',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: storeGreen),
                  ),
                  Text(
                    'Customer cancellation requests for paid orders awaiting admin refund review.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh requests'),
                onPressed: () => ref.invalidate(adminCancellationsProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          cancellations.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text('Could not load refund queue: $error')),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(adminCancellationsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                          'No pending refund or cancellation requests. All customer orders are in good standing.'),
                    ),
                  ),
                );
              }
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final order = rows[index];
                    final orderNumber =
                        order['order_number']?.toString() ?? order['id'] ?? '';
                    final total = double.tryParse(
                            order['total']?.toString() ?? '') ??
                        0.0;
                    final reason = order['cancel_reason']?.toString() ??
                        order['notes']?.toString() ??
                        '';
                    final customerPhone =
                        order['contact_phone']?.toString() ?? '';
                    final isRefunded =
                        order['payment_status']?.toString().toUpperCase() ==
                            'REFUNDED';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isRefunded
                              ? const Color(0xffecfdf5)
                              : const Color(0xfffee2e2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isRefunded
                              ? Icons.check_circle_outline
                              : Icons.assignment_return_outlined,
                          color: isRefunded ? storeGreen : storeError,
                        ),
                      ),
                      title: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Order #$orderNumber',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(customerPhone,
                              style: const TextStyle(
                                  color: storeGreen,
                                  fontWeight: FontWeight.w600)),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: isRefunded
                                ? const Color(0xffdcfce7)
                                : const Color(0xfffef3c7),
                            label: Text(
                              isRefunded ? 'REFUNDED' : 'PENDING REVIEW',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isRefunded
                                      ? storeGreen
                                      : const Color(0xffb45309)),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total: ${storeMoney(total)} • Status: ${order['status'] ?? ''} • Payment: ${order['payment_status'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xff475569)),
                            ),
                            if (reason.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Reason: $reason',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: storeError,
                                      fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                      trailing: isRefunded
                          ? null
                          : FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.rate_review_outlined,
                                  size: 16),
                              label: const Text('Review / Refund'),
                              onPressed: () => _processRefundDialog(order),
                            ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pre-launch Purchase Interests',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: storeGreen),
                  ),
                  Text(
                    'No payment or shipment is created. Contact interested customers before launch.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh interests'),
                onPressed: () => ref.invalidate(adminPurchaseInterestsProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          interests.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Could not load interests: $error')),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(adminPurchaseInterestsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: Text('No customer purchase interests yet.'),
                    ),
                  ),
                );
              }
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final interest = rows[index];
                    final address = interest['address'] is Map
                        ? Map<String, dynamic>.from(interest['address'] as Map)
                        : const <String, dynamic>{};
                    final items = interest['items'] is List
                        ? interest['items'] as List
                        : const [];
                    final titles = items
                        .whereType<Map>()
                        .map((item) =>
                            '${item['title'] ?? 'Product'} ×${item['quantity'] ?? 1}')
                        .join(', ');
                    final total =
                        double.tryParse(interest['total']?.toString() ?? '') ??
                            0;
                    final customerPhone =
                        interest['customer_phone']?.toString() ?? '';
                    final recipient =
                        address['recipient_name']?.toString() ?? 'Customer';
                    final place = [
                      address['village_or_city'] ?? address['city'],
                      address['state'],
                    ]
                        .where((value) =>
                            value != null && value.toString().isNotEmpty)
                        .join(', ');

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xfffff7df),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.phone_callback_outlined,
                            color: Color(0xffa16207)),
                      ),
                      title: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(recipient,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(customerPhone,
                              style: const TextStyle(
                                  color: storeGreen,
                                  fontWeight: FontWeight.w700)),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                                interest['interest_status']?.toString() ??
                                    'NEW',
                                style: const TextStyle(fontSize: 10)),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${titles.isEmpty ? 'No items' : titles}\n$place • Indicative basket ${storeMoney(total)} • ${interest['created_at'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xff475569)),
                        ),
                      ),
                      isThreeLine: true,
                      onTap: () => _editInterest(interest),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Batch Certificates & Quality Assurance
  // ---------------------------------------------------------------------------
  Widget _buildCertificatesTab(AdminMarketplaceState adminState) {
    final certificates = adminState.batchCertificates;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch Quality & Lab Test Certificates',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: storeGreen),
                  ),
                  Text(
                    'FSSAI, Agmark & Soil Analysis verified batches (${certificates.length} Total)',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Issue New Batch Certificate'),
                onPressed: () => _showCreateCertificateDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: 260,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: certificates.length,
            itemBuilder: (context, i) {
              final cert = certificates[i];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified,
                                  size: 13, color: Color(0xff166534)),
                              const SizedBox(width: 4),
                              Text(
                                cert.status,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xff166534)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Purity: ${cert.purityPercent}%',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: storeGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'BATCH #${cert.batchNumber}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: storeGreen),
                    ),
                    Text(
                      cert.productTitle,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff1e293b)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Testing Lab: ${cert.laboratory}',
                      style: const TextStyle(fontSize: 11, color: storeMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'FSSAI / Standard: ${cert.fssaiLicense}',
                      style: const TextStyle(fontSize: 11, color: storeMuted),
                    ),
                    const Spacer(),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Signatory: ${cert.certifiedBy.split('(').first.trim()}',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xff64748b)),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _showCertificateDetailsDialog(cert),
                          child: const Text('View Report',
                              style: TextStyle(fontSize: 11)),
                        ),
                        IconButton(
                            tooltip: 'Edit certificate',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _showCreateCertificateDialog(existing: cert)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateCertificateDialog(
      {BatchCertificate? existing}) async {
    List<Product> products;
    try {
      products = await ref.read(adminCatalogProductsProvider.future);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(commerceError(error))));
      return;
    }
    if (!mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Create a backend product before adding a certificate.')));
      return;
    }
    var productId = products.any((p) => p.id == existing?.productId)
        ? existing!.productId
        : products.first.id;
    var status = existing?.status ?? 'PENDING_REVIEW';
    final batch = TextEditingController(text: existing?.batchNumber ?? '');
    final date = TextEditingController(
        text: existing?.testDate.toUtc().toIso8601String() ?? '');
    final lab = TextEditingController(text: existing?.laboratory ?? '');
    final license = TextEditingController(text: existing?.fssaiLicense ?? '');
    final purity =
        TextEditingController(text: existing?.purityPercent?.toString() ?? '');
    final certifier = TextEditingController(text: existing?.certifiedBy ?? '');
    final report = TextEditingController(text: existing?.reportUrl ?? '');
    final remarks = TextEditingController(text: existing?.remarks ?? '');
    final parameters = TextEditingController(
        text: existing?.testParameters.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('\n') ??
            '');
    Widget field(TextEditingController controller, String label,
            {int lines = 1}) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
                controller: controller,
                maxLines: lines,
                decoration: InputDecoration(labelText: label)));
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => AlertDialog(
                  title: Text(existing == null
                      ? 'Add Batch Certificate'
                      : 'Edit Batch Certificate'),
                  scrollable: true,
                  content: SizedBox(
                      width: 580,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        DropdownButtonFormField<String>(
                            initialValue: productId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Backend product / pack'),
                            items: products
                                .map((p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                        '${p.title} · ${p.packSize ?? p.unit}',
                                        overflow: TextOverflow.ellipsis)))
                                .toList(),
                            onChanged: (v) => update(() => productId = v!)),
                        field(batch, 'Batch number'),
                        field(date, 'Test date UTC (ISO date/time)'),
                        field(lab, 'Testing laboratory'),
                        field(license, 'License / registration (optional)'),
                        field(purity, 'Purity % (optional)'),
                        field(certifier, 'Certified by'),
                        field(report, 'Report URL (http/https)'),
                        field(remarks, 'Remarks', lines: 2),
                        field(parameters,
                            'Measured parameters (one Name: Result per line)',
                            lines: 4),
                        DropdownButtonFormField<String>(
                            initialValue: status,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Review status'),
                            items: ['PENDING_REVIEW', 'CERTIFIED', 'REJECTED']
                                .map((s) =>
                                    DropdownMenuItem(value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) => update(() => status = v!)),
                        const SizedBox(height: 12),
                        const Text(
                            'Only certified records with a report link appear to customers. Enter actual results; blank fields do not imply passed tests.'),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => _saveAdminAction(() async {
                              final testDate = DateTime.tryParse(date.text);
                              final percent = purity.text.trim().isEmpty
                                  ? null
                                  : double.tryParse(purity.text);
                              if (testDate == null ||
                                  (purity.text.isNotEmpty && percent == null))
                                throw StateError(
                                    'Enter a valid test date and purity value.');
                              final values = <String, String>{};
                              for (final line in parameters.text
                                  .split('\n')
                                  .where((v) => v.trim().isNotEmpty)) {
                                final split = line.indexOf(':');
                                if (split <= 0 || split == line.length - 1)
                                  throw StateError(
                                      'Use Name: Result for each parameter.');
                                values[line.substring(0, split).trim()] =
                                    line.substring(split + 1).trim();
                              }
                              final product =
                                  products.firstWhere((p) => p.id == productId);
                              await ref
                                  .read(adminMarketplaceProvider.notifier)
                                  .saveCertificate(BatchCertificate(
                                      id: existing?.id ?? '',
                                      batchNumber: batch.text.trim(),
                                      productId: productId,
                                      productTitle: product.title,
                                      category: product.category.name,
                                      testDate: testDate,
                                      laboratory: lab.text.trim(),
                                      fssaiLicense: license.text.trim(),
                                      purityPercent: percent,
                                      testParameters: values,
                                      status: status,
                                      certifiedBy: certifier.text.trim(),
                                      remarks: remarks.text.trim(),
                                      reportUrl: report.text.trim().isEmpty
                                          ? null
                                          : report.text.trim()));
                            }, dialog: ctx),
                        child: const Text('Save Certificate')),
                  ],
                )));
    for (final c in [
      batch,
      date,
      lab,
      license,
      purity,
      certifier,
      report,
      remarks,
      parameters
    ]) {
      c.dispose();
    }
  }

  void _showCertificateDetailsDialog(BatchCertificate cert) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: storeGreen,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.verified,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MILTERRA QUALITY ASSURANCE CERTIFICATE',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: storeGreen,
                                    letterSpacing: 0.8)),
                            Text('Batch #${cert.batchNumber}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('Product: ${cert.productTitle}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Laboratory: ${cert.laboratory}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff475569))),
                  Text('FSSAI / Agro License: ${cert.fssaiLicense}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff475569))),
                  Text('Purity Score: ${cert.purityPercent}%',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: storeGreen)),
                  const SizedBox(height: 16),
                  const Text('LABORATORY TEST MATRIX',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: storeMuted)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffe2e8f0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        for (final entry in cert.testParameters.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0xfff1f5f9))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xff334155))),
                                Text(entry.value,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Remarks: ${cert.remarks}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Color(0xff64748b))),
                  Text('Certified By: ${cert.certifiedBy}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff334155))),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: storeGreen),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Live Carts & Abandoned Cart Recovery
  // ---------------------------------------------------------------------------
  Widget _buildLiveCartsTab() {
    final analyticsState = ref.watch(adminAnalyticsProvider);
    final analyticsNotifier = ref.read(adminAnalyticsProvider.notifier);

    final carts = analyticsState.carts;
    final activeCount =
        carts.where((c) => !c.isAbandoned && c.status == 'ACTIVE').length;
    final abandonedCount = carts.where((c) => c.isAbandoned).length;
    final totalAtRisk = carts
        .where((c) => c.isAbandoned)
        .fold(0.0, (sum, c) => sum + c.subtotal);

    return RefreshIndicator(
      onRefresh: () => analyticsNotifier.fetchCarts(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
            Row(
              children: [
                _buildAnalyticsKpiCard(
                  title: 'Active Carts Right Now',
                  value: activeCount.toString(),
                  subtitle: 'Shoppers currently adding items',
                  icon: Icons.shopping_cart_outlined,
                  color: storeGreen,
                ),
                const SizedBox(width: 16),
                _buildAnalyticsKpiCard(
                  title: 'Abandoned Carts (>1hr)',
                  value: abandonedCount.toString(),
                  subtitle: 'Inactive carts needing recovery',
                  icon: Icons.remove_shopping_cart_outlined,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 16),
                _buildAnalyticsKpiCard(
                  title: 'Cart Value at Risk',
                  value: '₹${totalAtRisk.toStringAsFixed(0)}',
                  subtitle: 'Potential revenue recoverable',
                  icon: Icons.currency_rupee,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 16),
                _buildAnalyticsKpiCard(
                  title: 'Recovery Rate',
                  value: '—',
                  subtitle: 'Requires completed recovery events',
                  icon: Icons.trending_up,
                  color: Colors.teal.shade700,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Controls & Filters
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText:
                              'Search by customer phone (+91...) or product...',
                          prefixIcon: const Icon(Icons.search,
                              size: 20, color: Color(0xff64748b)),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xfff8fafc),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xffe2e8f0)),
                          ),
                        ),
                        onChanged: (val) =>
                            analyticsNotifier.setCartSearch(val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip(
                            'All Carts',
                            'all',
                            analyticsState.cartFilter,
                            (f) => analyticsNotifier.setCartFilter(f)),
                        _buildFilterChip(
                            'Active Only',
                            'active',
                            analyticsState.cartFilter,
                            (f) => analyticsNotifier.setCartFilter(f)),
                        _buildFilterChip(
                            'Abandoned',
                            'abandoned',
                            analyticsState.cartFilter,
                            (f) => analyticsNotifier.setCartFilter(f)),
                        _buildFilterChip(
                            'High Value (>₹1k)',
                            'high_value',
                            analyticsState.cartFilter,
                            (f) => analyticsNotifier.setCartFilter(f)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xff64748b)),
                      tooltip: 'Refresh Carts',
                      onPressed: () => analyticsNotifier.fetchCarts(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Carts List
            if (analyticsState.isLoadingCarts)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else if (analyticsState.cartsError != null)
              _buildAdminDataState(
                message: analyticsState.cartsError!,
                icon: Icons.cloud_off_outlined,
                onRetry: analyticsNotifier.fetchCarts,
              )
            else if (carts.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 48, color: Color(0xff94a3b8)),
                        SizedBox(height: 12),
                        Text('No carts match the current filter',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: carts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (ctx, idx) {
                  final cart = carts[idx];
                  return _buildAdminCartCard(cart, analyticsNotifier);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCartCard(
      AdminCartSummary cart, AdminAnalyticsNotifier notifier) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cart.isAbandoned
              ? Colors.orange.shade300
              : const Color(0xffe2e8f0),
          width: cart.isAbandoned ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: User phone, role, status badge, timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cart.isAbandoned
                        ? Colors.orange.shade50
                        : const Color(0xfff0fdf4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    cart.isAbandoned
                        ? Icons.remove_shopping_cart
                        : Icons.shopping_bag,
                    color:
                        cart.isAbandoned ? Colors.orange.shade800 : storeGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cart.userPhone,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xff0f172a)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffe2e8f0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cart.userRole.toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff475569)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last activity: ${cart.inactiveDurationMinutes < 60 ? "${cart.inactiveDurationMinutes}m ago" : "${cart.inactiveDurationMinutes ~/ 60}h ago"}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xff64748b)),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cart.isAbandoned
                        ? Colors.red.shade50
                        : const Color(0xffdcfce7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: cart.isAbandoned
                            ? Colors.red.shade200
                            : Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cart.isAbandoned
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 14,
                        color:
                            cart.isAbandoned ? Colors.red.shade700 : storeGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cart.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cart.isAbandoned
                              ? Colors.red.shade800
                              : storeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xfff1f5f9)),

            // Cart Items List
            Column(
              children: cart.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xffe2e8f0)),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            size: 18, color: storeGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.title,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xff1e293b))),
                            Text('SKU: ${it.productId}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xff94a3b8))),
                          ],
                        ),
                      ),
                      Text(
                        '${it.quantity} × ₹${it.unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xff64748b)),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '₹${it.lineTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0f172a)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const Divider(height: 24, color: Color(0xfff1f5f9)),

            // Footer: Subtotal & Actions
            Row(
              children: [
                RichText(
                  text: TextSpan(
                    text: 'Total Cart Value: ',
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xff475569)),
                    children: [
                      TextSpan(
                        text: '₹${cart.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: storeGreen,
                            fontSize: 16),
                      ),
                      TextSpan(
                        text: ' (${cart.itemCount} items)',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xff94a3b8)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff334155),
                    side: const BorderSide(color: Color(0xffcbd5e1)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.ads_click, size: 16),
                  label: const Text('Inspect Journey',
                      style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    notifier.setClickstreamUserPhone(cart.userPhone);
                    _tabController
                        .animateTo(4); // Jump to User Clickstream Tab (index 4)
                  },
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff25d366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('WhatsApp Recovery Nudge',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showWhatsAppNudgeDialog(cart, notifier),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWhatsAppNudgeDialog(
      AdminCartSummary cart, AdminAnalyticsNotifier notifier) async {
    final nudge = await notifier.getNudgeLink(cart.cartId);
    if (!mounted) return;
    if (nudge == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not prepare a reminder. Please retry.')));
      return;
    }
    final link = nudge['whatsapp_link'].toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: const Color(0xffdcfce7),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chat_outlined,
                  color: Color(0xff25d366), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Cart Recovery Nudge',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Target Customer: ${cart.userPhone} (${cart.userRole.toUpperCase()})',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Text(
                  'Cart Contents: ${cart.items.map((i) => i.title).join(", ")}',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xff64748b))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Text(
                  nudge['sms_message'].toString(),
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.4, color: Color(0xff334155)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Recovery Link:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              SelectableText(
                link,
                style: const TextStyle(fontSize: 11, color: storeGreen),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff25d366)),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Copy reminder link'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Link copied. No message has been sent to ${cart.userPhone}.')),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Traffic & Geolocation Analytics
  // ---------------------------------------------------------------------------
  Widget _buildTrafficGeoTab() {
    final analyticsState = ref.watch(adminAnalyticsProvider);
    final traffic = analyticsState.traffic;
    final analyticsNotifier = ref.read(adminAnalyticsProvider.notifier);

    if (analyticsState.isLoadingTraffic && traffic == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (traffic == null) {
      return _buildAdminDataState(
        message: analyticsState.trafficError ??
            'No traffic analytics have been recorded yet.',
        icon: analyticsState.trafficError == null
            ? Icons.analytics_outlined
            : Icons.cloud_off_outlined,
        onRetry: analyticsNotifier.fetchTraffic,
      );
    }

    final totalVisits = traffic.totalVisitors;
    final todayVisits = traffic.todayVisitors;
    final liveVisits = traffic.liveVisitors30m;
    final totalPageViews = traffic.totalPageViews;
    final bounceRate = traffic.bounceRatePercent;
    final avgDurationSecs = traffic.avgSessionDurationSeconds;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Cards
          Row(
            children: [
              _buildAnalyticsKpiCard(
                title: 'Total Site Visitors',
                value: totalVisits.toString(),
                subtitle: 'Unique customer sessions',
                icon: Icons.people_outline,
                color: storeGreen,
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Today\'s Visitors',
                value: todayVisits.toString(),
                subtitle: 'Sessions recorded today',
                icon: Icons.today_outlined,
                color: const Color(0xff2563eb),
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Live Visitors Now',
                value: liveVisits.toString(),
                subtitle: 'Active in last 30 minutes',
                icon: Icons.circle,
                color: const Color(0xff16a34a),
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Total Page Views',
                value: totalPageViews.toString(),
                subtitle:
                    'Avg ${totalVisits == 0 ? '0.0' : (totalPageViews / totalVisits).toStringAsFixed(1)} pages/visit',
                icon: Icons.visibility_outlined,
                color: Colors.purple.shade700,
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Bounce Rate',
                value: '$bounceRate%',
                subtitle: 'Recorded session bounce rate',
                icon: Icons.exit_to_app_outlined,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Avg Session Duration',
                value: '${avgDurationSecs ~/ 60}m ${avgDurationSecs % 60}s',
                subtitle: 'Across recorded sessions',
                icon: Icons.timer_outlined,
                color: Colors.teal.shade700,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Two-column layout: Geo distribution on left, Traffic Acquisition on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Where people are visiting from (Geo distribution)
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: const Color(0xffdbeafe),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.public,
                                  color: Color(0xff2563eb), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Visitor Geographic Distribution',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xff0f172a))),
                                Text(
                                    'Where customers are visiting your store from in India',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xff64748b))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Top States & Dairy Belts',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        ...(traffic.topStates.map((s) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(s.name,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff1e293b))),
                                    Text(
                                        '${s.visitorsCount} visits (${s.percent}%)',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff2563eb))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: s.percent / 100.0,
                                  backgroundColor: const Color(0xfff1f5f9),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          Color(0xff2563eb)),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          );
                        })),
                        const Divider(height: 32, color: Color(0xfff1f5f9)),
                        const Text('Top Cities',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: traffic.topCities.map((c) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xfff8fafc),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xffe2e8f0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14, color: storeGreen),
                                  const SizedBox(width: 6),
                                  Text(c.name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xff0f172a))),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: const Color(0xffe2e8f0),
                                        borderRadius: BorderRadius.circular(4)),
                                    child: Text('${c.visitorsCount}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xff475569))),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Column 2: How they arrived (Acquisition / Referrers)
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: const Color(0xfffef3c7),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.alt_route,
                                  color: Color(0xffd97706), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Traffic Acquisition & Sources',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xff0f172a))),
                                Text(
                                    'How visitors discovered and arrived at your storefront',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xff64748b))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Traffic Sources',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        ...(traffic.topReferrers.map((r) {
                          IconData refIcon = Icons.link;
                          Color refColor = const Color(0xff64748b);
                          if (r.type == 'whatsapp') {
                            refIcon = Icons.chat_outlined;
                            refColor = const Color(0xff25d366);
                          } else if (r.type == 'google') {
                            refIcon = Icons.search;
                            refColor = Colors.blue;
                          } else if (r.type == 'instagram') {
                            refIcon = Icons.camera_alt_outlined;
                            refColor = Colors.pink;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(refIcon, size: 16, color: refColor),
                                    const SizedBox(width: 8),
                                    Text(r.source,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xff1e293b))),
                                    const Spacer(),
                                    Text(
                                        '${r.visitorsCount} visits (${r.percent}%)',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: refColor)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: r.percent / 100.0,
                                  backgroundColor: const Color(0xfff1f5f9),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(refColor),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          );
                        })),
                        const Divider(height: 32, color: Color(0xfff1f5f9)),
                        const Text('Device & Technology Breakdown',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDeviceCard(
                                icon: Icons.phone_android,
                                label: 'Mobile App / Web',
                                count: traffic.deviceBreakdown['mobile'] ?? 334,
                                percent: '78%',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDeviceCard(
                                icon: Icons.laptop_mac,
                                label: 'Desktop Browser',
                                count: traffic.deviceBreakdown['desktop'] ?? 82,
                                percent: '19%',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDeviceCard(
                                icon: Icons.tablet_mac,
                                label: 'Tablet / iPad',
                                count: traffic.deviceBreakdown['tablet'] ?? 12,
                                percent: '3%',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
      {required IconData icon,
      required String label,
      required int count,
      required String percent}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xff64748b)),
          const SizedBox(height: 8),
          Text(percent,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0f172a))),
          Text('$count visits',
              style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff475569))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 5: User Clickstream & Behavior Journey
  // ---------------------------------------------------------------------------
  Widget _buildClickstreamTab() {
    final analyticsState = ref.watch(adminAnalyticsProvider);
    final analyticsNotifier = ref.read(adminAnalyticsProvider.notifier);
    final events = analyticsState.clickstreamEvents;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xffe2e8f0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: const Color(0xfff3e8ff),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.ads_click,
                            color: Color(0xff9333ea), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User Clickstream & Interaction Journey',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff0f172a))),
                          Text(
                              'Step-by-step click log: what a particular user or visitor clicked on your website',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xff64748b))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText:
                                'Filter by customer phone (e.g. 9820112345) or session ID...',
                            prefixIcon: const Icon(Icons.person_search,
                                size: 20, color: Color(0xff64748b)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xfff8fafc),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: Color(0xffe2e8f0)),
                            ),
                          ),
                          onSubmitted: (val) =>
                              analyticsNotifier.setClickstreamUserPhone(
                                  val.trim().isEmpty ? null : val.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (analyticsState.selectedUserPhone != null) ...[
                        Chip(
                          backgroundColor: const Color(0xffe0f2fe),
                          label: Text(
                              'Customer: ${analyticsState.selectedUserPhone}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff0284c7))),
                          onDeleted: () =>
                              analyticsNotifier.setClickstreamUserPhone(null),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Spacer(),
                      IconButton(
                        icon:
                            const Icon(Icons.refresh, color: Color(0xff64748b)),
                        tooltip: 'Refresh Clickstream',
                        onPressed: () => analyticsNotifier.fetchClickstream(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                          'All Actions',
                          'ALL',
                          analyticsState.selectedEventType ?? 'ALL',
                          (e) => analyticsNotifier
                              .setClickstreamEventType(e == 'ALL' ? null : e)),
                      _buildFilterChip(
                          'Product Views',
                          'PRODUCT_VIEW',
                          analyticsState.selectedEventType ?? 'ALL',
                          (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip(
                          'Add to Cart',
                          'ADD_TO_CART',
                          analyticsState.selectedEventType ?? 'ALL',
                          (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip(
                          'Searches',
                          'SEARCH_QUERY',
                          analyticsState.selectedEventType ?? 'ALL',
                          (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip(
                          'Lab Certificates',
                          'CERTIFICATE_VIEW',
                          analyticsState.selectedEventType ?? 'ALL',
                          (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip(
                          'Checkouts',
                          'CHECKOUT_INITIATE',
                          analyticsState.selectedEventType ?? 'ALL',
                          (e) => analyticsNotifier.setClickstreamEventType(e)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Timeline Feed
          if (analyticsState.isLoadingClickstream)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator()))
          else if (analyticsState.clickstreamError != null)
            _buildAdminDataState(
              message: analyticsState.clickstreamError!,
              icon: Icons.cloud_off_outlined,
              onRetry: analyticsNotifier.fetchClickstream,
            )
          else if (events.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.touch_app_outlined,
                          size: 48, color: Color(0xff94a3b8)),
                      SizedBox(height: 12),
                      Text('No clickstream events recorded for this selection',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final ev = events[idx];
                    return _buildTimelineEventRow(ev, idx == 0);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineEventRow(ClickstreamEventItem ev, bool isLatest) {
    Color badgeColor;
    IconData eventIcon;

    switch (ev.eventType) {
      case 'ADD_TO_CART':
        badgeColor = const Color(0xff16a34a);
        eventIcon = Icons.add_shopping_cart;
        break;
      case 'REMOVE_FROM_CART':
        badgeColor = Colors.red.shade700;
        eventIcon = Icons.remove_shopping_cart;
        break;
      case 'PRODUCT_VIEW':
        badgeColor = const Color(0xff2563eb);
        eventIcon = Icons.visibility_outlined;
        break;
      case 'SEARCH_QUERY':
        badgeColor = const Color(0xffd97706);
        eventIcon = Icons.search;
        break;
      case 'CERTIFICATE_VIEW':
        badgeColor = const Color(0xff0d9488);
        eventIcon = Icons.verified_outlined;
        break;
      case 'CHECKOUT_INITIATE':
        badgeColor = const Color(0xff9333ea);
        eventIcon = Icons.shopping_bag_outlined;
        break;
      default:
        badgeColor = const Color(0xff64748b);
        eventIcon = Icons.touch_app_outlined;
    }

    final timeFormatted =
        '${ev.createdAt.hour.toString().padLeft(2, '0')}:${ev.createdAt.minute.toString().padLeft(2, '0')}:${ev.createdAt.second.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time & relative label
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeFormatted,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xff1e293b))),
              const Text('UTC',
                  style: TextStyle(fontSize: 10, color: Color(0xff94a3b8))),
            ],
          ),
        ),

        // Node circle icon
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: 1.5),
          ),
          child: Icon(eventIcon, size: 16, color: badgeColor),
        ),
        const SizedBox(width: 14),

        // Content
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isLatest ? const Color(0xfff0fdf4) : const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isLatest
                      ? Colors.green.shade300
                      : const Color(0xffe2e8f0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        ev.eventType,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ev.elementText ?? ev.pageUrl,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0f172a)),
                      ),
                    ),
                    if (ev.userPhone != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xffe2e8f0),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          ev.userPhone!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff334155)),
                        ),
                      )
                    else
                      Text(
                        'Session: ${ev.sessionId.substring(0, ev.sessionId.length > 12 ? 12 : ev.sessionId.length)}...',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xff94a3b8)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.language,
                        size: 12, color: Color(0xff94a3b8)),
                    const SizedBox(width: 4),
                    Text('Route: ${ev.pageUrl}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xff64748b))),
                    if (ev.metadata != null && ev.metadata!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Payload: ${ev.metadata}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: Color(0xff475569)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Card Helper
  // ---------------------------------------------------------------------------
  Widget _buildAdminDataState({
    required String message,
    required IconData icon,
    VoidCallback? onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xffe2e8f0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: const Color(0xff64748b)),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xff334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xffe2e8f0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff64748b))),
                  Icon(icon, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xff94a3b8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentVal,
      Function(String) onSelect) {
    final isSelected = currentVal == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      selectedColor: storeGreen,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : const Color(0xff334155),
      ),
      backgroundColor: const Color(0xfff1f5f9),
    );
  }
}
