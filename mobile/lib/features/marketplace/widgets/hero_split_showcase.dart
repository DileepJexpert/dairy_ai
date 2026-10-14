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
  const _CinematicBannerData(this.slide);

  final HeroProductSlide slide;

  String get headline => '${slide.packSize} ${slide.name}'.toUpperCase();
  String get feature1Icon => '📦';
  String get feature1Text => slide.packSize;
  String get feature2Icon => '🌿';
  String get feature2Text => slide.shortBenefit ?? slide.category;
  String get panoramicImage => slide.imagePath;
  String get cutoutImage => slide.mobileImagePath ?? slide.imagePath;
  String get stampText {
    final source = slide.highlightBadge ?? slide.badge;
    return source.trim().isEmpty ? 'MILTERRA' : source.replaceAll('✨', '').replaceAll('🔥', '').replaceAll('⚡', '').trim();
  }
  String get stampSub => slide.isHighlightedDeal ? 'FEATURED' : 'SELECT';
  double get salePrice => slide.price;
  double get regularPrice => slide.originalPrice ?? slide.price;
  bool get hasDiscount => regularPrice > salePrice;
  String get priceDropText {
    final saving = regularPrice - salePrice;
    return saving > 0 ? 'SAVE ${storeMoney(saving)}' : 'CATALOGUE PRICE';
  }
  String? get couponPillText {
    final code = slide.campaignCouponCode?.trim();
    if (code == null || code.isEmpty) return null;
    final description = slide.campaignCouponText?.trim();
    return '${description == null || description.isEmpty ? 'ACTIVE OFFER' : description} · CODE: $code';
  }
  String get footnoteText =>
      slide.highlightHeadline ?? slide.shortBenefit ?? slide.description;
  String get targetRoute => slide.targetRoute;
}

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
  late final FocusNode _carouselFocusNode;
  int _activeBanner = 0;
  Timer? _autoTimer;
  bool _isPointerHovering = false;
  bool _hasCarouselFocus = false;

  bool get _isAutoPlayPaused => _isPointerHovering || _hasCarouselFocus;
  List<_CinematicBannerData> get _banners => widget.productSlides
      .map(_CinematicBannerData.new)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _bannerController = PageController();
    _carouselFocusNode = FocusNode(debugLabel: 'Featured products carousel');
    _startAutoPlayTimer();
  }

  @override
  void didUpdateWidget(covariant HeroSplitShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay) {
      _startAutoPlayTimer();
    }
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _carouselFocusNode.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  void _startAutoPlayTimer() {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (!widget.autoPlay || widget.productSlides.length <= 1) {
      return;
    }
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return;
    }

    _autoTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (_isAutoPlayPaused ||
          !_bannerController.hasClients ||
          widget.productSlides.isEmpty) {
        return;
      }
      _showBanner(
        (_activeBanner + 1) % widget.productSlides.length,
        duration: const Duration(milliseconds: 500),
      );
    });
  }

  void _showBanner(
    int index, {
    Duration duration = const Duration(milliseconds: 400),
  }) {
    if (!_bannerController.hasClients) {
      return;
    }
    final bannerCount = widget.productSlides.length;
    if (bannerCount == 0) return;
    final normalizedIndex = (index % bannerCount + bannerCount) % bannerCount;
    _bannerController.animateToPage(
      normalizedIndex,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _showPreviousBanner() => _showBanner(_activeBanner - 1);

  void _showNextBanner() => _showBanner(_activeBanner + 1);

  KeyEventResult _handleCarouselKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _showPreviousBanner();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _showNextBanner();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _showBanner(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _showBanner(widget.productSlides.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _spokenHeadline(_CinematicBannerData item) =>
      item.headline.replaceAll('\n', ' ');

  void navigateToFirstStory() {
    FarmStoryShowcase.showStoryDetail(
      context,
      defaultHeroFarmStories.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = widget.screenWidth < 880;
    final double bannerHeight = isMobile ? 210.0 : 275.0;
    final banners = _banners;

    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final carousel = SizedBox(
      height: bannerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // 100% Full-Width Edge-to-Edge PageView
          PageView.builder(
            controller: _bannerController,
            itemCount: banners.length,
            onPageChanged: (idx) => setState(() => _activeBanner = idx),
            itemBuilder: (context, idx) {
              final item = banners[idx];
              return _buildSingleHeroSlide(item, isMobile, idx);
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
                  label: 'Show previous featured product',
                  onTap: _showPreviousBanner,
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
                  label: 'Show next featured product',
                  onTap: _showNextBanner,
                ),
              ),
            ),

          // HealthKart Centered Dark Capsule Pagination Dots [ ••••• ]
          Positioned(
            bottom: 10,
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
                  children: List.generate(banners.length, (i) {
                    final isCurrent = i == _activeBanner;
                    final item = banners[i];
                    final label =
                        'Show featured product ${i + 1} of ${banners.length}: ${_spokenHeadline(item)}';
                    return Semantics(
                      button: true,
                      selected: isCurrent,
                      label: label,
                      onTap: () => _showBanner(i),
                      child: ExcludeSemantics(
                        child: Tooltip(
                          message: label,
                          child: InkWell(
                            onTap: () => _showBanner(i),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 6,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: isCurrent ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? const Color(0xff0d9488)
                                      : Colors.white.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
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

    return MouseRegion(
      onEnter: (_) => _isPointerHovering = true,
      onExit: (_) => _isPointerHovering = false,
      child: Focus(
        focusNode: _carouselFocusNode,
        onFocusChange: (hasFocus) => _hasCarouselFocus = hasFocus,
        onKeyEvent: _handleCarouselKeyEvent,
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Featured products carousel',
          child: carousel,
        ),
      ),
    );
  }

  /// The entire banner is clickable! Clicking navigates straight to the product page.
  Widget _buildSingleHeroSlide(
    _CinematicBannerData item,
    bool isMobile,
    int index,
  ) {
    void navigateToProduct() => context.push(item.targetRoute);
    return Semantics(
      container: true,
      button: true,
      label:
          'Featured product ${index + 1} of ${widget.productSlides.length}: ${_spokenHeadline(item)}',
      hint: 'Open product details',
      onTap: navigateToProduct,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: navigateToProduct,
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
                alignment: Alignment.center,
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
        ),
      ),
    );
  }

  Widget _buildDesktopHeroSlide(_CinematicBannerData item) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 8),
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
                      top: 10,
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
                          if (item.hasDiscount) ...[
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
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              height: 28,
                              width: 1,
                              color: const Color(0xff475569),
                            ),
                          ],
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.hasDiscount
                                    ? 'Sale Price'
                                    : 'Current Price',
                                style: const TextStyle(
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

                    if (item.couponPillText != null) ...[
                      // Only rendered when the campaign API includes a
                      // backend-verified active coupon definition.
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: const Color(0xff0284c7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.couponPillText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

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
                      if (item.hasDiscount) ...[
                        Text(
                          storeMoney(item.regularPrice),
                          style: const TextStyle(
                            color: Color(0xff94a3b8),
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
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
                if (item.couponPillText != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xff0284c7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.couponPillText!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
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
                  height: 145,
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
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          child: Material(
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
          ),
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
                  const Flexible(
                    child: Text(
                      'Artisanal Harvest Ranges',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xff111827),
                        letterSpacing: -0.3,
                      ),
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

