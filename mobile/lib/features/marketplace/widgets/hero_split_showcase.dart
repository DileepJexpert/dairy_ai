import 'dart:ui' show PointerDeviceKind;
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

/// Fallback product slides with authentic organic photography and interactive hover flips
final List<HeroProductSlide> _fallbackHeroProducts = [
  const HeroProductSlide(
    id: 'ffd7186f-6cee-4b8e-9a87-6af173aabffd',
    category: 'A2 Desi Cow Ghee',
    badge: '100% BILONA',
    name: 'MILTERRA A2 Sahiwal Cow Bilona Ghee',
    packSize: '1 Litre',
    price: 2200.0,
    originalPrice: 2596.0,
    description: 'Traditional Vedic Bilona Ghee churned from cultured A2 curd in earthen pots.',
    shortBenefit: 'Curd-churned in clay pots · Handcrafted in Anand, Gujarat',
    imagePath: 'assets/store/cinematic-3d-cow-ghee-jar.jpg',
    hoverImagePath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverBadge: 'Sahiwal Cows & Pasture',
    targetRoute: '/shop/product/ffd7186f-6cee-4b8e-9a87-6af173aabffd',
  ),
  const HeroProductSlide(
    id: '54b52256-c0d6-436c-b8aa-737b35ab1636',
    category: 'Wood-Pressed Oils',
    badge: 'KACHI GHANI',
    name: 'Kacchi Ghani Black Mustard Oil (Lakdi Ghani)',
    packSize: '1 Litre',
    price: 220.0,
    originalPrice: 260.0,
    description: 'Pure cold-pressed mustard oil extracted on traditional wooden kolhu.',
    shortBenefit: 'First cold extraction · Zero heat or chemical treatment',
    imagePath: 'assets/store/cinematic-3d-mustard-oil-bottle.jpg',
    hoverImagePath: 'assets/store/lakdi-kolhu-craft-hd.jpg',
    hoverBadge: 'Cold-Press Lakdi Kolhu',
    targetRoute: '/shop/product/54b52256-c0d6-436c-b8aa-737b35ab1636',
  ),
  const HeroProductSlide(
    id: 'ad431721-27f9-477b-85ce-53def61d7f36',
    category: 'A2 Buffalo Ghee',
    badge: 'DANEDAR GRAIN',
    name: 'Milterra Traditional Cultured Buffalo Ghee',
    packSize: '1 Litre',
    price: 1299.0,
    originalPrice: 1532.0,
    description: 'Golden granular ghee churned from Murrah buffalo cultured curd.',
    shortBenefit: 'Naturally thick granular texture · High energy Vedic nutrition',
    imagePath: 'assets/store/cinematic-3d-buffalo-ghee-jar.jpg',
    hoverImagePath: 'assets/store/farm-bilona-cinematic.jpg',
    hoverBadge: 'Vedic Bilona Churning',
    targetRoute: '/shop/product/ad431721-27f9-477b-85ce-53def61d7f36',
  ),
  const HeroProductSlide(
    id: 'b20f6def-861a-4ba7-b7fa-dab5f4504278',
    category: 'Fresh Dairy',
    badge: 'FARM FRESH',
    name: 'Milterra Fresh Sahiwal Milk Paneer',
    packSize: '200g',
    price: 140.0,
    originalPrice: 160.0,
    description: 'Farm-fresh soft paneer made from whole A2 milk.',
    shortBenefit: 'Ultra-soft malai texture · Zero preservatives · 18g protein',
    imagePath: 'assets/store/cinematic-3d-paneer-pack.jpg',
    hoverImagePath: 'assets/store/farm-pasture-cinematic.jpg',
    hoverBadge: 'Fresh A2 Sahiwal Milk',
    targetRoute: '/shop/product/b20f6def-861a-4ba7-b7fa-dab5f4504278',
  ),
];

