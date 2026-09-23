import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/store_theme.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/providers/wishlist_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../widgets/milterra_store_header.dart';
import '../widgets/milterra_store_footer.dart';

/// MILTERRA Product Detail — Farm Foods, Earth Essentials & Sacred Living.
class MilterraProductDetailScreen extends ConsumerStatefulWidget {
  const MilterraProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<MilterraProductDetailScreen> createState() =>
      _MilterraProductDetailScreenState();
}

class _MilterraProductDetailScreenState
    extends ConsumerState<MilterraProductDetailScreen> {
  int _selectedPackIndex = 0;
  int _quantity = 1;
  int _activePhotoIndex = 0;

  static const List<Map<String, dynamic>> _defaultGheePacks = [
    {'size': '500 ml Glass Jar', 'multiplier': 1.0, 'tag': 'Most Popular'},
    {'size': '1 Litre Glass Jar', 'multiplier': 1.9, 'tag': 'Save 5%'},
    {'size': '250 ml Glass Jar', 'multiplier': 0.55, 'tag': 'Trial Size'},
    {'size': '5 Litre Family Tin', 'multiplier': 8.8, 'tag': 'Best Value'},
  ];

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));
    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const MilterraStoreHeader(),
          Expanded(
            child: productAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: storeGreen)),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: storeError),
                      const SizedBox(height: 12),
                      Text('Product not found: $err',
                          style: const TextStyle(color: storeText)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/shop'),
                        child: const Text('Back to MILTERRA Store'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (product) {
                final basePrice = product.price;
                final pack = _defaultGheePacks[_selectedPackIndex];
                final currentPrice =
                    (basePrice * (pack['multiplier'] as double)).roundToDouble();
                final isWishlisted = wishlist.any((p) => p.id == product.id);

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: StoreLayout.maxWidth),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Breadcrumb
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => context.go('/shop'),
                                      child: const Text('MILTERRA Store',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: storeMuted,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const Text(' / ',
                                        style: TextStyle(color: storeMuted)),
                                    Text(product.title,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: storeGreen,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Main Product Responsive Layout
                                LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    final isWide = constraints.maxWidth >= 860;
                                    return Flex(
                                      direction: isWide
                                          ? Axis.horizontal
                                          : Axis.vertical,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Left Image Gallery
                                        Expanded(
                                          flex: isWide ? 5 : 0,
                                          child: _buildGallery(product),
                                        ),
                                        if (isWide) const SizedBox(width: 32)
                                        else const SizedBox(height: 24),

                                        // Right Details & Buy Box
                                        Expanded(
                                          flex: isWide ? 6 : 0,
                                          child: _buildBuyBox(product,
                                              currentPrice, isWishlisted),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 40),

                                // Vedic Nutrition & Purity Matrix
                                _buildNutritionAndPurityMatrix(product),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const MilterraStoreFooter(),
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

  Widget _buildGallery(Product product) {
    final images = product.media;

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            height: 380,
            width: double.infinity,
            decoration: BoxDecoration(
              color: storeCream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: images.isEmpty
                ? const Center(
                    child: Icon(Icons.spa, size: 90, color: storeGold))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: images[_activePhotoIndex.clamp(0, images.length - 1)]
                            .startsWith('assets/')
                        ? Image.asset(
                            images[
                                _activePhotoIndex.clamp(0, images.length - 1)],
                            fit: BoxFit.contain,
                          )
                        : Image.network(
                            images[
                                _activePhotoIndex.clamp(0, images.length - 1)],
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                                child:
                                    Icon(Icons.spa, size: 80, color: storeGold)),
                          ),
                  ),
          ),
          if (images.length > 1) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final isSelected = _activePhotoIndex == i;
                return InkWell(
                  onTap: () => setState(() => _activePhotoIndex = i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? storeGold : storeBorder,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: images[i].startsWith('assets/')
                            ? Image.asset(images[i], fit: BoxFit.cover)
                            : Image.network(images[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBuyBox(Product product, double price, bool isWishlisted) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: storeGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'MILTERRA CERTIFIED • KNOW YOUR SOURCE',
              style: TextStyle(
                color: storeGreen,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            product.title,
            style: const TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: storeGreen,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Rating
          const Row(
            children: [
              Icon(Icons.star, color: storeGold, size: 18),
              Icon(Icons.star, color: storeGold, size: 18),
              Icon(Icons.star, color: storeGold, size: 18),
              Icon(Icons.star, color: storeGold, size: 18),
              Icon(Icons.star_half, color: storeGold, size: 18),
              SizedBox(width: 6),
              Text(
                '4.9 (128 Customer Reviews)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: storeText),
              ),
            ],
          ),
          const Divider(height: 28),

          // Price & In-Stock Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${price.toInt()}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: storeGreen,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Inclusive of all taxes',
                style: TextStyle(fontSize: 12, color: storeMuted),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: storeGreen),
                    SizedBox(width: 4),
                    Text('In Stock',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: storeGreen)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pack Size Selector
          const Text(
            'SELECT PACKAGING SIZE:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: storeMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_defaultGheePacks.length, (i) {
              final pack = _defaultGheePacks[i];
              final isSelected = _selectedPackIndex == i;
              return InkWell(
                onTap: () => setState(() => _selectedPackIndex = i),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? storeGold.withValues(alpha: 0.15) : storeCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? storeGold : storeBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack['size'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? storeGreen : storeText,
                        ),
                      ),
                      if (pack['tag'] != null)
                        Text(
                          pack['tag'] as String,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? storeOrange : storeMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Quantity & CTA Buttons
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: storeBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      onPressed: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                    ),
                    Text('$_quantity',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => setState(() => _quantity++),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: storeGold,
                    foregroundColor: storeGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    await ref
                        .read(cartProvider.notifier)
                        .add(product.id, _quantity, product);
                    if (mounted) {
                      showStoreCart(context);
                    }
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: const Text('Add to Cart',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                icon: Icon(
                  isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: isWishlisted ? storeOrange : storeGreen,
                ),
                onPressed: () =>
                    ref.read(wishlistProvider.notifier).toggle(product),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: storeGreen,
              foregroundColor: storeWhite,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await ref
                  .read(cartProvider.notifier)
                  .add(product.id, _quantity, product);
              if (mounted) {
                context.push('/marketplace/checkout');
              }
            },
            child: const Text('Buy Now — Fast Delivery',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionAndPurityMatrix(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Details & Lab Certification',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every MILTERRA product is batch-tested and source-verified. Lab reports available on request.',
            style: TextStyle(fontSize: 12, color: storeMuted),
          ),
          const Divider(height: 28),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 768;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isWide ? 2.8 : 2.2,
                children: const [
                  _NutriCard(title: 'A2 Beta-Casein', value: '100% Pure Gir Cow'),
                  _NutriCard(title: 'Natural Butyric Acid', value: '3.8g / 100g'),
                  _NutriCard(title: 'Fat Soluble Vitamins', value: 'A, D, E, K2'),
                  _NutriCard(title: 'Omega 3 & Omega 9', value: 'Optimal 1:1 Ratio'),
                  _NutriCard(title: 'Granular (Danedaar)', value: 'Slow Simmered'),
                  _NutriCard(title: 'Palm Oil / Starch', value: '0% (NABL Tested)'),
                  _NutriCard(title: 'Lactose & Casein', value: '< 0.01% (Digestible)'),
                  _NutriCard(title: 'Shelf Life', value: '12 Months (Glass Jar)'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NutriCard extends StatelessWidget {
  const _NutriCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: storeCream,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 11,
                  color: storeMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: storeGreen)),
        ],
      ),
    );
  }
}
