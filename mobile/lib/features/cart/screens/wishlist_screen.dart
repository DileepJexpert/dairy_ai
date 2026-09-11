import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/widgets/store_product_card.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  final Set<String> _busyIds = {};

  Future<void> _moveToCart(Product product) async {
    setState(() => _busyIds.add(product.id));
    try {
      await ref
          .read(cartProvider.notifier)
          .add(product.id, product.minOrderQuantity, product);
      ref.read(wishlistProvider.notifier).remove(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text('${product.title} moved to your cart.'),
            action: SnackBarAction(
              label: 'View Cart',
              textColor: storeGold,
              onPressed: () => context.go('/cart'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not move item to cart.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(product.id));
    }
  }

  void _removeFromWishlist(Product product) {
    ref.read(wishlistProvider.notifier).remove(product.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${product.title} from your wishlist.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => ref.read(wishlistProvider.notifier).add(product),
        ),
      ),
    );
  }

  Future<void> _addRecommendedToCart(Product item) async {
    setState(() => _busyIds.add(item.id));
    try {
      await ref
          .read(cartProvider.notifier)
          .add(item.id, item.minOrderQuantity, item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: storeGreen,
          content: Text('Added ${item.title} to cart.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Store Header & Category Bar
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Wishlist'),

          // Main Wishlist Body
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < StoreLayout.tablet;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: StoreLayout.maxWidth),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 12 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Breadcrumbs
                                Wrap(
                                  children: [
                                    InkWell(
                                      onTap: () => context.go('/shop'),
                                      child: const Text('Home',
                                          style: TextStyle(
                                              fontSize: 12, color: storeMuted)),
                                    ),
                                    const Text(' › ',
                                        style: TextStyle(
                                            fontSize: 12, color: storeMuted)),
                                    InkWell(
                                      onTap: () => context.go('/profile'),
                                      child: const Text('Your Account',
                                          style: TextStyle(
                                              fontSize: 12, color: storeMuted)),
                                    ),
                                    const Text(' › ',
                                        style: TextStyle(
                                            fontSize: 12, color: storeMuted)),
                                    const Text(
                                      'Wishlist',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Title Row
                                Row(
                                  children: [
                                    const Text(
                                      'Your Wishlist',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: storeGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: storeGreen.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${wishlist.length} items',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: storeGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Main Content: Items or Empty State
                                if (wishlist.isEmpty)
                                  _buildEmptyState(context)
                                else
                                  _buildWishlistGrid(wishlist, isMobile),

                                const SizedBox(height: 40),
                                const Divider(),
                                const SizedBox(height: 24),

                                // Recommended For You Section
                                _buildRecommendations(isMobile),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const StoreFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: storeGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_border,
              size: 56,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Wishlist is empty',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Explore pure dairy foods, animal feeds, and farm equipment to save your favorite items for later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: storeMuted,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: storeAmber,
              foregroundColor: storeGreen,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => context.go('/shop'),
            icon: const Icon(Icons.shopping_bag_outlined, size: 20),
            label: const Text(
              'Explore Products',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistGrid(List<Product> items, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isMobile
            ? (constraints.maxWidth < 480 ? 1 : 2)
            : (constraints.maxWidth >= 1000 ? 4 : 2);
        final itemWidth =
            ((constraints.maxWidth - 16 * (columns - 1)) / columns)
                .clamp(160.0, constraints.maxWidth);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items.map((product) {
            final isBusy = _busyIds.contains(product.id);

            return SizedBox(
              width: itemWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: storeWhite,
                  borderRadius: BorderRadius.circular(StoreLayout.radius),
                  border: Border.all(color: storeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Artwork
                    InkWell(
                      onTap: () => context.go('/shop/product/${product.id}'),
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Color(0xfffaf8f5),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(StoreLayout.radius),
                          ),
                        ),
                        child: ProductArtwork(product: product),
                      ),
                    ),

                    // Details
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (product.brand ?? storeCategory(product))
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: storeMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () =>
                                context.go('/shop/product/${product.id}'),
                            child: Text(
                              product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xff111111),
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const AmazonRatingStars(
                              rating: 4.8, reviewCount: 38, size: 12),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                storeMoney(product.price),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: storeGreen,
                                ),
                              ),
                              if (product.unit.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '/ ${product.unit}',
                                  style: const TextStyle(
                                      fontSize: 12, color: storeMuted),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'In Stock',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff007600),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Action Buttons
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: storeAmber,
                                foregroundColor: storeGreen,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              onPressed:
                                  isBusy ? null : () => _moveToCart(product),
                              child: isBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: storeGreen,
                                      ),
                                    )
                                  : const Text(
                                      'Move to Cart',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: TextButton(
                              onPressed: () => _removeFromWishlist(product),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'Remove from list',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff007185),
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
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecommendations(bool isMobile) {
    final recs = defaultMilterraProducts.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended based on your Wishlist',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, space) {
            final columns = isMobile
                ? (space.maxWidth < 480 ? 1 : 2)
                : (space.maxWidth >= 1000 ? 4 : 2);
            final itemWidth =
                ((space.maxWidth - 16 * (columns - 1)) / columns)
                    .clamp(160.0, space.maxWidth);

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: recs.map((p) {
                return SizedBox(
                  width: itemWidth,
                  child: StoreProductCard(
                    packs: [p],
                    compact: isMobile,
                    busyIds: _busyIds,
                    onOpen: (item) => context.go('/shop/product/${item.id}'),
                    onAdd: (item) => _addRecommendedToCart(item),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
