import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import '../../commerce/utils/courier_tracking_utils.dart';
import '../providers/order_repository.dart';
import '../../marketplace/widgets/store_design.dart';

final orderDetailProvider =
    Provider.autoDispose.family<StoreOrder?, String>((ref, orderId) {
  final orders = ref.watch(ordersNotifierProvider);
  try {
    return orders.firstWhere(
      (o) => o.id.toLowerCase() == orderId.toLowerCase(),
    );
  } catch (_) {
    return null;
  }
});

final liveOrderTrackingProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, orderId) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/marketplace/orders/$orderId/tracking');
    if (response.data is Map && response.data['data'] is Map) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
  } catch (_) {}
  return null;
});

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Future<void> _openPayment(StoreOrder order) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post('/marketplace/orders/${order.id}/payment-link');
      if (response.data['data']['payment_status'] == 'PAID') {
        ref.read(ordersNotifierProvider.notifier).refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment confirmed for this order.')),
          );
        }
        return;
      }
      final uri = Uri.tryParse(response.data['data']['url']?.toString() ?? '');
      if (uri == null ||
          uri.scheme != 'https' ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Payment page could not be opened');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Secure payment is unavailable. Please try again later.')));
      }
    }
  }

  Future<void> _checkPayment(StoreOrder order) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post('/marketplace/orders/${order.id}/payment/verify');
      ref.read(ordersNotifierProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(response.data['data']['confirmed'] == true
                ? 'Payment confirmed.'
                : 'Payment is still pending.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment could not be checked. Please retry.')));
      }
    }
  }

  void _showOrderSummaryDialog(BuildContext context, StoreOrder order) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(order.isPrelaunchInterest
            ? 'Purchase interest summary'
            : 'Order summary'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reference: ${order.id}'),
                const SizedBox(height: 8),
                Text('Order status: ${order.status}'),
                Text(order.isPrelaunchInterest
                    ? 'No payment was taken. This is not a tax invoice.'
                    : 'Payment status: ${order.paymentStatus}'),
                const Divider(height: 24),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('${item.title} × ${item.quantity}'),
                  ),
                const Divider(height: 24),
                Text('Total: ${storeMoney(order.total)}'),
                const SizedBox(height: 8),
                const Text('This summary is not a tax invoice.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(BuildContext context, StoreOrder order) {
    final requiresRefund = order.paymentStatus == 'PAID';
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: storeOrange, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Cancel Order',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: storeGreen),
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
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
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
                          const Icon(Icons.account_balance_wallet,
                              size: 18, color: storeGreen),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              requiresRefund
                                  ? 'Your paid order will remain active while staff reviews the cancellation and verifies a refund to the original payment method. No instant refund is made.'
                                  : order.isPrelaunchInterest
                                      ? 'This withdraws your purchase interest. No payment was taken.'
                                      : 'This cancels the unpaid order. No payment or refund will be made.',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: storeGreen,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Please select a cancellation reason:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: storeMuted)),
                    const SizedBox(height: 6),
                    for (final r in reasons)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: InkWell(
                          onTap: () => setModalState(() => selectedReason = r),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 4),
                            child: Row(
                              children: [
                                Icon(
                                  selectedReason == r
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 18,
                                  color: selectedReason == r
                                      ? storeOrange
                                      : storeMuted,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(r,
                                        style: const TextStyle(fontSize: 12))),
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
                  child: const Text('Nevermind',
                      style: TextStyle(color: storeMuted)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffd32f2f),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      await ref
                          .read(ordersNotifierProvider.notifier)
                          .cancelOrder(
                            order.id,
                            reason: selectedReason,
                          );
                      if (!context.mounted) return;
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: storeGreen,
                          content: Text(
                            requiresRefund
                                ? 'Cancellation requested. Your order remains paid until a refund is verified.'
                                : 'Order #${order.id} cancelled. No refund or payment was made.',
                          ),
                        ),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Cancellation could not be saved. Please retry or contact support.')));
                      }
                    }
                  },
                  child: Text(requiresRefund
                      ? 'Request cancellation'
                      : 'Confirm cancellation'),
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
          if (ref.watch(orderLoadStateProvider).isLoading)
            const LinearProgressIndicator(),
          if (ref.watch(orderLoadStateProvider).hasError)
            ListTile(
                title: const Text('Order could not be loaded.'),
                trailing: TextButton(
                    onPressed: () =>
                        ref.read(ordersNotifierProvider.notifier).refresh(),
                    child: const Text('Retry'))),
          Expanded(
            child: order == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 48, color: storeMuted),
                        const SizedBox(height: 12),
                        const Text('Order not found', style: StoreType.heading),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.go('/marketplace/orders'),
                          child: const Text('Back to your orders'),
                        ),
                      ],
                    ),
                  )
                : _buildOrderContent(context, ref, order),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderContent(
      BuildContext context, WidgetRef ref, StoreOrder order) {
    final id = order.id;
    final createdAt = order.createdAt;
    final total = order.total;
    final subtotal = order.subtotal;
    final deliveryFee = order.deliveryFee;
    final items = order.items;
    final address = order.address;
    final recipient = address['recipient_name']?.toString() ?? 'Customer';
    final street = address['address_line1']?.toString() ?? '';
    final city = address['village_or_city']?.toString() ?? '';
    final state = address['state']?.toString() ?? '';
    final postalCode = address['postal_code']?.toString() ?? '';
    final phone = address['phone']?.toString() ?? '';
    final liveTracking =
        ref.watch(liveOrderTrackingProvider(order.id)).valueOrNull;
    final trackingNumber = order.trackingNumber.isNotEmpty
        ? order.trackingNumber
        : (liveTracking?['awb']?.toString() ?? '');
    final carrier = order.carrier.isNotEmpty
        ? order.carrier
        : (liveTracking?['carrier']?.toString() ?? '');
    final currentStep = order.currentStep;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < StoreLayout.tablet;

        return SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Breadcrumbs
                        Wrap(
                          children: [
                            InkWell(
                              onTap: () => context.go('/account'),
                              child: const Text('Your Account',
                                  style: TextStyle(
                                      fontSize: 12, color: storeMuted)),
                            ),
                            const Text(' › ',
                                style:
                                    TextStyle(fontSize: 12, color: storeMuted)),
                            InkWell(
                              onTap: () => context.go('/marketplace/orders'),
                              child: const Text('Your Orders',
                                  style: TextStyle(
                                      fontSize: 12, color: storeMuted)),
                            ),
                            const Text(' › ',
                                style:
                                    TextStyle(fontSize: 12, color: storeMuted)),
                            Text('Order # $id',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: storeGreen)),
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
                                    order.isPrelaunchInterest
                                        ? 'Launch Reservation Details'
                                        : 'Order Details & Tracking',
                                    style: TextStyle(
                                      fontSize: isMobile ? 22 : 26,
                                      fontWeight: FontWeight.w800,
                                      color: storeGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    order.isPrelaunchInterest
                                        ? 'Registered on $createdAt · Reference # $id'
                                        : 'Ordered on $createdAt · Order # $id',
                                    style: const TextStyle(
                                        fontSize: 13, color: storeMuted),
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
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                  ),
                                  onPressed: () =>
                                      _showOrderSummaryDialog(context, order),
                                  icon: Icon(
                                      order.isPrelaunchInterest
                                          ? Icons.description_outlined
                                          : Icons.receipt_outlined,
                                      size: 16,
                                      color: storeGreen),
                                  label: const Text('Order summary',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: storeGreen)),
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: storeAmber,
                                    foregroundColor: storeGreen,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                  ),
                                  onPressed: () {
                                    for (final item in order.items) {
                                      if (item.productId.isNotEmpty) {
                                        ref
                                            .read(cartProvider.notifier)
                                            .add(item.productId, item.quantity);
                                      }
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: storeGreen,
                                        content: Text(
                                            '${order.items.length} item(s) added back to your cart!'),
                                        action: SnackBarAction(
                                          label: 'View Cart',
                                          textColor: storeAmber,
                                          onPressed: () => context.go('/cart'),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.shopping_cart_checkout,
                                      size: 16, color: storeGreen),
                                  label: const Text('Buy Again',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: storeGreen)),
                                ),
                                if (order.status != 'CANCELLED' &&
                                    order.status != 'DELIVERED' &&
                                    order.status != 'PACKED' &&
                                    order.status != 'SHIPPED' &&
                                    order.status != 'DISPATCHED' &&
                                    order.status != 'OUT_FOR_DELIVERY' &&
                                    order.cancellationStatus != 'REQUESTED')
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xffd32f2f),
                                      side: const BorderSide(
                                          color: Color(0xffef9a9a)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                    ),
                                    onPressed: () =>
                                        _showCancelOrderDialog(context, order),
                                    icon: const Icon(Icons.cancel_outlined,
                                        size: 16),
                                    label: Text(
                                        order.paymentStatus == 'PAID'
                                            ? 'Request cancellation'
                                            : 'Cancel Order',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                if (order.cancellationStatus == 'REQUESTED')
                                  const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Text(
                                        'Cancellation requested · Refund review pending'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (!order.isPrelaunchInterest &&
                            order.paymentStatus == 'PENDING' &&
                            order.status != 'CANCELLED' &&
                            order.paymentMethod != 'cod') ...[
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            FilledButton.icon(
                              onPressed: () => _openPayment(order),
                              icon: const Icon(Icons.payment),
                              label: const Text('Pay securely'),
                            ),
                            OutlinedButton(
                              onPressed: () => _checkPayment(order),
                              child: const Text('Check payment status'),
                            ),
                          ]),
                          const SizedBox(height: 20),
                        ],

                        // Cancellation Notice Banner (if cancelled)
                        if (order.status == 'CANCELLED') ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xffffebee),
                              borderRadius:
                                  BorderRadius.circular(StoreLayout.radius),
                              border:
                                  Border.all(color: const Color(0xffef9a9a)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel,
                                    color: Color(0xffd32f2f), size: 24),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'This order has been cancelled',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xffc62828)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Cancellation is saved. No automatic refund or payment was made.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xff5f2120)),
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
                                child: _buildAddressCard(recipient, street,
                                    city, state, postalCode, phone),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 3,
                                child: _buildPaymentSummaryCard(
                                    subtotal, deliveryFee, total),
                              ),
                            ],
                          )
                        else ...[
                          _buildAddressCard(recipient, street, city, state,
                              postalCode, phone),
                          const SizedBox(height: 20),
                          _buildPaymentSummaryCard(
                              subtotal, deliveryFee, total),
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
    if (order.isPrelaunchInterest) {
      final isCancelled = order.status == 'CANCELLED';
      return Container(
        decoration: BoxDecoration(
          color: storeWhite,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          border: Border.all(color: storeBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isCancelled
                    ? const Color(0xffffebee)
                    : const Color(0xffe1f5fe).withValues(alpha: 0.4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(StoreLayout.radius),
                  topRight: Radius.circular(StoreLayout.radius),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isCancelled
                        ? const Color(0xffef9a9a)
                        : const Color(0xffb3e5fc),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? const Color(0xffd32f2f)
                          : const Color(0xff0277bd),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCancelled
                          ? Icons.bookmark_remove_outlined
                          : Icons.bookmark_added_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCancelled
                              ? 'Launch Interest Withdrawn'
                              : 'Launch Reservation Recorded',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isCancelled
                                ? const Color(0xffc62828)
                                : const Color(0xff01579b),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pre-launch registration only: No payment was collected and no courier dispatch is scheduled.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xff565959),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What happens next?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: storeGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Milterra will notify you when products become available for dispatch in your area. You can then review the final price and complete payment securely via hosted UPI, cards, net banking, or choose Cash on Delivery.',
                    style:
                        TextStyle(fontSize: 13, height: 1.4, color: storeMuted),
                  ),
                  if (order.timeline.isNotEmpty) ...[
                    const Divider(height: 28, color: storeBorder),
                    const Text(
                      'Reservation Activity',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: storeGreen,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final event in order.timeline)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle,
                                size: 8, color: storeGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xff0f1111),
                                    ),
                                  ),
                                  Text(
                                    '${event.time}${event.remarks.isNotEmpty ? ' · ${event.remarks}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: storeMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    final stages = [
      {
        'title': 'Ordered',
        'subtitle': 'Order placed & verified',
        'date': order.createdAt
      },
      {
        'title': 'Packed',
        'subtitle':
            currentStep >= 1 ? 'Packed for dispatch' : 'Pending packaging',
        'date': currentStep >= 1 ? 'Completed' : 'Pending',
      },
      {
        'title': 'Dispatched',
        'subtitle': currentStep >= 2
            ? 'Handed to ${carrier.isNotEmpty ? carrier : 'courier'}'
            : 'Awaiting courier handover',
        'date': currentStep >= 2 ? 'Dispatched' : 'Pending',
      },
      {
        'title': 'Out for Delivery',
        'subtitle': currentStep >= 3
            ? 'Courier marked out for delivery'
            : 'Awaiting courier update',
        'date': currentStep >= 3 ? 'Out for delivery' : 'Pending',
      },
      {
        'title': 'Delivered',
        'subtitle': currentStep >= 4
            ? 'Delivery confirmed'
            : 'Awaiting delivery confirmation',
        'date': currentStep >= 4 ? 'Delivered' : 'Pending',
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
                  child: const Icon(Icons.local_shipping,
                      color: storeWhite, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentStep >= 4
                            ? 'Package delivered'
                            : trackingNumber.isNotEmpty
                                ? 'Courier tracking available'
                                : 'Awaiting courier booking',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: storeGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trackingNumber.isNotEmpty
                            ? 'Carrier: $carrier · Tracking ID: $trackingNumber'
                            : 'No courier reference has been issued yet',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xff565959),
                            fontWeight: FontWeight.w500),
                      ),
                      if (trackingNumber.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () =>
                              launchCourierTracking(carrier, trackingNumber),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.open_in_new,
                                  size: 13, color: Color(0xff007185)),
                              SizedBox(width: 4),
                              Text(
                                'Track Live on Courier Portal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff007185),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Stepper
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24, vertical: 24),
            child: isMobile
                ? _buildMobileTimeline(stages, currentStep)
                : _buildDesktopTimeline(stages, currentStep),
          ),

          if (currentStep >= 4) ...[
            const Divider(height: 1, color: storeBorder),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: storeBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_return_outlined,
                        color: storeGreen, size: 22),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need to return or exchange?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1e293b),
                            ),
                          ),
                          Text(
                            'Report transit damage, broken seal, or quality issue within 48h.',
                            style: TextStyle(fontSize: 11, color: storeMuted),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: storeGreen,
                        side: const BorderSide(color: storeGreen),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _showReturnRequestDialog(order.id),
                      child: const Text(
                        'Return / Replace',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const Divider(height: 1, color: storeBorder),

          // Live Activity Log Accordion
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(Icons.history, color: storeGreen, size: 20),
              title: const Text('View All Tracking Updates',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xff007185))),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    children: [
                      if (order.timeline.isNotEmpty)
                        for (final ev in order.timeline)
                          _buildActivityEvent(ev.time,
                              '${ev.title} — ${ev.remarks} (${ev.location})')
                      else
                        _buildActivityEvent(order.createdAt,
                            'Order placed and confirmed at Milterra Store'),
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

  Widget _buildDesktopTimeline(
      List<Map<String, String>> stages, int currentStep) {
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
                            : (i <= currentStep
                                ? const Color(0xff067d62)
                                : const Color(0xffe7e7e7)),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentStep
                            ? const Color(0xff067d62)
                            : const Color(0xffffffff),
                        border: Border.all(
                          color: i <= currentStep
                              ? const Color(0xff067d62)
                              : const Color(0xffcccccc),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: i < currentStep
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : (i == currentStep
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white),
                                  )
                                : null),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 4,
                        color: i == stages.length - 1
                            ? Colors.transparent
                            : (i < currentStep
                                ? const Color(0xff067d62)
                                : const Color(0xffe7e7e7)),
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
                    fontWeight:
                        i <= currentStep ? FontWeight.w800 : FontWeight.w600,
                    color:
                        i <= currentStep ? const Color(0xff0f1111) : storeMuted,
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

  Widget _buildMobileTimeline(
      List<Map<String, String>> stages, int currentStep) {
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
                      color: i <= currentStep
                          ? const Color(0xff067d62)
                          : const Color(0xffffffff),
                      border: Border.all(
                        color: i <= currentStep
                            ? const Color(0xff067d62)
                            : const Color(0xffcccccc),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: i <= currentStep
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  ),
                  if (i < stages.length - 1)
                    Container(
                      width: 2,
                      height: 36,
                      color: i < currentStep
                          ? const Color(0xff067d62)
                          : const Color(0xffe7e7e7),
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
                          fontWeight: i <= currentStep
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: i <= currentStep
                              ? const Color(0xff0f1111)
                              : storeMuted,
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
            child: Text(time,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: storeGreen)),
          ),
          Expanded(
            child: Text(desc,
                style: const TextStyle(fontSize: 12, color: Color(0xff333333))),
          ),
        ],
      ),
    );
  }

  Widget _buildShipmentItemsCard(BuildContext context, WidgetRef ref,
      List<StoreOrderItem> items, bool isMobile) {
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
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen),
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
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: storeOrange),
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
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: () {
                              if (item.productId.isNotEmpty) {
                                ref
                                    .read(cartProvider.notifier)
                                    .add(item.productId, 1);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Item added back to your cart!')),
                                );
                              }
                            },
                            icon: const Icon(Icons.replay,
                                size: 14, color: storeGreen),
                            label: const Text('Buy it again',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(130, 32),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(color: storeBorder),
                            ),
                            onPressed: () {
                              if (item.productId.isNotEmpty) {
                                context.go('/shop/product/${item.productId}');
                              }
                            },
                            icon: const Icon(Icons.star_outline,
                                size: 14, color: storeGreen),
                            label: const Text('Write product review',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: storeGreen,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item != items.last)
              const Divider(height: 28, color: storeBorder),
          ],
        ],
      ),
    );
  }

  Widget _buildAddressCard(String recipient, String street, String city,
      String state, String postalCode, String phone) {
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
              Text('Shipping Address',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: storeGreen)),
            ],
          ),
          const Divider(height: 20, color: storeBorder),
          Text(recipient,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff0f1111))),
          const SizedBox(height: 4),
          Text(street,
              style: const TextStyle(fontSize: 13, color: Color(0xff333333))),
          Text('$city, $state $postalCode',
              style: const TextStyle(fontSize: 13, color: Color(0xff333333))),
          const SizedBox(height: 6),
          Text('Phone: $phone',
              style: const TextStyle(fontSize: 12, color: storeMuted)),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(
      double subtotal, double deliveryFee, double total) {
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
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: storeGreen)),
            ],
          ),
          const Divider(height: 20, color: storeBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items Subtotal:',
                  style: TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text(storeMoney(subtotal),
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xff0f1111))),
            ],
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shipping & Handling:',
                  style: TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text('FREE',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff067d62))),
            ],
          ),
          const Divider(height: 20, color: storeBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total:',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: storeGreen)),
              Text(storeMoney(total),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: storeOrange)),
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
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: storeGreen)),
                SizedBox(height: 2),
                Text(
                    'Contact Milterra 24/7 Dairy Customer Support for delivery queries or product replacements.',
                    style: TextStyle(fontSize: 12, color: storeMuted)),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: storeGreen),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Support line: +91 1800 233 4567 | support@milterra.in')),
              );
            },
            child: const Text('Contact Us',
                style: TextStyle(
                    fontSize: 12,
                    color: storeGreen,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showReturnRequestDialog(String orderId) async {
    String selectedReason = 'Damaged on delivery';
    final remarksCtrl = TextEditingController();
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.assignment_return_outlined, color: storeGreen),
              SizedBox(width: 8),
              Text(
                'Request Return or Exchange',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select the primary reason for returning this item. Our quality inspection team will review and approve pickup within 24 hours.',
                  style: TextStyle(fontSize: 12, color: storeMuted),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'Reason for return',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Damaged on delivery',
                      child: Text('Damaged on delivery'),
                    ),
                    DropdownMenuItem(
                      value: 'Broken container / Defective seal',
                      child: Text('Broken container / Defective seal'),
                    ),
                    DropdownMenuItem(
                      value: 'Spoilage or quality issue',
                      child: Text('Spoilage or quality issue'),
                    ),
                    DropdownMenuItem(
                      value: 'Wrong product delivered',
                      child: Text('Wrong product delivered'),
                    ),
                    DropdownMenuItem(
                      value: 'Other issue',
                      child: Text('Other issue'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setDialogState(() => selectedReason = v);
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Details / Description',
                    hintText:
                        'e.g. Broken packaging upon delivery, photos available...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        final dio = ref.read(dioProvider);
                        final res = await dio.post(
                          '/marketplace/orders/$orderId/return',
                          data: {
                            'reason': selectedReason,
                            'remarks': remarksCtrl.text.trim(),
                          },
                        );
                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                        }
                        if (!mounted) return;
                        ref.invalidate(orderDetailProvider(orderId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              res.data['message']?.toString() ??
                                  'Return request submitted successfully',
                            ),
                            backgroundColor: storeGreen,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit return: $e'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }
}
