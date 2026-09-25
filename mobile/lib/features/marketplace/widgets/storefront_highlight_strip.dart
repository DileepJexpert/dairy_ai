import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/product_models.dart';
import '../providers/merchandising_provider.dart';
import 'store_design.dart';

class StorefrontHighlightStrip extends ConsumerStatefulWidget {
  const StorefrontHighlightStrip({super.key, this.currentProductId});

  final String? currentProductId;

  @override
  ConsumerState<StorefrontHighlightStrip> createState() =>
      _StorefrontHighlightStripState();
}

class _CampaignTheme {
  const _CampaignTheme({
    required this.defaultBadge,
    required this.icon,
    required this.backgroundGradient,
    required this.borderColor,
    required this.borderHighlightColor,
    required this.badgeBg,
    required this.badgeTextColor,
    required this.glowColor,
    required this.ctaGradientStart,
    required this.ctaGradientEnd,
    required this.ctaText,
  });

  final String defaultBadge;
  final IconData icon;
  final List<Color> backgroundGradient;
  final Color borderColor;
  final Color borderHighlightColor;
  final Color badgeBg;
  final Color badgeTextColor;
  final Color glowColor;
  final Color ctaGradientStart;
  final Color ctaGradientEnd;
  final String ctaText;

  static _CampaignTheme resolve(StorefrontPlacement placement) {
    final badge = (placement.badge ?? '').toLowerCase();
    final headline = placement.headline.toLowerCase();
    final combined = '$badge $headline';

    if (combined.contains('deal') ||
        combined.contains('sale') ||
        combined.contains('offer') ||
        combined.contains('discount') ||
        combined.contains('save') ||
        combined.contains('%')) {
      return const _CampaignTheme(
        defaultBadge: 'LIMITED DEAL',
        icon: Icons.local_fire_department_rounded,
        backgroundGradient: [
          Color(0xfffff7ed),
          Color(0xfffed7aa),
          Color(0xfffee2e2),
          Color(0xfffff7ed),
        ],
        borderColor: Color(0xffea580c),
        borderHighlightColor: Color(0xffdc2626),
        badgeBg: Color(0xffdc2626),
        badgeTextColor: Colors.white,
        glowColor: Color(0xffea580c),
        ctaGradientStart: Color(0xffea580c),
        ctaGradientEnd: Color(0xffc2410c),
        ctaText: 'Claim Deal',
      );
    }

    if (combined.contains('new') ||
        combined.contains('launch') ||
        combined.contains('fresh') ||
        combined.contains('arrival') ||
        combined.contains('preview')) {
      return const _CampaignTheme(
        defaultBadge: 'NEW LAUNCH',
        icon: Icons.auto_awesome_rounded,
        backgroundGradient: [
          Color(0xfff0fdf4),
          Color(0xffdcfce7),
          Color(0xfffef9c3),
          Color(0xfff0fdf4),
        ],
        borderColor: Color(0xff16a34a),
        borderHighlightColor: Color(0xff15803d),
        badgeBg: Color(0xff15803d),
        badgeTextColor: Colors.white,
        glowColor: Color(0xff22c55e),
        ctaGradientStart: Color(0xff15803d),
        ctaGradientEnd: Color(0xff166534),
        ctaText: 'Explore Now',
      );
    }

    if (combined.contains('exclusive') ||
        combined.contains('festive') ||
        combined.contains('special') ||
        combined.contains('vip') ||
        combined.contains('reserve')) {
      return const _CampaignTheme(
        defaultBadge: 'EXCLUSIVE SELECTION',
        icon: Icons.star_rounded,
        backgroundGradient: [
          Color(0xfffdf4ff),
          Color(0xfffae8ff),
          Color(0xfffef3c7),
          Color(0xfffdf4ff),
        ],
        borderColor: Color(0xffc026d3),
        borderHighlightColor: Color(0xffa21caf),
        badgeBg: Color(0xffa21caf),
        badgeTextColor: Colors.white,
        glowColor: Color(0xffd946ef),
        ctaGradientStart: Color(0xff9333ea),
        ctaGradientEnd: Color(0xff6b21a8),
        ctaText: 'Discover',
      );
    }

    return const _CampaignTheme(
      defaultBadge: 'FEATURED SELECTION',
      icon: Icons.verified_rounded,
      backgroundGradient: [
        Color(0xfffffbeb),
        Color(0xfffef3c7),
        Color(0xfffff7ed),
        Color(0xfffffbeb),
      ],
      borderColor: Color(0xfff59e0b),
      borderHighlightColor: Color(0xffea580c),
      badgeBg: Color(0xffd97706),
      badgeTextColor: Colors.white,
      glowColor: Color(0xfff59e0b),
      ctaGradientStart: Color(0xffb45309),
      ctaGradientEnd: Color(0xff92400e),
      ctaText: 'Shop Now',
    );
  }
}

