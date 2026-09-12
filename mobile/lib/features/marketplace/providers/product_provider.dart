import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/product_models.dart';
import '../models/concept_catalogue.dart';

// The first Milterra hero was created before products received database UUIDs.
// Keep those shared links working by resolving their stable SKU server-side;
// the returned product still supplies the real UUID for cart and checkout.
const _legacyStorefrontSkuAliases = <String, String>{
  'mil-ghee-500': 'MIL-GHEE-500',
  'mil-ghee-1000': 'MIL-GHEE-1000',
  'mil-buff-500': 'MIL-BUFF-500',
  'mil-paneer-200': 'MIL-PANEER-200',
};

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
  return [
    ...items,
    ...conceptCatalogue.where((preview) =>
        (category == null || preview.category == category) &&
        !items
            .any((p) => p.id == preview.id || p.familyKey == preview.familyKey))
  ];
});

final productDetailProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  for (final preview in conceptCatalogue) {
    if (preview.id == id) return preview;
  }
  // Reuse a product only when it came from the backend-backed provider.
  final inMemoryProducts = ref.read(productsProvider(null)).valueOrNull;
  if (inMemoryProducts != null) {
    for (final p in inMemoryProducts) {
      if (p.id == id) return p;
    }
  }

  final legacySku = _legacyStorefrontSkuAliases[id];
  if (legacySku != null) {
    final response = await ref.read(dioProvider).get(
      '/marketplace/products',
      queryParameters: {'sku': legacySku, 'page': 1, 'per_page': 1},
    );
    final body = response.data;
    if (body is Map &&
        body['data'] is List &&
        (body['data'] as List).isNotEmpty) {
      final product = (body['data'] as List).first;
      if (product is Map) {
        return Product.fromJson(Map<String, dynamic>.from(product));
      }
    }
    throw StateError('The live product for $legacySku was not found');
  }

  final response = await ref.read(dioProvider).get('/marketplace/products/$id');
  final body = response.data;
  if (body is Map && body['data'] is Map) {
    return Product.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }
  throw const FormatException('Product response did not contain details');
});
