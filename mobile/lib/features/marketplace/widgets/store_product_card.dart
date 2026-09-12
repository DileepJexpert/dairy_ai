import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    return Container(
        decoration: StoreLayout.panel,
        child: Material(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            clipBehavior: Clip.antiAlias,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(children: [
                    InkWell(
                        onTap: () => widget.onOpen(p),
                        child: AspectRatio(
                            aspectRatio: StoreLayout.productImageAspectRatio,
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: ProductArtwork(product: p)))),
                    if (p.isConcept)
                      Positioned(
                          top: 8,
                          left: 8,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: storeGreen,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Text('Concept Preview',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10))))),
                    Positioned(
                        top: 8,
                        right: 8,
                        child: WishlistHeartButton(product: p)),
                  ]),
                  Padding(
                      padding: StoreLayout.productCardPadding,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                                key: ValueKey('catalogue-open-${p.id}'),
                                onTap: () => widget.onOpen(p),
                                child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 48),
                                    child: Text(p.title,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.35,
                                            fontWeight: FontWeight.w600,
                                            color: storeGreen)))),
                            const SizedBox(height: 4),
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
                            Text(
                                p.isConcept
                                    ? 'In development · Not for sale'
                                    : storeMoney(p.price),
                                style: TextStyle(
                                    fontSize: p.isConcept ? 13 : 20,
                                    fontWeight: FontWeight.w700,
                                    color: storeGreen)),
                            const SizedBox(height: 4),
                            Text(
                                p.isConcept
                                    ? 'Price not announced'
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
                                    : p.inStock &&
                                            p.availableQuantity >=
                                                p.minOrderQuantity &&
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
                ])));
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
          onTap: () {
            final added = ref.read(wishlistProvider.notifier).toggle(product);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                backgroundColor: storeGreen,
                content: Text(
                  added
                      ? 'Added ${product.title} to your Wishlist.'
                      : 'Removed from your Wishlist.',
                ),
                action: SnackBarAction(
                  label: 'View',
                  textColor: storeGold,
                  onPressed: () => context.go('/wishlist'),
                ),
              ),
            );
          },
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
