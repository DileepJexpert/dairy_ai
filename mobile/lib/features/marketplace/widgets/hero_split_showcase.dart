import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/hero_showcase_config.dart';
import 'farm_story_showcase.dart';
import 'store_design.dart';

sealed class HeroSlideItem {}

class ProductHeroSlideItem extends HeroSlideItem {
  final HeroProductSlide slide;
  ProductHeroSlideItem(this.slide);
}

class StoryHeroSlideItem extends HeroSlideItem {
  final HeroFarmStory story;
  StoryHeroSlideItem(this.story);
}

class _CinematicBannerData {
  final String headline;
  final String feature1Icon;
  final String feature1Text;
  final String feature2Icon;
  final String feature2Text;
  final String cutoutImage;
  final String stampText;
  final String stampSub;
  final String priceDropText;
  final double salePrice;
  final double regularPrice;
  final String couponPillText;
  final String footnoteText;
  final String targetRoute;
  final List<Color> wallGradient;
  final List<Color> shelfGradient;

  const _CinematicBannerData({
    required this.headline,
    required this.feature1Icon,
    required this.feature1Text,
    required this.feature2Icon,
    required this.feature2Text,
    required this.cutoutImage,
    required this.stampText,
    required this.stampSub,
    required this.priceDropText,
    required this.salePrice,
    required this.regularPrice,
    required this.couponPillText,
    required this.footnoteText,
    required this.targetRoute,
    required this.wallGradient,
    required this.shelfGradient,
  });
}

final List<_CinematicBannerData> _defaultCinematicBanners = [
  const _CinematicBannerData(
    headline: '1KG A2 GIR COW VEDIC BILONA GHEE\n(CLAY POT VALONA CHURN)',
    feature1Icon: '🥄',
    feature1Text: '100% Valona Churn',
    feature2Icon: '🌿',
    feature2Text: 'Certified A2 Beta-Casein',
    cutoutImage: 'assets/store/cow-ghee-hero-cutout.png',
    stampText: '100% PURE\nBILONA',
    stampSub: 'NABL LAB',
    priceDropText: 'PRICE DROPPED BY ₹396',
    salePrice: 2200,
    regularPrice: 2596,
    couponPillText: '+ EXTRA 15% OFF · CODE: PURE15',
    footnoteText: '*Prepaid orders get instant free shipping | 100% Valona Guarantee',
    targetRoute: '/shop/product/ffd7186f-6cee-4b8e-9a87-6af173aabffd',
    wallGradient: [Color(0xff6e8396), Color(0xff889dae), Color(0xffa4b6c5)],
    shelfGradient: [Color(0xff4a5d6e), Color(0xff394a59)],
  ),
  const _CinematicBannerData(
    headline: '1L KACCHI GHANI BLACK MUSTARD OIL\n(HEIRLOOM LAKDI GHANI)',
    feature1Icon: '🪵',
    feature1Text: 'Wood Kolhu <38°C',
    feature2Icon: '⚡',
    feature2Text: '100% Unrefined & Sulfur-Free',
    cutoutImage: 'assets/store/sarso-oil-hero-milterra-concept.png',
    stampText: 'COLD PRESS\nKOLHU',
    stampSub: 'VIRGIN',
    priceDropText: 'PRICE DROPPED BY ₹40',
    salePrice: 220,
    regularPrice: 260,
    couponPillText: '+ FLAT 10% OFF · CODE: KOLHU10',
    footnoteText: '*Preserves Natural Allyl Isothiocyanate & Native Omega-3',
    targetRoute: '/shop/product/54b52256-c0d6-436c-b8aa-737b35ab1636',
    wallGradient: [Color(0xff8a7e66), Color(0xffa4987f), Color(0xffbfb49d)],
    shelfGradient: [Color(0xff5f543e), Color(0xff4c412c)],
  ),
  const _CinematicBannerData(
    headline: '1L CULTURED MURRAH BUFFALO GHEE\n(THICK DANEDAR GRAIN)',
    feature1Icon: '🍯',
    feature1Text: 'Thick Granular Grain',
    feature2Icon: '💪',
    feature2Text: 'High Smoke Point for Cooking',
    cutoutImage: 'assets/store/buffalo-ghee-hero-cutout.png',
    stampText: 'MURRAH\nHERITAGE',
    stampSub: 'DANEDAR',
    priceDropText: 'PRICE DROPPED BY ₹233',
    salePrice: 1299,
    regularPrice: 1532,
    couponPillText: '+ SAVE EXTRA ₹200 · CODE: MURRAH200',
    footnoteText: '*Naturally Sweet Aroma · Churned from Live Murrah Curd',
    targetRoute: '/shop/product/ad431721-27f9-477b-85ce-53def61d7f36',
    wallGradient: [Color(0xff5b7c73), Color(0xff75968d), Color(0xff92b0a8)],
    shelfGradient: [Color(0xff3c5a52), Color(0xff2b443d)],
  ),
  const _CinematicBannerData(
    headline: '500G FRESH LIVING MALAI PANEER\n(SAME-DAY CHURNED FRESH)',
    feature1Icon: '🥛',
    feature1Text: 'Pure Whole A2 Cow Milk',
    feature2Icon: '🧊',
    feature2Text: 'Melt-In-Mouth Zero Starch',
    cutoutImage: 'assets/store/paneer-hero-cutout.png',
    stampText: 'SAME-DAY\nCHURN',
    stampSub: 'NO STARCH',
    priceDropText: 'PRICE DROPPED BY ₹60',
    salePrice: 240,
    regularPrice: 300,
    couponPillText: '+ INTRO COMBO 20% OFF · CODE: FRESH20',
    footnoteText: '*Cold-Chain Vacuum Sealed & Delivered Direct from Farm',
    targetRoute: '/shop',
    wallGradient: [Color(0xff687391), Color(0xff838eaa), Color(0xff9ea8c2)],
    shelfGradient: [Color(0xff47526e), Color(0xff343d54)],
  ),
];

