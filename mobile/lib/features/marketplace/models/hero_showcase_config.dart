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
    this.mobileImagePath,
    this.hoverImagePath,
    this.hoverBadge,
    this.imageNote,
    required this.targetRoute,
    this.accentColor,
    this.isHighlightedDeal = false,
    this.highlightBadge,
    this.highlightHeadline,
    this.campaignCouponCode,
    this.campaignCouponText,
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

  /// Optional transparent product image used by the compact mobile layout.
  final String? mobileImagePath;

  /// Optional asset path displayed on mouse hover (e.g. cold-press machine or farm cows)
  final String? hoverImagePath;

  /// Optional label displayed on hover (e.g. "Cold-Press Lakdi Kolhu")
  final String? hoverBadge;

  /// Optional disclosure for illustrative merchandising artwork.
  final String? imageNote;

  /// Route to navigate on tap
  final String targetRoute;

  /// Optional background tint
  final Color? accentColor;

  /// Whether this slide is the highlighted deal of the day / top seller
  final bool isHighlightedDeal;

  /// Top blinking badge text (e.g. "⚡ TOP SELLER OF THE DAY", "🔥 DEAL OF THE DAY")
  final String? highlightBadge;

  /// Optional special headline
  final String? highlightHeadline;

  /// Backend-verified coupon. Null unless the active campaign API returned an
  /// active, non-expired coupon definition.
  final String? campaignCouponCode;
  final String? campaignCouponText;

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
    this.hoverPosterPath,
    this.hoverBadge,
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

  /// Optional second poster image displayed on mouse hover
  final String? hoverPosterPath;

  /// Optional badge displayed on hover
  final String? hoverBadge;

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

/// Default instantaneous hero product slides used on initial frame before
/// asynchronous remote catalogues or placement campaigns complete.
const List<HeroProductSlide> defaultHeroProductSlides = [
  HeroProductSlide(
    id: 'ffd7186f-6cee-4b8e-9a87-6af173aabffd',
    category: 'Cow ghee',
    badge: 'Sahiwal Cows & Pasture',
    name: 'MILTERRA A2 Sahiwal Cow Bilona Ghee (Kitchen Jar)',
    packSize: '1 litre',
    price: 2200.0,
    originalPrice: null,
    description: 'Authentic grass-fed A2 bilona ghee for everyday Ayurvedic wellness, culinary richness, and enhanced digestion.',
    imagePath: 'assets/store/panoramic-cow-ghee-hero.jpg',
    hoverImagePath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverBadge: 'Sahiwal Cows & Pasture',
    imageNote: 'A2 Sahiwal Cow Bilona Ghee 1kg Glass Jar',
    targetRoute: '/shop/product/ffd7186f-6cee-4b8e-9a87-6af173aabffd',
  ),
  HeroProductSlide(
    id: '54b52256-c0d6-436c-b8aa-737b35ab1636',
    category: 'Cold-Pressed Cooking Oils',
    badge: 'Cold-Press Lakdi Kolhu',
    name: 'Kacchi Ghani Black Mustard Oil (Lakdi Ghani)',
    packSize: '1 Litre Glass Bottle',
    price: 220.0,
    originalPrice: 250.0,
    description: 'Traditional lakdi ghani extraction; intense natural pungency (jhanjh); zero solvent extraction, chemical refining, or synthetic argemone.',
    imagePath: 'assets/store/panoramic-mustard-oil-hero.jpg',
    hoverImagePath: 'assets/store/lakdi-kolhu-craft-hd.jpg',
    hoverBadge: 'Cold-Press Lakdi Kolhu',
    imageNote: 'Wood-Pressed Mustard Oil 1 Litre Glass Bottle',
    targetRoute: '/shop/product/54b52256-c0d6-436c-b8aa-737b35ab1636',
  ),
  HeroProductSlide(
    id: 'ad431721-27f9-477b-85ce-53def61d7f36',
    category: 'Buffalo ghee',
    badge: 'Vedic Bilona Churning',
    name: 'Milterra Traditional Cultured Buffalo Ghee',
    packSize: '1 litre',
    price: 1299.0,
    originalPrice: null,
    description: 'Artisanal Murrah buffalo cultured ghee for sweets and rotis.',
    imagePath: 'assets/store/panoramic-buffalo-ghee-hero.jpg',
    hoverImagePath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverBadge: 'Vedic Bilona Churning',
    imageNote: 'Cultured Buffalo Ghee 1kg Glass Jar',
    targetRoute: '/shop/product/ad431721-27f9-477b-85ce-53def61d7f36',
  ),
  HeroProductSlide(
    id: 'b20f6def-861a-4ba7-b7fa-dab5f4504278',
    category: 'Paneer',
    badge: 'Fresh A2 Sahiwal Milk',
    name: 'Milterra Fresh Sahiwal Milk Paneer',
    packSize: '200 g',
    price: 160.0,
    originalPrice: null,
    description: 'Planned fresh paneer made from Sahiwal cow milk and packed under refrigeration.',
    imagePath: 'assets/store/panoramic-paneer-hero.jpg',
    hoverImagePath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverBadge: 'Fresh A2 Sahiwal Milk',
    imageNote: 'Fresh Sahiwal Milk Malai Paneer 500g Stand-up Pouch',
    targetRoute: '/shop/product/b20f6def-861a-4ba7-b7fa-dab5f4504278',
  ),
  HeroProductSlide(
    id: '9ab837fd-142d-4799-85ef-02a58e93bb8c',
    category: 'Fresh Milk',
    badge: 'Farm Fresh A2 Milk',
    name: 'MILTERRA Pure A2 Sahiwal Cow Milk (1 Litre Glass Bottle)',
    packSize: '1 Litre',
    price: 85.0,
    originalPrice: 95.0,
    description: 'Farm-fresh, raw chilled A2 Sahiwal & Gir cow milk delivered in our signature 1 Litre heavy glass bottle with protective silicone grip sleeve. 100% pure, unadulterated, rich in natural A2 beta-casein protein, freshly milked every morning.',
    imagePath: 'assets/store/panoramic-milk-bottle-hero.jpg',
    hoverImagePath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverBadge: 'Farm Fresh A2 Milk',
    imageNote: 'MILTERRA Pure A2 Sahiwal Cow Milk 1 Litre Reusable Glass Bottle',
    targetRoute: '/shop/product/9ab837fd-142d-4799-85ef-02a58e93bb8c',
  ),
  HeroProductSlide(
    id: '0e12db10-a3a8-40c2-a004-6ccdcb9d710b',
    category: 'Cow ghee',
    badge: 'Traditional Valona Bilona',
    name: 'Milterra A2 Sahiwal Cow Ghee (Heritage Tin)',
    packSize: '2 litre',
    price: 2999.0,
    originalPrice: 3498.0,
    description: 'Planned family pack of A2 Sahiwal cow cultured-butter ghee in a food-grade heritage tin.',
    imagePath: 'assets/store/panoramic-ghee-tin-hero-v2.png',
    hoverImagePath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverBadge: 'Traditional Valona Bilona',
    imageNote: '2 Litre Heritage A2 Bilona Ghee Tin',
    targetRoute: '/shop/product/0e12db10-a3a8-40c2-a004-6ccdcb9d710b',
  ),
  HeroProductSlide(
    id: 'e7c41a29-8f3b-410a-b28e-5b12da612002',
    category: 'Cold-Pressed Cooking Oils',
    badge: 'Cold-Press Lakdi Kolhu',
    name: 'Kacchi Ghani Black Mustard Oil (Rectangular Tin)',
    packSize: '2 Litre Rectangular Tin',
    price: 430.0,
    originalPrice: 490.0,
    description: 'Authentic wood-pressed black mustard oil in an artisanal rectangular metal tin with carry handle and pour spout. Protects cold-pressed oil from UV rays and plastic leaching.',
    imagePath: 'assets/store/panoramic-mustard-tin-hero-v2.png',
    hoverImagePath: 'assets/store/lakdi-kolhu-craft-hd.jpg',
    hoverBadge: 'Cold-Press Lakdi Kolhu',
    imageNote: '2 Litre Rectangular Mustard Oil Tin',
    targetRoute: '/shop/product/e7c41a29-8f3b-410a-b28e-5b12da612002',
  ),
];


