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
    id: 'story-grazing',
    title: 'Sunlit Grazing & Holistic Herd Care',
    caption:
        'Illustrative imagery, not evidence of product testing or farm operations.',
    storyBadge: 'ILLUSTRATIVE STORY',
    posterPath: 'assets/store/farm-pasture.jpg',
    videoUrl: null,
    detailStory:
        'This illustration introduces a dairy-related topic. It is not a verified account of MILTERRA farm operations, product composition, testing, or certification. Product-specific evidence will be published in Quality & Research when available.',
    location: 'Illustrative brand story',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-bilona',
    title: 'Traditional Wooden Bilona Churning',
    caption:
        'Illustrative imagery, not evidence of product testing or farm operations.',
    storyBadge: 'ILLUSTRATIVE STORY',
    posterPath: 'assets/store/farm-bilona.jpg',
    videoUrl: null,
    detailStory:
        'This illustration introduces a dairy-related topic. It is not a verified account of MILTERRA farm operations, product composition, testing, or certification. Product-specific evidence will be published in Quality & Research when available.',
    location: 'Illustrative brand story',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-milking',
    title: 'Automated Touch-Free Milking Parlour',
    caption:
        'Illustrative imagery, not evidence of product testing or farm operations.',
    storyBadge: 'ILLUSTRATIVE STORY',
    posterPath: 'assets/store/farm-milking.jpg',
    videoUrl: null,
    detailStory:
        'This illustration introduces a dairy-related topic. It is not a verified account of MILTERRA farm operations, product composition, testing, or certification. Product-specific evidence will be published in Quality & Research when available.',
    location: 'Illustrative brand story',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-paneer',
    title: 'Farm Kitchen Artisan Paneer Making',
    caption:
        'Illustrative imagery, not evidence of product testing or farm operations.',
    storyBadge: 'ILLUSTRATIVE STORY',
    posterPath: 'assets/store/farm-pasture.jpg',
    videoUrl: null,
    detailStory:
        'This illustration introduces a dairy-related topic. It is not a verified account of MILTERRA farm operations, product composition, testing, or certification. Product-specific evidence will be published in Quality & Research when available.',
    location: 'Illustrative brand story',
    durationSeconds: 7,
  ),
  HeroFarmStory(
    id: 'story-purity',
    title: 'Quality & Research',
    caption:
        'Illustrative imagery, not evidence of product testing or farm operations.',
    storyBadge: 'QUALITY & RESEARCH',
    posterPath: 'assets/store/farm-milking.jpg',
    videoUrl: null,
    detailStory:
        'This illustration introduces a dairy-related topic. It is not a verified account of MILTERRA farm operations, product composition, testing, or certification. Product-specific evidence will be published in Quality & Research when available.',
    location: 'Illustrative brand story',
    durationSeconds: 7,
  ),
];
