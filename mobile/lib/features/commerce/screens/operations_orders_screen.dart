import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../admin/providers/admin_marketplace_provider.dart';

final operationsOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentUserProvider);
  final response =
      await ref.watch(dioProvider).get('/marketplace/orders/operations');
  return (response.data['data'] as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
});

class OperationsOrdersScreen extends ConsumerWidget {
  const OperationsOrdersScreen({super.key, required this.title});
  final String title;

  Future<void> update(
      BuildContext context, WidgetRef ref, Map<String, dynamic> order) async {
    final current = order['status'];
    final next = {
      'PENDING': 'CONFIRMED',
      'CONFIRMED': 'PACKED',
      'PACKED': 'DISPATCHED',
      'DISPATCHED': 'DELIVERED',
      'SHIPPED': 'DELIVERED',
    }[current];
    if (next == null) return;
    final carrier = TextEditingController(text: order['carrier']?.toString() ?? '');
    final tracking = TextEditingController(text: order['tracking_number']?.toString() ?? '');
    final note = TextEditingController();
    var saving = false;
    await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialog) => AlertDialog(
                  title: Text('Confirm ${next.toLowerCase()}'),
                  content: SizedBox(
                      width: 440,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Record an actual completed action. This does not book a courier or charge a customer.'),
                        const SizedBox(height: 12),
                        if (next == 'DISPATCHED' || next == 'SHIPPED') ...[
                          TextField(
                              controller: carrier,
                              decoration: const InputDecoration(
                                  labelText: 'Courier partner name',
                                  hintText: 'e.g. Blue Dart, Delhivery, DTDC')),
                          const SizedBox(height: 10),
                          TextField(
                              controller: tracking,
                              decoration: const InputDecoration(
                                  labelText: 'AWB / Tracking reference',
                                  hintText: 'e.g. BLU-8921829012')),
                          const SizedBox(height: 10),
                        ],
                        TextField(
                            controller: note,
                            maxLength: 800,
                            decoration: const InputDecoration(
                                labelText: 'Notes / proof reference',
                                hintText: 'e.g. Handed over to courier driver')),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel')),
                    FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: storeGreen),
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
                                        'tracking_number': tracking.text.trim(),
                                        'remarks': note.text.trim(),
                                      });
                                  ref.invalidate(operationsOrdersProvider);
                                  if (context.mounted) Navigator.pop(context);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Order updated to $next successfully.'),
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
                        child:
                            Text(saving ? 'Saving…' : 'Confirm $next'))
                  ],
                )));
    carrier.dispose();
    tracking.dispose();
    note.dispose();
  }

  void _showPackingSlipDialog(BuildContext context, Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final invoiceNumber = 'MIL-INV-$shortId';
    final createdAt = order['created_at']?.toString() ?? '';
    final status = order['status']?.toString() ?? 'CONFIRMED';
    final paymentMethod = order['payment_method']?.toString() ?? 'Prepaid (Online)';
    final total = double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
    final subtotal = double.tryParse(order['subtotal']?.toString() ?? '') ?? total;

    final address = order['address'] is Map
        ? Map<String, dynamic>.from(order['address'] as Map)
        : const <String, dynamic>{};
    final recipient = address['recipient_name']?.toString() ?? 'Valued Customer';
    final phone = address['phone_number']?.toString() ?? address['phone']?.toString() ?? 'N/A';
    final street = address['street_address']?.toString() ?? '';
    final city = address['village_or_city']?.toString() ?? address['city']?.toString() ?? '';
    final district = address['district']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final pincode = address['pincode']?.toString() ?? '';

    final vendorInfo = order['vendor_info'] is Map
        ? Map<String, dynamic>.from(order['vendor_info'] as Map)
        : const <String, dynamic>{};
    final vendorName = vendorInfo['business_name']?.toString() ?? 'Milterra Partner Vendor';
    final vendorGst = vendorInfo['gst_number']?.toString() ?? '29AAAAA0000A1Z5';
    final vendorFssai = vendorInfo['license_number']?.toString() ?? '10020011000456';
    final vendorOrigin = [vendorInfo['district'], vendorInfo['state']].where((v) => v != null && v.toString().isNotEmpty).join(', ');

    final items = order['items'] is List ? (order['items'] as List).whereType<Map>().toList() : [];
    final carrier = order['carrier']?.toString() ?? '';
    final trackingNumber = order['tracking_number']?.toString() ?? '';

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 650,
          constraints: const BoxConstraints(maxHeight: 740),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xfff0fdf4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: storeGreen, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TAX INVOICE & PACKING SLIP',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: storeGreen, letterSpacing: 0.5)),
                          Text('Invoice: $invoiceNumber', style: const TextStyle(fontSize: 12, color: storeMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Scrollable Printable Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status and Payment Strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffe2e8f0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order Date: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            Text('Payment: $paymentMethod (PAID)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              backgroundColor: const Color(0xffe2e8f0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Seller & Buyer 2-Column Details
                      LayoutBuilder(builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 480;
                        final col1 = Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SOLD BY / DISPATCH ORIGIN',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeMuted, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: storeGreen)),
                              const SizedBox(height: 2),
                              Text('GSTIN: $vendorGst', style: const TextStyle(fontSize: 11, color: Color(0xff475569))),
                              Text('FSSAI Reg: $vendorFssai', style: const TextStyle(fontSize: 11, color: Color(0xff475569))),
                              if (vendorOrigin.isNotEmpty)
                                Text('Location: $vendorOrigin', style: const TextStyle(fontSize: 11, color: Color(0xff475569))),
                            ],
                          ),
                        );

                        final col2 = Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfff8fafc),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xffe2e8f0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SHIP TO / CUSTOMER',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeMuted, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(recipient, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('Contact: $phone', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: storeGreen)),
                              Text(
                                [street, city, district, pincode.isNotEmpty ? 'PIN: $pincode' : '', state]
                                    .where((s) => s.trim().isNotEmpty)
                                    .join(', '),
                                style: const TextStyle(fontSize: 11, color: Color(0xff475569)),
                              ),
                            ],
                          ),
                        );

                        return isNarrow
                            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [col1, const SizedBox(height: 10), col2])
                            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(child: col1),
                                const SizedBox(width: 12),
                                Expanded(child: col2),
                              ]);
                      }),
                      const SizedBox(height: 18),

                      // Itemized Packing List Table
                      const Text('ITEMIZED PACKING LIST',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffcbd5e1)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xff0d1b15),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(width: 28, child: Text('#', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                  Expanded(child: Text('Item Description', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 50, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 75, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                  SizedBox(width: 85, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (c, idx) {
                                final it = items[idx];
                                final qty = it['quantity']?.toString() ?? '1';
                                final unitPrice = double.tryParse(it['unit_price']?.toString() ?? '') ?? 0.0;
                                final lineTotal = double.tryParse(it['line_total']?.toString() ?? '') ??
                                    (unitPrice * (double.tryParse(qty) ?? 1));
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 28, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: storeMuted))),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(it['title']?.toString() ?? 'Product', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            if (it['fulfillment_status'] != null)
                                              Text('Status: ${it['fulfillment_status']}', style: const TextStyle(fontSize: 10, color: storeGreen)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 50, child: Text(qty, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                      SizedBox(width: 75, child: Text(storeMoney(unitPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                                      SizedBox(width: 85, child: Text(storeMoney(lineTotal), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Divider(height: 1),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                color: Color(0xfff8fafc),
                                borderRadius: BorderRadius.vertical(bottom: Radius.circular(7)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Subtotal:', style: TextStyle(fontSize: 11, color: storeMuted)),
                                      Text(storeMoney(subtotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Shipping & Handling:', style: TextStyle(fontSize: 11, color: storeMuted)),
                                      Text('FREE', style: TextStyle(fontSize: 11, color: storeGreen, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Divider(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Grand Total (Tax Inclusive):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                      Text(storeMoney(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: storeGreen)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Logistics & Courier Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfffffbeb),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xfffef3c7)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined, color: Color(0xffb45309), size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    carrier.isNotEmpty ? 'Courier Partner: $carrier' : 'Courier Partner: Self-Fulfill / Awaiting Handover',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff92400e)),
                                  ),
                                  if (trackingNumber.isNotEmpty)
                                    Text('AWB Tracking Ref: $trackingNumber',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff78350f))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xffd97706)),
                              ),
                              child: Text('||||| $shortId |||||',
                                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Statutory declaration
                      const Text(
                        'Declaration: Certified that all goods are packed in food-grade hygienic containers meeting FSSAI standards. Computer-generated tax invoice & packing slip.',
                        style: TextStyle(fontSize: 10, color: storeMuted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Slip Summary'),
                    onPressed: () {
                      final slipSummary = '''
MILTERRA TAX INVOICE & PACKING SLIP
Invoice: $invoiceNumber
Date: $createdAt
Status: $status | Payment: $paymentMethod (PAID)

SOLD BY:
$vendorName
GSTIN: $vendorGst | FSSAI: $vendorFssai

SHIP TO:
$recipient ($phone)
$street, $city, $district, $state - $pincode

ITEMS:
${items.map((it) => '• ${it['title']} ×${it['quantity']} = ${it['line_total']}').join('\n')}

TOTAL: ${storeMoney(total)}
''';
                      Clipboard.setData(ClipboardData(text: slipSummary.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Packing slip summary copied to clipboard!'), backgroundColor: storeGreen),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
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

  void _showShippingLabelDialog(BuildContext context, Map<String, dynamic> order) {
    final orderId = order['id']?.toString() ?? '';
    final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
    final createdAt = order['created_at']?.toString() ?? '';
    final carrier = (order['carrier']?.toString().isNotEmpty == true) ? order['carrier'].toString() : 'Delhivery Surface';
    final trackingNumber = (order['tracking_number']?.toString().isNotEmpty == true)
        ? order['tracking_number'].toString()
        : 'MLT${shortId}IN';

    final address = order['address'] is Map
        ? Map<String, dynamic>.from(order['address'] as Map)
        : const <String, dynamic>{};
    final recipient = address['recipient_name']?.toString() ?? 'Consignee Customer';
    final phone = address['phone_number']?.toString() ?? address['phone']?.toString() ?? '9876543210';
    final street = address['street_address']?.toString() ?? 'Direct Route';
    final city = address['village_or_city']?.toString() ?? address['city']?.toString() ?? 'City Hub';
    final district = address['district']?.toString() ?? '';
    final state = address['state']?.toString() ?? 'India';
    final pincode = address['pincode']?.toString() ?? '110001';

    final vendor = order['vendor_info'] is Map ? Map<String, dynamic>.from(order['vendor_info'] as Map) : const <String, dynamic>{};
    final vendorName = vendor['business_name']?.toString() ?? 'Milterra Producer Cooperative';
    final vendorOrigin = [vendor['district'], vendor['state']].where((s) => s != null && s.toString().isNotEmpty).join(', ');
    final vendorGst = vendor['gst_number']?.toString() ?? '29AABCM1234F1Z5';

    final items = order['items'] is List ? (order['items'] as List).whereType<Map>().toList() : [];
    final total = double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
    final paymentMethod = order['payment_method']?.toString() ?? 'PREPAID';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 24, color: storeGreen),
                      SizedBox(width: 8),
                      Text(
                        'Standard Logistics Waybill (4" × 6")',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: storeGreen),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(carrier.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
                              Text('ROUTING: ${state.toUpperCase().substring(0, state.length.clamp(0, 3))}/HUB-${pincode.length >= 3 ? pincode.substring(0, 3) : "DEL"}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Text(
                              paymentMethod.toUpperCase().contains('COD') ? 'COD : $total' : 'PREPAID',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            color: const Color(0xfff8fafc),
                            child: const Text(
                              '| ||| | || |||| | ||| | ||||| || | ||| || ||| | ||| |||| | ||',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'AWB: $trackingNumber',
                            style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.black, thickness: 1.5, height: 1),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('SHIP TO / CONSIGNEE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.8)),
                                const SizedBox(height: 4),
                                Text(recipient, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text('$street, $city', style: const TextStyle(fontSize: 12, height: 1.2)),
                                Text('$district, $state', style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('Contact: +91 $phone', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Column(
                              children: [
                                const Text('PIN CODE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 9)),
                                const SizedBox(height: 2),
                                Text(
                                  pincode,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.black, thickness: 1.5, height: 1),

                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('RETURN IF UNDELIVERED TO (SHIPPER):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text(vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(vendorOrigin.isNotEmpty ? vendorOrigin : 'Milterra Central Hub', style: const TextStyle(fontSize: 11)),
                          Text('GSTIN: $vendorGst', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.black, thickness: 1.5, height: 1),

                    Container(
                      padding: const EdgeInsets.all(10),
                      color: const Color(0xfff8fafc),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order ID: #$shortId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              Text('Date: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}', style: const TextStyle(fontSize: 11)),
                              const Text('Weight: 0.85 kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contents: ${items.map((it) => "${it['title']} (×${it['quantity']})").join(", ")}',
                            style: const TextStyle(fontSize: 11, color: Color(0xff334155)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Waybill Text'),
                    onPressed: () {
                      final waybillText = '''
CARRIER: ${carrier.toUpperCase()}
AWB: $trackingNumber
SERVICE: $paymentMethod
PIN CODE: $pincode

CONSIGNEE:
$recipient
$street, $city, $district, $state - $pincode
PHONE: +91 $phone

SHIPPER:
$vendorName
$vendorOrigin
GSTIN: $vendorGst

ORDER: #$shortId | WEIGHT: 0.85 KG
ITEMS: ${items.map((it) => "${it['title']} ×${it['quantity']}").join(", ")}
''';
                      Clipboard.setData(ClipboardData(text: waybillText.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Waybill text copied to clipboard!'), backgroundColor: storeGreen),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: storeGreen),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Close'),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: storeCream,
        appBar: AppBar(
          backgroundColor: const Color(0xff0d1b15),
          foregroundColor: Colors.white,
          title: Text(title),
          actions: [
            IconButton(
                tooltip: 'Refresh orders',
                onPressed: () => ref.invalidate(operationsOrdersProvider),
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: ref.watch(operationsOrdersProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                  child:
                      Text('Orders could not be loaded: ${commerceError(e)}')),
              data: (orders) => orders.isEmpty
                  ? const Center(
                      child: Text(
                          'No paid commercial orders to fulfill.\nPre-launch interests are managed in the admin contact list.',
                          textAlign: TextAlign.center))
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final order = orders[i];
                        final orderId = order['id']?.toString() ?? '';
                        final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
                        final status = order['status']?.toString().toUpperCase() ?? 'PENDING';
                        final total = double.tryParse(order['total']?.toString() ?? '') ?? 0.0;
                        final createdAt = order['created_at']?.toString() ?? '';
                        final carrier = order['carrier']?.toString() ?? '';
                        final tracking = order['tracking_number']?.toString() ?? '';

                        final address = order['address'] is Map
                            ? Map<String, dynamic>.from(order['address'] as Map)
                            : const <String, dynamic>{};
                        final recipient = address['recipient_name']?.toString() ?? 'Customer';
                        final phone = address['phone_number']?.toString() ?? address['phone']?.toString() ?? '';
                        final fullAddress = [
                          address['street_address'],
                          address['village_or_city'] ?? address['city'],
                          address['district'],
                          address['state'],
                          address['pincode'] != null ? 'PIN: ${address['pincode']}' : null,
                        ].where((s) => s != null && s.toString().trim().isNotEmpty).join(', ');

                        final items = order['items'] is List ? (order['items'] as List).whereType<Map>().toList() : [];

                        Color statusBg;
                        Color statusFg;
                        switch (status) {
                          case 'DELIVERED':
                            statusBg = const Color(0xffdcfce7);
                            statusFg = storeGreen;
                            break;
                          case 'DISPATCHED':
                          case 'SHIPPED':
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

                        final canFulfill = ['PENDING', 'CONFIRMED', 'PACKED', 'DISPATCHED', 'SHIPPED'].contains(status);

                        return Card(
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order Number and Status Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Order #$shortId',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: storeGreen)),
                                        const SizedBox(height: 2),
                                        Text('${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt} · Commercial Delivery',
                                            style: const TextStyle(fontSize: 11, color: storeMuted)),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                const Divider(height: 20),

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
                                      const Icon(Icons.location_on_outlined, size: 20, color: storeGreen),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(recipient, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                if (phone.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Text(phone, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: storeGreen)),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              fullAddress.isEmpty ? 'Delivery address pending' : fullAddress,
                                              style: const TextStyle(fontSize: 12, color: Color(0xff475569)),
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
                                          const Icon(Icons.check_circle_outline, size: 14, color: storeGreen),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${it['title'] ?? 'Item'} ×${it['quantity'] ?? 1}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Text(
                                            storeMoney(double.tryParse(it['line_total']?.toString() ?? '') ?? 0.0),
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )),

                                const Divider(height: 18),

                                // Tracking Box (if dispatched)
                                if (carrier.isNotEmpty || tracking.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfffaf5ff),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xfff3e8ff)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.local_shipping, size: 16, color: Color(0xff7e22ce)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Courier: ${carrier.isEmpty ? 'Courier' : carrier} · AWB: ${tracking.isEmpty ? 'Pending' : tracking}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff6b21a8)),
                                          ),
                                        ),
                                        if (tracking.isNotEmpty)
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: tracking));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('AWB copied to clipboard!'), duration: Duration(seconds: 2)),
                                              );
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              child: Text('Copy AWB', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff7e22ce))),
                                            ),
                                          ),
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
                                        const Text('Order Total', style: TextStyle(fontSize: 10, color: storeMuted)),
                                        Text(storeMoney(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: storeGreen)),
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
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.receipt_long, size: 16),
                                            label: const Text('Invoice', style: TextStyle(fontSize: 12)),
                                            onPressed: () => _showPackingSlipDialog(context, order),
                                          ),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xff1e293b),
                                              side: const BorderSide(color: Color(0xffcbd5e1)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            ),
                                            icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                                            label: const Text('Label (4x6)', style: TextStyle(fontSize: 12)),
                                            onPressed: () => _showShippingLabelDialog(context, order),
                                          ),
                                          if (canFulfill)
                                            FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor: storeGreen,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              ),
                                              icon: const Icon(Icons.local_shipping_outlined, size: 16),
                                              label: const Text('Update', style: TextStyle(fontSize: 12)),
                                              onPressed: () => update(context, ref, order),
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
                      },
                    ),
            ),
      );
}