class _RangePosterData {
  final String eyebrow;
  final String title;
  final String badgeText;
  final String imagePath;
  final String category;
  final List<Color> gradient;

  const _RangePosterData({
    required this.eyebrow,
    required this.title,
    required this.badgeText,
    required this.imagePath,
    required this.category,
    required this.gradient,
  });
}

final List<_RangePosterData> _rangePosters = [
  const _RangePosterData(
    eyebrow: 'MILTERRA HERITAGE',
    title: 'Vedic A2 Cow Ghee Range',
    badgeText: '100% VALONA CHURN',
    imagePath: 'assets/store/cinematic-cow-ghee.jpg',
    category: 'Vedic Bilona Ghee',
    gradient: [Color(0xff451a03), Color(0xff78350f), Color(0xff92400e)],
  ),
  const _RangePosterData(
    eyebrow: 'HEIRLOOM KOLHU',
    title: 'Wood-Pressed Oils Range',
    badgeText: 'COLD PRESSED · EXTRA VIRGIN',
    imagePath: 'assets/store/cinematic-mustard-oil.jpg',
    category: 'Cold-Pressed Sarso (Mustard) Oil',
    gradient: [Color(0xff1c1917), Color(0xff292524), Color(0xff44403c)],
  ),
  const _RangePosterData(
    eyebrow: 'MURRAH HERITAGE',
    title: 'Cultured Buffalo Ghee Range',
    badgeText: 'THICK DANEDAR GRAIN',
    imagePath: 'assets/store/cinematic-buffalo-ghee.jpg',
    category: 'Cultured Buffalo Ghee',
    gradient: [Color(0xff064e3b), Color(0xff065f46), Color(0xff047857)],
  ),
  const _RangePosterData(
    eyebrow: 'FARM-TO-DOORSTEP',
    title: 'Fresh Living Dairy & Harvest',
    badgeText: 'CHURNED SAME-DAY FRESH',
    imagePath: 'assets/store/cinematic-paneer.jpg',
    category: 'Fresh Milk & Dairy',
    gradient: [Color(0xff1e1b4b), Color(0xff312e81), Color(0xff3730a3)],
  ),
  const _RangePosterData(
    eyebrow: 'NATIVE TERROIR',
    title: 'Himalayan Salts & Spices',
    badgeText: 'STONE POUNDED · UNREFINED',
    imagePath: 'assets/store/lakadong-turmeric.jpg',
    category: 'Terroir Salts & Native Spices',
    gradient: [Color(0xff7c2d12), Color(0xff9a3412), Color(0xffc2410c)],
  ),
  const _RangePosterData(
    eyebrow: 'PURE SWEETENERS',
    title: 'Wild Forest Honey & Gur',
    badgeText: '100% RAW & UNPASTEURIZED',
    imagePath: 'assets/store/raw-mustard-honey.jpg',
    category: 'Wood-Pressed Oils & Pure Sweeteners',
    gradient: [Color(0xff713f12), Color(0xff854d0e), Color(0xffa16207)],
  ),
  const _RangePosterData(
    eyebrow: 'STONE CHAKKI ATTA',
    title: 'Heirloom Khapli & Flours',
    badgeText: 'COLD MILLED · 100% BRAN',
    imagePath: 'assets/store/khapli-atta.jpg',
    category: 'Stone-Ground Chakki Atta & Flours',
    gradient: [Color(0xff365314), Color(0xff3f6212), Color(0xff4d7c0f)],
  ),
  const _RangePosterData(
    eyebrow: 'SACRED HERITAGE',
    title: 'Panchagavya Hawan & Dhoop',
    badgeText: 'INDIGENOUS COW ESSENTIALS',
    imagePath: 'assets/store/panchagavya-dhoop.jpg',
    category: 'Puja & Hawan: Sacred Essentials',
    gradient: [Color(0xff3b0764), Color(0xff581c87), Color(0xff6b21a8)],
  ),
];

