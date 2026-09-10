import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});
  String money(double value) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
          .format(value);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart'), actions: [
        if ((cart.valueOrNull?.items.isNotEmpty ?? false))
          IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              tooltip: 'Clear cart')
      ]),
      body: cart.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) => data.items.isEmpty
            ? const Center(child: Text('Your cart is empty'))
            : Column(children: [
                Expanded(
                    child: ListView.builder(
                        itemCount: data.items.length,
                        itemBuilder: (_, i) =>
                            _item(context, ref, data.items[i]))),
                _summary(context, data.subtotal)
              ]),
      ),
    );
  }

  Widget _item(BuildContext context, WidgetRef ref, CartItem item) => Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 68,
                height: 68,
                child: item.primaryImage == null
                    ? const Icon(Icons.inventory_2, size: 40)
                    : Image.network(item.primaryImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.inventory_2))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.title,
                      style: Theme.of(context).textTheme.titleSmall),
                  if (item.vendorName != null) Text(item.vendorName!),
                  Text('${money(item.currentPrice)} / ${item.unit ?? 'unit'}'),
                  if (item.priceChanged)
                    Text('Price changed from ${money(item.priceWhenAdded)}',
                        style: const TextStyle(color: Colors.orange)),
                  if (!item.inStock)
                    Text(
                        item.availableQuantity == 0
                            ? 'Out of stock'
                            : 'Only ${item.availableQuantity} available',
                        style: const TextStyle(color: Colors.red)),
                  Row(children: [
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: item.quantity > 1
                            ? () => ref
                                .read(cartProvider.notifier)
                                .update(item.id, item.quantity - 1)
                            : null),
                    Text('${item.quantity}'),
                    IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: item.quantity < item.availableQuantity
                            ? () => ref
                                .read(cartProvider.notifier)
                                .update(item.id, item.quantity + 1)
                            : null),
                    const Spacer(),
                    Text(money(item.lineTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            ref.read(cartProvider.notifier).remove(item.id)),
                  ]),
                ])),
          ]),
        ),
      );

  Widget _summary(BuildContext context, double subtotal) => SafeArea(
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black12))),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Subtotal', style: TextStyle(fontSize: 18)),
              Text(money(subtotal),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))
            ]),
            const SizedBox(height: 10),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => context.push('/marketplace/checkout'),
                    child: const Text('Checkout')))
          ])));
}
