import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/merchandising_provider.dart';
import 'store_design.dart';

class StorefrontHighlightStrip extends ConsumerStatefulWidget {
  const StorefrontHighlightStrip({super.key, this.currentProductId});

  final String? currentProductId;

  @override
  ConsumerState<StorefrontHighlightStrip> createState() =>
      _StorefrontHighlightStripState();
}

class _StorefrontHighlightStripState extends ConsumerState<StorefrontHighlightStrip>
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

        // Resolve crisp ghee jar image
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

        return Container(
          width: double.infinity,
          color: const Color(0xfffffdfa),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(-1.5 + 3.0 * shimmerVal, -0.5),
                          end: Alignment(-0.3 + 3.0 * shimmerVal, 0.5),
                          colors: const [
                            Color(0xfffffbeb),
                            Color(0xfffef3c7),
                            Color(0xfffff7ed),
                            Color(0xfffffbeb),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color.lerp(
                            const Color(0xfff59e0b),
                            const Color(0xffea580c),
                            pulseVal,
                          )!.withValues(alpha: 0.6 + 0.35 * pulseVal),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xfff59e0b)
                                .withValues(alpha: 0.12 + 0.1 * pulseVal),
                            blurRadius: 10 + 4 * pulseVal,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Small Crisp Ghee Jar with subtle bobbing animation
                          Transform.translate(
                            offset: Offset(0, -1.5 * pulseVal),
                            child: Container(
                              width: isMobile ? 48 : 56,
                              height: isMobile ? 48 : 54,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xfff59e0b)
                                      .withValues(alpha: 0.4),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xffd97706)
                                        .withValues(alpha: 0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: StoreMediaImage(
                                  source: resolvedImage,
                                  fit: BoxFit.contain,
                                  fallbackIconSize: 24,
                                  fallbackColor: storeOrange,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Titles & Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    // Animated live pulsing beacon dot
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xffea580c),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xffea580c)
                                                .withValues(alpha: 0.6),
                                            blurRadius: 4 + 4 * pulseVal,
                                            spreadRadius: 1 + 2 * pulseVal,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      (placement.badge ?? 'NEW LAUNCH PREVIEW')
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xffc2410c),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: .8,
                                      ),
                                    ),
                                    if (!isMobile) ...[
                                      const SizedBox(width: 8),
                                      const Text(
                                        '•',
                                        style: TextStyle(
                                          color: Color(0xfff59e0b),
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
                                  ],
                                ),
                                if (isMobile) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    placement.headline,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: storeDarkGreenNav,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Text(
                                  placement.subheadline ?? product.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: storeMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Discount tag
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
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          // Price
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                product.isConcept
                                    ? 'Concept'
                                    : storeMoney(product.price),
                                style: const TextStyle(
                                  color: storeDarkGreenNav,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (compareAt != null && discount != null)
                                Text(
                                  storeMoney(compareAt),
                                  style: const TextStyle(
                                    color: storeMuted,
                                    fontSize: 10,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(width: 10),

                          // Eye-catching CTA Pill Button with moving arrow
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : 12,
                              vertical: isMobile ? 5 : 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xff15803d), Color(0xff166534)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xff15803d)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isMobile) ...[
                                  const Text(
                                    'Order Now',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Transform.translate(
                                  offset: Offset(2 * pulseVal, 0),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
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
