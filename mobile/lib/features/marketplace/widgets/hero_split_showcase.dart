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
  final String panoramicImage;
  final String cutoutImage;
  final String stampText;
  final String stampSub;
  final String priceDropText;
  final double salePrice;
  final double regularPrice;
  final String couponPillText;
  final String footnoteText;
  final String targetRoute;

  const _CinematicBannerData({
    required this.headline,
    required this.feature1Icon,
    required this.feature1Text,
    required this.feature2Icon,
    required this.feature2Text,
    required this.panoramicImage,
    required this.cutoutImage,
    required this.stampText,
    required this.stampSub,
    required this.priceDropText,
    required this.salePrice,
    required this.regularPrice,
    required this.couponPillText,
    required this.footnoteText,
    required this.targetRoute,
  });
}

final List<_CinematicBannerData> _defaultCinematicBanners = [
  const _CinematicBannerData(
    headline: '1KG A2 GIR COW VEDIC BILONA GHEE\n(CLAY POT VALONA CHURN)',
    feature1Icon: '🥄',
    feature1Text: '100% Valona Churn',
    feature2Icon: '🌿',
    feature2Text: 'Certified A2 Beta-Casein',
    panoramicImage: 'assets/store/panoramic-cow-ghee-hero.jpg',
    cutoutImage: 'assets/store/tilted-cow-ghee-3d.png',
    stampText: '100% PURE\nBILONA',
    stampSub: 'NABL LAB',
    priceDropText: 'PRICE DROPPED BY ₹396',
    salePrice: 2200,
    regularPrice: 2596,
    couponPillText: '+ EXTRA 15% OFF · CODE: PURE15',
    footnoteText: '*Prepaid orders get instant free shipping | 100% Valona Guarantee',
    targetRoute: '/shop/product/ffd7186f-6cee-4b8e-9a87-6af173aabffd',
  ),
  const _CinematicBannerData(
    headline: '1L KACCHI GHANI BLACK MUSTARD OIL\n(HEIRLOOM LAKDI GHANI)',
    feature1Icon: '🪵',
    feature1Text: 'Wood Kolhu <38°C',
    feature2Icon: '⚡',
    feature2Text: '100% Unrefined & Sulfur-Free',
    panoramicImage: 'assets/store/panoramic-mustard-oil-hero.jpg',
    cutoutImage: 'assets/store/tilted-mustard-oil-3d.png',
    stampText: 'COLD PRESS\nKOLHU',
    stampSub: 'VIRGIN',
    priceDropText: 'PRICE DROPPED BY ₹40',
    salePrice: 220,
    regularPrice: 260,
    couponPillText: '+ FLAT 10% OFF · CODE: KOLHU10',
    footnoteText: '*Preserves Natural Allyl Isothiocyanate & Native Omega-3',
    targetRoute: '/shop/product/54b52256-c0d6-436c-b8aa-737b35ab1636',
  ),
  const _CinematicBannerData(
    headline: '1L CULTURED MURRAH BUFFALO GHEE\n(THICK DANEDAR GRAIN)',
    feature1Icon: '🍯',
    feature1Text: 'Thick Danedar Grain',
    feature2Icon: '💪',
    feature2Text: 'High Smoke Point for Cooking',
    panoramicImage: 'assets/store/panoramic-buffalo-ghee-hero.jpg',
    cutoutImage: 'assets/store/tilted-buffalo-ghee-3d.png',
    stampText: 'MURRAH\nHERITAGE',
    stampSub: 'DANEDAR',
    priceDropText: 'PRICE DROPPED BY ₹233',
    salePrice: 1299,
    regularPrice: 1532,
    couponPillText: '+ SAVE EXTRA ₹200 · CODE: MURRAH200',
    footnoteText: '*Naturally Sweet Aroma · Churned from Live Murrah Curd',
    targetRoute: '/shop/product/ad431721-27f9-477b-85ce-53def61d7f36',
  ),
  const _CinematicBannerData(
    headline: '500G FRESH LIVING MALAI PANEER\n(SAME-DAY CHURNED FRESH)',
    feature1Icon: '🥛',
    feature1Text: 'Pure Whole A2 Cow Milk',
    feature2Icon: '🧊',
    feature2Text: 'Melt-In-Mouth Zero Starch',
    panoramicImage: 'assets/store/panoramic-paneer-hero.jpg',
    cutoutImage: 'assets/store/tilted-paneer-3d.png',
    stampText: 'SAME-DAY\nCHURN',
    stampSub: 'NO STARCH',
    priceDropText: 'PRICE DROPPED BY ₹60',
    salePrice: 240,
    regularPrice: 300,
    couponPillText: '+ INTRO COMBO 20% OFF · CODE: FRESH20',
    footnoteText: '*Cold-Chain Vacuum Sealed & Delivered Direct from Farm',
    targetRoute: '/shop',
  ),
];

class _RangePosterData {
  final String title;
  final String imagePath;
  final String category;

  const _RangePosterData({
    required this.title,
    required this.imagePath,
    required this.category,
  });
}

