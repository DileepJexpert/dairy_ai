import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Merchandising choices only. Product names, prices and routes come from the
/// published catalogue, so changing a hero image cannot change a sellable SKU.
class HomeHeroProduct {
  const HomeHeroProduct({
    required this.productId,
    required this.heroImage,
    this.hoverImage,
    this.hoverBadge,
    this.imageNote,
  });

  final String productId;
  final String heroImage;
  final String? hoverImage;
  final String? hoverBadge;
  final String? imageNote;
}

const Map<String, String> _defaultHeroImages = {
  'ffd7186f-6cee-4b8e-9a87-6af173aabffd': 'assets/store/ghee-jar-1l.jpg',
  '54b52256-c0d6-436c-b8aa-737b35ab1636': 'assets/store/sarso-oil.jpg',
  'ad431721-27f9-477b-85ce-53def61d7f36': 'assets/store/buffalo-ghee.png',
  'b20f6def-861a-4ba7-b7fa-dab5f4504278': 'assets/store/paneer.png',
  '603800ab-1b07-46c2-b840-6246056de521': 'assets/store/raw-mustard-honey.jpg',
  'bd71ec08-ad44-4938-921d-27316eb56590': 'assets/store/lakadong-turmeric.jpg',
};

const Map<String, String> _defaultHoverImages = {
  'ffd7186f-6cee-4b8e-9a87-6af173aabffd': 'assets/store/farm-pasture-cinematic.jpg',
  '54b52256-c0d6-436c-b8aa-737b35ab1636': 'assets/store/mustard-kolhu-machine.jpg',
  'ad431721-27f9-477b-85ce-53def61d7f36': 'assets/store/farm-bilona-cinematic.jpg',
  'b20f6def-861a-4ba7-b7fa-dab5f4504278': 'assets/store/farm-pasture-cinematic.jpg',
  '603800ab-1b07-46c2-b840-6246056de521': 'assets/store/farm-pasture.jpg',
  'bd71ec08-ad44-4938-921d-27316eb56590': 'assets/store/live-microgreens.jpg',
};

const Map<String, String> _defaultHoverBadges = {
  'ffd7186f-6cee-4b8e-9a87-6af173aabffd': 'Sahiwal Cows & Pasture',
  '54b52256-c0d6-436c-b8aa-737b35ab1636': 'Cold-Press Lakdi Kolhu',
  'ad431721-27f9-477b-85ce-53def61d7f36': 'Vedic Bilona Churning',
  'b20f6def-861a-4ba7-b7fa-dab5f4504278': 'Fresh A2 Sahiwal Milk',
  '603800ab-1b07-46c2-b840-6246056de521': 'Wild Flora Bee Farm',
  'bd71ec08-ad44-4938-921d-27316eb56590': 'Organic Heritage Roots',
};

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
      var image = (raw['hero_image'] as String).trim();
      // Ensure natural rustic photos are prioritized over old CGI renders
      if ((image.contains('cinematic-cow-ghee') ||
              image.contains('cinematic-mustard-oil') ||
              image.contains('cinematic-buffalo-ghee')) &&
          _defaultHeroImages.containsKey(id)) {
        image = _defaultHeroImages[id]!;
      }

      if (id.isEmpty || !seen.add(id) || !image.startsWith('assets/store/')) {
        throw const FormatException('Duplicate product or invalid hero image');
      }
      final hoverImg = raw['hover_image']?.toString().trim();
      final effectiveHover = (hoverImg != null && hoverImg.isNotEmpty)
          ? hoverImg
          : _defaultHoverImages[id];
      final effectiveBadge =
          raw['hover_badge']?.toString() ?? _defaultHoverBadges[id];

      slides.add(HomeHeroProduct(
        productId: id,
        heroImage: image,
        hoverImage: effectiveHover,
        hoverBadge: effectiveBadge,
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
