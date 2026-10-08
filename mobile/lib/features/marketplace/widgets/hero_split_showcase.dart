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
  final String eyebrow;
  final String headline;
  final String featurePill;
  final String subtitle;
  final String imagePath;
  final double salePrice;
  final double regularPrice;
  final double priceDrop;
  final String perkText;
  final String category;
  final String targetRoute;
  final List<Color> bgGradient;

  const _CinematicBannerData({
    required this.eyebrow,
    required this.headline,
    required this.featurePill,
    required this.subtitle,
    required this.imagePath,
    required this.salePrice,
    required this.regularPrice,
    required this.priceDrop,
    required this.perkText,
    required this.category,
    required this.targetRoute,
    required this.bgGradient,
  });
}

final List<_CinematicBannerData> _defaultCinematicBanners = [
  const _CinematicBannerData(
    eyebrow: '100% VEDIC BILONA CHURN',
    headline: 'A2 SAHIWAL COW VEDIC BILONA GHEE',
    featurePill: 'Curd-Churned in Earthen Pots | Certified A2 Beta-Casein',
    subtitle:
        'Crafted from indigenous Gir & Sahiwal cows grazing on open pastures. Golden bilona aroma, zero chemical additives.',
    imagePath: 'assets/store/cinematic-cow-ghee.jpg',
    salePrice: 2200,
    regularPrice: 2596,
    priceDrop: 396,
    perkText: '+ Free Handcrafted Wooden Spoon & Glass Jar Included',
    category: 'Vedic Bilona Ghee',
    targetRoute: '/shop/product/ffd7186f-6cee-4b8e-9a87-6af173aabffd',
    bgGradient: [Color(0xffe8ecef), Color(0xfff8fafc)],
  ),
  const _CinematicBannerData(
    eyebrow: 'TRADITIONAL LAKDI GHANI',
    headline: 'KACCHI GHANI BLACK MUSTARD OIL (1L)',
    featurePill: 'First Cold Extraction <38°C | 100% Unrefined & Sulfur-Free',
    subtitle:
        'Crushed on heirloom wooden kolhu to preserve natural allyl isothiocyanate. Pungent, golden, pure.',
    imagePath: 'assets/store/cinematic-mustard-oil.jpg',
    salePrice: 220,
    regularPrice: 260,
    priceDrop: 40,
    perkText: 'First cold-press retains all natural antioxidants',
    category: 'Cold-Pressed Sarso (Mustard) Oil',
    targetRoute: '/shop/product/54b52256-c0d6-436c-b8aa-737b35ab1636',
    bgGradient: [Color(0xfffef9ee), Color(0xfffffdfa)],
  ),
  const _CinematicBannerData(
    eyebrow: 'MURRAH BUFFALO HERITAGE',
    headline: 'TRADITIONAL CULTURED BUFFALO GHEE',
    featurePill: 'Thick Danedar Granular Texture | Naturally Sweet Aroma',
    subtitle:
        'Rich cultured Murrah buffalo ghee churned from live curd. High smoke point for authentic Indian festive cooking.',
    imagePath: 'assets/store/ghee-jar-1l.jpg',
    salePrice: 1299,
    regularPrice: 1532,
    priceDrop: 233,
    perkText: 'Ayurvedic nutrition for bone vitality & stamina',
    category: 'Cultured Buffalo Ghee',
    targetRoute: '/shop/product/ad431721-27f9-477b-85ce-53def61d7f36',
    bgGradient: [Color(0xfff1f5f9), Color(0xffffffff)],
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
    imagePath: 'assets/store/ghee-jar-1l.jpg',
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
];

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
    final isMobile = widget.screenWidth < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. HEALTHKART WIDE CINEMATIC HERO BANNER (Screenshot 5)
        _buildCinematicHeroBanner(isMobile),

        const SizedBox(height: 28),

        // 2. HEALTHKART 4-CAMPAIGN RANGE POSTERS (Screenshot 1)
        _buildCampaignRangePosters(isMobile),

        const SizedBox(height: 16),

        // 3. CENTERED VIEW ALL BUTTON (Screenshot 1)
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff0d9488),
              side: const BorderSide(color: Color(0xff0d9488), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
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

  // --------------------------------------------------------------------------
  // TIER 1: HEALTHKART WIDE CINEMATIC HERO BANNER
  // --------------------------------------------------------------------------
  Widget _buildCinematicHeroBanner(bool isMobile) {
    final double bannerHeight = isMobile ? 260.0 : 340.0;

    return SizedBox(
      height: bannerHeight,
      child: Stack(
        children: [
          // Banner PageView
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _defaultCinematicBanners.length,
              onPageChanged: (idx) => setState(() => _activeBanner = idx),
              itemBuilder: (context, idx) {
                final item = _defaultCinematicBanners[idx];
                return _buildSingleHeroSlide(item, isMobile);
              },
            ),
          ),

          // Floating Left Chevron
          if (!isMobile)
            Positioned(
              left: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildChevronCircle(
                  icon: Icons.chevron_left,
                  onTap: () {
                    final prev = (_activeBanner - 1 + _defaultCinematicBanners.length) %
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

          // Floating Right Chevron
          if (!isMobile)
            Positioned(
              right: 12,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildChevronCircle(
                  icon: Icons.chevron_right,
                  onTap: () {
                    final next = (_activeBanner + 1) % _defaultCinematicBanners.length;
                    _bannerController.animateToPage(
                      next,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                ),
              ),
            ),

          // Bottom Pagination Dots
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                        : const Color(0xffcbd5e1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleHeroSlide(_CinematicBannerData item, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: item.bgGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 48,
        vertical: isMobile ? 16 : 24,
      ),
      child: isMobile
          ? Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.eyebrow,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xff0d9488),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.headline,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xff0f172a),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            storeMoney(item.salePrice),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xff0f172a),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            storeMoney(item.regularPrice),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff94a3b8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff0d9488),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => context.push(item.targetRoute),
                        child: const Text('Explore Churn →',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: Image.asset(
                      item.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.spa, size: 60, color: storeGold),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                // Left Column: Headline & Features
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xffccfbf1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.eyebrow,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xff0f766e),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.headline,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xff0f172a),
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xffe2e8f0), width: 1),
                        ),
                        child: Text(
                          item.featurePill,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff334155),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xff64748b),
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Center Column: Big Clean Product Render
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Image.asset(
                        item.imagePath,
                        fit: BoxFit.contain,
                        height: 250,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.spa, size: 90, color: storeGold),
                      ),
                    ),
                  ),
                ),

                // Right Column: Price Drop & Value
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: const Color(0xffe2e8f0), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0a000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PRICE DROPPED BY ₹${item.priceDrop.toInt()}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xffdc2626),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              storeMoney(item.salePrice),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xff0f172a),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              storeMoney(item.regularPrice),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xff94a3b8),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.perkText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff16a34a),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff0d9488),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => context.push(item.targetRoute),
                            icon: const Icon(Icons.shopping_bag_outlined,
                                size: 18),
                            label: const Text(
                              'Explore Range →',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildChevronCircle({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x20000000),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: const Color(0xff1f2937)),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TIER 2: HEALTHKART 4-CAMPAIGN RANGE POSTERS (Screenshot 1)
  // --------------------------------------------------------------------------
  Widget _buildCampaignRangePosters(bool isMobile) {
    final posterWidth = isMobile ? 220.0 : 265.0;
    final posterHeight = isMobile ? 300.0 : 350.0;

    return SizedBox(
      height: posterHeight,
      child: ListView.separated(
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
                    blurRadius: 12,
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
                            fontSize: 10.5,
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
                            fontSize: 16,
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
                              fontSize: 10,
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
                    left: 10,
                    right: 10,
                    height: posterHeight * 0.55,
                    child: Image.asset(
                      poster.imagePath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.spa, size: 80, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
