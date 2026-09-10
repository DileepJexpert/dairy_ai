import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

final vendorOrderItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final body = (await ref.read(dioProvider).get('/marketplace/orders/vendor'))
      .data as Map<String, dynamic>;
  return (body['data'] as List? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
});

class VendorOrdersScreen extends ConsumerWidget {
  const VendorOrdersScreen({super.key});
  static const _next = {
    'PENDING': 'CONFIRMED',
    'CONFIRMED': 'PACKED',
    'PACKED': 'SHIPPED',
    'SHIPPED': 'DELIVERED'
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(vendorOrderItemsProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Vendor orders')),
        body: queue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('$error')),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No order items to fulfill'))
              : RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(vendorOrderItemsProvider),
                  child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, index) =>
                          _card(context, ref, items[index])),
                ),
        ));
  }

  Widget _card(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final status = item['fulfillment_status'].toString();
    final next = _next[status];
    final address = Map<String, dynamic>.from(item['delivery_address'] as Map);
    return Card(
        margin: const EdgeInsets.all(10),
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'].toString(),
                  style: Theme.of(context).textTheme.titleMedium),
              Text('Quantity: ${item['quantity']}  •  $status'),
              const SizedBox(height: 8),
              Text(
                  'Deliver to: ${address['recipient_name']}\n${address['address_line1']}, ${address['village_or_city']}\n${address['phone']}'),
              if (next != null)
                Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                        onPressed: () async {
                          await ref.read(dioProvider).put(
                              '/marketplace/orders/vendor/items/${item['item_id']}/fulfillment',
                              queryParameters: {'fulfillment_status': next});
                          ref.invalidate(vendorOrderItemsProvider);
                        },
                        child: Text('Mark $next'))),
            ])));
  }
}
