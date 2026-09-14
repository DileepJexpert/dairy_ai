import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/merchandising_provider.dart';
import 'store_design.dart';

class StorefrontHighlightStrip extends ConsumerWidget {
  const StorefrontHighlightStrip({super.key, this.currentProductId});

  final String? currentProductId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placements = ref.watch(storefrontPlacementsProvider);
    return placements.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final alternatives =
            items.where((item) => item.productId != currentProductId).toList();
        final placement =
            alternatives.isNotEmpty ? alternatives.first : items.first;
        final product = placement.product;
        final compareAt = product.compareAtPrice;
        final discount = compareAt != null && compareAt > product.price
            ? ((compareAt - product.price) / compareAt * 100).round()
            : null;
        final imageSource = product.media.isNotEmpty
            ? product.media.first
            : StoreImages.productArtwork(product);

        return Container(
          width: double.infinity,
          color: storeWhite,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
              child: InkWell(
                onTap: () => context.go('/shop/product/${product.id}'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff7ef),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: storeOrange.withValues(alpha: .55)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 58,
                        height: 48,
                        child: StoreMediaImage(
                          source: imageSource,
                          fallbackIconSize: 28,
                          fallbackColor: storeGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if ((placement.badge ?? '').isNotEmpty)
                                  Text(
                                    placement.badge!.toUpperCase(),
                                    style: const TextStyle(
                                      color: storeOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .7,
                                    ),
                                  ),
                                Text(
                                  placement.headline,
                                  style: const TextStyle(
                                    color: storeGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              placement.subheadline ?? product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: storeMuted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (discount != null)
                        Text(
                          '-$discount%',
                          style: const TextStyle(
                            color: storeError,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            product.isConcept
                                ? 'Concept preview'
                                : storeMoney(product.price),
                            style: const TextStyle(
                              color: storeGreen,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (compareAt != null && discount != null)
                            Text(
                              'M.R.P. ${storeMoney(compareAt)}',
                              style: const TextStyle(
                                color: storeMuted,
                                fontSize: 10,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: storeGreen),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
