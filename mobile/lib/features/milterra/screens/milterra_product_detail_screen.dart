import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _isSubscription = false;
  int _selectedSubscriptionInterval = 30; // 30, 45, 60 days

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
                final regularPrice =
                    (basePrice * (pack['multiplier'] as double)).roundToDouble();
                final currentPrice = _isSubscription
                    ? (regularPrice * 0.90).roundToDouble()
                    : regularPrice;
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
                                              regularPrice, currentPrice, isWishlisted),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 36),

                                // Vedic Nutrition & Purity Matrix
                                _buildNutritionAndPurityMatrix(product),
                                const SizedBox(height: 32),

                                // 1. The 5-Stage Vedic Bilona Journey
                                _buildBilonaProcessJourney(),
                                const SizedBox(height: 32),

                                // 2. Side-by-Side Comparison Matrix ("Milterra Vedic Bilona vs Commercial Factory Ghee")
                                _buildBilonaVsCommercialComparison(),
                                const SizedBox(height: 32),

                                // 3. Ghee Selector Guide ("Which Ghee is Right for You?")
                                _buildGheeSelectionGuide(),
                                const SizedBox(height: 32),

                                // 4. Batch Quality & Independent NABL Lab Certification
                                _buildBatchCertificateCard(),
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
    final resolvedFallback = StoreImages.productArtwork(product);
    final images = product.media.isNotEmpty
        ? product.media
        : (resolvedFallback != null ? [resolvedFallback] : const <String>[]);

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

  Widget _buildBuyBox(
      Product product, double regularPrice, double currentPrice, bool isWishlisted) {
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
                '₹${currentPrice.toInt()}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: storeGreen,
                ),
              ),
              if (_isSubscription) ...[
                const SizedBox(width: 8),
                Text(
                  '₹${regularPrice.toInt()}',
                  style: const TextStyle(
                    fontSize: 18,
                    color: storeMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xff16a34a),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('10% OFF',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
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
          const SizedBox(height: 20),

          // Purchase Type: One-Time vs Subscribe & Save 10%
          _buildPurchaseOptionToggle(regularPrice),
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
                  icon: Icon(_isSubscription ? Icons.repeat : Icons.shopping_bag_outlined, size: 20),
                  label: Text(_isSubscription ? 'Subscribe & Add' : 'Add to Cart',
                      style: const TextStyle(
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
            child: Text(
              _isSubscription ? 'Start Recurring Subscription (₹${currentPrice.toInt()})' : 'Buy Now — Fast Delivery',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
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

  Widget _buildPurchaseOptionToggle(double regularPrice) {
    final subPrice = (regularPrice * 0.90).roundToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isSubscription = false),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: !_isSubscription ? storeGold.withValues(alpha: 0.15) : storeCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_isSubscription ? storeGold : storeBorder,
                      width: !_isSubscription ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            !_isSubscription ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: !_isSubscription ? storeGreen : storeMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'One-Time',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('₹${regularPrice.toInt()}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: storeGreen)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _isSubscription = true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSubscription ? storeGold.withValues(alpha: 0.15) : storeCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isSubscription ? storeGold : storeBorder,
                      width: _isSubscription ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isSubscription ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: _isSubscription ? storeGreen : storeMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Subscribe & Save',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('₹${subPrice.toInt()}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: storeGreen)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xff16a34a),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('SAVE 10%',
                                style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isSubscription) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffbbf7d0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVERY FREQUENCY:',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeGreen, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [30, 45, 60].map((days) {
                    final isSel = _selectedSubscriptionInterval == days;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedSubscriptionInterval = days),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel ? storeGreen : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSel ? storeGreen : storeBorder),
                          ),
                          child: Text(
                            'Every $days Days${days == 30 ? ' ★' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : storeText,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                const Text(
                  '✓ Free doorstep shipping • Pause or cancel anytime • Earn 100 bonus loyalty points on first renewal.',
                  style: TextStyle(fontSize: 11, color: Color(0xff15803d), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBilonaProcessJourney() {
    final stages = [
      {
        'step': '01',
        'title': 'Ethical A2 Milking',
        'desc': 'Grass-fed Sahiwal & Gir cows grazing in open pastures. Cruelty-free Ahimsa milking — calf is fully fed first.',
        'icon': Icons.favorite_outline,
      },
      {
        'step': '02',
        'title': 'Earthen Pot Boiling',
        'desc': 'Fresh milk gently boiled in traditional clay and brass vessels over low flame to preserve natural enzymes.',
        'icon': Icons.local_fire_department_outlined,
      },
      {
        'step': '03',
        'title': 'Curd Culturing',
        'desc': 'Cooled milk is inoculated with natural probiotic cultures and set overnight into rich, live whole curd.',
        'icon': Icons.hourglass_top_outlined,
      },
      {
        'step': '04',
        'title': 'Wooden Bilona Churning',
        'desc': 'Bi-directional churning with wooden madhani clockwise & counter-clockwise to separate pure, nutrient-rich makkhan.',
        'icon': Icons.sync_outlined,
      },
      {
        'step': '05',
        'title': 'Slow Clarification',
        'desc': 'Makkhan is slow-melted over cow dung cakes (<100°C) into aromatic golden crystalline Danedar ghee in glass jars.',
        'icon': Icons.auto_awesome_outlined,
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: storeGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ANCIENT AYURVEDIC STANDARD',
                  style: TextStyle(color: storeGreen, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'The Sacred 5-Stage Vedic Bilona Method',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Unlike factory ghee made from leftover cream, Milterra ghee is handcrafted strictly from whole curd according to classical Ayurvedic texts.',
            style: TextStyle(fontSize: 13, color: storeMuted),
          ),
          const Divider(height: 32),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 768;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: stages.map((s) {
                  return SizedBox(
                    width: isWide ? (constraints.maxWidth - 64) / 5 : constraints.maxWidth,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: storeCream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: storeBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xffeaf2ef),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(s['icon'] as IconData, color: storeGreen, size: 20),
                              ),
                              Text(
                                s['step'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: storeGold,
                                  fontFamily: 'CormorantGaramond',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: storeGreen),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s['desc'] as String,
                            style: const TextStyle(fontSize: 11.5, color: storeMuted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBilonaVsCommercialComparison() {
    final comparisonRows = [
      {
        'param': 'Cow Breed & Welfare',
        'milterra': '100% Desi A2 Cows (Sahiwal & Gir). Free-grazing, grass-fed, cruelty-free Ahimsa care (calf fed first).',
        'commercial': 'High-yield crossbred Jersey/HF cows. Confined in industrial stalls, given hormonal boosters.',
      },
      {
        'param': 'Base Ingredient',
        'milterra': 'Cultured whole curd (Dahi) fermented overnight with live probiotic cultures.',
        'commercial': 'Leftover industrial raw cream separated via high-speed mechanical centrifuges.',
      },
      {
        'param': 'Milk Required per 1 kg',
        'milterra': '28 to 30 Litres of 100% pure A2 milk boiled, curdled, and slow-churned.',
        'commercial': 'Synthesized from factory cream derivatives and recombined milk fats.',
      },
      {
        'param': 'Heating & Clarification',
        'milterra': 'Slow-simmered over low wood & cow-dung flame (<100°C), preserving heat-sensitive enzymes.',
        'commercial': 'Heated at high pressure (180°C+) in industrial steel steam boilers, destroying enzymes.',
      },
      {
        'param': 'Texture & Natural Aroma',
        'milterra': 'Rich golden crystalline Danedar texture with an authentic, sweet nutty aroma.',
        'commercial': 'Smooth, greasy, oily consistency. Often added with synthetic flavoring & color.',
      },
      {
        'param': 'Digestibility & Health',
        'milterra': 'A2 Beta-Casein, 100% lactose-free, rich in gut-soothing Butyric acid & Vitamin K2.',
        'commercial': 'Contains inflammatory A1 Beta-Casein peptide (BCM-7), often triggering gut bloating.',
      },
      {
        'param': 'Purity Guarantee & Packaging',
        'milterra': 'FSSAI & NABL lab-certified 0% palm oil. Packed in lead-free food grade glass jars.',
        'commercial': 'Mass aggregated, non-traceable supply chains with high adulteration risk.',
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SIDE-BY-SIDE PURITY MATRIX',
                  style: TextStyle(color: storeGreen, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Why Milterra Vedic Bilona Ghee vs Regular Factory Ghee',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ever wondered why genuine Vedic Bilona Ghee costs ₹1,150+ while supermarket commercial ghee is ₹450? Here is the exact difference.',
            style: TextStyle(fontSize: 13, color: storeMuted),
          ),
          const SizedBox(height: 24),
          // Comparison Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: storeGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Quality Standard',
                      style: TextStyle(color: storeGold, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                Expanded(
                  flex: 4,
                  child: Text('MILTERRA VEDIC BILONA',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
                Expanded(
                  flex: 4,
                  child: Text('REGULAR FACTORY GHEE',
                      style: TextStyle(color: Color(0xffcbd5e1), fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...comparisonRows.map((row) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: storeBorder)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row['param']!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: storeGreen),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xff16a34a), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row['milterra']!,
                            style: const TextStyle(fontSize: 12, color: storeText, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cancel_rounded, color: Color(0xffef4444), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            row['commercial']!,
                            style: const TextStyle(fontSize: 12, color: storeMuted, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGheeSelectionGuide() {
    final gheeTypes = [
      {
        'title': 'A2 Sahiwal Cow Ghee',
        'tag': 'Best for Everyday Cooking & Immunity',
        'highlights': [
          'Signature golden crystalline Danedar texture.',
          'Highest natural content of Butyric Acid & Vitamin A.',
          'Boosts children’s energy and daily family wellness.',
        ],
        'idealFor': 'Everyday dal tadka, rotis, khichdi, and boosting digestive fire.',
      },
      {
        'title': 'A2 Gir Cow Vedic Ghee',
        'tag': 'Ayurvedic Medicinal & Brain Health',
        'highlights': [
          'Crafted from indigenous Gir cows of Saurashtra.',
          'Rich in Omega 3 & 9 and Fat-Soluble Vitamin K2.',
          'Deep Ayurvedic rejuvenation for nervous system.',
        ],
        'idealFor': 'Morning empty-stomach ghee shot, nasya therapy, joint relief & pregnancy.',
      },
      {
        'title': 'Cultured Buffalo Ghee',
        'tag': 'High Smoke Point & Traditional Sweets',
        'highlights': [
          'Extra rich, creamy white crystalline texture.',
          'High smoke point (250°C), ideal for deep roasting.',
          'Promotes healthy weight gain and deep sound sleep.',
        ],
        'idealFor': 'Traditional Indian sweets (halwa, ladoo), parathas, and high-heat roasting.',
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: storeGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'BUYER’S SELECTION GUIDE',
                  style: TextStyle(color: storeGreen, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Which Milterra Ghee is Right for You?',
            style: TextStyle(
              fontFamily: 'CormorantGaramond',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Explore our handcrafted varieties to match your culinary and wellness goals.',
            style: TextStyle(fontSize: 13, color: storeMuted),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 768;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: gheeTypes.map((ghee) {
                  return SizedBox(
                    width: isWide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: storeCream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: storeBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: storeGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ghee['tag'] as String,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeGreen),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            ghee['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: storeGreen),
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          ...(ghee['highlights'] as List<String>).map((hl) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(color: storeGold, fontWeight: FontWeight.bold)),
                                    Expanded(
                                      child: Text(hl, style: const TextStyle(fontSize: 12, color: storeText, height: 1.3)),
                                    ),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Ideal for: ${ghee['idealFor']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: storeMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCertificateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffbbf7d0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xff16a34a), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'LAB TESTED & BATCH CERTIFIED',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff166534),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffbbf7d0)),
                ),
                child: const Text(
                  'Batch: MIL-GHEE-2026-10',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff166534)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Zero Adulteration Guarantee — Tested by National Dairy Testing Laboratory (NABL Accredited)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff15803d)),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Purity Score: 99.9%', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xff166534), fontSize: 13)),
              Text('Milk Fat: 99.85%', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xff166534), fontSize: 13)),
              Text('Palm Oil: 0.0%', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xff166534), fontSize: 13)),
              Text('Beta-Casein: 100% A2', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xff166534), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Every jar has a batch QR code. Scan on arrival with your phone camera or the Milterra app to inspect the official FSSAI / NABL test certificate.',
            style: TextStyle(fontSize: 12, color: Color(0xff166534), height: 1.4),
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
