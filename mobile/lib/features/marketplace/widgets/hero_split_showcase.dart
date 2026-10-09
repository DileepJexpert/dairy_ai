import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/hero_showcase_config.dart';
import '../providers/campaign_posters_provider.dart';
import 'campaign_posters_admin_dialog.dart';
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
  final Alignment? desktopAlignment;
  final Alignment? mobileAlignment;

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
    this.desktopAlignment,
    this.mobileAlignment,
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
    targetRoute: '/shop/product/b20f6def-861a-4ba7-b7fa-dab5f4504278',
  ),
  const _CinematicBannerData(
    headline: '2L VEDIC A2 GIR COW BILONA GHEE\n(HERITAGE RECTANGULAR TIN)',
    feature1Icon: '🥄',
    feature1Text: '100% Valona Churn',
    feature2Icon: '🛡️',
    feature2Text: '100% UV & Plastic-Free Tin',
    panoramicImage: 'assets/store/panoramic-ghee-tin-hero.jpg',
    cutoutImage: 'assets/store/tilted-cow-ghee-3d.png',
    stampText: 'HERITAGE\nTIN',
    stampSub: 'UV SAFE',
    priceDropText: 'PRICE DROPPED BY ₹499',
    salePrice: 2999,
    regularPrice: 3498,
    couponPillText: '+ EXTRA 15% OFF · CODE: BILONA15',
    footnoteText: '*Food-grade tin protects living nutrients from UV oxidation',
    targetRoute: '/shop/product/0e12db10-a3a8-40c2-a004-6ccdcb9d710b',
    desktopAlignment: Alignment(0.0, 0.55),
    mobileAlignment: Alignment(-0.6, 0.55),
  ),
  const _CinematicBannerData(
    headline: '2L KACCHI GHANI BLACK MUSTARD OIL\n(HERITAGE RECTANGULAR TIN)',
    feature1Icon: '🪵',
    feature1Text: 'Wood Kolhu <38°C',
    feature2Icon: '🛡️',
    feature2Text: '100% UV & Plastic-Free Tin',
    panoramicImage: 'assets/store/panoramic-mustard-tin-hero.jpg',
    cutoutImage: 'assets/store/tilted-mustard-oil-3d.png',
    stampText: 'HERITAGE\nTIN',
    stampSub: 'UV SAFE',
    priceDropText: 'PRICE DROPPED BY ₹60',
    salePrice: 430,
    regularPrice: 490,
    couponPillText: '+ EXTRA 15% OFF · CODE: SARSO15',
    footnoteText: '*Preserves Natural Allyl Isothiocyanate & Native Omega-3',
    targetRoute: '/shop/product/e7c41a29-8f3b-410a-b28e-5b12da612002',
    desktopAlignment: Alignment(0.0, 0.55),
    mobileAlignment: Alignment(-0.6, 0.55),
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
                alignment: isMobile
                    ? (item.mobileAlignment ?? Alignment.centerLeft)
                    : (item.desktopAlignment ?? Alignment.center),
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
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
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

/// HealthKart Artisanal Campaign Range Posters Slider with promotional offers & navigation controls.
class StorefrontCampaignPosters extends ConsumerStatefulWidget {
  const StorefrontCampaignPosters({
    super.key,
    required this.isMobile,
    this.onExploreCategory,
  });

  final bool isMobile;
  final ValueChanged<String>? onExploreCategory;

  @override
  ConsumerState<StorefrontCampaignPosters> createState() =>
      _StorefrontCampaignPostersState();
}

class _StorefrontCampaignPostersState
    extends ConsumerState<StorefrontCampaignPosters> {
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
    final posters = ref.watch(campaignPostersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser?.role == 'admin' || currentUser?.role == 'super_admin';

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final int cardsPerRow = widget.isMobile
            ? 1
            : (availableWidth >= 1050
                ? 4
                : (availableWidth >= 750
                    ? 3
                    : 2));
        final double gap = widget.isMobile ? 12.0 : 16.0;
        final double posterWidth = widget.isMobile
            ? (availableWidth * 0.78).clamp(210.0, 280.0)
            : (availableWidth - (cardsPerRow - 1) * gap) / cardsPerRow;
        final double posterHeight = widget.isMobile ? 295.0 : 318.0;
        final double scrollStep =
            (posterWidth + gap) * (widget.isMobile ? 1 : cardsPerRow);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Compact Header: Title on Left, Admin Edit + View All + Slider Controls on Right
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
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => showCampaignPostersAdminDialog(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xfff1f5f9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xffcbd5e1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note,
                                size: 14, color: Color(0xff334155)),
                            SizedBox(width: 4),
                            Text(
                              'Edit Offers',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                  if (!widget.isMobile && posters.length > cardsPerRow) ...[
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

            // Horizontal Sliding Promotional Campaign Posters
            SizedBox(
              height: posterHeight,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: posters.length,
                separatorBuilder: (_, __) => SizedBox(width: gap),
                itemBuilder: (context, idx) {
                  final poster = posters[idx];
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: _HealthKartCampaignCard(
                      poster: poster,
                      width: posterWidth,
                      height: posterHeight,
                      onTap: () {
                        if (widget.onExploreCategory != null) {
                          widget.onExploreCategory!(poster.category);
                        } else {
                          storeBrowse(context, category: poster.category);
                        }
                      },
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

class _HealthKartCampaignCard extends StatelessWidget {
  const _HealthKartCampaignCard({
    required this.poster,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final CampaignPosterConfig poster;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xff18181b),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffeae5dc), width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: The Full Uncut Product Image
              Image.asset(
                poster.imagePath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.spa, color: Colors.amber, size: 40),
                ),
              ),

              // Layer 2: Transparent Soft Vignette Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.68),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.78),
                    ],
                    stops: const [0.0, 0.38, 1.0],
                  ),
                ),
              ),

              // Layer 3: Overlaid Transparent Content (Image Background fully visible)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Transparent Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          poster.brand,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                            color: Colors.white.withValues(alpha: 0.9),
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          poster.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.2,
                            height: 1.15,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 6),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xffef4444).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x30000000), blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            poster.highlightTag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Transparent Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Translucent frosted glass price pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.48),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 0.8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'Was ${poster.wasPrice}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withValues(alpha: 0.7),
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Now ',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    poster.nowPrice,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xfffde047),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1.5),
                              Text(
                                poster.rewardTag,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Amber Coupon Code Pill
                        Material(
                          color: const Color(0xfffef08a),
                          borderRadius: BorderRadius.circular(5),
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: poster.couponCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Copied code: ${poster.couponCode}! Applied to range.'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xff0d9488),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                    color: const Color(0xfffacc15),
                                    width: 0.9),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x25000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'CODE : ${poster.couponCode}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xff854d0e),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.copy,
                                    size: 9.5,
                                    color: Color(0xff854d0e),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '*T&Cs Apply',
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.white.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