final List<_RangePosterData> _rangePosters = [
  const _RangePosterData(
    title: 'Vedic A2 Cow Ghee Range',
    imagePath: 'assets/store/poster-card-cow-ghee.jpg',
    category: 'Vedic Bilona Ghee',
  ),
  const _RangePosterData(
    title: 'Wood-Pressed Oils Range',
    imagePath: 'assets/store/poster-card-mustard-oil.jpg',
    category: 'Cold-Pressed Sarso (Mustard) Oil',
  ),
  const _RangePosterData(
    title: 'Cultured Buffalo Ghee Range',
    imagePath: 'assets/store/poster-card-buffalo-ghee.jpg',
    category: 'Cultured Buffalo Ghee',
  ),
  const _RangePosterData(
    title: 'Fresh Living Dairy & Harvest',
    imagePath: 'assets/store/poster-card-paneer.jpg',
    category: 'Fresh Milk & Dairy',
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
    final double bannerHeight = isMobile ? 240.0 : 340.0;

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
            fit: StackFit.expand,
            children: [
              // 1. Panoramic 16:9 Studio Background with 3D Tilted Product in Center
              Image.asset(
                item.panoramicImage,
                fit: BoxFit.cover,
                alignment: isMobile ? Alignment.centerLeft : Alignment.center,
              ),

              // 2. Subtle soft studio light vignette for guaranteed text contrast
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: isMobile ? 0.70 : 0.30),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: isMobile ? 0.65 : 0.20),
                    ],
                    stops: const [0.0, 0.32, 0.68, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),

              // 3. HealthKart Interactive UI Layout
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
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 12),
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
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff0f172a),
                        letterSpacing: -0.3,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Frosted Feature Capsule with divider
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
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

              // CENTER: Open focal space showcasing the 3D tilted product jar & Circular Trust Stamp
              Expanded(
                flex: 8,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Circular Trust Stamp Badge (like HealthKart's "INFORMED PROTEIN U.S.A")
                    Positioned(
                      top: 14,
                      right: 18,
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
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff0f172a),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // HealthKart Dark Price Tag Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xff334155),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xff94a3b8),
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
                    const SizedBox(height: 8),

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xff0f172a),
                    height: 1.15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  item.priceDropText,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff0f172a),
                  ),
                ),
                const SizedBox(height: 5),
                // Compact Dark Price Tag Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xff0284c7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.couponPillText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Right: 3D Product Cutout on Shelf + Stamp
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  item.cutoutImage,
                  height: 165,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _buildCircularStamp(item.stampText, item.stampSub),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // On desktop, dynamically size so exactly 4 cards fill the row edge-to-edge!
        final int cardsPerRow = widget.isMobile
            ? 1
            : (availableWidth >= 1050
                ? 4
                : (availableWidth >= 750
                    ? 3
                    : 2));
        final double gap = widget.isMobile ? 12.0 : 16.0;
        final double posterWidth = widget.isMobile
            ? (availableWidth * 0.76).clamp(200.0, 270.0)
            : (availableWidth - (cardsPerRow - 1) * gap) / cardsPerRow;
        // Height proportional to 3:4 aspect ratio, clamped to prevent vertical bloat:
        final double posterHeight = widget.isMobile
            ? 280.0
            : (posterWidth * 1.33).clamp(260.0, 335.0);
        final double scrollStep =
            (posterWidth + gap) * (widget.isMobile ? 1 : cardsPerRow);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Header: Title on Left, View All + Slider Controls on Right (saving vertical height!)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Artisanal Harvest Ranges',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      if (widget.onExploreCategory != null) {
                        widget.onExploreCategory!('All Organic Essentials');
                      } else {
                        storeBrowse(context,
                            category: 'All Organic Essentials');
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff0d9488),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.chevron_right,
                              size: 16, color: Color(0xff0d9488)),
                        ],
                      ),
                    ),
                  ),
                  if (!widget.isMobile &&
                      _rangePosters.length > cardsPerRow) ...[
                    const SizedBox(width: 10),
                    _buildSliderButton(
                      icon: Icons.chevron_left,
                      enabled: _canScrollLeft,
                      onTap: () => _scroll(-scrollStep),
                    ),
                    const SizedBox(width: 6),
                    _buildSliderButton(
                      icon: Icons.chevron_right,
                      enabled: _canScrollRight,
                      onTap: () => _scroll(scrollStep),
                    ),
                  ],
                ],
              ),
            ),

            // Horizontal Sliding Posters: 100% Full Image Cards (No nested cutouts!)
            SizedBox(
              height: posterHeight,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _rangePosters.length,
                separatorBuilder: (_, __) => SizedBox(width: gap),
                itemBuilder: (context, idx) {
                  final poster = _rangePosters[idx];
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
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
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            poster.imagePath,
                            width: posterWidth,
                            height: posterHeight,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xff1e293b),
                              child: const Center(
                                child: Icon(Icons.spa,
                                    color: Colors.amber, size: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