class _StorefrontHighlightStripState
    extends ConsumerState<StorefrontHighlightStrip>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerController;
  late final AnimationController _pulseController;

  bool get _isTesting =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (!_isTesting) {
      _shimmerController.repeat();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildFlashingBadge({
    required _CampaignTheme theme,
    required String text,
    required double pulseVal,
    double? maxWidth,
  }) {
    final badgeContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: 1.0 + 0.15 * pulseVal,
          child: Icon(theme.icon, size: 11, color: theme.badgeTextColor),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.badgeTextColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: theme.badgeBg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: theme.glowColor.withValues(alpha: 0.35 + 0.35 * pulseVal),
            blurRadius: 5 + 5 * pulseVal,
            spreadRadius: 0.5 + 1.0 * pulseVal,
          ),
        ],
      ),
      child: maxWidth != null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: badgeContent,
            )
          : badgeContent,
    );
  }

  Widget? _buildEndsAtChip(_CampaignTheme theme, DateTime? endsAt) {
    if (endsAt == null) return null;
    final diff = endsAt.difference(DateTime.now());
    if (diff.isNegative) return null;

    final String timeStr;
    if (diff.inDays > 0) {
      timeStr = '${diff.inDays}d left';
    } else if (diff.inHours > 0) {
      timeStr = '${diff.inHours}h ${diff.inMinutes.remainder(60)}m left';
    } else if (diff.inMinutes > 0) {
      timeStr = '${diff.inMinutes}m left';
    } else {
      timeStr = 'Ending soon';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 10, color: theme.borderColor),
          const SizedBox(width: 3),
          Text(
            timeStr,
            style: TextStyle(
              color: theme.borderColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildTickerSpans({
    required StorefrontPlacement placement,
    required Product product,
    required int? discount,
    required _CampaignTheme theme,
  }) {
    const sep = '     ✦     ';
    const sepStyle = TextStyle(
      color: Color(0xff94a3b8),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final spans = <InlineSpan>[];

    void addSegment({
      required String icon,
      required String label,
      required String value,
      Color? labelColor,
    }) {
      spans.add(TextSpan(text: '$icon '));
      spans.add(TextSpan(
        text: '$label: ',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: labelColor ?? theme.badgeBg,
          letterSpacing: 0.2,
        ),
      ));
      spans.add(TextSpan(
        text: value,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: storeDarkGreenNav,
        ),
      ));
      spans.add(const TextSpan(text: sep, style: sepStyle));
    }

    if (discount != null) {
      addSegment(
        icon: '⚡',
        label: 'LIMITED OFFER',
        value: 'Extra $discount% Off Today',
        labelColor: const Color(0xffdc2626),
      );
    } else {
      addSegment(
        icon: '✨',
        label: 'FEATURED RESERVE',
        value: 'Fresh Small Batch Harvest',
        labelColor: theme.badgeBg,
      );
    }

    if (placement.subheadline != null &&
        placement.subheadline!.trim().isNotEmpty) {
      addSegment(
        icon: '🏺',
        label: 'VEDIC METHOD',
        value: placement.subheadline!.trim(),
        labelColor: const Color(0xffb45309),
      );
    } else {
      addSegment(
        icon: '🏺',
        label: 'AUTHENTIC BILONA',
        value: 'Hand-Churned in Earthen Pots from Cultured Curd',
        labelColor: const Color(0xffb45309),
      );
    }

    addSegment(
      icon: '🐄',
      label: '100% PURE A2',
      value: 'Direct from Free-Grazing Indigenous Sahiwal Cows',
      labelColor: const Color(0xff15803d),
    );

    addSegment(
      icon: '🌿',
      label: 'VEDIC HERITAGE',
      value: 'Certified Authentic · Golden Granular Danedaar Texture',
      labelColor: const Color(0xff047857),
    );

    addSegment(
      icon: '🚚',
      label: 'EXPRESS DISPATCH',
      value: 'Dispatched within 24 Hours with Real-Time Tracking',
      labelColor: const Color(0xff0284c7),
    );

    addSegment(
      icon: '⭐',
      label: 'PURITY GUARANTEE',
      value: 'Zero Additives, Preservatives or Adulterants',
      labelColor: const Color(0xffd97706),
    );

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final placements = ref.watch(storefrontPlacementsProvider);

    return placements.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final alternatives = items
            .where((item) => item.productId != widget.currentProductId)
            .toList();
        final placement =
            alternatives.isNotEmpty ? alternatives.first : items.first;
        final product = placement.product;
        final compareAt = product.compareAtPrice;
        final discount = compareAt != null && compareAt > product.price
            ? ((compareAt - product.price) / compareAt * 100).round()
            : null;

        final theme = _CampaignTheme.resolve(placement);
        final badgeText = (placement.badge?.trim().isNotEmpty == true)
            ? placement.badge!.trim().toUpperCase()
            : theme.defaultBadge;

        // Resolve crisp ghee jar / product image
        String resolvedImage = 'assets/store/cow-ghee.png';
        if (product.media.isNotEmpty &&
            product.media.first.trim().isNotEmpty &&
            !product.media.first.contains('null')) {
          resolvedImage = product.media.first.trim();
        } else {
          final artwork = StoreImages.productArtwork(product);
          if (artwork != null && artwork.isNotEmpty) {
            resolvedImage = artwork;
          }
        }

        final isMobile = MediaQuery.sizeOf(context).width < StoreLayout.mobile;
        final endsAtChip = _buildEndsAtChip(theme, placement.endsAt);
        final tickerSpans = _buildTickerSpans(
          placement: placement,
          product: product,
          discount: discount,
          theme: theme,
        );

        return Container(
          width: double.infinity,
          color: const Color(0xfffffdfa),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
              child: AnimatedBuilder(
                animation: Listenable.merge([_shimmerController, _pulseController]),
                builder: (context, child) {
                  final shimmerVal = _shimmerController.value;
                  final pulseVal = _pulseController.value;

                  return InkWell(
                    onTap: () => context.go('/shop/product/${product.id}'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 16,
                        vertical: isMobile ? 6 : 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.5 + 3.0 * shimmerVal, -0.5),
                          end: Alignment(-0.3 + 3.0 * shimmerVal, 0.5),
                          colors: theme.backgroundGradient,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color.lerp(
                            theme.borderColor,
                            theme.borderHighlightColor,
                            pulseVal,
                          )!.withValues(alpha: 0.6 + 0.35 * pulseVal),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.glowColor
                                .withValues(alpha: 0.12 + 0.1 * pulseVal),
                            blurRadius: 10 + 4 * pulseVal,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Wide eye-catching Product Image (width enlarged, compact height)
                          Transform.translate(
                            offset: Offset(0, -1.5 * pulseVal),
                            child: Container(
                              width: isMobile ? 74 : 100,
                              height: isMobile ? 48 : 52,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Color.lerp(
                                    theme.borderColor,
                                    theme.borderHighlightColor,
                                    pulseVal,
                                  )!.withValues(alpha: 0.5 + 0.35 * pulseVal),
                                  width: 1.3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.glowColor
                                        .withValues(alpha: 0.18 + 0.12 * pulseVal),
                                    blurRadius: 6 + 3 * pulseVal,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: StoreMediaImage(
                                  source: resolvedImage,
                                  fit: BoxFit.cover,
                                  fallbackIconSize: isMobile ? 22 : 26,
                                  fallbackColor: theme.badgeBg,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 10 : 14),

                          // Titles, Campaign Badges & Moving Ticker
                          if (isMobile)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      _buildFlashingBadge(
                                        theme: theme,
                                        text: badgeText,
                                        pulseVal: pulseVal,
                                        maxWidth: 190,
                                      ),
                                      if (endsAtChip != null) endsAtChip,
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    placement.headline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: storeDarkGreenNav,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  SizedBox(
                                    height: 14,
                                    child: _StorefrontMarqueeTicker(
                                      spans: tickerSpans,
                                      speed: 28.0,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 5,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        product.isConcept
                                            ? 'Concept'
                                            : storeMoney(product.price),
                                        style: const TextStyle(
                                          color: storeDarkGreenNav,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      if (compareAt != null && discount != null) ...[
                                        Text(
                                          storeMoney(compareAt),
                                          style: const TextStyle(
                                            color: storeMuted,
                                            fontSize: 10,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xffdc2626),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: Text(
                                            '-$discount%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      _buildFlashingBadge(
                                        theme: theme,
                                        text: badgeText,
                                        pulseVal: pulseVal,
                                        maxWidth: 240,
                                      ),
                                      if (endsAtChip != null) ...[
                                        const SizedBox(width: 8),
                                        endsAtChip,
                                      ],
                                      const SizedBox(width: 8),
                                      const Text(
                                        '•',
                                        style: TextStyle(
                                          color: Color(0xff9ca3af),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          placement.headline,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: storeDarkGreenNav,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xfffef3c7),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(
                                            color: const Color(0xfff59e0b)
                                                .withValues(alpha: 0.4),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.bolt_rounded,
                                              size: 10,
                                              color: Color(0xffd97706),
                                            ),
                                            SizedBox(width: 2),
                                            Text(
                                              'LIVE HIGHLIGHTS',
                                              style: TextStyle(
                                                color: Color(0xffb45309),
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SizedBox(
                                          height: 16,
                                          child: _StorefrontMarqueeTicker(
                                            spans: tickerSpans,
                                            speed: 36.0,
                                            fontSize: 11.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                          // Desktop Price Column
                          if (!isMobile) ...[
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (discount != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xffdc2626),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '-$discount%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      product.isConcept
                                          ? 'Concept'
                                          : storeMoney(product.price),
                                      style: const TextStyle(
                                        color: storeDarkGreenNav,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                if (compareAt != null && discount != null)
                                  Text(
                                    storeMoney(compareAt),
                                    style: const TextStyle(
                                      color: storeMuted,
                                      fontSize: 11,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                          ],

                          SizedBox(width: isMobile ? 8 : 12),

                          // Dynamic CTA Action Button with animated sliding arrow
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 10 : 14,
                              vertical: isMobile ? 7 : 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.ctaGradientStart,
                                  theme.ctaGradientEnd,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.ctaGradientStart
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isMobile
                                      ? (theme.ctaText.contains('Deal') ? 'Deal' : 'Shop')
                                      : theme.ctaText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Transform.translate(
                                  offset: Offset(2 * pulseVal, 0),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: isMobile ? 12 : 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Continuous smooth horizontal marquee ticker tape
/// Soft-edge gradient shader mask, synchronous TextPainter measurement,
/// and pause-on-hover so customers can comfortably read the live offers.
class _StorefrontMarqueeTicker extends StatefulWidget {
  final List<InlineSpan> spans;
  final double speed;
  final double fontSize;

  const _StorefrontMarqueeTicker({
    required this.spans,
    this.speed = 35.0,
    this.fontSize = 11.0,
  });

  @override
  State<_StorefrontMarqueeTicker> createState() =>
      _StorefrontMarqueeTickerState();
}

class _StorefrontMarqueeTickerState extends State<_StorefrontMarqueeTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _measuredWidth = 0.0;
  bool _isHovered = false;

  bool get _isTesting =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _measureAndAnimate();
  }

  @override
  void didUpdateWidget(covariant _StorefrontMarqueeTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spans != widget.spans ||
        oldWidget.fontSize != widget.fontSize ||
        oldWidget.speed != widget.speed) {
      _measureAndAnimate();
    }
  }

  void _measureAndAnimate() {
    final textPainter = TextPainter(
      text: TextSpan(
        children: widget.spans,
        style: TextStyle(
          fontSize: widget.fontSize,
          fontFamily: 'Inter',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    _measuredWidth = textPainter.width;
    if (_measuredWidth <= 0) {
      _measuredWidth = 600.0;
    }

    final durationSeconds = (_measuredWidth / widget.speed).clamp(8.0, 120.0);
    _controller.duration = Duration(
      milliseconds: (durationSeconds * 1000).round(),
    );

    if (!_isTesting && !_isHovered) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isTesting || _measuredWidth <= 0) {
      return Text.rich(
        TextSpan(children: widget.spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: widget.fontSize,
          color: storeDarkGreenNav,
        ),
      );
    }

    final tripleSpans = <InlineSpan>[
      ...widget.spans,
      ...widget.spans,
      ...widget.spans,
    ];

    return MouseRegion(
      onEnter: (_) {
        if (_isTesting) return;
        _isHovered = true;
        _controller.stop();
      },
      onExit: (_) {
        if (_isTesting) return;
        _isHovered = false;
        _controller.repeat();
      },
      child: ClipRect(
        child: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.02, 0.98, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final offset = -_controller.value * _measuredWidth;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 0.0,
              maxWidth: double.infinity,
              child: Text.rich(
                TextSpan(children: tripleSpans),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  color: storeDarkGreenNav,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
