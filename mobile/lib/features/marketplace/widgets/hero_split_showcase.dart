import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/hero_showcase_config.dart';
import '../models/product_models.dart';
import 'store_design.dart';

/// Full-width two-column split hero combining shopping with farm storytelling:
/// - Left 50%: Automatic Product Showcase Carousel (A2 Cow Ghee, Buffalo Ghee, Paneer, Milk)
/// - Right 50%: Independent Farm Story Showcase Carousel (Bilona, Milking, Herd care, Purity test)
class HeroSplitShowcase extends StatefulWidget {
  const HeroSplitShowcase({
    super.key,
    required this.screenWidth,
    this.productSlides = defaultHeroProductSlides,
    this.farmStories = defaultHeroFarmStories,
    this.onExploreCategory,
  });

  final double screenWidth;
  final List<HeroProductSlide> productSlides;
  final List<HeroFarmStory> farmStories;
  final ValueChanged<String>? onExploreCategory;

  @override
  State<HeroSplitShowcase> createState() => _HeroSplitShowcaseState();
}

class _HeroSplitShowcaseState extends State<HeroSplitShowcase>
    with SingleTickerProviderStateMixin {
  // Left 50% Product Carousel State
  late final PageController _productController;
  int _currentProduct = 0;
  Timer? _productTimer;

  // Right 50% Farm Story Carousel State
  late final PageController _storyController;
  int _currentStory = 0;
  Timer? _storyTimer;
  bool _isStoryPaused = false;
  bool _isMuted = true;

  // Story progress animation (7.5 seconds)
  late final AnimationController _storyProgressCtrl;

  @override
  void initState() {
    super.initState();
    _productController = PageController();
    _storyController = PageController();

    _storyProgressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7500),
    );

    _storyProgressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_isStoryPaused) {
        _nextStory(animate: true);
      }
    });

    _startProductAutoSlide();
    _startStoryProgress();
  }

  @override
  void dispose() {
    _productTimer?.cancel();
    _storyTimer?.cancel();
    _storyProgressCtrl.dispose();
    _productController.dispose();
    _storyController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Left Carousel Timers & Navigation (Every 5 seconds)
  // --------------------------------------------------------------------------
  void _startProductAutoSlide() {
    _productTimer?.cancel();
    _productTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.productSlides.isEmpty) return;
      final next = (_currentProduct + 1) % widget.productSlides.length;
      _productController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _nextProduct() {
    if (widget.productSlides.isEmpty) return;
    final next = (_currentProduct + 1) % widget.productSlides.length;
    _productController.animateToPage(
      next,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    _startProductAutoSlide();
  }

  void _prevProduct() {
    if (widget.productSlides.isEmpty) return;
    final prev = (_currentProduct - 1 + widget.productSlides.length) %
        widget.productSlides.length;
    _productController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    _startProductAutoSlide();
  }

  // --------------------------------------------------------------------------
  // Right Farm Story Timers & Story Progression (Every 7.5 seconds)
  // --------------------------------------------------------------------------
  void _startStoryProgress() {
    _storyProgressCtrl.reset();
    if (!_isStoryPaused) {
      _storyProgressCtrl.forward();
    }
  }

  void _nextStory({bool animate = true}) {
    if (widget.farmStories.isEmpty) return;
    final next = (_currentStory + 1) % widget.farmStories.length;
    if (animate) {
      _storyController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _storyController.jumpToPage(next);
    }
    _startStoryProgress();
  }

  void _prevStory() {
    if (widget.farmStories.isEmpty) return;
    final prev = (_currentStory - 1 + widget.farmStories.length) %
        widget.farmStories.length;
    _storyController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
    _startStoryProgress();
  }

  void _setStoryPaused(bool pause) {
    if (_isStoryPaused == pause) return;
    setState(() => _isStoryPaused = pause);
    if (pause) {
      _storyProgressCtrl.stop();
    } else {
      _storyProgressCtrl.forward();
    }
  }

  void _toggleStoryPause() {
    _setStoryPaused(!_isStoryPaused);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        backgroundColor: storeGreen,
        content: Text(_isMuted
            ? 'Story video audio muted.'
            : 'Story audio enabled (where supported).'),
      ),
    );
  }

  void _openStoryDetail(HeroFarmStory story) {
    _setStoryPaused(true);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Media Header
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(StoreLayout.radius),
                    ),
                    child: SizedBox(
                      height: 220,
                      width: double.infinity,
                      child: Image.asset(
                        story.posterPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: storeWarm,
                          child: const Icon(Icons.yard_outlined,
                              size: 56, color: storeGreen),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 14, color: storeAmber),
                          const SizedBox(width: 6),
                          Text(
                            story.storyBadge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),

              // Narrative Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 15, color: storeMuted),
                        const SizedBox(width: 6),
                        Text(
                          story.location,
                          style: const TextStyle(
                            fontSize: 12,
                            color: storeMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: storeGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      story.caption,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff556b2f),
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      story.detailStory,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: Color(0xff2d3748),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: storeAmber,
                            foregroundColor: storeGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            context.go('/shop');
                          },
                          child: const Text(
                            'Shop Farm Products',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) _setStoryPaused(false);
    });
  }

  // --------------------------------------------------------------------------
  // Main Build: 50/50 Desktop Split vs Stacked Mobile
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isDesktop = widget.screenWidth >= 860;
    const desktopHeight = 195.0;

    if (isDesktop) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 205.0,
        ),
        child: SizedBox(
          width: double.infinity,
          height: desktopHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left 50%: Product Showcase Carousel
              Expanded(
                flex: 50,
                child: _buildProductShowcase(isDesktop: true),
              ),
              const SizedBox(width: 14),

              // Right 50%: Farm Story Showcase Carousel
              Expanded(
                flex: 50,
                child: _buildFarmStoryShowcase(isDesktop: true),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile / Tablet stacked view: sleek strip (150px each)
    const mobilePanelHeight = 150.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: mobilePanelHeight,
          child: _buildProductShowcase(isDesktop: false),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: mobilePanelHeight,
          child: _buildFarmStoryShowcase(isDesktop: false),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // LEFT 50% — PRODUCT SHOWCASE CAROUSEL
  // --------------------------------------------------------------------------
  Widget _buildProductShowcase({required bool isDesktop}) {
    if (widget.productSlides.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfffcfbf8),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Page View of Products
          PageView.builder(
            controller: _productController,
            itemCount: widget.productSlides.length,
            onPageChanged: (index) {
              setState(() => _currentProduct = index);
            },
            itemBuilder: (context, index) {
              final slide = widget.productSlides[index];
              return _buildProductSlide(slide, isDesktop: isDesktop);
            },
          ),

          // Previous Arrow (Left)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavArrow(
                icon: Icons.chevron_left,
                onTap: _prevProduct,
                tooltip: 'Previous product',
              ),
            ),
          ),

          // Next Arrow (Right)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _buildNavArrow(
                icon: Icons.chevron_right,
                onTap: _nextProduct,
                tooltip: 'Next product',
              ),
            ),
          ),

          // Carousel Dots Indicator (Bottom Center)
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.productSlides.length, (i) {
                final isActive = i == _currentProduct;
                return GestureDetector(
                  onTap: () {
                    _productController.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                    );
                    _startProductAutoSlide();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: isActive ? 16 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isActive ? storeAmber : storeBorder,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSlide(HeroProductSlide slide, {required bool isDesktop}) {
    final matchedProduct = defaultMilterraProducts
        .where((p) => p.id == slide.id)
        .firstOrNull;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 60 : 48,
        isDesktop ? 8 : 6,
        isDesktop ? 22 : 14,
        isDesktop ? 10 : 6,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left text column (concise typography for half-height strip)
                Expanded(
                  flex: 47,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Quiet Category Eyebrow
                      Text(
                        slide.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: storeAmber,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Product Name
                      Text(
                        slide.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: storeGreen,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),

                      // Short benefit highlight (fills space with authentic context)
                      if (slide.shortBenefit != null) ...[
                        Text(
                          slide.shortBenefit!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xff4b5563),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Pack size & Price in a clean single line
                      Text(
                        '${slide.packSize}  ·  ${storeMoney(slide.price)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: storeOrange,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // "Shop now" CTA button
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          minimumSize: const Size(0, 28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          if (slide.targetRoute.startsWith('/')) {
                            context.go(slide.targetRoute);
                          } else if (widget.onExploreCategory != null) {
                            widget.onExploreCategory!(slide.category);
                          }
                        },
                        child: const Text(
                          'Shop now →',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Right product image column (elevated pedestal with soft glow)
                Expanded(
                  flex: 53,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 180,
                        maxWidth: 190,
                      ),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0a000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        slide.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => matchedProduct != null
                            ? ProductArtwork(
                                product: matchedProduct,
                                showCaption: false,
                              )
                            : const Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: storeMuted,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              // Mobile View: Horizontal compact strip layout
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slide.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: storeAmber,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        slide.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: storeGreen,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${slide.packSize}  ·  ${storeMoney(slide.price)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: storeOrange,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          minimumSize: const Size(0, 26),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => context.go(slide.targetRoute),
                        child: const Text(
                          'Shop now →',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 48,
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 125,
                        maxWidth: 130,
                      ),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        slide.imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => matchedProduct != null
                            ? ProductArtwork(
                                product: matchedProduct,
                                showCaption: false,
                              )
                            : const Icon(
                                Icons.inventory_2_outlined,
                                size: 48,
                                color: storeMuted,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --------------------------------------------------------------------------
  // RIGHT 50% — FARM STORY SHOWCASE CAROUSEL
  // --------------------------------------------------------------------------
  Widget _buildFarmStoryShowcase({required bool isDesktop}) {
    if (widget.farmStories.isEmpty) return const SizedBox.shrink();

    return MouseRegion(
      onEnter: (_) => _setStoryPaused(true),
      onExit: (_) => _setStoryPaused(false),
      child: GestureDetector(
        onTap: _toggleStoryPause,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xff12231c),
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0a000000),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Page View for stories
              PageView.builder(
                controller: _storyController,
                itemCount: widget.farmStories.length,
                onPageChanged: (index) {
                  setState(() => _currentStory = index);
                  _startStoryProgress();
                },
                itemBuilder: (context, index) {
                  final story = widget.farmStories[index];
                  return _buildStorySlide(story, isDesktop: isDesktop);
                },
              ),

              // Animated Top Story Progress Bar (7.5s)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _storyProgressCtrl,
                  builder: (context, _) {
                    return LinearProgressIndicator(
                      value: _storyProgressCtrl.value,
                      minHeight: 3.5,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(storeAmber),
                    );
                  },
                ),
              ),

              // Top-right Audio Toggle
              Positioned(
                top: 8,
                right: 10,
                child: IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 15,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    padding: const EdgeInsets.all(5),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: _toggleMute,
                  tooltip: _isMuted ? 'Unmute video' : 'Mute video',
                ),
              ),

              // Previous Arrow (Left)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavArrow(
                    icon: Icons.chevron_left,
                    onTap: _prevStory,
                    tooltip: 'Previous story',
                    isDark: true,
                  ),
                ),
              ),

              // Next Arrow (Right)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildNavArrow(
                    icon: Icons.chevron_right,
                    onTap: () => _nextStory(animate: true),
                    tooltip: 'Next story',
                    isDark: true,
                  ),
                ),
              ),

              // Bottom Dots Indicator
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.farmStories.length, (i) {
                    final isActive = i == _currentStory;
                    return GestureDetector(
                      onTap: () {
                        _storyController.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                        );
                        _startStoryProgress();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: isActive ? 16 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isActive
                              ? storeAmber
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorySlide(HeroFarmStory story, {required bool isDesktop}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Media: Authentic farm photography (panoramic & unzoomed)
        story.posterPath.startsWith('http')
            ? Image.network(
                story.posterPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Image.asset(
                  StoreImages.hero,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => _buildStorySlideFallback(story),
                ),
              )
            : Image.asset(
                story.posterPath,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Image.asset(
                  StoreImages.hero,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => _buildStorySlideFallback(story),
                ),
              ),

        // High-contrast deep gradient overlay ensuring white typography remains 100% readable over every photo
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.88),
              ],
              stops: const [0.0, 0.25, 0.60, 1.0],
            ),
          ),
        ),

        // Story Overlay Content with safe left/right clearance from carousel arrows
        Positioned(
          left: isDesktop ? 54 : 44,
          right: isDesktop ? 40 : 32,
          bottom: isDesktop ? 16 : 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quiet Category Eyebrow
              Text(
                story.storyBadge.toUpperCase(),
                style: TextStyle(
                  fontSize: isDesktop ? 9.5 : 8.5,
                  fontWeight: FontWeight.w700,
                  color: storeAmber,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),

              // Powerful Story Title
              Text(
                story.title,
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 13.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      offset: Offset(0, 1.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Harmonized "Explore story →" Action Button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: storeAmber,
                  foregroundColor: storeGreen,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 13 : 11,
                    vertical: isDesktop ? 5 : 4,
                  ),
                  minimumSize: const Size(0, 26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _openStoryDetail(story),
                icon: Icon(Icons.play_circle_fill_outlined,
                    size: isDesktop ? 13 : 11, color: storeGreen),
                label: Text(
                  'Explore story →',
                  style: TextStyle(
                    fontSize: isDesktop ? 11 : 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorySlideFallback(HeroFarmStory story) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF143025),
            Color(0xFF1F4434),
            Color(0xFF2D5A45),
            Color(0xFF10281E),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.grass_rounded,
                size: 38,
                color: Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              story.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Navigation Arrow Helper Button
  // --------------------------------------------------------------------------
  Widget _buildNavArrow({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isDark = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : storeWhite.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : storeBorder,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1a000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white : storeGreen,
          ),
        ),
      ),
    );
  }
}
