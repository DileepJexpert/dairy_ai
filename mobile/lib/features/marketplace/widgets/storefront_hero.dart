import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hero_showcase_config.dart';
import '../models/home_hero_config.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../providers/merchandising_provider.dart';
import 'hero_split_showcase.dart';
import 'store_design.dart';

/// The landing page owns this slot; its presentation can be replaced without
/// changing the product catalogue, hero merchandising or the rest of the page.
class StorefrontHero extends ConsumerWidget {
  const StorefrontHero({
    super.key,
    required this.screenWidth,
    this.onExploreCategory,
    this.onAddToCart,
    this.showcaseKey,
  });

  final double screenWidth;
  final ValueChanged<String>? onExploreCategory;
  final ValueChanged<HeroProductSlide>? onAddToCart;
  final GlobalKey<HeroSplitShowcaseState>? showcaseKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(homeHeroConfigProvider).valueOrNull;
    final products = ref.watch(productsProvider(null)).valueOrNull;
    final placements =
        ref.watch(storefrontPlacementsProvider).valueOrNull ?? [];

    final Map<String, Product> byId = {
      for (final Product product in products ?? const <Product>[])
        if (product.isActive) product.id: product,
    };

    StorefrontPlacement? activeHighlight;
    for (final pl in placements) {
      if (pl.isActive &&
          (pl.placementType == 'highlight' ||
              pl.placementType == 'deal' ||
              pl.placementType == 'new_launch')) {
        activeHighlight = pl;
        break;
      }
    }

    final slides = <HeroProductSlide>[];
    for (final choice in config?.productSlides ?? <HomeHeroProduct>[]) {
      final product = byId[choice.productId];
      if (product == null) continue;
      final image = choice.heroImage.isNotEmpty
          ? choice.heroImage
          : ((product.media.isNotEmpty ? product.media.first : null) ??
              StoreImages.hero);

      final isThisHighlight = activeHighlight != null &&
          activeHighlight.productId == product.id;

      slides.add(HeroProductSlide(
        id: product.id,
        category: storeCategory(product),
        badge: isThisHighlight && activeHighlight.badge?.isNotEmpty == true
            ? activeHighlight.badge!
            : (product.badge ?? ''),
        name: product.title,
        packSize: product.packSize ?? product.unit,
        price: product.price,
        originalPrice: product.compareAtPrice ?? (product.price * 1.18),
        description: product.description ?? '',
        imagePath: image,
        hoverImagePath: choice.hoverImage,
        hoverBadge: choice.hoverBadge,
        imageNote: choice.imageNote,
        targetRoute: '/shop/product/${product.id}',
        isHighlightedDeal: isThisHighlight,
        highlightBadge: isThisHighlight
            ? (activeHighlight.badge?.isNotEmpty == true
                ? activeHighlight.badge!
                : (activeHighlight.placementType == 'new_launch'
                    ? '✨ NEW LAUNCH'
                    : (activeHighlight.placementType == 'deal'
                        ? '🔥 DEAL OF THE DAY'
                        : '⚡ TOP SELLER OF THE DAY')))
            : null,
        highlightHeadline: isThisHighlight ? activeHighlight.headline : null,
      ));
    }

    // If an active highlight is from a product not in the default slides, inject it at position 2
    if (activeHighlight != null &&
        !slides.any((s) => s.id == activeHighlight!.productId)) {
      final p = activeHighlight.product;
      final heroImg = (p.media.isNotEmpty ? p.media.first : null) ??
          StoreImages.hero;
      final injectedSlide = HeroProductSlide(
        id: p.id,
        category: storeCategory(p),
        badge: activeHighlight.badge?.isNotEmpty == true
            ? activeHighlight.badge!
            : (p.badge ?? 'TOP SELLER'),
        name: p.title,
        packSize: p.packSize ?? p.unit,
        price: p.price,
        originalPrice: p.compareAtPrice ?? (p.price * 1.20),
        description: p.description ?? '',
        imagePath: heroImg,
        targetRoute: '/shop/product/${p.id}',
        isHighlightedDeal: true,
        highlightBadge: activeHighlight.badge?.isNotEmpty == true
            ? activeHighlight.badge!
            : (activeHighlight.placementType == 'new_launch'
                ? '✨ NEW LAUNCH'
                : '⚡ TOP SELLER OF THE DAY'),
        highlightHeadline: activeHighlight.headline,
      );
      if (slides.length >= 2) {
        slides.insert(2, injectedSlide);
      } else {
        slides.insert(0, injectedSlide);
      }
    } else if (activeHighlight == null && slides.isNotEmpty) {
      // Default fallback: highlight index 2 (or index 0) so there's always a live deal card
      final targetIdx = slides.length > 2 ? 2 : 0;
      final p = slides[targetIdx];
      slides[targetIdx] = HeroProductSlide(
        id: p.id,
        category: p.category,
        badge: 'TOP SELLER',
        name: p.name,
        packSize: p.packSize,
        price: p.price,
        originalPrice: p.originalPrice,
        description: p.description,
        shortBenefit: p.shortBenefit,
        imagePath: p.imagePath,
        hoverImagePath: p.hoverImagePath,
        hoverBadge: p.hoverBadge,
        imageNote: p.imageNote,
        targetRoute: p.targetRoute,
        isHighlightedDeal: true,
        highlightBadge: '⚡ TOP SELLER OF THE DAY',
        highlightHeadline: 'Farm-Fresh Daily Churn',
      );
    }

    return HeroSplitShowcase(
      key: showcaseKey,
      screenWidth: screenWidth,
      onExploreCategory: onExploreCategory,
      onAddToCart: onAddToCart,
      productSlides: slides,
    );
  }
}