/// Artisanal Organic Multi-Card Hero Showcase (Ekaris-Inspired & Refined):
/// Features clean, warm ivory cards with arched tops, clear natural product photography,
/// golden star reviews, and authentic farm storytelling without loud distracting colors.
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
  late final ScrollController _scrollController;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  double _lastCardWidth = 275.0;
  static const double _gap = 16.0;

  List<HeroSlideItem> _slides = [];


  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollUpdate);
    _updateSlides();
  }

  @override
  void didUpdateWidget(HeroSplitShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productSlides != widget.productSlides ||
        oldWidget.farmStories != widget.farmStories) {
      _updateSlides();
    }
  }

  void _onScrollUpdate() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canLeft = offset > 8;
    final canRight = offset < maxScroll - 8;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _updateSlides() {
    final list = <HeroSlideItem>[];
    final products = widget.productSlides.isNotEmpty
        ? widget.productSlides
        : _fallbackHeroProducts;

    // All products only: farm stories are removed from this carousel as requested
    for (final p in products) {
      list.add(ProductHeroSlideItem(p));
    }

    _slides = list;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollRight() {
    if (!_scrollController.hasClients) return;
    final step = (_lastCardWidth + _gap) * 2;
    final target = (_scrollController.offset + step).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _scrollLeft() {
    if (!_scrollController.hasClients) return;
    final step = (_lastCardWidth + _gap) * 2;
    final target = (_scrollController.offset - step).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Jump directly to the first farm story card
  void navigateToFirstStory() {
    final storyIndex = _slides.indexWhere((item) => item is StoryHeroSlideItem);
    if (storyIndex != -1 && _scrollController.hasClients) {
      final target = (storyIndex * (_lastCardWidth + _gap)).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _openStoryModal(HeroFarmStory story) {
    FarmStoryShowcase.showStoryDetail(context, story);
  }



  // --------------------------------------------------------------------------
  // MAIN BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDesktop = widget.screenWidth >= 1024;
    const double cardHeight = 380.0;

    // Card width calculation: 4 cards fill desktop cleanly
    final visibleWidth = (widget.screenWidth - 32).clamp(320.0, 1200.0);
    final cardWidth = isDesktop
        ? ((visibleWidth - (3 * _gap)) / 4).clamp(260.0, 290.0)
        : (widget.screenWidth < 600 ? 250.0 : 270.0);
    _lastCardWidth = cardWidth;

    if (_slides.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfffcfbf8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffebe7dd), width: 1.0),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HORIZONTAL MULTI-CARD ROW WITH FLOATING CHEVRONS
          SizedBox(
            height: cardHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Scrollable Card Row
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 2, vertical: 4),
                    itemCount: _slides.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: _gap),
                    itemBuilder: (context, index) {
                      final item = _slides[index];
                      if (item is ProductHeroSlideItem) {
                        return _EkarisProductCard(
                          slide: item.slide,
                          width: cardWidth,
                          height: cardHeight,
                          onTap: () {
                            if (item.slide.targetRoute.startsWith('/')) {
                              context.go(item.slide.targetRoute);
                            } else if (widget.onExploreCategory != null) {
                              widget.onExploreCategory!(item.slide.category);
                            }
                          },
                          onAddToCart: widget.onAddToCart != null
                              ? () => widget.onAddToCart!(item.slide)
                              : null,
                        );
                      } else if (item is StoryHeroSlideItem) {
                        return _EkarisStoryCard(
                          story: item.story,
                          width: cardWidth,
                          height: cardHeight,
                          onTap: () => _openStoryModal(item.story),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),

                // Floating Left Chevron
                if (_canScrollLeft)
                  Positioned(
                    left: -4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildChevronButton(
                        icon: Icons.chevron_left,
                        tooltip: 'Previous products',
                        onTap: _scrollLeft,
                      ),
                    ),
                  ),

                // Floating Right Chevron
                if (_canScrollRight)
                  Positioned(
                    right: -4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildChevronButton(
                        icon: Icons.chevron_right,
                        tooltip: 'More products',
                        onTap: _scrollRight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChevronButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xffdcd6cb), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1e000000),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, size: 24, color: const Color(0xff1f2937)),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// EKARIS-STYLE ARCHED PRODUCT CARD (CLEAN, ARTISANAL, CRISP)
// ----------------------------------------------------------------------------
class _EkarisProductCard extends StatefulWidget {
  const _EkarisProductCard({
    required this.slide,
    required this.width,
    required this.height,
    required this.onTap,
    this.onAddToCart,
  });

  final HeroProductSlide slide;
  final double width;
  final double height;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;

  @override
  State<_EkarisProductCard> createState() => _EkarisProductCardState();
}

class _EkarisProductCardState extends State<_EkarisProductCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _pulseAnim =
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

  late final Animation<double> _blinkAnim =
      Tween<double>(begin: 0.25, end: 1.0).animate(_pulseAnim);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slide;
    final isHighlighted = slide.isHighlightedDeal;
    final activeImagePath = (_isHovered &&
            slide.hoverImagePath != null &&
            slide.hoverImagePath!.isNotEmpty)
        ? slide.hoverImagePath!
        : slide.imagePath;
    final isPngCutout = activeImagePath.endsWith('.png');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final pulseVal = _pulseAnim.value;
            final blinkVal = _blinkAnim.value;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: widget.width,
              transform: _isHovered
                  ? (Matrix4.identity()
                    ..setEntry(3, 2, 0.0006)
                    ..setTranslationRaw(0.0, -5.0, 0.0)
                    ..rotateX(-0.015))
                  : Matrix4.identity(),
              decoration: BoxDecoration(
                color: isHighlighted ? const Color(0xfffffdf7) : Colors.white,
                // Iconic Arched Top Corners
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                border: Border.all(
                  color: isHighlighted
                      ? Color.lerp(
                          const Color(0xfff59e0b),
                          const Color(0xff10b981),
                          pulseVal,
                        )!
                      : (_isHovered
                          ? const Color(0xff166534)
                          : const Color(0xffe8e5de)),
                  width: isHighlighted ? 2.5 : (_isHovered ? 1.4 : 1.0),
                ),
                boxShadow: [
                  if (isHighlighted) ...[
                    BoxShadow(
                      color: const Color(0xfff59e0b)
                          .withValues(alpha: 0.25 + 0.35 * pulseVal),
                      blurRadius: 16 + 10 * pulseVal,
                      spreadRadius: 1.0 + 2.0 * pulseVal,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xff10b981)
                          .withValues(alpha: 0.15 + 0.15 * pulseVal),
                      blurRadius: 24,
                      spreadRadius: 0.5,
                    ),
                  ] else
                    BoxShadow(
                      color: _isHovered
                          ? const Color(0x18000000)
                          : const Color(0x0a000000),
                      blurRadius: _isHovered ? 16 : 8,
                      offset: Offset(0, _isHovered ? 6 : 2),
                    ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HIGHLIGHTED DEAL OF THE DAY BANNER RIBBON (KEEP BLINKING ON SCREEN)
                  if (isHighlighted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xffb45309), // Amber 700
                            Color(0xffd97706), // Amber 600
                            Color(0xff166534), // Emerald 700
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Pulsing Red/Golden Beacon Dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xffef4444)
                                  .withValues(alpha: blinkVal),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xffef4444)
                                      .withValues(alpha: blinkVal),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            slide.highlightBadge ?? '⚡ TOP SELLER OF THE DAY',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                color: const Color(0xfffef08a)
                                    .withValues(alpha: blinkVal),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              // TOP IMAGE STAGE: Direct, Seamless Presentation with Hover Flip (Edge-to-Edge)
              SizedBox(
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Base background with subtle studio radial light
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xfffcfbf8),
                        gradient: RadialGradient(
                          center: Alignment(0.0, -0.15),
                          radius: 0.9,
                          colors: [
                            Color(0xffffffff),
                            Color(0xfff5f3ec),
                          ],
                        ),
                      ),
                    ),

                    // DIRECT SEAMLESS PRODUCT IMAGE WITH SMOOTH HOVER FLIP
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(activeImagePath),
                        child: SizedBox.expand(
                          child: isPngCutout
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: AnimatedScale(
                                    scale: _isHovered ? 1.05 : 1.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Transform(
                                      transform: Matrix4.identity()
                                        ..setEntry(3, 2, 0.0012)
                                        ..rotateZ(_isHovered ? -0.012 : -0.035)
                                        ..rotateY(_isHovered ? 0.04 : 0.09),
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        activeImagePath,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                        errorBuilder: (_, __, ___) => Image.asset(
                                          StoreImages.hero,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : _buildCleanImage(
                                  activeImagePath,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                ),
                        ),
                      ),
                    ),

                    // Top-Left Circular Badge (e.g. "1 LITRE" or "500 ML" like Ekaris)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff164e2e),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1a000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          slide.packSize.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Top-Right Purity Tag (e.g. "100% BILONA")
                    if (slide.badge.isNotEmpty)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xfffef3c7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xfffde68a),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            slide.badge.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff92400e),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                    // Bottom-Right Hover flip hint / active badge
                    if (slide.hoverImagePath != null) ...[
                      // Hint when not hovered
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHovered ? 0.0 : 0.9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xdd164e2e),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1a000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz,
                                      size: 11, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Hover to flip',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Active pill when hovered
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHovered ? 0.95 : 0.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xee164e2e),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x24000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 10, color: Color(0xff86efac)),
                                  const SizedBox(width: 4),
                                  Text(
                                    slide.hoverBadge ?? 'Traditional Method',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // BOTTOM CONTENT: Clean Typography & Details
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Title (Forest Green, bold, 2 lines)
                    SizedBox(
                      height: 38,
                      child: Text(
                        slide.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff164e2e),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Short Benefit (Subtle grey, 1 line)
                    SizedBox(
                      height: 18,
                      child: Text(
                        slide.shortBenefit?.isNotEmpty == true
                            ? slide.shortBenefit!
                            : slide.description,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xff6b7280),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Star Rating Row (Golden Stars like Ekaris)
                    const Row(
                      children: [
                        Icon(Icons.star,
                            size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star,
                            size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star,
                            size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star,
                            size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star_half,
                            size: 13, color: Color(0xfff59e0b)),
                        SizedBox(width: 4),
                        Text(
                          '4.8',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffd97706),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '(240+)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Color(0xff9ca3af),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Price & Savings Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          slide.price > 0
                              ? storeMoney(slide.price)
                              : 'Best Price',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xff164e2e),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          storeMoney(slide.originalPrice ?? (slide.price * 1.18)),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff9ca3af),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Save ${slide.discountPercent ?? 18}%',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff15803d),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action Button ("+ Add to Cart" with Cart Drawer)
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: isHighlighted
                              ? (_isHovered
                                  ? const Color(0xffb45309)
                                  : const Color(0xffd97706))
                              : (_isHovered
                                  ? const Color(0xff164e2e)
                                  : const Color(0xff1b5e20)),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: isHighlighted ? 3 : 0,
                          shadowColor: const Color(0xffd97706)
                              .withValues(alpha: 0.5),
                        ),
                        onPressed: widget.onAddToCart ?? widget.onTap,
                        icon: Icon(
                          isHighlighted
                              ? Icons.flash_on
                              : Icons.add_shopping_cart,
                          size: 14,
                        ),
                        label: Text(
                          isHighlighted ? 'Claim Deal & Add 🛒' : 'Add to Cart',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  ),
);
  }
}