/// Configurable farm story showcase slides (Right 50%)
const List<HeroFarmStory> defaultHeroFarmStories = [
  HeroFarmStory(
    id: 'story-brand-origin',
    title: 'The MILTERRA Story · Indigenous Sahiwal Heritage',
    caption:
        'Rooted in Vedic tradition: ethically raised Sahiwal & Gir cows grazing freely.',
    storyBadge: 'OUR ORIGIN',
    posterPath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverPosterPath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverBadge: 'Vedic Bilona Churning',
    videoUrl: null,
    detailStory:
        'MILTERRA was born from a singular mission: reviving authentic, ethical Indian dairy heritage. We partner with pastoralists raising indigenous Bos indicus cows (Sahiwal and Gir). Our cattle are raised with reverence, enjoying open sunlight, green fodder, and cruelty-free care where the calf is always fed first.',
    location: 'Milterra Heritage Project',
    durationSeconds: 8,
  ),
  HeroFarmStory(
    id: 'story-bilona',
    title: 'Traditional Wooden Bilona Churning',
    caption: 'Whole cultured curd churned bidirectionally with wooden valona.',
    storyBadge: 'THE BILONA METHOD',
    posterPath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverPosterPath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverBadge: 'Sahiwal Cows & Pasture',
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
    posterPath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverPosterPath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverBadge: 'Sahiwal Cows & Pasture',
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
    posterPath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverPosterPath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverBadge: 'Artisan Kitchen Handcraft',
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
    posterPath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverPosterPath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverBadge: 'Lab Quality Certified',
    videoUrl: null,
    detailStory:
        'Every batch is tracked and sent for rigorous analytical testing: NMR verification for honey, purity testing for ghee, cold-press temperature certification for oils, and stone-mill temperature control for flours. We believe transparency is the highest form of respect.',
    location: 'Quality & Research Lab',
    durationSeconds: 7,
  ),
];
