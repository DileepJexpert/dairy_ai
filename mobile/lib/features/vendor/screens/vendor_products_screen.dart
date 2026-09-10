import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';

final vendorProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final body = (await ref.read(dioProvider).get('/vendor/products')).data
      as Map<String, dynamic>;
  return (body['data'] as List? ?? [])
      .map((x) => Product.fromJson(Map<String, dynamic>.from(x as Map)))
      .toList();
});

class VendorProductsScreen extends ConsumerWidget {
  const VendorProductsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('My products')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _add(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add product')),
        body: ref.watch(vendorProductsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('Add your first product to start selling.'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final p = items[i];
                      return Card(
                          child: ListTile(
                              leading: p.media.isEmpty
                                  ? const Icon(Icons.inventory_2)
                                  : Image.network(p.media.first,
                                      width: 48, fit: BoxFit.cover),
                              title: Text(p.title),
                              subtitle: Text(
                                  '₹${p.price} · Stock ${p.availableQuantity}'),
                              trailing:
                                  Switch(value: p.inStock, onChanged: null)));
                    })),
      );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController(),
        price = TextEditingController(),
        stock = TextEditingController(text: '1'),
        image = TextEditingController(),
        unit = TextEditingController(text: 'unit');
    ProductCategory category = ProductCategory.feedNutrition;
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.viewInsetsOf(sheet).bottom + 16),
            child: StatefulBuilder(
                builder: (_, setState) => SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('New product',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      DropdownButtonFormField(
                          value: category,
                          items: ProductCategory.values
                              .map((x) => DropdownMenuItem(
                                  value: x,
                                  child: Text(x == ProductCategory.equipment
                                      ? 'Equipment'
                                      : 'Feed & nutrition')))
                              .toList(),
                          onChanged: (x) => setState(() => category = x!)),
                      for (final field in [
                        (title, 'Product name'),
                        (price, 'Sale price'),
                        (stock, 'Stock quantity'),
                        (unit, 'Unit, e.g. bag'),
                        (image, 'Image URL (optional)')
                      ])
                        TextField(
                            controller: field.$1,
                            decoration: InputDecoration(labelText: field.$2),
                            keyboardType: field.$2.contains('price') ||
                                    field.$2.contains('Stock')
                                ? TextInputType.number
                                : TextInputType.text),
                      FilledButton(
                          onPressed: () async {
                            if (title.text.trim().length < 2 ||
                                double.tryParse(price.text) == null) return;
                            final dio = ref.read(dioProvider);
                            final created =
                                (await dio.post('/vendor/products', data: {
                              'sku':
                                  'APP-${DateTime.now().microsecondsSinceEpoch}',
                              'title': title.text.trim(),
                              'category': category == ProductCategory.equipment
                                  ? 'EQUIPMENT'
                                  : 'FEED_NUTRITION',
                              'base_price': price.text,
                              'unit': unit.text.trim()
                            }))
                                    .data['data'];
                            final id = created['id'];
                            await dio.put('/vendor/products/$id/inventory',
                                data: {
                                  'available_quantity':
                                      int.tryParse(stock.text) ?? 0
                                });
                            if (image.text.trim().isNotEmpty)
                              await dio.post('/vendor/products/$id/media',
                                  data: {
                                    'url': image.text.trim(),
                                    'is_primary': true
                                  });
                            ref.invalidate(vendorProductsProvider);
                            if (sheet.mounted) Navigator.pop(sheet);
                          },
                          child: const Text('Publish product')),
                    ])))));
    for (final c in [title, price, stock, image, unit]) {
      c.dispose();
    }
  }
}
