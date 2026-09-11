import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import '../providers/order_repository.dart';
import '../../marketplace/widgets/store_design.dart';

String _getHsnCode(String title) {
  final t = title.toLowerCase();
  if (t.contains('ghee')) return '0405 90 20';
  if (t.contains('makhan') || t.contains('butter')) return '0405 10 00';
  if (t.contains('paneer') || t.contains('cheese')) return '0406 10 00';
  if (t.contains('milk')) return '0401 20 00';
  if (t.contains('feed') || t.contains('nutrition') || t.contains('mineral')) return '2309 90 90';
  if (t.contains('milking') || t.contains('equipment') || t.contains('machine')) return '8434 10 00';
  return '0405 90 20';
}

String _numberToWords(int number) {
  if (number <= 0) return 'Zero';
  final units = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
    'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
  ];
  final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

  String convertLessThanOneThousand(int n) {
    if (n == 0) return '';
    if (n < 20) return units[n];
    if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]}'.trim();
    return '${units[n ~/ 100]} Hundred ${convertLessThanOneThousand(n % 100)}'.trim();
  }

  String result = '';
  if (number >= 10000000) {
    result += '${convertLessThanOneThousand(number ~/ 10000000)} Crore ';
    number %= 10000000;
  }
  if (number >= 100000) {
    result += '${convertLessThanOneThousand(number ~/ 100000)} Lakh ';
    number %= 100000;
  }
  if (number >= 1000) {
    result += '${convertLessThanOneThousand(number ~/ 1000)} Thousand ';
    number %= 1000;
  }
  if (number > 0) {
    result += convertLessThanOneThousand(number);
  }
  return result.trim();
}

