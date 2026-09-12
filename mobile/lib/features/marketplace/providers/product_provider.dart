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
    final response = await ref
        .read(dioProvider)
        .get('/marketplace/products', queryParameters: {
      if (category != null)
        'category': category == ProductCategory.equipment
            ? 'EQUIPMENT'
            : 'FEED_NUTRITION',
      'sort_by': 'featured',
      'page': page,
      'per_page': 100,
    });
    final body = response.data;
    if (body is! Map || body['data'] is! List) {
      throw const FormatException('Product response did not contain a list');
    }
    final rawData = body['data'] as List;
    final batch = rawData
        .whereType<Map>()
        .map((x) => Product.fromJson(Map<String, dynamic>.from(x)))
        .toList();
    items.addAll(batch);
    final total = body['total'];
    final totalCount = total is int ? total : items.length;
    if (batch.isEmpty || items.length >= totalCount) {
      break;
    }
    page++;
  }
  return items;
});

final productDetailProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  // Reuse a product only when it came from the backend-backed provider.
  final inMemoryProducts = ref.read(productsProvider(null)).valueOrNull;
  if (inMemoryProducts != null) {
    for (final p in inMemoryProducts) {
      if (p.id == id) return p;
    }
  }

  final response = await ref.read(dioProvider).get('/marketplace/products/$id');
  final body = response.data;
  if (body is Map && body['data'] is Map) {
    return Product.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }
  throw const FormatException('Product response did not contain details');
});
