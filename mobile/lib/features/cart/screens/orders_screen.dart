import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/order_repository.dart';
import '../../marketplace/widgets/store_design.dart';

final ordersProvider = Provider.autoDispose<List<StoreOrder>>((ref) {
  return ref.watch(ordersNotifierProvider);
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
                                      onTap: () => context.go('/shop'),
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
                                          border: Border.all(color: storeBorder),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.search,
                                                size: 18, color: storeMuted),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Search all orders',
                                                style: TextStyle(
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
                                      return _buildOrderCard(
                                          context, orders[index], isMobile);
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

  Widget _buildOrderCard(
      BuildContext context, StoreOrder order, bool isMobile) {
    final id = order.id;
    final total = order.total;
    final status = order.status;
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
                    _orderHeaderItem('ORDER PLACED', createdAt),
                    _orderHeaderItem('TOTAL', storeMoney(total)),
                    _orderHeaderItem('SHIP TO', order.address['recipient_name']?.toString() ?? 'Direct Delivery'),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('/marketplace/orders/$id'),
                  child: Row(
                    children: [
                      Text(
                        'ORDER # $id',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff007185),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xff007185)),
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
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xff067d62), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Status: $status',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xff067d62),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xffe8f5e9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xffa5d6a7)),
                      ),
                      child: Text(
                        order.carrier,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff1b5e20)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final item in items) ...[
                  InkWell(
                    onTap: () {
                      final targetId = _resolveProductId(item);
                      context.push('/shop/product/$targetId');
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
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
                          const Icon(Icons.chevron_right, size: 18, color: storeMuted),
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
                          style: TextStyle(fontSize: 12, color: storeGreen, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () => context.go('/marketplace/orders/$id'),
                      child: const Text('View order details',
                          style: TextStyle(fontSize: 12, color: Color(0xff007185))),
                    ),
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
    if (title.contains('makhan') || title.contains('butter')) return 'mil-butter-250';
    if (title.contains('paneer')) return 'mil-paneer-500';
    if (title.contains('janam')) return 'feed-janam-42';
    if (title.contains('minera') || title.contains('mineral')) return 'milterra-min-supp-1';
    return 'mil-ghee-500';
  }
}

