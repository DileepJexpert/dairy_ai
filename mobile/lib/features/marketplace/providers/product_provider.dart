import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/product_models.dart';

final productsProvider = FutureProvider.family<List<Product>, ProductCategory?>(
    (ref, category) async {
  // Load all pages so category, search and price controls cover the collection,
  // not just the API's default first 20 records. Keep backend order for Featured.
  final items = <Product>[];
  var page = 1;
  while (true) {
    final body = (await ref
            .read(dioProvider)
            .get('/marketplace/products', queryParameters: {
      if (category != null)
        'category': category == ProductCategory.equipment
            ? 'EQUIPMENT'
            : 'FEED_NUTRITION',
      'sort_by': 'featured',
      'page': page,
      'per_page': 100,
    }))
        .data as Map<String, dynamic>;
    final batch =
        (body['data'] as List).map((x) => Product.fromJson(x)).toList();
    items.addAll(batch);
    if (batch.isEmpty ||
        items.length >= (body['total'] as int? ?? items.length)) {
      break;
    }
    page++;
  }
  return items;
});
final productDetailProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  final b = (await ref.read(dioProvider).get('/marketplace/products/$id')).data
      as Map<String, dynamic>;
  return Product.fromJson(b['data']);
});
