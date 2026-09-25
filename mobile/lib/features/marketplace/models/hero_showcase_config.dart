import 'package:flutter/material.dart';

/// Configuration model for Left 50% Product Showcase Carousel
@immutable
class HeroProductSlide {
  const HeroProductSlide({
    required this.id,
    required this.category,
    required this.badge,
    required this.name,
    required this.packSize,
    required this.price,
    this.originalPrice,
    required this.description,
    this.shortBenefit,
    required this.imagePath,
    required this.targetRoute,
    this.accentColor,
  });

  /// Unique product identifier matching the store catalogue
  final String id;

  /// Display category, e.g. "A2 Desi Cow Ghee", "Granular Buffalo Ghee", "Fresh Malai Paneer"
  final String category;

  /// Top badge text, e.g. "100% PURE BILONA", "FARM TO TABLE · 18G PROTEIN"
  final String badge;

  /// Product display name
  final String name;

  /// Product pack size, e.g. "500 ml Glass Jar", "200 g Vacuum Pack"
  final String packSize;

  /// Current selling price in INR
  final double price;

  /// Original/MRP price for discount calculation
  final double? originalPrice;

  /// Detailed storytelling description
  final String description;

  /// Concise 1-line benefit for compact hero layouts
  final String? shortBenefit;

  /// Asset path or network URL
  final String imagePath;

  /// Route to navigate on tap
  final String targetRoute;

  /// Optional background tint
  final Color? accentColor;

  /// Calculate savings percentage if original price is provided
  int? get discountPercent {
    if (originalPrice == null || originalPrice! <= price) return null;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }
}

/// Configuration model for Right 50% Farm Story Showcase Carousel
@immutable
class HeroFarmStory {
  const HeroFarmStory({
    required this.id,
    required this.title,
    required this.caption,
    required this.storyBadge,
    required this.posterPath,
    this.videoUrl,
    required this.detailStory,
    this.location = 'Milterra Partner Farms · Anand & Nashik',
    this.durationSeconds = 8,
  });

  /// Unique story identifier
  final String id;

  /// Story headline
  final String title;

  /// One-line summary caption
  final String caption;

  /// Story category tag, e.g. "HERITAGE BILONA", "ZERO HUMAN TOUCH", "FARM KITCHEN"
  final String storyBadge;

  /// Poster image path (local asset or remote URL). Displays if video cannot load or while loading
  final String posterPath;

  /// Optional video URL (mp4 / webm) for short 10-15s muted story clip
  final String? videoUrl;

  /// Extended narrative shown in "Explore the story" modal
  final String detailStory;

  /// Geographic origin of the farm story
  final String location;

  /// Auto-slide duration in seconds (defaults to 8s)
  final int durationSeconds;
}

// ============================================================================
// EASY-TO-EDIT CONFIGURATION ARRAYS
// You can add, remove, or modify daily images, videos, titles, and captions here
// without changing any component or widget code.
// ============================================================================

// Product slides are constructed from productsProvider; no second price/name catalogue.

/// Configurable farm story showcase slides (Right 50%)
const List<HeroFarmStory> defaultHeroFarmStories = [
  HeroFarmStory(
    id: 'story-brand-origin',
    title: 'The MILTERRA Story · Indigenous Sahiwal Heritage',
    caption:
        'Rooted in Vedic tradition: ethically raised Sahiwal & Gir cows grazing freely.',
    storyBadge: 'OUR ORIGIN',
    posterPath: 'assets/store/farm-pasture.jpg',
    videoUrl: null,
    detailStory:
        'MILTERRA was born from a singular mission: reviving authentic, ethical Indian dairy heritage. We partner with pastoralists raising indigenous Bos indicus cows (Sahiwal and Gir). Our cattle are raised with reverence, enjoying open sunlight, green fodder, and cruelty-free care where the calf is always fed first.',
    location: 'Milterra Heritage Project',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-bilona',
    title: 'Traditional Wooden Bilona Churning',
    caption:
        'Whole cultured curd churned bidirectionally with wooden valona.',
    storyBadge: 'THE BILONA METHOD',
    posterPath: 'assets/store/farm-bilona.jpg',
    videoUrl: null,
    detailStory:
        'Unlike modern industrial ghee made by centrifuging raw milk cream, authentic Vedic Bilona Ghee starts from whole curd. The cultured curd is churned slowly with a wooden bilona to yield aromatic makkhan, which is clarified over low firewood flame into golden granular ghee.',
    location: 'Traditional Bilona Kitchen',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-our-process',
    title: 'Our Learning & Traditional Making Process',
    caption:
        'Educational study: Hand-milking, Ahinsa calf-first care & earthen pot setting.',
    storyBadge: 'LEARNING & PROCESS',
    posterPath: 'assets/store/farm-bilona.jpg',
    videoUrl: null,
    detailStory:
        'Educational Article: Modern mechanical milking parlours maximize yield, but traditional Ayurvedic ahinsa dairy prioritizes animal well-being and natural maternal bonds. In our documented process, cows are hand-milked gently only after the calf has drunk its fill. Whole milk is rested in clay pots and naturally cultured, preserving native microflora and vital micronutrients.',
    location: 'Milterra Research & Field Studies',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-paneer',
    title: 'Farm Kitchen Artisan Paneer Making',
    caption:
        'Fresh whole milk gently curdled with organic lemon juice & pure whey.',
    storyBadge: 'FARM KITCHEN',
    posterPath: 'assets/store/farm-pasture.jpg',
    videoUrl: null,
    detailStory:
        'Crafted in small batches with zero artificial binders, emulsifiers, or preservatives. Our artisan paneer retains its natural moisture, velvety softness, and rich protein profile directly from pure milk.',
    location: 'Milterra Farm Kitchen',
    durationSeconds: 7,
  ),
  HeroFarmStory(
    id: 'story-purity',
    title: 'Quality & Research · Lab Verification',
    caption:
        'Independent testing for fatty acid profile, purity & zero adulterants.',
    storyBadge: 'QUALITY & RESEARCH',
    posterPath: 'assets/store/farm-pasture.jpg',
    videoUrl: null,
    detailStory:
        'Every batch is tracked and sent for rigorous analytical testing: NMR verification for honey, purity testing for ghee, cold-press temperature certification for oils, and stone-mill temperature control for flours. We believe transparency is the highest form of respect.',
    location: 'Quality & Research Lab',
    durationSeconds: 7,
  ),
];
