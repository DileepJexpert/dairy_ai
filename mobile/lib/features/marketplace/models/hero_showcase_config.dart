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

/// Configurable product showcase slides (Left 50%)
const List<HeroProductSlide> defaultHeroProductSlides = [
  HeroProductSlide(
    id: 'mil-ghee-500',
    category: 'A2 Desi Cow Ghee',
    badge: '100% PURE BILONA · LAB TESTED',
    name: 'Milterra A2 Vedic Gir Cow Ghee',
    packSize: '500 ml Glass Jar',
    price: 799,
    originalPrice: 950,
    shortBenefit: 'Slow-cooked Vedic bilona from A2 Gir cow milk',
    description:
        'Cultured whole A2 curd churned with traditional wooden bilona. Golden granular aroma rich in fat-soluble vitamins.',
    imagePath: 'assets/store/cow-ghee.png',
    targetRoute: '/shop/product/mil-ghee-500',
  ),
  HeroProductSlide(
    id: 'mil-buff-500',
    category: 'Granular Buffalo Ghee',
    badge: 'DANEDAAR · AUTHENTIC FLAVOUR',
    name: 'Milterra Rich Murrah Buffalo Ghee',
    packSize: '500 ml Eco-Pack',
    price: 699,
    originalPrice: 820,
    shortBenefit: 'Slow-cooked from farm-fresh buffalo milk',
    description:
        'Full-bodied aroma with distinct grainy crystals. Perfect for festive sweets, sizzling dal tadka, and crispy parathas.',
    imagePath: 'assets/store/buffalo-ghee.png',
    targetRoute: '/shop/product/mil-buff-500',
  ),
  HeroProductSlide(
    id: 'mil-paneer-200',
    category: 'Fresh Malai Paneer',
    badge: 'FARM FRESH · 18G NATURAL PROTEIN',
    name: 'Milterra Artisan Malai Paneer',
    packSize: '200 g Vacuum Sealed',
    price: 160,
    originalPrice: 190,
    shortBenefit: 'Freshly cultured malai paneer with 18g protein',
    description:
        'Melt-in-the-mouth freshness made with unadulterated whole farm milk. Zero artificial starches or chemical coagulants.',
    imagePath: 'assets/store/paneer.png',
    targetRoute: '/shop/product/mil-paneer-200',
  ),
  HeroProductSlide(
    id: 'mil-milk-1000',
    category: 'Pure Farm Milk',
    badge: 'CHILLED IN 45 MINS · A2 BETA-CASEIN',
    name: 'Milterra Pure Farm Fresh A2 Milk',
    packSize: '1 Litre Glass Bottle',
    price: 75,
    originalPrice: 90,
    shortBenefit: 'Untouched by hand • Chilled to 4°C within 45 mins',
    description:
        'Non-homogenized natural farm milk from pasture-grazed desi cows. Untouched by hand and chilled immediately at 4°C.',
    imagePath: 'assets/store/hero.png',
    targetRoute: '/shop?category=Cow+ghee',
  ),
];

/// Configurable farm story showcase slides (Right 50%)
const List<HeroFarmStory> defaultHeroFarmStories = [
  HeroFarmStory(
    id: 'story-grazing',
    title: 'Sunlit Grazing & Holistic Herd Care',
    caption: 'Free-roaming indigenous Gir cows on organic pesticide-free pastures.',
    storyBadge: 'CATTLE WELLNESS',
    posterPath: 'assets/store/farm-pasture.jpg',
    videoUrl: null,
    detailStory:
        'Our indigenous Gir and Sahiwal cows graze freely on mineral-rich organic Napier grass, Moringa leaves, and seasonal legumes. Clean borewell water, Ayurvedic herbal licks, and affectionate animal caretakers ensure a happy, stress-free herd.',
    location: 'Milterra Organic Pastures · Anand',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-bilona',
    title: 'Traditional Wooden Bilona Churning',
    caption: 'Slow-simmered cultured makhan over gentle firewood embers.',
    storyBadge: 'HERITAGE CRAFT',
    posterPath: 'assets/store/farm-bilona.jpg',
    videoUrl: null,
    detailStory:
        'Every jar of Milterra ghee begins with whole A2 milk naturally fermented into curd. Two-way wooden bilona churning separates pure golden butter, which is gently clarified over slow firewood to develop signature golden crystals without destroying heat-sensitive nutrients.',
    location: 'Milterra Heritage Ghee Unit · Gir Somnath',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-milking',
    title: 'Automated Touch-Free Milking Parlour',
    caption: 'Pneumatic extraction and inline chillers ensure clinical purity.',
    storyBadge: 'ETHICAL MILKING',
    posterPath: 'assets/store/farm-milking.jpg',
    videoUrl: null,
    detailStory:
        'Our cows enter automated milking stalls at their own pace. Soft food-grade silicone cups mimic natural calf suckling, and fresh milk flows directly through closed stainless steel pipes into flash chillers at 4°C within 45 seconds, eliminating ambient exposure completely.',
    location: 'Milterra Model Dairy Farm · Nashik Valley',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-paneer',
    title: 'Farm Kitchen Artisan Paneer Making',
    caption: 'Natural lemon coagulation and hand-pressed muslin curds.',
    storyBadge: 'FARM FRESH KITCHEN',
    posterPath: 'assets/store/farm-pasture.jpg',
    videoUrl: null,
    detailStory:
        'Within four hours of morning milking, rich whole milk is brought to gentle boil and naturally curdled using citrus curdling agents. Curds are immediately hand-transferred into muslin presses to retain exceptional moisture, pillow-soft texture, and 18g intact protein.',
    location: 'Milterra Artisan Dairy · Pune Rural',
    durationSeconds: 7,
  ),
  HeroFarmStory(
    id: 'story-purity',
    title: 'Digital Ultrasonic Milk Purity Screening',
    caption: 'Batch-by-batch Gerber & ultrasonic testing for zero adulteration.',
    storyBadge: 'LAB CERTIFIED PURITY',
    posterPath: 'assets/store/farm-milking.jpg',
    videoUrl: null,
    detailStory:
        'Every morning lot undergoes stringent 14-point purity verification: automated ultrasonic analyzers record exact Fat % and SNF, while strip and chemical assays confirm zero starch, urea, synthetic oils, or detergent residues.',
    location: 'Milterra Central Quality Lab · Anand Hub',
    durationSeconds: 7,
  ),
];
