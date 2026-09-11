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
    try {
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
      }).timeout(const Duration(seconds: 2));
      final body = response.data;
      if (body is! Map) break;
      final rawData = body['data'];
      if (rawData is! List) break;
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
    } catch (_) {
      break;
    }
  }
  // Merge rich multi-department catalogue items if not yet seeded in backend
  final existingTitles = items.map((p) => p.title.toLowerCase()).toSet();
  for (final def in defaultMilterraProducts) {
    if (!existingTitles.contains(def.title.toLowerCase())) {
      if (category == null || def.category == category) {
        items.add(def);
      }
    }
  }

  return items;
});

final productDetailProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  // 1. Instant local lookup for default Milterra catalogue items (0ms latency)
  for (final p in defaultMilterraProducts) {
    if (p.id == id) return p;
  }

  // 2. Check cached in-memory product catalogue
  final inMemoryProducts = ref.read(productsProvider(null)).valueOrNull;
  if (inMemoryProducts != null) {
    for (final p in inMemoryProducts) {
      if (p.id == id) return p;
    }
  }

  // 3. Fast backend query for dynamic/newly-created vendor products
  try {
    final response = await ref
        .read(dioProvider)
        .get('/marketplace/products/$id')
        .timeout(const Duration(milliseconds: 1500));
    final body = response.data;
    if (body is Map && body['data'] is Map) {
      return Product.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    }
  } catch (_) {}

  // 4. Fallback search by title or partial ID in defaults
  for (final p in defaultMilterraProducts) {
    if (p.id == id || p.title.toLowerCase().contains(id.toLowerCase())) {
      return p;
    }
  }

  throw Exception('Failed to load product details');
});
