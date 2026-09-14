import 'package:flutter/material.dart';
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
      'SHIPPED': 'DELIVERED'
    }[current];
    if (next == null) return;
    final carrier = TextEditingController();
    final tracking = TextEditingController();
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
                        if (next == 'DISPATCHED') ...[
                          TextField(
                              controller: carrier,
                              decoration: const InputDecoration(
                                  labelText: 'Courier name')),
                          TextField(
                              controller: tracking,
                              decoration: const InputDecoration(
                                  labelText: 'Actual tracking reference')),
                        ],
                        TextField(
                            controller: note,
                            maxLength: 800,
                            decoration: const InputDecoration(
                                labelText: 'Notes / proof reference')),
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
                                  await ref.read(dioProvider).put(
                                      '/marketplace/orders/operations/${order['id']}',
                                      data: {
                                        'status': next,
                                        'carrier': carrier.text,
                                        'tracking_number': tracking.text,
                                        'remarks': note.text
                                      });
                                  ref.invalidate(operationsOrdersProvider);
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
                        child:
                            Text(saving ? 'Saving…' : 'Save confirmed action'))
                  ],
                )));
    carrier.dispose();
    tracking.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: storeCream,
        appBar: AppBar(title: Text(title), actions: [
          IconButton(
              onPressed: () => ref.invalidate(operationsOrdersProvider),
              icon: const Icon(Icons.refresh))
        ]),
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: orders.length,
                      itemBuilder: (context, i) {
                        final order = orders[i];
                        return Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Order ${order['id']}',
                                          style: StoreType.heading),
                                      Text(
                                          '${order['created_at']} · ${order['status']}'),
                                      for (final item in order['items'] as List)
                                        Text(
                                            '${item['quantity']} × ${item['title']} · ${item['fulfillment_status']}'),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Total: ${storeMoney(double.parse(order['total'].toString()))}'),
                                      if ([
                                        'PENDING',
                                        'CONFIRMED',
                                        'PACKED',
                                        'SHIPPED'
                                      ].contains(order['status']))
                                        FilledButton(
                                            onPressed: () =>
                                                update(context, ref, order),
                                            child: const Text(
                                                'Update fulfillment')),
                                    ])));
                      }),
            ),
      );
}
