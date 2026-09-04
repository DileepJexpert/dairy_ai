import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key, required this.category});
  final ProductCategory category;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);
    return Scaffold(
        appBar: AppBar(
            title: Text(category == ProductCategory.equipment
                ? 'Equipment'
                : 'Feed & Nutrition'),
            actions: [
              IconButton(
                  onPressed: () => context.push('/marketplace/cart'),
                  icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text('$count'),
                      child: const Icon(Icons.shopping_cart_outlined)))
            ]),
        body: ref.watch(productsProvider(category)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final product = items[index];
                  return Card(
                      child: ListTile(
                          onTap: () => context
                              .push('/marketplace/product/${product.id}'),
                          leading: product.media.isEmpty
                              ? const Icon(Icons.inventory_2)
                              : Image.network(product.media.first,
                                  width: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.inventory_2)),
                          title: Text(product.title),
                          subtitle: Text(
                              '${product.brand ?? ''} • ${product.inStock ? 'In stock' : 'Out of stock'}\n${product.vendor?['business_name'] ?? ''}'),
                          isThreeLine: true,
                          trailing: Text(NumberFormat.currency(
                                  locale: 'en_IN',
                                  symbol: '₹',
                                  decimalDigits: 0)
                              .format(product.price))));
                })));
  }
}
