import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/hero_showcase_config.dart';
import 'store_design.dart';

/// Standalone immersive Farm Story Showcase Carousel:
/// Features authentic farm video/photo documentaries, herd care, traditional Bilona
/// churning in Anand & Nashik, audio toggle, progress indicator, and interactive story modals.
class FarmStoryShowcase extends StatefulWidget {
  const FarmStoryShowcase({
    super.key,
    required this.screenWidth,
    this.height,
    this.farmStories = defaultHeroFarmStories,
    this.autoPlay = true,
  });

  final double screenWidth;
  final double? height;
  final List<HeroFarmStory> farmStories;
  final bool autoPlay;

  /// Open full-screen storytelling modal for any given farm story
  static void showStoryDetail(BuildContext context, HeroFarmStory story,
      {VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 580,
            maxHeight: MediaQuery.sizeOf(ctx).height - 48,
          ),
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
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
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
                        child: story.posterPath.startsWith('http')
                            ? Image.network(
                                story.posterPath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  StoreImages.hero,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
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
      ),
    ).then((_) {
      if (onDismiss != null) onDismiss();
    });
  }

  @override
  State<FarmStoryShowcase> createState() => _FarmStoryShowcaseState();
}

class _FarmStoryShowcaseState extends State<FarmStoryShowcase>
    with SingleTickerProviderStateMixin {
  late final PageController _storyController;
  int _currentStory = 0;
  bool _isStoryPaused = false;
  bool _isMuted = true;

  late final AnimationController _storyProgressCtrl;

  @override
  void initState() {
    super.initState();
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

    if (widget.autoPlay) {
      _startStoryProgress();
    }
  }

  @override
  void dispose() {
    _storyProgressCtrl.dispose();
    _storyController.dispose();
    super.dispose();
  }

  void _startStoryProgress() {
    if (!widget.autoPlay) return;
    _storyProgressCtrl.reset();
    if (!_isStoryPaused) {
      _storyProgressCtrl.forward();
    }
  }

  void _nextStory({bool animate = true}) {
    if (widget.farmStories.isEmpty) return;
    final next = (_currentStory + 1) % widget.farmStories.length;
    if (animate && _storyController.hasClients) {
      _storyController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else if (_storyController.hasClients) {
      _storyController.jumpToPage(next);
    }
    setState(() => _currentStory = next);
    _startStoryProgress();
  }

  void _prevStory() {
    if (widget.farmStories.isEmpty) return;
    final prev = (_currentStory - 1 + widget.farmStories.length) %
        widget.farmStories.length;
    _storyController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentStory = prev);
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
        duration: const Duration(seconds: 2),
        content: Text(_isMuted
            ? 'Story video audio muted.'
            : 'Story audio enabled (where supported).'),
      ),
    );
  }

  void _openDetail(HeroFarmStory story) {
    _setStoryPaused(true);
    FarmStoryShowcase.showStoryDetail(
      context,
      story,
      onDismiss: () {
        if (mounted) _setStoryPaused(false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.farmStories.isEmpty) return const SizedBox.shrink();
    final isDesktop = widget.screenWidth >= 860;
    final panelHeight = widget.height ?? (isDesktop ? 220.0 : 200.0);

    return SizedBox(
      height: panelHeight,
      width: double.infinity,
      child: MouseRegion(
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
                    ),
                  ),
                ),

                // Story Dots Indicator (Bottom Center)
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
      ),
    );
  }

  Widget _buildStorySlide(HeroFarmStory story, {required bool isDesktop}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Media: Authentic farm photography
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

        // Deep gradient overlay ensuring high text readability
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
          left: isDesktop ? 64 : 44,
          right: isDesktop ? 64 : 32,
          bottom: isDesktop ? 16 : 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quiet Category Eyebrow
              Text(
                story.storyBadge.toUpperCase(),
                style: TextStyle(
                  fontSize: isDesktop ? 10 : 8.5,
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
                  fontSize: isDesktop ? 17 : 13.5,
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

              // "Explore story →" Action Button
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: storeAmber,
                  foregroundColor: storeGreen,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 14 : 11,
                    vertical: isDesktop ? 6 : 4,
                  ),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => _openDetail(story),
                icon: Icon(Icons.play_circle_fill_outlined,
                    size: isDesktop ? 14 : 11, color: storeGreen),
                label: Text(
                  'Explore story →',
                  style: TextStyle(
                    fontSize: isDesktop ? 11.5 : 10,
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
        child: Icon(
          Icons.nature_people_outlined,
          size: 64,
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  Widget _buildNavArrow({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.45),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
