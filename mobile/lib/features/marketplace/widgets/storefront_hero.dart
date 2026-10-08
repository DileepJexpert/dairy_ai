import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hero_showcase_config.dart';
import '../models/home_hero_config.dart';
import '../providers/product_provider.dart';
import 'hero_split_showcase.dart';
import 'store_design.dart';

/// The landing page owns this slot; its presentation can be replaced without
/// changing the product catalogue, hero merchandising or the rest of the page.
class StorefrontHero extends ConsumerWidget {
  const StorefrontHero({
    super.key,
    required this.screenWidth,
    this.onExploreCategory,
    this.showcaseKey,
  });

  final double screenWidth;
  final ValueChanged<String>? onExploreCategory;
  final GlobalKey<HeroSplitShowcaseState>? showcaseKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(homeHeroConfigProvider).valueOrNull;
    final products = ref.watch(productsProvider(null)).valueOrNull;
    final byId = {
      for (final product in products ?? [])
        if (product.isActive) product.id: product,
    };
    final slides = <HeroProductSlide>[];
    for (final choice in config?.productSlides ?? <HomeHeroProduct>[]) {
      final product = byId[choice.productId];
      if (product == null) continue;
      final image = choice.heroImage.isNotEmpty
          ? choice.heroImage
          : ((product.media.isNotEmpty ? product.media.first : null) ??
              StoreImages.hero);
      slides.add(HeroProductSlide(
        id: product.id,
        category: storeCategory(product),
        badge: product.badge ?? '',
        name: product.title,
        packSize: product.packSize ?? product.unit,
        price: product.price,
        description: product.description ?? '',
        imagePath: image,
        hoverImagePath: choice.hoverImage,
        hoverBadge: choice.hoverBadge,
        imageNote: choice.imageNote,
        targetRoute: '/shop/product/${product.id}',
      ));
    }

    return HeroSplitShowcase(
      key: showcaseKey,
      screenWidth: screenWidth,
      onExploreCategory: onExploreCategory,
      productSlides: slides,
    );
  }
}
