import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';
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
    if (product.isConcept) return;
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

  Future<void> _addRecommendedToCart(Product item) async {
    if (item.isConcept) return;
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
                                        color:
                                            storeGreen.withValues(alpha: 0.1),
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

  Widget _buildWishlistGrid(List<Product> wishlist, bool isMobile) =>
      LayoutBuilder(builder: (context, space) {
        final count = space.maxWidth >= 960
            ? 4
            : space.maxWidth >= 650
                ? 3
                : space.maxWidth >= 380
                    ? 2
                    : 1;
        return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: wishlist
                .map((p) => SizedBox(
                      width: (space.maxWidth - 16 * (count - 1)) / count,
                      child: StoreProductCard(
                          packs: [p],
                          busyIds: _busyIds,
                          onOpen: (p) => context.push('/shop/product/${p.id}'),
                          onAdd: _moveToCart),
                    ))
                .toList());
      });

  Widget _buildRecommendations(bool isMobile) {
    final recs = (ref.watch(productsProvider(null)).valueOrNull ?? <Product>[])
        .where(
            (p) => !ref.read(wishlistProvider).any((saved) => saved.id == p.id))
        .take(4)
        .toList();

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
            final itemWidth = ((space.maxWidth - 16 * (columns - 1)) / columns)
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
