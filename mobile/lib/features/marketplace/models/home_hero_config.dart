import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Merchandising choices only. Product names, prices and routes come from the
/// published catalogue, so changing a hero image cannot change a sellable SKU.
class HomeHeroProduct {
  const HomeHeroProduct({
    required this.productId,
    required this.heroImage,
    this.imageNote,
  });

  final String productId;
  final String heroImage;
  final String? imageNote;
}

class HomeHeroConfig {
  const HomeHeroConfig(this.productSlides);

  static const assetPath = 'assets/catalogue/home_hero.json';
  final List<HomeHeroProduct> productSlides;

  factory HomeHeroConfig.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map ||
        decoded['schema_version'] != 1 ||
        decoded['product_slides'] is! List) {
      throw const FormatException('Invalid home hero configuration');
    }
    final seen = <String>{};
    final slides = <HomeHeroProduct>[];
    for (final raw in decoded['product_slides'] as List) {
      if (raw is! Map ||
          raw['product_id'] is! String ||
          raw['hero_image'] is! String) {
        throw const FormatException('Invalid home hero product');
      }
      final id = (raw['product_id'] as String).trim();
      final image = (raw['hero_image'] as String).trim();
      if (id.isEmpty || !seen.add(id) || !image.startsWith('assets/store/')) {
        throw const FormatException('Duplicate product or invalid hero image');
      }
      slides.add(HomeHeroProduct(
        productId: id,
        heroImage: image,
        imageNote: raw['image_note']?.toString(),
      ));
    }
    return HomeHeroConfig(List.unmodifiable(slides));
  }
}

final homeHeroConfigProvider = FutureProvider<HomeHeroConfig>((ref) async {
  final source = await rootBundle.loadString(HomeHeroConfig.assetPath);
  return HomeHeroConfig.parse(source);
});
