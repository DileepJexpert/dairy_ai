import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cart/providers/wishlist_provider.dart';
import '../models/product_models.dart';
import 'store_design.dart';

List<List<Product>> storeProductGroups(List<Product> products) {
  final groups = <String, List<Product>>{};
  for (final p in products) {
    groups
        .putIfAbsent(p.packSize == null ? p.id : p.familyKey, () => [])
        .add(p);
  }
  return groups.values.toList();
}

class StoreProductCard extends StatefulWidget {
  const StoreProductCard(
      {super.key,
      required this.packs,
      required this.onOpen,
      required this.onAdd,
      this.busyIds = const {},
      this.compact = false});
  final List<Product> packs;
  final ValueChanged<Product> onOpen, onAdd;
  final Set<String> busyIds;
  final bool compact;
  @override
  State<StoreProductCard> createState() => _StoreProductCardState();
}

class _StoreProductCardState extends State<StoreProductCard> {
  String? _selected;
  @override
  Widget build(BuildContext context) {
    final p = widget.packs
        .firstWhere((p) => p.id == _selected, orElse: () => widget.packs.first);
    final busy = widget.busyIds.contains(p.id);
    final discountPercent = (p.compareAtPrice != null &&
            p.compareAtPrice! > p.price)
        ? (((p.compareAtPrice! - p.price) / p.compareAtPrice!) * 100).round()
        : 0;

    return Container(
        decoration: StoreLayout.panel,
        child: Material(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(builder: (context, constraints) {
              final isBounded = constraints.hasBoundedHeight;

              Widget imageSection;
              if (isBounded) {
                imageSection = Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InkWell(
                        onTap: () => widget.onOpen(p),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ProductArtwork(product: p),
                        ),
                      ),
                      if (p.isConcept)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: storeGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                'Concept Preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (p.badge != null && p.badge!.isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: p.badge!.toUpperCase().contains('BEST')
                                  ? const Color(0xff232f3e)
                                  : (p.badge!.toUpperCase().contains('DEAL')
                                      ? const Color(0xffcc0c39)
                                      : storeGreen),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              p.badge!,
                              style: TextStyle(
                                color: p.badge!.toUpperCase().contains('BEST')
                                    ? const Color(0xffff9900)
                                    : storeWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: WishlistHeartButton(product: p),
                      ),
                    ],
                  ),
                );
              } else {
                imageSection = Stack(
                  children: [
                    InkWell(
                      onTap: () => widget.onOpen(p),
                      child: AspectRatio(
                        aspectRatio: StoreLayout.productImageAspectRatio,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ProductArtwork(product: p),
                        ),
                      ),
                    ),
                    if (p.isConcept)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: storeGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                              'Concept Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (p.badge != null && p.badge!.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: p.badge!.toUpperCase().contains('BEST')
                                ? const Color(0xff232f3e)
                                : (p.badge!.toUpperCase().contains('DEAL')
                                    ? const Color(0xffcc0c39)
                                    : storeGreen),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            p.badge!,
                            style: TextStyle(
                              color: p.badge!.toUpperCase().contains('BEST')
                                  ? const Color(0xffff9900)
                                  : storeWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: WishlistHeartButton(product: p),
                    ),
                  ],
                );
              }

              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    imageSection,
                    Padding(
                        padding: StoreLayout.productCardPadding,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InkWell(
                                  key: ValueKey('catalogue-open-${p.id}'),
                                  onTap: () => widget.onOpen(p),
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(minHeight: 44),
                                      child: Text(p.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              height: 1.35,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xff0f1111))))),
                              if (!p.isConcept &&
                                  !p.isStaticSnapshot &&
                                  p.rating > 0 &&
                                  p.reviewCount > 0) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    AmazonRatingStars(
                                      rating: p.rating,
                                      reviewCount: p.reviewCount,
                                      size: 13,
                                      showCount: false,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${p.reviewCount})',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xff007185),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              if (widget.packs.length > 1)
                                Wrap(
                                    spacing: 5,
                                    runSpacing: 4,
                                    children: widget.packs
                                        .map((pack) => ChoiceChip(
                                              key: ValueKey(
                                                  'catalogue-pack-${pack.id}'),
                                              visualDensity:
                                                  VisualDensity.compact,
                                              label: Text(
                                                  pack.packSize ?? pack.unit),
                                              selected: pack.id == p.id,
                                              onSelected: (_) => setState(
                                                  () => _selected = pack.id),
                                            ))
                                        .toList())
                              else
                                SizedBox(
                                    height: StoreLayout.productVariantMinHeight,
                                    child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(p.packSize ?? p.unit,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: storeMuted)))),
                              const SizedBox(height: 6),
                              if (!p.isConcept) ...[
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(storeMoney(p.price),
                                        style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xff0f1111))),
                                    if (discountPercent > 0) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        storeMoney(p.compareAtPrice!),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: storeMuted,
                                          decoration:
                                              TextDecoration.lineThrough,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '($discountPercent% off)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xffcc0c39),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.check,
                                        size: 13, color: storeSuccess),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        p.isStaticSnapshot
                                            ? 'Delivery checked at checkout'
                                            : 'FREE Delivery by Tomorrow, 8 AM',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: storeSuccess,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const Text(
                                  'In development · Not for sale',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: storeGreen,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 3),
                              Text(
                                  p.isConcept
                                      ? 'Price not announced'
                                      : !p.stockKnown
                                          ? 'Availability checked when added'
                                          : (p.inStock
                                              ? 'In stock'
                                              : 'Currently unavailable'),
                                  style: const TextStyle(
                                      fontSize: 11, color: storeMuted)),
                              const SizedBox(height: 8),
                              FilledButton(
                                  style: p.isConcept
                                      ? null
                                      : StoreTheme.addToCartButton,
                                  onPressed: p.isConcept
                                      ? () => widget.onOpen(p)
                                      : (!p.stockKnown ||
                                                  (p.inStock &&
                                                      p.availableQuantity >=
                                                          p.minOrderQuantity)) &&
                                              !busy
                                          ? () => widget.onAdd(p)
                                          : null,
                                  child: Text(
                                      p.isConcept
                                          ? 'Explore Concept'
                                          : busy
                                              ? 'Adding…'
                                              : 'Add to cart',
                                      textAlign: TextAlign.center)),
                            ])),
                  ]);
            })));
  }
}

class WishlistHeartButton extends ConsumerWidget {
  const WishlistHeartButton({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlisted = ref.watch(isWishlistedProvider(product.id));

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: wishlisted ? 'Remove from Wishlist' : 'Add to Wishlist',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => toggleWishlist(context, ref, product),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              wishlisted ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: wishlisted ? const Color(0xffd9383a) : storeMuted,
            ),
          ),
        ),
      ),
    );
  }
}