/// 100% Full-width HealthKart panoramic edge-to-edge cinematic studio carousel.
/// The entire banner is clickable, product rests naturally on perspective shelf.
class HeroSplitShowcase extends StatefulWidget {
  const HeroSplitShowcase({
    super.key,
    required this.screenWidth,
    this.productSlides = const [],
    this.farmStories = defaultHeroFarmStories,
    this.onExploreCategory,
    this.onAddToCart,
    this.autoPlay = true,
  });

  final double screenWidth;
  final List<HeroProductSlide> productSlides;
  final List<HeroFarmStory> farmStories;
  final ValueChanged<String>? onExploreCategory;
  final ValueChanged<HeroProductSlide>? onAddToCart;
  final bool autoPlay;

  @override
  State<HeroSplitShowcase> createState() => HeroSplitShowcaseState();
}

class HeroSplitShowcaseState extends State<HeroSplitShowcase> {
  late final PageController _bannerController;
  int _activeBanner = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    if (widget.autoPlay) {
      _autoTimer = Timer.periodic(const Duration(seconds: 7), (_) {
        if (!_bannerController.hasClients) return;
        final next = (_activeBanner + 1) % _defaultCinematicBanners.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void navigateToFirstStory() {
    FarmStoryShowcase.showStoryDetail(
      context,
      defaultHeroFarmStories.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.screenWidth < 880;
    final double bannerHeight = isMobile ? 260.0 : 330.0;

    return SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // 100% Full-Width Edge-to-Edge PageView
          PageView.builder(
            controller: _bannerController,
            itemCount: _defaultCinematicBanners.length,
            onPageChanged: (idx) => setState(() => _activeBanner = idx),
            itemBuilder: (context, idx) {
              final item = _defaultCinematicBanners[idx];
              return _buildSingleHeroSlide(item, isMobile);
            },
          ),

          // Floating Left Circular Chevron (<)
          if (!isMobile)
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildChevronCircle(
                  icon: Icons.chevron_left,
                  onTap: () {
                    final prev = (_activeBanner -
                            1 +
                            _defaultCinematicBanners.length) %
                        _defaultCinematicBanners.length;
                    _bannerController.animateToPage(
                      prev,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                ),
              ),
            ),

          // Floating Right Circular Chevron (>)
          if (!isMobile)
            Positioned(
              right: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildChevronCircle(
                  icon: Icons.chevron_right,
                  onTap: () {
                    final next =
                        (_activeBanner + 1) % _defaultCinematicBanners.length;
                    _bannerController.animateToPage(
                      next,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                ),
              ),
            ),

          // HealthKart Centered Dark Capsule Pagination Dots [ ••••• ]
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xff334155).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_defaultCinematicBanners.length, (i) {
                    final isCurrent = i == _activeBanner;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isCurrent ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xff0d9488)
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The entire banner is clickable! Clicking navigates straight to the product page.
  Widget _buildSingleHeroSlide(_CinematicBannerData item, bool isMobile) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => context.push(item.targetRoute),
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              // 1. Studio Wall Gradient (Top 70%)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: item.wallGradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 2. Realistic Perspective Shelf Base (Lower portion with specular highlight)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: isMobile ? 75 : 95,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: item.shelfGradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    border: const Border(
                      top: BorderSide(
                        color: Color(0x66ffffff),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. HealthKart Visual Content Composition
              Positioned.fill(
                child: isMobile
                    ? _buildMobileHeroSlide(item)
                    : _buildDesktopHeroSlide(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeroSlide(_CinematicBannerData item) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LEFT: Product Title & Frosted Glass Feature Capsule
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.headline,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff0f172a),
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Frosted Feature Capsule with divider
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.70),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.feature1Icon,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            item.feature1Text,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff1e293b),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            height: 14,
                            width: 1.2,
                            color: const Color(0xff94a3b8),
                          ),
                          Text(item.feature2Icon,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            item.feature2Text,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff1e293b),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // CENTER: 3D Product Cutout Standing on Shelf + Circular Stamp
              Expanded(
                flex: 8,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Soft floor shadow
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 165,
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                              Radius.elliptical(165, 14)),
                          gradient: RadialGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Product Cutout Image
                    Positioned(
                      bottom: 12,
                      child: Image.asset(
                        item.cutoutImage,
                        height: 245,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.spa,
                          size: 90,
                          color: Color(0xfffde047),
                        ),
                      ),
                    ),
                    // Circular Trust Stamp Badge (like HealthKart's "INFORMED PROTEIN U.S.A")
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _buildCircularStamp(item.stampText, item.stampSub),
                    ),
                  ],
                ),
              ),

              // RIGHT: Price Drop, Dark Price Tag Box, Cyan Discount Pill & Footnote
              Expanded(
                flex: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.priceDropText,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff0f172a),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // HealthKart Dark Price Tag Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xff334155),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Regular Price',
                                style: TextStyle(
                                  color: Color(0xff94a3b8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                storeMoney(item.regularPrice),
                                style: const TextStyle(
                                  color: Color(0xffcbd5e1),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xffcbd5e1),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 14),
                            height: 28,
                            width: 1,
                            color: const Color(0xff475569),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sale Price',
                                style: TextStyle(
                                  color: Color(0xff94a3b8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                storeMoney(item.salePrice),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // HealthKart Cyan / Teal Discount Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: const Color(0xff0284c7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.couponPillText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Footnote
                    Text(
                      item.footnoteText,
                      style: const TextStyle(
                        color: Color(0xff334155),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeroSlide(_CinematicBannerData item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Info & Price
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.headline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff0f172a),
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  item.priceDropText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff0f172a),
                  ),
                ),
                const SizedBox(height: 6),
                // Compact Dark Price Tag Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xff334155),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        storeMoney(item.regularPrice),
                        style: const TextStyle(
                          color: Color(0xff94a3b8),
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        storeMoney(item.salePrice),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xff0284c7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.couponPillText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right: Product on shelf
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 4,
                  child: Container(
                    width: 100,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.all(Radius.elliptical(100, 8)),
                      gradient: RadialGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Image.asset(
                  item.cutoutImage,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.spa,
                    size: 60,
                    color: Color(0xfffde047),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularStamp(String text, String sub) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xffb91c1c),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified, size: 13, color: Colors.white),
            const SizedBox(height: 1),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              sub,
              style: const TextStyle(
                color: Color(0xfffef08a),
                fontSize: 6,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChevronCircle({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
      ),
    );
  }
}

typedef StorefrontHeroBanner = HeroSplitShowcase;
typedef StorefrontHeroBannerState = HeroSplitShowcaseState;

/// HealthKart Artisanal Campaign Range Posters Slider with 8 curated ranges & navigation controls.
class StorefrontCampaignPosters extends StatefulWidget {
  const StorefrontCampaignPosters({
    super.key,
    required this.isMobile,
    this.onExploreCategory,
  });

  final bool isMobile;
  final ValueChanged<String>? onExploreCategory;

  @override
  State<StorefrontCampaignPosters> createState() =>
      _StorefrontCampaignPostersState();
}

class _StorefrontCampaignPostersState extends State<StorefrontCampaignPosters> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollButtons);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) return;
    final canLeft = _scrollController.offset > 10;
    final canRight = _scrollController.offset <
        _scrollController.position.maxScrollExtent - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final posterWidth = widget.isMobile ? 220.0 : 255.0;
    final posterHeight = widget.isMobile ? 300.0 : 345.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with Title & Slider Navigation Buttons
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Artisanal Harvest Ranges',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Curated straight from certified indigenous farms, heirloom kolhus & earthen pots',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isMobile) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSliderButton(
                      icon: Icons.chevron_left,
                      enabled: _canScrollLeft,
                      onTap: () => _scroll(-(posterWidth + 14) * 2),
                    ),
                    const SizedBox(width: 8),
                    _buildSliderButton(
                      icon: Icons.chevron_right,
                      enabled: _canScrollRight,
                      onTap: () => _scroll((posterWidth + 14) * 2),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Horizontal Sliding Posters
        SizedBox(
          height: posterHeight,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _rangePosters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, idx) {
              final poster = _rangePosters[idx];
              return InkWell(
                onTap: () {
                  if (widget.onExploreCategory != null) {
                    widget.onExploreCategory!(poster.category);
                  } else {
                    storeBrowse(context, category: poster.category);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: posterWidth,
                  height: posterHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: poster.gradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Top Copy Header
                      Positioned(
                        top: 18,
                        left: 14,
                        right: 14,
                        child: Column(
                          children: [
                            Text(
                              poster.eyebrow,
                              style: const TextStyle(
                                color: Color(0xfffcd34d),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              poster.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                poster.badgeText,
                                style: const TextStyle(
                                  color: Color(0xff1e2022),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom High-Res Packaging Render
                      Positioned(
                        bottom: 0,
                        left: 8,
                        right: 8,
                        height: posterHeight * 0.54,
                        child: Image.asset(
                          poster.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.spa,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Centered "View All Products" Outline Button
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff0d9488),
              side: const BorderSide(color: Color(0xff0d9488), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            ),
            onPressed: () {
              if (widget.onExploreCategory != null) {
                widget.onExploreCategory!('All Organic Essentials');
              } else {
                storeBrowse(context, category: 'All Organic Essentials');
              }
            },
            icon: const Text(
              'View All Products',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xff0d9488),
              ),
            ),
            label: const Icon(Icons.chevron_right, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled ? Colors.white : const Color(0xfff3f4f6),
      shape: const CircleBorder(),
      elevation: enabled ? 2 : 0,
      shadowColor: const Color(0x20000000),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? const Color(0xff1f2937) : const Color(0xff9ca3af),
          ),
        ),
      ),
    );
  }
}
