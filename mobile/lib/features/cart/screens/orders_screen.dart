import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../providers/order_repository.dart';
import '../../marketplace/widgets/store_design.dart';

final orderSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final ordersProvider = Provider.autoDispose<List<StoreOrder>>((ref) {
  final query = ref.watch(orderSearchProvider).trim().toLowerCase();
  return ref
      .watch(ordersNotifierProvider)
      .where((o) =>
          query.isEmpty ||
          o.id.toLowerCase().contains(query) ||
          o.items.any((i) => i.title.toLowerCase().contains(query)))
      .toList();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Amazon Top Navigation
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Your Orders'),
          if (ref.watch(orderLoadStateProvider).isLoading)
            const LinearProgressIndicator(),
          if (ref.watch(orderLoadStateProvider).hasError)
            ListTile(
                title: const Text('Orders could not be loaded.'),
                trailing: TextButton(
                    onPressed: () =>
                        ref.read(ordersNotifierProvider.notifier).refresh(),
                    child: const Text('Retry'))),

          // Main Orders List
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < StoreLayout.tablet;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: StoreLayout.maxWidth),
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
                                        style: TextStyle(
                                            fontSize: 12, color: storeMuted)),
                                    const Text(
                                      'Your Orders',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Title & Search Row
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Your Orders',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: storeGreen,
                                        ),
                                      ),
                                    ),
                                    if (!isMobile)
                                      Container(
                                        width: 280,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: storeWhite,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border:
                                              Border.all(color: storeBorder),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.search,
                                                size: 18, color: storeMuted),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                onChanged: (value) => ref
                                                    .read(orderSearchProvider
                                                        .notifier)
                                                    .state = value,
                                                decoration:
                                                    const InputDecoration(
                                                        hintText:
                                                            'Search all orders',
                                                        border:
                                                            InputBorder.none),
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: storeMuted),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Orders List or Empty State
                                if (orders.isEmpty)
                                  _buildEmptyOrders(context)
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: orders.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 18),
                                    itemBuilder: (context, index) {
                                      return _buildOrderCard(context, ref,
                                          orders[index], isMobile);
                                    },
                                  ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 64, color: storeMuted),
          const SizedBox(height: 16),
          const Text(
            'You have not placed any orders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore pure A2 dairy products, cattle feed, and farm equipment.',
            style: TextStyle(fontSize: 13, color: storeMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: storeAmber,
              foregroundColor: storeGreen,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () => context.go('/shop'),
            child: const Text('Start Shopping',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openPayment(
      BuildContext context, WidgetRef ref, StoreOrder order) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post('/marketplace/orders/${order.id}/payment-link');
      if (response.data['data']['payment_status'] == 'PAID') {
        ref.read(ordersNotifierProvider.notifier).refresh();
        if (context.mounted) {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Secure payment is unavailable. Please try again later.'),
        ));
      }
    }
  }

  Future<void> _checkPayment(
      BuildContext context, WidgetRef ref, StoreOrder order) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post('/marketplace/orders/${order.id}/payment/verify');
      ref.read(ordersNotifierProvider.notifier).refresh();
      if (context.mounted) {
        final confirmed = response.data['data']?['confirmed'] == true;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: confirmed ? storeGreen : const Color(0xffe65100),
          content: Text(confirmed
              ? 'Payment confirmed.'
              : 'Payment is still pending verification from the provider.'),
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment could not be checked. Please retry.'),
        ));
      }
    }
  }

  Widget _buildStatusHeader(StoreOrder order) {
    if (order.isPrelaunchInterest) {
      if (order.status == 'CANCELLED') {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_remove_outlined,
                    color: Color(0xffc62828), size: 18),
                SizedBox(width: 8),
                Text(
                  'Interest Withdrawn',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xffc62828),
                  ),
                ),
              ],
            ),
            _statusBadge(
              label: 'Pre-launch · Cancelled',
              bgColor: const Color(0xffffebee),
              borderColor: const Color(0xffef9a9a),
              textColor: const Color(0xffc62828),
            ),
          ],
        );
      }
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_added_rounded,
                  color: Color(0xff0277bd), size: 18),
              SizedBox(width: 8),
              Text(
                'Launch Interest Recorded',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff0277bd),
                ),
              ),
            ],
          ),
          _statusBadge(
            label: 'Pre-launch · No payment taken',
            bgColor: const Color(0xffe1f5fe),
            borderColor: const Color(0xff81d4fa),
            textColor: const Color(0xff01579b),
          ),
          _statusBadge(
            label: 'Fulfillment on Launch',
            bgColor: const Color(0xfff1f8e9),
            borderColor: const Color(0xffc5e1a5),
            textColor: const Color(0xff33691e),
          ),
        ],
      );
    }

    if (order.status == 'CANCELLED') {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_outlined, color: Color(0xffd32f2f), size: 18),
              SizedBox(width: 8),
              Text(
                'Order Cancelled',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xffc62828),
                ),
              ),
            ],
          ),
          _statusBadge(
            label: 'Cancelled',
            bgColor: const Color(0xffffebee),
            borderColor: const Color(0xffef9a9a),
            textColor: const Color(0xffc62828),
          ),
        ],
      );
    }

    if (order.cancellationStatus == 'REQUESTED') {
      return _statusBadge(
        label: 'Cancellation requested · Refund review pending',
        bgColor: const Color(0xfffff3e0),
        borderColor: const Color(0xffffcc80),
        textColor: const Color(0xffe65100),
      );
    }

    final isPaymentPending =
        order.paymentStatus == 'PENDING' || order.status == 'PENDING_PAYMENT';

    if (isPaymentPending) {
      final isCod = order.paymentMethod.toLowerCase() == 'cod';
      if (isCod) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_shipping_outlined,
                    color: Color(0xff067d62), size: 18),
                SizedBox(width: 8),
                Text(
                  'Order Confirmed · Cash on Delivery',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff067d62),
                  ),
                ),
              ],
            ),
            _statusBadge(
              label: 'Pay on delivery',
              bgColor: const Color(0xffe8f5e9),
              borderColor: const Color(0xffa5d6a7),
              textColor: const Color(0xff1b5e20),
            ),
            if (order.carrier.isNotEmpty && order.carrier != 'Not assigned')
              _statusBadge(
                label: order.carrier,
                bgColor: const Color(0xfff0f4c3),
                borderColor: const Color(0xffdce775),
                textColor: const Color(0xff827717),
              ),
          ],
        );
      }

      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, color: Color(0xffe65100), size: 18),
              SizedBox(width: 8),
              Text(
                'Payment Pending',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xffe65100),
                ),
              ),
            ],
          ),
          _statusBadge(
            label: 'Awaiting payment',
            bgColor: const Color(0xfffff3e0),
            borderColor: const Color(0xffffcc80),
            textColor: const Color(0xffe65100),
          ),
          _statusBadge(
            label: 'Delivery scheduled after payment',
            bgColor: const Color(0xfff5f5f5),
            borderColor: const Color(0xffe0e0e0),
            textColor: const Color(0xff616161),
          ),
        ],
      );
    }

    String displayStatus;
    switch (order.status.toUpperCase()) {
      case 'CONFIRMED':
        displayStatus = 'Order Confirmed';
        break;
      case 'PACKED':
        displayStatus = 'Order Packed';
        break;
      case 'DISPATCHED':
        displayStatus = 'Dispatched';
        break;
      case 'OUT_FOR_DELIVERY':
        displayStatus = 'Out for Delivery';
        break;
      case 'DELIVERED':
        displayStatus = 'Delivered';
        break;
      default:
        displayStatus = 'Status: ${order.status}';
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xff067d62), size: 18),
            const SizedBox(width: 8),
            Text(
              displayStatus,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xff067d62),
              ),
            ),
          ],
        ),
        if (order.carrier.isNotEmpty && order.carrier != 'Not assigned')
          _statusBadge(
            label: order.carrier,
            bgColor: const Color(0xffe8f5e9),
            borderColor: const Color(0xffa5d6a7),
            textColor: const Color(0xff1b5e20),
          )
        else
          _statusBadge(
            label: 'Processing',
            bgColor: const Color(0xffe8f5e9),
            borderColor: const Color(0xffa5d6a7),
            textColor: const Color(0xff1b5e20),
          ),
      ],
    );
  }

  Widget _statusBadge({
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildOrderCard(
      BuildContext context, WidgetRef ref, StoreOrder order, bool isMobile) {
    final id = order.id;
    final total = order.total;
    final items = order.items;
    final createdAt = order.createdAt;

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amazon Order Card Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xfff0f2f2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(StoreLayout.radius),
                topRight: Radius.circular(StoreLayout.radius),
              ),
              border: Border(bottom: BorderSide(color: storeBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 6,
                  children: [
                    _orderHeaderItem(
                        order.isPrelaunchInterest
                            ? 'INTEREST RECORDED'
                            : 'ORDER PLACED',
                        createdAt),
                    _orderHeaderItem(
                        order.isPrelaunchInterest
                            ? 'INDICATIVE VALUE'
                            : 'TOTAL',
                        storeMoney(total)),
                    _orderHeaderItem(
                        'SHIP TO',
                        order.address['recipient_name']?.toString() ??
                            'Direct Delivery'),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('/marketplace/orders/$id'),
                  child: Row(
                    children: [
                      Text(
                        order.isPrelaunchInterest
                            ? 'RESERVATION # $id'
                            : 'ORDER # $id',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff007185),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 16, color: Color(0xff007185)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(order),
                const SizedBox(height: 14),
                for (final item in items) ...[
                  InkWell(
                    onTap: () {
                      final targetId = _resolveProductId(item);
                      context.push('/shop/product/$targetId');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: storeCream,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: storeBorder),
                            ),
                            child: item.image != null && item.image!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item.image!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.inventory_2_outlined,
                                          color: storeMuted),
                                    ),
                                  )
                                : const Icon(Icons.inventory_2_outlined,
                                    color: storeMuted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff007185),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Qty: ${item.quantity} · ${storeMoney(item.lineTotal)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: storeMuted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 18, color: storeMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                const Divider(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (!order.isPrelaunchInterest &&
                        (order.paymentStatus == 'PENDING' ||
                            order.status == 'PENDING_PAYMENT') &&
                        order.status != 'CANCELLED' &&
                        order.paymentMethod.toLowerCase() != 'cod') ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(130, 34),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17)),
                        ),
                        onPressed: () => _openPayment(context, ref, order),
                        icon: const Icon(Icons.payment, size: 16),
                        label: const Text('Pay securely',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(140, 34),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17)),
                          side: const BorderSide(color: storeBorder),
                        ),
                        onPressed: () => _checkPayment(context, ref, order),
                        icon:
                            const Icon(Icons.sync, size: 16, color: storeGreen),
                        label: const Text('Check payment status',
                            style: TextStyle(
                                fontSize: 12,
                                color: storeGreen,
                                fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/marketplace/orders/$id'),
                        child: const Text('View order details',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xff007185))),
                      ),
                    ] else if (order.isPrelaunchInterest) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          minimumSize: const Size(140, 34),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17)),
                        ),
                        onPressed: () => context.go('/marketplace/orders/$id'),
                        icon: const Icon(Icons.description_outlined,
                            size: 16, color: storeGreen),
                        label: const Text('View Reservation Details',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(120, 34),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17)),
                          side: const BorderSide(color: storeBorder),
                        ),
                        onPressed: () {
                          if (items.isNotEmpty) {
                            final firstId = _resolveProductId(items.first);
                            context.push('/shop/product/$firstId');
                          } else {
                            context.go('/shop');
                          }
                        },
                        child: const Text('Explore Product',
                            style: TextStyle(
                                fontSize: 12,
                                color: storeGreen,
                                fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          minimumSize: const Size(120, 34),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17)),
                        ),
                        onPressed: () {
                          if (items.isNotEmpty) {
                            final firstId = _resolveProductId(items.first);
                            context.push('/shop/product/$firstId');
                          } else {
                            context.go('/shop');
                          }
                        },
                        child: const Text('Buy it again',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      if (order.status != 'CANCELLED')
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(120, 34),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17)),
                            side: const BorderSide(color: storeBorder),
                          ),
                          onPressed: () {
                            context.go('/marketplace/orders/$id');
                          },
                          child: const Text('Track package',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: storeGreen,
                                  fontWeight: FontWeight.bold)),
                        ),
                      TextButton(
                        onPressed: () => context.go('/marketplace/orders/$id'),
                        child: const Text('View order details',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xff007185))),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderHeaderItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xff565959),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xff0f1111),
          ),
        ),
      ],
    );
  }

  String _resolveProductId(StoreOrderItem item) {
    if (item.productId.isNotEmpty) {
      if (item.productId == 'prod-ghee-gir') return 'mil-ghee-1000';
      if (item.productId == 'prod-makhan-white') return 'mil-butter-250';
      if (item.productId == 'prod-paneer-soft') return 'mil-paneer-500';
      return item.productId;
    }
    final title = item.title.toLowerCase();
    if (title.contains('ghee')) return 'mil-ghee-500';
    if (title.contains('makhan') || title.contains('butter')) {
      return 'mil-butter-250';
    }
    if (title.contains('paneer')) return 'mil-paneer-500';
    if (title.contains('janam')) return 'feed-janam-42';
    if (title.contains('minera') || title.contains('mineral')) {
      return 'milterra-min-supp-1';
    }
    return 'mil-ghee-500';
  }
}