// ----------------------------------------------------------------------------
// EKARIS-STYLE ARCHED STORY CARD (AUTHENTIC VEDIC HERITAGE)
// ----------------------------------------------------------------------------
class _EkarisStoryCard extends StatefulWidget {
  const _EkarisStoryCard({
    required this.story,
    required this.width,
    required this.height,
    required this.onTap,
  });

  final HeroFarmStory story;
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  State<_EkarisStoryCard> createState() => _EkarisStoryCardState();
}

class _EkarisStoryCardState extends State<_EkarisStoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final activePoster = (_isHovered &&
            story.hoverPosterPath != null &&
            story.hoverPosterPath!.isNotEmpty)
        ? story.hoverPosterPath!
        : story.posterPath;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: widget.width,
          transform: _isHovered
              ? (Matrix4.identity()
                ..setEntry(3, 2, 0.0006)
                ..setTranslationRaw(0.0, -5.0, 0.0)
                ..rotateX(-0.015))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: const Color(0xfff6f7f2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xff166534)
                  : const Color(0xffd5ded2),
              width: _isHovered ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0x18000000)
                    : const Color(0x0a000000),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TOP IMAGE: Framed Authentic Farm Photography with Hover Flip
              SizedBox(
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Authentic Photograph with AnimatedSwitcher
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      ),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<String>(activePoster),
                        child: SizedBox.expand(
                          child: _buildCleanImage(
                            activePoster,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0.0, -0.35),
                          ),
                        ),
                      ),
                    ),

                    // Top-Left Circular Badge ("OUR STORY")
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xff164e2e),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x2a000000),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Text(
                          'OUR STORY',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Bottom-Right Hover flip hint / active badge
                    if (story.hoverPosterPath != null) ...[
                      // Hint when not hovered
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHovered ? 0.0 : 0.9,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xdd164e2e),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x1a000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.swap_horiz,
                                      size: 11, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Hover to flip',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Active pill when hovered
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _isHovered ? 0.95 : 0.0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xee164e2e),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x24000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 10, color: Color(0xff86efac)),
                                  const SizedBox(width: 4),
                                  Text(
                                    story.hoverBadge ?? 'Farm Heritage',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Top-Right Location Tag
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xdd0f172a),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on,
                                size: 10, color: Color(0xff4ade80)),
                            SizedBox(width: 2),
                            Text(
                              'Anand, Gujarat',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // BOTTOM CONTENT: Heritage Storytelling
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Story Title
                    SizedBox(
                      height: 38,
                      child: Text(
                        story.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff164e2e),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Story Caption
                    SizedBox(
                      height: 18,
                      child: Text(
                        story.caption,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xff4b5563),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Heritage Trust Rating
                    const Row(
                      children: [
                        Icon(Icons.star, size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star, size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star, size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star, size: 13, color: Color(0xfff59e0b)),
                        Icon(Icons.star, size: 13, color: Color(0xfff59e0b)),
                        SizedBox(width: 4),
                        Text(
                          '5.0',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xffd97706),
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '(Vedic Heritage)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: Color(0xff6b7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Ethos Pill
                    const Row(
                      children: [
                        Icon(Icons.eco,
                            size: 14, color: Color(0xff16a34a)),
                        SizedBox(width: 4),
                        Text(
                          'Calf Fed First · Ahimsa Ethos',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff166534),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action Button ("Explore Story →")
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff164e2e),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: widget.onTap,
                        child: const Text(
                          'Explore Story →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
}

Widget _buildCleanImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  double? width,
  double? height,
}) {
  if (path.startsWith('http')) {
    return Image.network(
      path,
      fit: fit,
      alignment: alignment,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      errorBuilder: (_, __, ___) => Image.asset(
        StoreImages.hero,
        fit: fit,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
      ),
    );
  }
  return Image.asset(
    path,
    fit: fit,
    alignment: alignment,
    width: width ?? double.infinity,
    height: height ?? double.infinity,
    errorBuilder: (_, __, ___) => Image.asset(
      StoreImages.hero,
      fit: fit,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
    ),
  );
}