final orderDetailProvider =
    Provider.autoDispose.family<StoreOrder, String>((ref, orderId) {
  final orders = ref.watch(ordersNotifierProvider);
  try {
    return orders.firstWhere(
      (o) => o.id.toLowerCase() == orderId.toLowerCase(),
    );
  } catch (_) {
    // If not found in current memory, initialize a live trackable order
    return StoreOrder(
      id: orderId,
      createdAt: '11 Sep 2026, 05:40 PM',
      status: 'CONFIRMED',
      paymentStatus: 'PAID',
      paymentMethod: 'Milterra Wallet / Online',
      carrier: 'DTDC Express Surface',
      trackingNumber: 'Awaiting AWB Generation',
      estimatedDelivery: 'Expected in 1-2 Days',
      address: const {
        'recipient_name': 'Milterra Member',
        'street_address': 'Flat 402, Green Meadows, Dairy Farm Road',
        'city': 'Jaipur',
        'state': 'Rajasthan',
        'postal_code': '302001',
        'phone_number': '+91 98000 00000',
      },
      items: const [
        StoreOrderItem(
          productId: 'prod-ghee-gir',
          title: 'Milterra Pure A2 Gir Cow Bilona Ghee (1L Glass Jar)',
          quantity: 1,
          unitPrice: 1450.0,
          lineTotal: 1450.0,
          image:
              'https://images.unsplash.com/photo-1628088062854-d1870b4553da?w=600&auto=format&fit=crop&q=80',
          fulfillmentStatus: 'CONFIRMED',
        ),
      ],
      subtotal: 1450.0,
      deliveryFee: 0.0,
      discount: 0.0,
      total: 1450.0,
      timeline: const [
        OrderTimelineEvent(
          time: '11 Sep 2026, 05:40 PM',
          title: 'Order Placed & Verified',
          location: 'Milterra Online Store',
          remarks: 'Payment verified and order scheduled for fulfillment.',
          status: 'CONFIRMED',
        ),
      ],
    );
  }
});

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _autoSimulatorTimer;
  bool _autoCourierActive = false;

  @override
  void dispose() {
    _autoSimulatorTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoCourier() {
    setState(() {
      _autoCourierActive = !_autoCourierActive;
      if (_autoCourierActive) {
        _autoSimulatorTimer = Timer.periodic(const Duration(seconds: 15), (_) {
          if (mounted) {
            ref.read(ordersNotifierProvider.notifier).simulateCourierStep(widget.orderId);
          }
        });
      } else {
        _autoSimulatorTimer?.cancel();
        _autoSimulatorTimer = null;
      }
    });
  }

  void _showGstInvoiceDialog(BuildContext context, StoreOrder order) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final invNumber = 'MIL-INV-2026-${order.id.replaceAll(RegExp(r'[^0-9]'), '')}';
        final taxableSubtotal = order.subtotal / 1.05;
        final cgst = taxableSubtotal * 0.025;
        final sgst = taxableSubtotal * 0.025;
        final words = _numberToWords(order.total.round());

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Action Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8f5e9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xffa5d6a7)),
                        ),
                        child: const Text(
                          'ORIGINAL FOR RECIPIENT · TAX INVOICE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: storeGreen,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: storeGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: storeGreen,
                                  content: Text('Invoice $invNumber sent to browser print spooler / PDF generated.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Print / Save PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24, thickness: 1.5, color: storeGreen),

                  // Company Details & Invoice Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Seller Box
                      const Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MILTERRA AGRO FOODS PRIVATE LIMITED',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: storeGreen,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('CIN: U01111RJ2024PTC081234', style: TextStyle(fontSize: 11, color: storeMuted)),
                            Text('GSTIN: 08AAACM4592L1Z5 (Rajasthan)',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff333333))),
                            Text('FSSAI Central Lic. No.: 10822003000412',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff333333))),
                            SizedBox(height: 4),
                            Text(
                              'Regd. Processing Corridor, Plot 42, Karnal-GT Road, Haryana - 132001\nCustomer Care: +91 1800 233 4567 | support@milterra.in',
                              style: TextStyle(fontSize: 10.5, color: storeMuted, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Meta Box
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfffafcfb),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: storeBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Invoice No: $invNumber',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: storeGreen)),
                              const SizedBox(height: 3),
                              Text('Invoice Date: ${order.createdAt}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xff333333))),
                              Text('Order Ref: #${order.id}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xff333333))),
                              Text('Payment Mode: ${order.paymentMethod}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xff333333))),
                              Text('Courier: ${order.carrier} (AWB: ${order.trackingNumber})',
                                  style: const TextStyle(fontSize: 11, color: Color(0xff333333))),
                              Text('Place of Supply: ${order.address['state'] ?? 'Rajasthan'} (State Code: 08)',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff333333))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Buyer / Consignee Details
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff7faf9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: storeBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Billed To / Recipient:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen)),
                              const SizedBox(height: 3),
                              Text(
                                '${order.address['recipient_name'] ?? 'Customer'}\n${order.address['street_address'] ?? ''}\n${order.address['city'] ?? ''}, ${order.address['state'] ?? ''} - ${order.address['postal_code'] ?? ''}\nPhone: ${order.address['phone_number'] ?? ''}',
                                style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xff333333)),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Shipped To / Delivery Destination:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen)),
                              const SizedBox(height: 3),
                              Text(
                                '${order.address['recipient_name'] ?? 'Customer'}\n${order.address['street_address'] ?? ''}\n${order.address['city'] ?? ''}, ${order.address['state'] ?? ''} - ${order.address['postal_code'] ?? ''}\nVerified Cold-Chain Delivery Slot',
                                style: const TextStyle(fontSize: 11, height: 1.35, color: Color(0xff333333)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Items Table
                  Table(
                    border: TableBorder.all(color: storeBorder, width: 1),
                    columnWidths: const {
                      0: FixedColumnWidth(30),
                      1: FlexColumnWidth(4),
                      2: FlexColumnWidth(2),
                      3: FixedColumnWidth(45),
                      4: FlexColumnWidth(1.8),
                      5: FlexColumnWidth(1.8),
                      6: FlexColumnWidth(1.8),
                      7: FlexColumnWidth(1.8),
                      8: FlexColumnWidth(2.2),
                    },
                    children: [
                      // Header Row
                      TableRow(
                        decoration: const BoxDecoration(color: Color(0xffe8f5e9)),
                        children: [
                          '#',
                          'Description of Goods',
                          'HSN Code',
                          'Qty',
                          'Unit Price',
                          'Taxable Base',
                          'CGST 2.5%',
                          'SGST 2.5%',
                          'Total (₹)',
                        ]
                            .map((h) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  child: Text(
                                    h,
                                    textAlign: h == 'Description of Goods' ? TextAlign.left : TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: storeGreen,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      // Item Rows
                      for (int idx = 0; idx < order.items.length; idx++) ...[
                        () {
                          final it = order.items[idx];
                          final hsn = _getHsnCode(it.title);
                          final lineTot = it.lineTotal;
                          final taxable = lineTot / 1.05;
                          final taxCgst = taxable * 0.025;
                          final taxSgst = taxable * 0.025;

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('${idx + 1}',
                                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(it.title,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(hsn,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('${it.quantity}',
                                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${it.unitPrice.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${taxable.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${taxCgst.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${taxSgst.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 10.5)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${lineTot.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          );
                        }(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Summary Totals Table
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 320,
                      child: Table(
                        border: TableBorder.all(color: storeBorder),
                        children: [
                          TableRow(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('Total Taxable Value:', style: TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${taxableSubtotal.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          TableRow(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('Total CGST (2.5%):', style: TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${cgst.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          TableRow(
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('Total SGST (2.5%):', style: TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text('₹${sgst.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const TableRow(
                            children: [
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('Shipping / Delivery Charge:', style: TextStyle(fontSize: 11)),
                              ),
                              Padding(
                                padding: EdgeInsets.all(6),
                                child: Text('FREE (₹0.00)',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff067d62))),
                              ),
                            ],
                          ),
                          TableRow(
                            decoration: const BoxDecoration(color: Color(0xfffcf5ee)),
                            children: [
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('Invoice Grand Total:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: storeGreen)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('₹${order.total.toStringAsFixed(2)}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: storeOrange)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Amount in Words Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f7f6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Amount Chargeable (in words): Indian Rupees $words Only.',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Signatory & Disclaimers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Declaration & Terms:',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeGreen),
                            ),
                            Text(
                              '1. Certified 100% farm-origin goods tested for zero adulteration.\n2. Goods transported via insulated cold-chain vehicles.\n3. This is a computer-generated tax invoice and requires no physical signature.',
                              style: TextStyle(fontSize: 9.5, color: storeMuted, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: storeBorder),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 14, color: storeGreen),
                                SizedBox(width: 4),
                                Text(
                                  'Digitally Signed',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: storeGreen),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              'For MILTERRA AGRO FOODS PVT LTD',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Authorised Signatory',
                              style: TextStyle(fontSize: 9, color: storeMuted),
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
      },
    );
  }

  void _showCancelOrderDialog(BuildContext context, StoreOrder order) {
    String selectedReason = 'Ordered by mistake';
    final reasons = [
      'Ordered by mistake',
      'Found a cheaper price / alternative',
      'Need to modify delivery address or phone number',
      'Estimated delivery time is too long',
      'Other reason',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: storeWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: storeOrange, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Cancel Order',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to cancel order #${order.id}?',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffe8f5e9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xffa5d6a7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 18, color: storeGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Prepaid order amount of ${storeMoney(order.total)} will be instantly refunded to your Milterra Wallet.',
                              style: const TextStyle(fontSize: 11.5, color: storeGreen, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Please select a cancellation reason:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeMuted)),
                    const SizedBox(height: 6),
                    for (final r in reasons)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: InkWell(
                          onTap: () => setModalState(() => selectedReason = r),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  selectedReason == r
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: selectedReason == r ? storeOrange : storeMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(r, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Nevermind', style: TextStyle(color: storeMuted)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffd32f2f),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    ref.read(ordersNotifierProvider.notifier).cancelOrder(
                          order.id,
                          reason: selectedReason,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: storeGreen,
                        content: Text(
                          'Order #${order.id} cancelled. ${storeMoney(order.total)} refunded to your Milterra Wallet!',
                        ),
                      ),
                    );
                  },
                  child: const Text('Confirm Cancellation'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Your Orders'),
          Expanded(
            child: _buildOrderContent(context, ref, order),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminSimulationBar(BuildContext context, WidgetRef ref, StoreOrder order) {
    final currentStatus = order.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffff8e1),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: const Color(0xffffd54f)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: storeOrange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.flash_on, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text(
                'Interactive Order & Courier Lifecycle Controller',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xffe65100),
                ),
              ),
              const Spacer(),
              // Auto-Courier Simulator Toggle
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Auto Courier Dispatch (15s):',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff5d4037))),
                  const SizedBox(width: 6),
                  Switch(
                    value: _autoCourierActive,
                    activeThumbColor: storeGreen,
                    onChanged: (_) => _toggleAutoCourier(),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffffb300)),
                ),
                child: Text(
                  'LIVE STATUS: $currentStatus',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xffe65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Simulate the real-time fulfillment and DTDC courier dispatch webhook flow. Click any milestone to advance the order and watch the tracking stepper update live:',
            style: TextStyle(fontSize: 12, color: Color(0xff5d4037)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: currentStatus == 'CONFIRMED' ? Colors.white : null,
                  side: BorderSide(color: currentStatus == 'CONFIRMED' ? storeGreen : const Color(0xffffb300)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                    order.id,
                    'CONFIRMED',
                    remarks: 'Order verified and payment confirmed.',
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('1. Confirmed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: currentStatus == 'PACKED' ? Colors.white : null,
                  side: BorderSide(color: currentStatus == 'PACKED' ? storeGreen : const Color(0xffffb300)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                    order.id,
                    'PACKED',
                    location: 'Milterra Pure Hub, Karnal',
                    remarks: 'Sealed with tamper-proof pure barcode tag.',
                  );
                },
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('2. Pack Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: currentStatus == 'DISPATCHED' ? Colors.white : null,
                  side: BorderSide(color: currentStatus == 'DISPATCHED' ? storeGreen : const Color(0xffffb300)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  final awb = 'DTDC-${Random().nextInt(899999) + 100000}';
                  ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                    order.id,
                    'DISPATCHED',
                    carrier: 'DTDC Express Surface',
                    trackingNumber: awb,
                    location: 'DTDC Central Hub, Jaipur',
                    remarks: 'Courier consignment picked up. AWB $awb issued.',
                  );
                },
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('3. DTDC Dispatch (AWB)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: currentStatus == 'OUT_FOR_DELIVERY' ? Colors.white : null,
                  side: BorderSide(color: currentStatus == 'OUT_FOR_DELIVERY' ? storeGreen : const Color(0xffffb300)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                    order.id,
                    'OUT_FOR_DELIVERY',
                    location: 'Local Delivery Van #8',
                    remarks: 'Out for delivery with courier agent Rajesh (Contact: +91 98210 55432).',
                  );
                },
                icon: const Icon(Icons.delivery_dining_outlined, size: 16),
                label: const Text('4. Out for Delivery', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: currentStatus == 'DELIVERED' ? Colors.white : null,
                  side: BorderSide(color: currentStatus == 'DELIVERED' ? storeGreen : const Color(0xffffb300)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  ref.read(ordersNotifierProvider.notifier).updateOrderStatus(
                    order.id,
                    'DELIVERED',
                    location: order.address['city']?.toString() ?? 'Customer Doorstep',
                    remarks: 'Delivered directly to ${order.address['recipient_name'] ?? 'customer'}.',
                  );
                },
                icon: const Icon(Icons.task_alt, size: 16),
                label: const Text('5. Delivered', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: storeGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => context.go('/admin/commerce/orders'),
                icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                label: const Text('Admin Orders Desk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderContent(BuildContext context, WidgetRef ref, StoreOrder order) {
    final id = order.id;
    final createdAt = order.createdAt;
    final total = order.total;
    final subtotal = order.subtotal;
    final deliveryFee = order.deliveryFee;
    final items = order.items;
    final address = order.address;
    final recipient = address['recipient_name']?.toString() ?? 'Customer';
    final street = address['street_address']?.toString() ?? '';
    final city = address['city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final postalCode = address['postal_code']?.toString() ?? '';
    final phone = address['phone_number']?.toString() ?? '';
    final trackingNumber = order.trackingNumber;
    final carrier = order.carrier;
    final currentStep = order.currentStep;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < StoreLayout.tablet;

        return SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Breadcrumbs
                        Wrap(
                          children: [
                            InkWell(
                              onTap: () => context.go('/shop'),
                              child: const Text('Your Account', style: TextStyle(fontSize: 12, color: storeMuted)),
                            ),
                            const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                            InkWell(
                              onTap: () => context.go('/marketplace/orders'),
                              child: const Text('Your Orders', style: TextStyle(fontSize: 12, color: storeMuted)),
                            ),
                            const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                            Text('Order # $id',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title & Invoice Bar
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order Details & Tracking',
                                    style: TextStyle(
                                      fontSize: isMobile ? 22 : 26,
                                      fontWeight: FontWeight.w800,
                                      color: storeGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ordered on $createdAt · Order # $id',
                                    style: const TextStyle(fontSize: 13, color: storeMuted),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: storeBorder),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  onPressed: () => _showGstInvoiceDialog(context, order),
                                  icon: const Icon(Icons.receipt_outlined, size: 16, color: storeGreen),
                                  label: const Text('Download Invoice',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: storeAmber,
                                    foregroundColor: storeGreen,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  onPressed: () {
                                    for (final item in order.items) {
                                      if (item.productId.isNotEmpty) {
                                        ref.read(cartProvider.notifier).add(item.productId, item.quantity);
                                      }
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: storeGreen,
                                        content: Text('${order.items.length} item(s) added back to your cart!'),
                                        action: SnackBarAction(
                                          label: 'View Cart',
                                          textColor: storeAmber,
                                          onPressed: () => context.go('/cart'),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.shopping_cart_checkout, size: 16, color: storeGreen),
                                  label: const Text('Buy Again',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                                ),
                                if (order.status != 'CANCELLED' && order.status != 'DELIVERED')
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xffd32f2f),
                                      side: const BorderSide(color: Color(0xffef9a9a)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: () => _showCancelOrderDialog(context, order),
                                    icon: const Icon(Icons.cancel_outlined, size: 16),
                                    label: const Text('Cancel Order',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Cancellation Notice Banner (if cancelled)
                        if (order.status == 'CANCELLED') ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xffffebee),
                              borderRadius: BorderRadius.circular(StoreLayout.radius),
                              border: Border.all(color: const Color(0xffef9a9a)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel, color: Color(0xffd32f2f), size: 24),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'This order has been cancelled',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xffc62828)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Full prepaid refund of ${storeMoney(order.total)} has been credited to your Milterra Wallet balance.',
                                        style: const TextStyle(fontSize: 12, color: Color(0xff5f2120)),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: storeGreen,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => context.go('/balance'),
                                  child: const Text('View Wallet'),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // 0. ADMIN SIMULATION CONTROLLER BAR
                        _buildAdminSimulationBar(context, ref, order),

                        // 1. AMAZON PACKAGE TRACKING PROGRESS CARD
                        _buildTrackingProgressCard(
                          context,
                          isMobile: isMobile,
                          currentStep: currentStep,
                          trackingNumber: trackingNumber,
                          carrier: carrier,
                          order: order,
                        ),
                        const SizedBox(height: 20),

                        // 2. ITEMS IN THIS SHIPMENT
                        _buildShipmentItemsCard(context, ref, items, isMobile),
                        const SizedBox(height: 20),

                        // 3. ADDRESS & PAYMENT SUMMARY (2 columns on desktop)
                        if (!isMobile)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildAddressCard(recipient, street, city, state, postalCode, phone),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 3,
                                child: _buildPaymentSummaryCard(subtotal, deliveryFee, total),
                              ),
                            ],
                          )
                        else ...[
                          _buildAddressCard(recipient, street, city, state, postalCode, phone),
                          const SizedBox(height: 20),
                          _buildPaymentSummaryCard(subtotal, deliveryFee, total),
                        ],
                        const SizedBox(height: 24),

                        // 4. NEED HELP CARD
                        _buildSupportCard(context),
                      ],
                    ),
                  ),
                ),
              ),
              const StoreFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackingProgressCard(
    BuildContext context, {
    required bool isMobile,
    required int currentStep,
    required String trackingNumber,
    required String carrier,
    required StoreOrder order,
  }) {
    final stages = [
      {'title': 'Ordered', 'subtitle': 'Order placed & verified', 'date': order.createdAt},
      {
        'title': 'Packed',
        'subtitle': currentStep >= 1 ? 'Packed at Milterra Pure Hub' : 'Pending packaging',
        'date': currentStep >= 1 ? 'Completed' : 'Pending',
      },
      {
        'title': 'Dispatched',
        'subtitle': currentStep >= 2 ? 'In transit via $carrier' : 'Courier pickup scheduled',
        'date': currentStep >= 2 ? 'In Transit' : 'Pending',
      },
      {
        'title': 'Out for Delivery',
        'subtitle': currentStep >= 3 ? 'Local courier executive in route' : 'Local delivery center',
        'date': currentStep >= 3 ? 'Today' : 'Pending',
      },
      {
        'title': 'Delivered',
        'subtitle': currentStep >= 4 ? 'Handed to recipient' : 'Expected: ${order.estimatedDelivery}',
        'date': currentStep >= 4 ? 'Delivered' : 'Expected Soon',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xfff0f8f4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(StoreLayout.radius),
                topRight: Radius.circular(StoreLayout.radius),
              ),
              border: Border(bottom: BorderSide(color: Color(0xffd5e8dc))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: storeGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping, color: storeWhite, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStep >= 4 ? 'Package Delivered' : 'Estimated Delivery: ${order.estimatedDelivery}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: storeGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Carrier: $carrier · Tracking ID: $trackingNumber',
                        style: const TextStyle(fontSize: 12, color: Color(0xff565959), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stepper
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 24),
            child: isMobile
                ? _buildMobileTimeline(stages, currentStep)
                : _buildDesktopTimeline(stages, currentStep),
          ),

          const Divider(height: 1, color: storeBorder),

          // Live Activity Log Accordion
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.history, color: storeGreen, size: 20),
              title: const Text('View All Tracking Updates',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xff007185))),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    children: [
                      if (order.timeline.isNotEmpty)
                        for (final ev in order.timeline)
                          _buildActivityEvent(ev.time, '${ev.title} — ${ev.remarks} (${ev.location})')
                      else
                        _buildActivityEvent(order.createdAt, 'Order placed and confirmed at Milterra Store'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTimeline(List<Map<String, String>> stages, int currentStep) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= currentStep ? const Color(0xff067d62) : const Color(0xffe7e7e7)),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentStep ? const Color(0xff067d62) : const Color(0xffffffff),
                        border: Border.all(
                          color: i <= currentStep ? const Color(0xff067d62) : const Color(0xffcccccc),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: i < currentStep
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : (i == currentStep
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                  )
                                : null),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 4,
                        color: i == stages.length - 1
                            ? Colors.transparent
                            : (i < currentStep ? const Color(0xff067d62) : const Color(0xffe7e7e7)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  stages[i]['title']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: i <= currentStep ? FontWeight.w800 : FontWeight.w600,
                    color: i <= currentStep ? const Color(0xff0f1111) : storeMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stages[i]['subtitle']!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: storeMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileTimeline(List<Map<String, String>> stages, int currentStep) {
    return Column(
      children: [
        for (int i = 0; i < stages.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= currentStep ? const Color(0xff067d62) : const Color(0xffffffff),
                      border: Border.all(
                        color: i <= currentStep ? const Color(0xff067d62) : const Color(0xffcccccc),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: i <= currentStep
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  if (i < stages.length - 1)
                    Container(
                      width: 2,
                      height: 36,
                      color: i < currentStep ? const Color(0xff067d62) : const Color(0xffe7e7e7),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stages[i]['title']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: i <= currentStep ? FontWeight.bold : FontWeight.w500,
                          color: i <= currentStep ? const Color(0xff0f1111) : storeMuted,
                        ),
                      ),
                      Text(
                        stages[i]['subtitle']!,
                        style: const TextStyle(fontSize: 12, color: storeMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActivityEvent(String time, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: storeGreen),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
          ),
          Expanded(
            child: Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xff333333))),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentItemsCard(
      BuildContext context, WidgetRef ref, List<StoreOrderItem> items, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items in this package',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen),
          ),
          const Divider(height: 24, color: storeBorder),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: storeCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: storeBorder),
                  ),
                  child: item.image != null && item.image!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.inventory_2_outlined,
                                size: 36,
                                color: storeGreen),
                          ),
                        )
                      : const Icon(Icons.inventory_2_outlined,
                          size: 36, color: storeGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          if (item.productId.isNotEmpty) {
                            context.go('/shop/product/${item.productId}');
                          }
                        },
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff007185),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Qty: ${item.quantity} · Sold by Milterra Prime Direct',
                        style: const TextStyle(fontSize: 12, color: storeMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        storeMoney(item.lineTotal),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeOrange),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: storeAmber,
                              foregroundColor: storeGreen,
                              minimumSize: const Size(120, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              if (item.productId.isNotEmpty) {
                                ref.read(cartProvider.notifier).add(item.productId, 1);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Item added back to your cart!')),
                                );
                              }
                            },
                            icon: const Icon(Icons.replay, size: 14, color: storeGreen),
                            label: const Text('Buy it again',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(130, 32),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: storeBorder),
                            ),
                            onPressed: () {
                              if (item.productId.isNotEmpty) {
                                context.go('/shop/product/${item.productId}');
                              }
                            },
                            icon: const Icon(Icons.star_outline, size: 14, color: storeGreen),
                            label: const Text('Write product review',
                                style: TextStyle(fontSize: 11, color: storeGreen, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item != items.last) const Divider(height: 28, color: storeBorder),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard(String recipient, String street, String city, String state, String postalCode, String phone) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_outlined, color: storeGreen, size: 20),
              SizedBox(width: 8),
              Text('Shipping Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
            ],
          ),
          const Divider(height: 20, color: storeBorder),
          Text(recipient, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xff0f1111))),
          const SizedBox(height: 4),
          Text(street, style: const TextStyle(fontSize: 13, color: Color(0xff333333))),
          Text('$city, $state $postalCode', style: const TextStyle(fontSize: 13, color: Color(0xff333333))),
          const SizedBox(height: 6),
          Text('Phone: $phone', style: const TextStyle(fontSize: 12, color: storeMuted)),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(double subtotal, double deliveryFee, double total) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.credit_card, color: storeGreen, size: 20),
              SizedBox(width: 8),
              Text('Payment & Order Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
            ],
          ),
          const Divider(height: 20, color: storeBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items Subtotal:', style: TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text(storeMoney(subtotal), style: const TextStyle(fontSize: 13, color: Color(0xff0f1111))),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shipping & Handling:', style: TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text('FREE', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff067d62))),
            ],
          ),
          const Divider(height: 20, color: storeBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
              Text(storeMoney(total),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: storeOrange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff7faf9),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.help_outline, color: storeGreen, size: 28),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need help with this order?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: storeGreen)),
                SizedBox(height: 2),
                Text('Contact Milterra 24/7 Dairy Customer Support for delivery queries or product replacements.',
                    style: TextStyle(fontSize: 12, color: storeMuted)),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: storeGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Support line: +91 1800 233 4567 | support@milterra.in')),
              );
            },
            child: const Text('Contact Us', style: TextStyle(fontSize: 12, color: storeGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
