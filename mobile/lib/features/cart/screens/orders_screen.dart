import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

final ordersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final body = (await ref.read(dioProvider).get('/marketplace/orders')).data
      as Map<String, dynamic>;
  return (body['data'] as List? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);
    final money =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Scaffold(
        appBar: AppBar(title: const Text('My orders')),
        body: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (items) => items.isEmpty
              ? const Center(child: Text('No orders yet'))
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(ordersProvider),
                  child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, index) {
                        final order = items[index];
                        final orderItems = order['items'] as List? ?? [];
                        return Card(
                            child: ListTile(
                                title: Text(
                                    'Order ${order['id'].toString().substring(0, 8)}'),
                                subtitle: Text(
                                    '${orderItems.length} item(s) · ${order['payment_status']}'),
                                trailing: Text(money.format(double.tryParse(
                                        order['total'].toString()) ??
                                    0))));
                      })),
        ));
  }
}
