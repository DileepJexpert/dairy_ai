import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../admin/providers/admin_marketplace_provider.dart';
import '../utils/courier_tracking_utils.dart';

final operationsOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentUserProvider);
  final response =
      await ref.watch(dioProvider).get('/marketplace/orders/operations');
  return (response.data['data'] as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});

class OperationsOrdersScreen extends ConsumerStatefulWidget {
  const OperationsOrdersScreen({
    super.key,
    required this.title,
    this.embedded = false,
  });
  final String title;
  final bool embedded;

  @override
  ConsumerState<OperationsOrdersScreen> createState() =>
      _OperationsOrdersScreenState();
}

class _OperationsOrdersScreenState
    extends ConsumerState<OperationsOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> simulateAction(
      BuildContext context, String orderId, String action) async {
    final path = '/marketplace/orders/admin/simulator/$orderId';
    try {
      if (action == 'dispatch' || action == 'collect') {
        await ref.read(dioProvider).post('$path/$action');
      } else {
        await ref.read(dioProvider).post('$path/event', data: {
          'event': action,
          if (action == 'DELIVERY_FAILED')
            'reason': 'Simulated delivery failure for flow testing',
        });
      }
      ref.invalidate(operationsOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Test event recorded. No courier or money was involved.'),
        ));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(commerceError(error))));
      }
    }
  }

  Future<void> collectCod(BuildContext context, String orderId) async {
    final reference = TextEditingController();
    try {
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Record COD remittance'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Confirm the courier has delivered the parcel and remitted the collected payment.'),
                  const SizedBox(height: 10),
                  TextField(
                      controller: reference,
                      maxLength: 100,
                      decoration: const InputDecoration(
                          labelText: 'Courier remittance reference',
                          hintText: 'e.g. DTDC-COD-2026-9912')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: storeGreen),
                      onPressed: () async {
                        try {
                          await ref.read(dioProvider).post(
                              '/marketplace/orders/admin/cod/$orderId/collect',
                              data: {
                                'remittance_reference': reference.text.trim()
                              });
                          ref.invalidate(operationsOrdersProvider);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(commerceError(error))));
                          }
                        }
                      },
                      child: const Text('Record payment')),
                ],
              ));
    } finally {
      reference.dispose();
    }
  }

  Future<void> openReturnToOrigin(BuildContext context, String orderId) async {
    final reason = TextEditingController();
    try {
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Record failed delivery / RTO'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                      'Open a return-to-origin case after the courier confirms that delivery failed.'),
                  const SizedBox(height: 10),
                  TextField(
                      controller: reason,
                      maxLength: 300,
                      decoration: const InputDecoration(
                          labelText: 'Courier reason or evidence',
                          hintText: 'e.g. Customer unreachable on 3 attempts')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: storeError),
                      onPressed: () async {
                        try {
                          await ref.read(dioProvider).post(
                              '/marketplace/orders/admin/returns/$orderId/rto',
                              data: {'reason': reason.text.trim()});
                          ref.invalidate(operationsOrdersProvider);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(commerceError(error))));
                          }
                        }
                      },
                      child: const Text('Open RTO case')),
                ],
              ));
    } finally {
      reason.dispose();
    }
  }

  Future<void> updateOrderStage(
    BuildContext context,
    Map<String, dynamic> order, {
    String? forcedNextStatus,
  }) async {
    final current = (order['status']?.toString() ?? '').toUpperCase();
    final next = forcedNextStatus ??
        {
          'PENDING': 'CONFIRMED',
          'PLACED': 'PACKED',
          'CREATED': 'PACKED',
          'CONFIRMED': 'PACKED',
          'PACKED': 'DISPATCHED',
          'DISPATCHED': 'DELIVERED',
          'SHIPPED': 'DELIVERED',
          'OUT_FOR_DELIVERY': 'DELIVERED',
        }[current];
    if (next == null) return;

    final carrier =
        TextEditingController(text: order['carrier']?.toString() ?? '');
    final tracking =
        TextEditingController(text: order['tracking_number']?.toString() ?? '');
    final note = TextEditingController();
    var saving = false;

    final isCourierEditOnly = forcedNextStatus == 'SHIPPED' &&
        (current == 'SHIPPED' || current == 'DISPATCHED');

    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  title: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          color: storeGreen),
                      const SizedBox(width: 8),
                      Text(isCourierEditOnly
                          ? 'Update Courier & AWB'
                          : 'Confirm ${next.toLowerCase()}'),
                    ],
                  ),
                  content: SizedBox(
                      width: 460,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                isCourierEditOnly
                                    ? 'Update the courier partner name and AWB tracking reference for this shipment.'
                                    : 'Record an actual completed warehouse or courier action.',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xff475569))),
                            const SizedBox(height: 14),
                            if (next == 'DISPATCHED' ||
                                next == 'SHIPPED' ||
                                isCourierEditOnly) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final preset in const [
                                    'DTDC',
                                    'Delhivery',
                                    'Blue Dart',
                                    'Ekart',
                                    'Shadowfax',
                                    'India Post'
                                  ])
                                    ActionChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(preset,
                                          style: const TextStyle(fontSize: 11)),
                                      onPressed: () =>
                                          setDialog(() => carrier.text = preset),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                  controller: carrier,
                                  decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Courier partner name',
                                      hintText:
                                          'e.g. Blue Dart, Delhivery, DTDC')),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: tracking,
                                  decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'AWB / Tracking reference',
                                      hintText: 'e.g. BLU-8921829012')),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                                controller: note,
                                maxLength: 800,
                                decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Notes / proof reference',
                                    hintText:
                                        'e.g. Handed over to courier driver')),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: storeGreen),
                        icon: const Icon(Icons.check, size: 16),
                        onPressed: saving
                            ? null
                            : () async {
                                setDialog(() => saving = true);
                                try {
                                  await ref.read(dioProvider).put(
                                      '/marketplace/orders/operations/${order['id']}',
                                      data: {
                                        'status': next,
                                        'carrier': carrier.text.trim(),
                                        'tracking_number':
                                            tracking.text.trim(),
                                        'remarks': note.text.trim(),
                                      });
                                  ref.invalidate(operationsOrdersProvider);
                                  if (context.mounted) Navigator.pop(context);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isCourierEditOnly
                                            ? 'Courier & AWB updated successfully.'
                                            : 'Order updated to $next successfully.'),
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
                                            backgroundColor: storeError));
                                  }
                                }
                              },
                        label: Text(saving
                            ? 'Saving…'
                            : (isCourierEditOnly
                                ? 'Save Courier Info'
                                : 'Confirm $next')))
                  ],
                )));
    carrier.dispose();
    tracking.dispose();
    note.dispose();
  }

  void _showPackingSlipDialog(
      BuildContext context, Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final shortId =
        orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final createdAt = order['created_at']?.toString() ?? '';
    final status = (order['status']?.toString() ?? 'CONFIRMED').toUpperCase();
    final paymentMethod =
        (order['payment_method']?.toString() ?? 'cod').toUpperCase();
    final paymentStatus =
        (order['payment_status']?.toString() ?? 'PENDING').toUpperCase();
    final total = double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
    final subtotal =
        double.tryParse(order['subtotal']?.toString() ?? '') ?? total;
    final deliveryFee =
        double.tryParse(order['delivery_fee']?.toString() ?? '') ?? 0.0;

    final address = order['address'] is Map
        ? Map<String, dynamic>.from(order['address'] as Map)
        : const <String, dynamic>{};
    final recipient =
        address['recipient_name']?.toString() ?? 'Valued Customer';
    final phone = address['phone_number']?.toString() ??
        address['phone']?.toString() ??
        'N/A';
    final street = address['address_line1']?.toString() ??
        address['street_address']?.toString() ??
        '';
    final line2 = address['address_line2']?.toString() ?? '';
    final city = address['village_or_city']?.toString() ??
        address['city']?.toString() ??
        '';
    final district = address['district']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final pincode = address['postal_code']?.toString() ??
        address['pincode']?.toString() ??
        '';

    final fullAddressText = [
      street,
      line2,
      city,
      district,
      state,
      pincode.isNotEmpty ? 'PIN: $pincode' : '',
    ].where((s) => s.trim().isNotEmpty).join(', ');

    final vendorInfo = order['vendor_info'] is Map
        ? Map<String, dynamic>.from(order['vendor_info'] as Map)
        : const <String, dynamic>{};
    final vendorName = vendorInfo['business_name']?.toString() ??
        'Milterra Central Fulfillment Hub';
    final vendorOrigin = [vendorInfo['district'], vendorInfo['state']]
        .where((v) => v != null && v.toString().isNotEmpty)
        .join(', ');

    final items = order['items'] is List
        ? (order['items'] as List).whereType<Map>().toList()
        : [];
    final carrier = order['carrier']?.toString() ?? '';
    final trackingNumber = order['tracking_number']?.toString() ?? '';
    final isCodCollect = paymentMethod == 'COD' && paymentStatus != 'PAID';

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: 720,
          constraints: const BoxConstraints(maxHeight: 820),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Dialog Header with Quick Print Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xfff0fdf4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long,
                            color: storeGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ORDER PACKING SLIP #$shortId',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                  color: storeGreen,
                                  letterSpacing: 0.4)),
                          Text('Order ID: $orderId',
                              style: const TextStyle(
                                  fontSize: 11, color: storeMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 22),

              // Scrollable Printable Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // COD / Prepaid Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCodCollect
                              ? const Color(0xfffffbeb)
                              : const Color(0xfff0fdf4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCodCollect
                                ? const Color(0xfff59e0b)
                                : const Color(0xff22c55e),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isCodCollect
                                      ? Icons.payments_outlined
                                      : Icons.verified_outlined,
                                  size: 18,
                                  color: isCodCollect
                                      ? const Color(0xffb45309)
                                      : storeGreen,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isCodCollect
                                      ? 'CASH ON DELIVERY — COLLECT ${storeMoney(total)} ON DELIVERY'
                                      : 'PREPAID / PAID ORDER (${storeMoney(total)})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: isCodCollect
                                        ? const Color(0xff92400e)
                                        : storeGreen,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Date: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt} · $status',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Seller & Buyer 2-Column Details
                      LayoutBuilder(builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 480;
                        final col1 = Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SOLD BY / DISPATCH ORIGIN',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: storeMuted,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Text(vendorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: storeGreen)),
                              const SizedBox(height: 4),
                              Text(
                                  vendorOrigin.isNotEmpty
                                      ? 'Origin: $vendorOrigin'
                                      : 'Milterra Quality Verified Dispatch',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff475569))),
                            ],
                          ),
                        );

                        final col2 = Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SHIP TO / CUSTOMER DELIVERY ADDRESS',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: storeMuted,
                                      letterSpacing: 0.5)),
                              const SizedBox(height: 6),
                              Text(recipient,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14)),
                              const SizedBox(height: 3),
                              Text('Phone: $phone',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: storeGreen)),
                              const SizedBox(height: 3),
                              Text(
                                fullAddressText.isNotEmpty
                                    ? fullAddressText
                                    : 'Address on file',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff334155),
                                    height: 1.35),
                              ),
                            ],
                          ),
                        );

                        return isNarrow
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    col1,
                                    const SizedBox(height: 10),
                                    col2
                                  ])
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Expanded(child: col1),
                                    const SizedBox(width: 12),
                                    Expanded(child: col2),
                                  ]);
                      }),
                      const SizedBox(height: 16),

                      // Itemized Packing List Table
                      const Text('ITEMIZED PACKING LIST',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: storeGreen,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffcbd5e1)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: const BoxDecoration(
                                color: Color(0xff0d1b15),
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(7)),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                      width: 28,
                                      child: Text('#',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  Expanded(
                                      child: Text('Item Description',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  SizedBox(
                                      width: 50,
                                      child: Text('Qty',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  SizedBox(
                                      width: 80,
                                      child: Text('Unit Price',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                  SizedBox(
                                      width: 90,
                                      child: Text('Line Total',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (c, idx) {
                                final it = items[idx];
                                final qty = it['quantity']?.toString() ?? '1';
                                final unitPrice = double.tryParse(
                                        it['unit_price']?.toString() ?? '') ??
                                    0.0;
                                final lineTotal = double.tryParse(
                                        it['line_total']?.toString() ?? '') ??
                                    (unitPrice * (double.tryParse(qty) ?? 1));
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                          width: 28,
                                          child: Text('${idx + 1}',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: storeMuted))),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                it['title']?.toString() ??
                                                    'Product',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            Text(
                                                'SKU: ${it['product_id'] ?? ''} · Status: ${it['fulfillment_status'] ?? status}',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: storeGreen)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                          width: 50,
                                          child: Text(qty,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w800))),
                                      SizedBox(
                                          width: 80,
                                          child: Text(storeMoney(unitPrice),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                  fontSize: 12))),
                                      SizedBox(
                                          width: 90,
                                          child: Text(storeMoney(lineTotal),
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xfff8fafc),
                                borderRadius: BorderRadius.vertical(
                                    bottom: Radius.circular(7)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Subtotal:',
                                          style: TextStyle(
                                              fontSize: 12, color: storeMuted)),
                                      Text(storeMoney(subtotal),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Shipping & Handling:',
                                          style: TextStyle(
                                              fontSize: 12, color: storeMuted)),
                                      Text(storeMoney(deliveryFee),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: storeGreen,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Divider(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Order Total:',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900)),
                                      Text(storeMoney(total),
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: storeGreen)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Logistics & Courier Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xfffffbeb),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xfffef3c7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                color: Color(0xffb45309), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    carrier.isNotEmpty
                                        ? 'Courier Partner: ${carrier.toUpperCase()}'
                                        : 'Courier Partner: Self-Fulfill / Awaiting Handover',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Color(0xff92400e)),
                                  ),
                                  if (trackingNumber.isNotEmpty)
                                    Text('AWB Tracking Ref: $trackingNumber',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xff78350f))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xffd97706)),
                              ),
                              child: Text('||||| $shortId |||||',
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w900,
                                      fontSize: 11,
                                      letterSpacing: 1.5)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions: Copy Summary & Done
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Summary'),
                    onPressed: () {
                      final slipSummary = '''
MILTERRA ORDER PACKING SLIP
Order: $orderId
Date: $createdAt
Status: $status | Payment: $paymentMethod ($paymentStatus)

SOLD BY:
$vendorName

SHIP TO:
$recipient ($phone)
$fullAddressText

ITEMS:
${items.map((it) => '• ${it['title']} ×${it['quantity']} = ${it['line_total']}').join('\n')}

TOTAL: ${storeMoney(total)}
''';
                      Clipboard.setData(
                          ClipboardData(text: slipSummary.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Packing slip summary copied to clipboard!'),
                            backgroundColor: storeGreen),
                      );
                    },
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: storeGreen),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Done'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _stageIndex(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'PLACED':
      case 'CREATED':
      case 'CONFIRMED':
        return 1;
      case 'PACKED':
        return 2;
      case 'DISPATCHED':
      case 'SHIPPED':
        return 3;
      case 'OUT_FOR_DELIVERY':
        return 4;
      case 'DELIVERED':
        return 5;
      default:
        return 0;
    }
  }

  Widget _buildStepIndicator(String currentStatus, bool hasReturnCase) {
    if (hasReturnCase || currentStatus == 'CANCELLED') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xfffef2f2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xfffecaca)),
        ),
        child: Row(
          children: [
            const Icon(Icons.assignment_return, size: 16, color: storeError),
            const SizedBox(width: 8),
            Text(
              hasReturnCase
                  ? 'RETURN TO ORIGIN (RTO) / FAILED DELIVERY CASE ACTIVE'
                  : 'ORDER CANCELLED',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: storeError),
            ),
          ],
        ),
      );
    }

    final activeIdx = _stageIndex(currentStatus);
    const steps = [
      (1, 'Confirmed', Icons.check_circle_outline),
      (2, 'Packed', Icons.inventory_2_outlined),
      (3, 'Shipped', Icons.local_shipping_outlined),
      (4, 'Out for Delivery', Icons.delivery_dining_outlined),
      (5, 'Delivered', Icons.verified_outlined),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeIdx >= steps[i].$1
                          ? storeGreen
                          : const Color(0xffe2e8f0),
                    ),
                    child: Icon(
                      activeIdx > steps[i].$1 ? Icons.check : steps[i].$3,
                      size: 13,
                      color: activeIdx >= steps[i].$1
                          ? Colors.white
                          : const Color(0xff64748b),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      steps[i].$2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: activeIdx >= steps[i].$1
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: activeIdx >= steps[i].$1
                            ? storeGreen
                            : const Color(0xff64748b),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i < steps.length - 1)
              Container(
                width: 22,
                height: 2,
                color: activeIdx > steps[i].$1
                    ? storeGreen
                    : const Color(0xffcbd5e1),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String filterKey,
  }) {
    final selected = _statusFilter == filterKey;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _statusFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 195,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : const Color(0xffe2e8f0),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff1e293b))),
                  Text(subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xff64748b))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(operationsOrdersProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text('Orders could not be loaded: ${commerceError(e)}')),
          data: (orders) {
            // Compute KPI counts
            int toPackCount = 0;
            int packedCount = 0;
            int shippedCount = 0;
            int deliveredCount = 0;
            int codPendingCount = 0;
            int returnsCount = 0;
            double totalGmv = 0;

            for (final o in orders) {
              final st = (o['status']?.toString() ?? '').toUpperCase();
              final tot = double.tryParse(o['total']?.toString() ?? '') ?? 0.0;
              totalGmv += tot;
              final hasRet = o['return_case'] is Map &&
                  (o['return_case'] as Map)['status'] != 'rejected';
              if (hasRet) returnsCount++;
              if (['PENDING', 'PLACED', 'CREATED', 'CONFIRMED'].contains(st)) {
                toPackCount++;
              } else if (st == 'PACKED') {
                packedCount++;
              } else if (['DISPATCHED', 'SHIPPED', 'OUT_FOR_DELIVERY']
                  .contains(st)) {
                shippedCount++;
              } else if (st == 'DELIVERED') {
                deliveredCount++;
              }
              if ((o['payment_method']?.toString() ?? '').toLowerCase() ==
                      'cod' &&
                  (o['payment_status']?.toString() ?? '').toUpperCase() !=
                      'PAID') {
                codPendingCount++;
              }
            }

            // Filter orders
            final filtered = orders.where((o) {
              final st = (o['status']?.toString() ?? '').toUpperCase();
              final hasRet = o['return_case'] is Map &&
                  (o['return_case'] as Map)['status'] != 'rejected';
              final isCodPending =
                  (o['payment_method']?.toString() ?? '').toLowerCase() ==
                          'cod' &&
                      (o['payment_status']?.toString() ?? '').toUpperCase() !=
                          'PAID';

              if (_statusFilter == 'TO_PACK' &&
                  !['PENDING', 'PLACED', 'CREATED', 'CONFIRMED'].contains(st)) {
                return false;
              }
              if (_statusFilter == 'PACKED' && st != 'PACKED') return false;
              if (_statusFilter == 'SHIPPED' &&
                  !['DISPATCHED', 'SHIPPED', 'OUT_FOR_DELIVERY'].contains(st)) {
                return false;
              }
              if (_statusFilter == 'DELIVERED' && st != 'DELIVERED') {
                return false;
              }
              if (_statusFilter == 'COD_PENDING' && !isCodPending) {
                return false;
              }
              if (_statusFilter == 'RETURNS' && !hasRet) return false;

              if (_searchQuery.isNotEmpty) {
                final addr = o['address'] is Map ? (o['address'] as Map) : {};
                final hay = [
                  o['id'],
                  o['carrier'],
                  o['tracking_number'],
                  addr['recipient_name'],
                  addr['phone'],
                  addr['village_or_city'],
                  addr['district'],
                  addr['postal_code'],
                ].where((e) => e != null).join(' ').toLowerCase();
                if (!hay.contains(_searchQuery.toLowerCase())) return false;
              }
              return true;
            }).toList();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. KPI Summary Strip
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildKpiCard(
                      label: 'All Orders',
                      value: '${orders.length}',
                      subtitle: 'GMV ${storeMoney(totalGmv)}',
                      icon: Icons.shopping_bag_outlined,
                      color: storeGreen,
                      filterKey: 'ALL',
                    ),
                    _buildKpiCard(
                      label: 'To Pack',
                      value: '$toPackCount',
                      subtitle: 'Awaiting warehouse pack',
                      icon: Icons.inventory_outlined,
                      color: const Color(0xffd97706),
                      filterKey: 'TO_PACK',
                    ),
                    _buildKpiCard(
                      label: 'Packed & Ready',
                      value: '$packedCount',
                      subtitle: 'Ready for courier pickup',
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xff0284c7),
                      filterKey: 'PACKED',
                    ),
                    _buildKpiCard(
                      label: 'Shipped / Transit',
                      value: '$shippedCount',
                      subtitle: 'With courier partner',
                      icon: Icons.local_shipping_outlined,
                      color: const Color(0xff7e22ce),
                      filterKey: 'SHIPPED',
                    ),
                    _buildKpiCard(
                      label: 'Delivered',
                      value: '$deliveredCount',
                      subtitle: 'Completed orders',
                      icon: Icons.verified_outlined,
                      color: const Color(0xff15803d),
                      filterKey: 'DELIVERED',
                    ),
                    _buildKpiCard(
                      label: 'COD / Returns',
                      value: '$codPendingCount / $returnsCount',
                      subtitle: 'Pending COD & RTO cases',
                      icon: Icons.currency_rupee,
                      color: const Color(0xffb91c1c),
                      filterKey: 'COD_PENDING',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Search & Filter Bar
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          hintText:
                              'Search by Order # (100641AE), customer name, phone (9839...), city (Noida), PIN (201305), or AWB...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xffcbd5e1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tab in [
                            ('ALL', 'All Orders (${orders.length})'),
                            ('TO_PACK', 'To Pack ($toPackCount)'),
                            ('PACKED', 'Packed ($packedCount)'),
                            ('SHIPPED', 'Shipped ($shippedCount)'),
                            ('DELIVERED', 'Delivered ($deliveredCount)'),
                            ('COD_PENDING', 'COD Pending ($codPendingCount)'),
                            ('RETURNS', 'RTO / Returns ($returnsCount)'),
                          ])
                            ChoiceChip(
                              label: Text(tab.$2,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _statusFilter == tab.$1
                                          ? FontWeight.bold
                                          : FontWeight.w500)),
                              selected: _statusFilter == tab.$1,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = tab.$1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xffe2e8f0)),
                    ),
                    child: const Center(
                      child: Text(
                        'No orders match the current filter or search query.',
                        style: TextStyle(fontSize: 14, color: storeMuted),
                      ),
                    ),
                  ),

                // 3. Order Fulfillment Cards
                for (final order in filtered) ...[
                  _buildOrderCard(context, order),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        );

    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        backgroundColor: const Color(0xff0d1b15),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Admin Control Panel',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/admin/ecommerce'),
        ),
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Admin Control Panel',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: () => context.go('/admin/ecommerce'),
          ),
          IconButton(
            tooltip: 'Serviceable Pincodes',
            icon: const Icon(Icons.pin_drop_outlined),
            onPressed: () => context.go('/admin/pincodes'),
          ),
          IconButton(
            tooltip: 'Customer Storefront',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.go('/shop'),
          ),
          IconButton(
            tooltip: 'Refresh orders',
            onPressed: () => ref.invalidate(operationsOrdersProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final shortId =
        orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
    final total = double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
    final createdAt = order['created_at']?.toString() ?? '';
    final carrier = order['carrier']?.toString() ?? '';
    final tracking = order['tracking_number']?.toString() ?? '';
    final paymentMethod =
        (order['payment_method']?.toString() ?? 'cod').toUpperCase();
    final paymentStatus =
        (order['payment_status']?.toString() ?? 'PENDING').toUpperCase();
    final isCodPending = paymentMethod == 'COD' && paymentStatus != 'PAID';

    final address = order['address'] is Map
        ? Map<String, dynamic>.from(order['address'] as Map)
        : const <String, dynamic>{};
    final recipient = address['recipient_name']?.toString() ?? 'Customer';
    final phone = address['phone']?.toString() ?? '';
    final fullAddress = [
      address['address_line1'],
      address['address_line2'],
      address['village_or_city'],
      address['district'],
      address['state'],
      address['postal_code'] != null ? 'PIN: ${address['postal_code']}' : null,
    ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');

    final items = order['items'] is List
        ? (order['items'] as List).whereType<Map>().toList()
        : [];

    Color statusBg;
    Color statusFg;
    switch (status) {
      case 'DELIVERED':
        statusBg = const Color(0xffdcfce7);
        statusFg = storeGreen;
        break;
      case 'DISPATCHED':
      case 'SHIPPED':
      case 'OUT_FOR_DELIVERY':
        statusBg = const Color(0xfff3e8ff);
        statusFg = const Color(0xff7e22ce);
        break;
      case 'PACKED':
        statusBg = const Color(0xffe0f2fe);
        statusFg = const Color(0xff0369a1);
        break;
      default:
        statusBg = const Color(0xfffef3c7);
        statusFg = const Color(0xffb45309);
    }

    final hasReturnCase = order['return_case'] is Map &&
        (order['return_case'] as Map)['status'] != 'rejected';
    final simulatedOrder =
        AppConstants.flowSimulation && order['is_test_order'] == true;
    final canFulfill = !hasReturnCase &&
        [
          'PENDING',
          'PLACED',
          'CREATED',
          'CONFIRMED',
          'PACKED',
          'DISPATCHED',
          'SHIPPED',
          'OUT_FOR_DELIVERY'
        ].contains(status);

    String nextButtonLabel = 'Update';
    IconData nextButtonIcon = Icons.local_shipping_outlined;
    if (['PENDING', 'PLACED', 'CREATED', 'CONFIRMED'].contains(status)) {
      nextButtonLabel = 'Mark Packed';
      nextButtonIcon = Icons.inventory_2_outlined;
    } else if (status == 'PACKED') {
      nextButtonLabel = 'Dispatch & Add AWB';
      nextButtonIcon = Icons.local_shipping_outlined;
    } else if (['DISPATCHED', 'SHIPPED', 'OUT_FOR_DELIVERY'].contains(status)) {
      nextButtonLabel = 'Mark Delivered';
      nextButtonIcon = Icons.check_circle_outline;
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Order ID, Date, Payment Badge, Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Order #$shortId',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: storeGreen)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: orderId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Order ID copied!'),
                                  duration: Duration(seconds: 1)),
                            );
                          },
                          child: const Icon(Icons.copy,
                              size: 14, color: storeMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        '${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt} · Commercial Delivery',
                        style:
                            const TextStyle(fontSize: 11, color: storeMuted)),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCodPending
                            ? const Color(0xfffffbeb)
                            : const Color(0xfff0fdf4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: isCodPending
                                ? const Color(0xfffcd34d)
                                : const Color(0xffbbf7d0)),
                      ),
                      child: Text(
                        isCodPending
                            ? 'COD · COLLECT ${storeMoney(total)}'
                            : '$paymentMethod · $paymentStatus',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isCodPending
                              ? const Color(0xffb45309)
                              : storeGreen,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusFg,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5-Step Progress Bar
            _buildStepIndicator(status, hasReturnCase),
            const SizedBox(height: 12),

            // Customer Delivery Address Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffe2e8f0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 20, color: storeGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(recipient,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            if (phone.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(phone,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: storeGreen)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fullAddress.isEmpty
                              ? 'Delivery address pending'
                              : fullAddress,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xff475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Items List
            ...items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 15, color: storeGreen),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${it['title'] ?? 'Item'} ×${it['quantity'] ?? 1}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        storeMoney(double.tryParse(
                                it['line_total']?.toString() ?? '') ??
                            0.0),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),

            const Divider(height: 18),

            // Tracking Box (if dispatched or carrier attached)
            if (carrier.isNotEmpty || tracking.isNotEmpty) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xfffaf5ff),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffe9d5ff)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping,
                        size: 17, color: Color(0xff7e22ce)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Courier: ${carrier.isEmpty ? 'Assigned' : carrier.toUpperCase()} · AWB: ${tracking.isEmpty ? 'Pending' : tracking}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff6b21a8)),
                      ),
                    ),
                    InkWell(
                      onTap: () => updateOrderStage(context, order,
                          forcedNextStatus: 'SHIPPED'),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text('Edit AWB',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff6b21a8))),
                      ),
                    ),
                    if (tracking.isNotEmpty) ...[
                      const Text(' · ',
                          style: TextStyle(
                              color: Color(0xffcbd5e1), fontSize: 11)),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: tracking));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('AWB copied to clipboard!'),
                                duration: Duration(seconds: 2)),
                          );
                        },
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text('Copy AWB',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff7e22ce))),
                        ),
                      ),
                      const Text(' · ',
                          style: TextStyle(
                              color: Color(0xffcbd5e1), fontSize: 11)),
                      InkWell(
                        onTap: () => launchCourierTracking(carrier, tracking),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new,
                                  size: 11, color: Color(0xff0284c7)),
                              SizedBox(width: 2),
                              Text('Track Live',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff0284c7))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Bottom Total & Action Buttons
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Total',
                        style: TextStyle(fontSize: 10, color: storeMuted)),
                    Text(storeMoney(total),
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: storeGreen)),
                  ],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        icon: const Icon(Icons.receipt_long, size: 16),
                        label: const Text('Packing slip',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _showPackingSlipDialog(context, order),
                      ),
                      if (!simulatedOrder &&
                          !hasReturnCase &&
                          (status == 'SHIPPED' ||
                              status == 'DISPATCHED' ||
                              status == 'OUT_FOR_DELIVERY'))
                        OutlinedButton.icon(
                          icon: const Icon(Icons.assignment_return_outlined,
                              size: 16),
                          label: const Text('Failed delivery / RTO',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => openReturnToOrigin(context, orderId),
                        ),
                      if (canFulfill &&
                          (!simulatedOrder ||
                              status == 'CONFIRMED' ||
                              status == 'PENDING'))
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: storeGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                          ),
                          icon: Icon(nextButtonIcon, size: 16),
                          label: Text(nextButtonLabel,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () => updateOrderStage(context, order),
                        ),
                      if (simulatedOrder &&
                          !hasReturnCase &&
                          status == 'PACKED')
                        OutlinedButton.icon(
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Simulate dispatch'),
                          onPressed: () =>
                              simulateAction(context, orderId, 'dispatch'),
                        ),
                      if (simulatedOrder &&
                          !hasReturnCase &&
                          status == 'SHIPPED')
                        OutlinedButton.icon(
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Simulate out for delivery'),
                          onPressed: () => simulateAction(
                              context, orderId, 'OUT_FOR_DELIVERY'),
                        ),
                      if (simulatedOrder &&
                          !hasReturnCase &&
                          status == 'OUT_FOR_DELIVERY')
                        OutlinedButton.icon(
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Simulate delivery'),
                          onPressed: () =>
                              simulateAction(context, orderId, 'DELIVERED'),
                        ),
                      if (simulatedOrder &&
                          !hasReturnCase &&
                          (status == 'SHIPPED' || status == 'OUT_FOR_DELIVERY'))
                        TextButton.icon(
                          icon: const Icon(Icons.warning_amber_outlined),
                          label: const Text('Simulate failed delivery'),
                          onPressed: () => simulateAction(
                              context, orderId, 'DELIVERY_FAILED'),
                        ),
                      if (simulatedOrder &&
                          !hasReturnCase &&
                          status == 'DELIVERED' &&
                          paymentStatus == 'PENDING')
                        OutlinedButton.icon(
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Simulate COD collection'),
                          onPressed: () =>
                              simulateAction(context, orderId, 'collect'),
                        ),
                      if (!simulatedOrder &&
                          paymentMethod == 'COD' &&
                          paymentStatus == 'PENDING' &&
                          status == 'DELIVERED' &&
                          !hasReturnCase &&
                          {'admin', 'super_admin'}
                              .contains(ref.watch(currentUserProvider)?.role))
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xffb45309)),
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: const Text('Record COD remittance',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => collectCod(context, orderId),
                        ),
                    ],
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
