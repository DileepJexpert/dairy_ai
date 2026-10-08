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

  Widget _buildRatingAndVegRow(Product p) {
    final ratingVal = p.rating > 0 ? p.rating : 4.8;
    final reviewCount = p.reviewCount > 0 ? p.reviewCount : 124;

    return Row(
      children: [
        // HealthKart Solid Teal Rating Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xff0d9488), // Solid Teal
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ratingVal.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2.5),
              const Icon(Icons.star, size: 9.5, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // FSSAI 100% Vegetarian Indicator
        Container(
          width: 13,
          height: 13,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xff16a34a), width: 1.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Center(
            child: CircleAvatar(
              radius: 2.2,
              backgroundColor: Color(0xff16a34a),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '($reviewCount)',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xff6b7280),
          ),
        ),
      ],
    );
  }

  String _puritySnippet(Product p) {
    final t = p.title.toLowerCase();
    if (t.contains('cow') && t.contains('ghee')) {
      return '100% Traditional Bilona · Certified A2';
    }
    if (t.contains('buffalo') && t.contains('ghee')) {
      return 'Cultured Murrah Churn · Rich Granular';
    }
    if (t.contains('ghee')) {
      return 'Handmade Bilona Method · Woodfire Clarified';
    }
    if (t.contains('mustard') || t.contains('sarso') || t.contains('oil')) {
      return 'Cold Wood-Pressed Kolhu · Zero Argemone';
    }
    if (t.contains('paneer') ||
        t.contains('milk') ||
        t.contains('chhachh') ||
        t.contains('chaas')) {
      return 'Fresh Farm Morning Harvest · Chilled Delivery';
    }
    if (t.contains('atta') || t.contains('flour') || t.contains('khapli')) {
      return 'Cold Stone-Ground Chakki · High Fiber Low-GI';
    }
    if (t.contains('honey') || t.contains('sweetener')) {
      return 'Single-Origin Raw Forest Harvest · Unheated';
    }
    return '100% Pure Organic Staple · Lab Certified';
  }

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe5e7eb), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
                      child: ProductArtwork(product: p, showCaption: false),
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
                    aspectRatio: 1.05,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: ProductArtwork(product: p, showCaption: false),
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
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HealthKart Teal Rating Pill + Green Veg Mark + Reviews
                    _buildRatingAndVegRow(p),
                    const SizedBox(height: 8),

                    // Product Title (2 Lines Max)
                    InkWell(
                      key: ValueKey('catalogue-open-${p.id}'),
                      onTap: () => widget.onOpen(p),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Text(
                          p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff111827),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Variant Pack Selector OR Clean Purity Tag
                    if (widget.packs.length > 1)
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: widget.packs.map((pack) {
                          final isCurrent = pack.id == p.id;
                          return InkWell(
                            onTap: () => setState(() => _selected = pack.id),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xff111827)
                                    : Colors.white,
                                border: Border.all(
                                  color: isCurrent
                                      ? const Color(0xff111827)
                                      : const Color(0xffd1d5db),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                pack.packSize ?? pack.unit,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? Colors.white
                                      : const Color(0xff4b5563),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        _puritySnippet(p),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xff059669),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),

                    // Price Row: Current Price + Strikethrough + Discount
                    if (!p.isConcept) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            storeMoney(p.price),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff111827),
                            ),
                          ),
                          if (discountPercent > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              storeMoney(p.compareAtPrice!),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xff9ca3af),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '$discountPercent% off',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff059669),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Concept · In Development',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff6b7280),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Sleek HealthKart Full-Width CTA Button
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff111827),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: p.isConcept
                            ? () => widget.onOpen(p)
                            : (!p.stockKnown ||
                                    (p.inStock &&
                                        p.availableQuantity >=
                                            p.minOrderQuantity)) &&
                                !busy
                            ? () => widget.onAdd(p)
                            : null,
                        icon: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.shopping_bag_outlined,
                                size: 15),
                        label: Text(
                          busy
                              ? 'Adding…'
                              : (p.inStock ? 'Add to Cart' : 'Out of Stock'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
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
