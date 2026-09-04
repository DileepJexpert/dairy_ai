import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import '../providers/product_provider.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int quantity = 1;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: ref.watch(productDetailProvider(widget.productId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (p) {
            if (quantity < p.minOrderQuantity) quantity = p.minOrderQuantity;
            return ListView(padding: const EdgeInsets.all(16), children: [
              SizedBox(
                  height: 220,
                  child: p.media.isEmpty
                      ? const Icon(Icons.inventory_2, size: 80)
                      : Image.network(p.media.first, fit: BoxFit.cover)),
              Text(p.title, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                  '${NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(p.price)} / ${p.unit}'),
              Text(p.inStock
                  ? 'In stock (${p.availableQuantity})'
                  : 'Out of stock'),
              if (p.packSize != null) Text('Pack: ${p.packSize}'),
              if (p.description != null) Text(p.description!),
              const Divider(),
              ...p.specifications.entries
                  .map((e) => Text('${e.key}: ${e.value}')),
              const Divider(),
              Text('Seller: ${p.vendor?['business_name'] ?? ''}'),
              Row(children: [
                const Text('Quantity'),
                IconButton(
                    onPressed: quantity > p.minOrderQuantity
                        ? () => setState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove)),
                Text('$quantity'),
                IconButton(
                    onPressed: quantity < p.availableQuantity
                        ? () => setState(() => quantity++)
                        : null,
                    icon: const Icon(Icons.add))
              ]),
              ElevatedButton.icon(
                  onPressed: !p.inStock
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(cartProvider.notifier)
                                .add(p.id, quantity);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Added to cart')));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(e is DioException
                                          ? dioErrorMessage(e)
                                          : 'Could not add to cart')));
                            }
                          }
                        },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to Cart'))
            ]);
          }));
}
