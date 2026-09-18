import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/store_theme.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../marketplace/widgets/store_product_card.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../widgets/milterra_store_header.dart';
import '../widgets/milterra_store_footer.dart';

/// Pure, bare-minimal D2C Storefront for Milterra Vedic Ghee & Pure Dairy.
class MilterraStoreScreen extends ConsumerStatefulWidget {
  const MilterraStoreScreen({
    super.key,
    this.initialCategory = 'All Ghee',
    this.initialQuery = '',
  });

  final String initialCategory;
  final String initialQuery;

  @override
  ConsumerState<MilterraStoreScreen> createState() =>
      _MilterraStoreScreenState();
}

class _MilterraStoreScreenState extends ConsumerState<MilterraStoreScreen> {
  late String _selectedCategory;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesCategory(Product p, String cat) {
    final t = p.title.toLowerCase();
    if (cat == 'All Ghee' || cat == 'All products' || cat == 'All') {
      return t.contains('ghee') ||
          t.contains('butter') ||
          t.contains('paneer') ||
          t.contains('earth') ||
          t.contains('samagri');
    }
    switch (cat) {
      case 'A2 Desi Cow Ghee':
        return t.contains('cow') && t.contains('ghee');
      case 'Rich Buffalo Ghee':
        return t.contains('buffalo') && t.contains('ghee');
      case 'Herbal Infused Ghee':
        return (t.contains('tulsi') ||
                t.contains('brahmi') ||
                t.contains('ashwagandha') ||
                t.contains('herbal')) &&
            t.contains('ghee');
      case 'Malai Paneer & Makhan':
        return t.contains('paneer') || t.contains('butter') || t.contains('makhan');
      case 'Puja & Hawan Samagri':
        return t.contains('hawan') ||
            t.contains('puja') ||
            t.contains('samagri') ||
            t.contains('diya') ||
            t.contains('kanda');
      case '🌱 MILTERRA Earth Soil':
        return t.contains('earth') ||
            t.contains('vermicompost') ||
            t.contains('manure') ||
            t.contains('soil');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          MilterraStoreHeader(
            selectedCategory: _selectedCategory,
            searchController: _searchController,
            onSearch: (val) => setState(() {}),
          ),
          MilterraCategoryNav(
            selectedCategory: _selectedCategory,
            onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Luxury D2C Hero Banner
                  _buildLuxuryHero(),

                  // Purity & Vedic Heritage Value Strip
                  _buildVedicValueStrip(),

                  // Main Product Showcase Grid
                  Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedCategory,
                                      style: const TextStyle(
                                        fontFamily: 'CormorantGaramond',
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Handcrafted using traditional wooden Bilona churning of A2 whole curd.',
                                      style: TextStyle(
                                          fontSize: 12, color: storeMuted),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: storeWhite,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: storeBorder),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified,
                                          color: storeGold, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        '100% Vedic Certified',
                                        style: TextStyle(
                                          color: storeGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Product Cards Grid
                            productsAsync.when(
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(
                                      color: storeGreen),
                                ),
                              ),
                              error: (err, _) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Text('Unable to load catalogue: $err',
                                      style: const TextStyle(color: storeText)),
                                ),
                              ),
                              data: (allProducts) {
                                // Filter exclusively for D2C Ghee & Foods
                                final d2cProducts = allProducts.where((p) {
                                   if (query.isNotEmpty) {
                                     final matchTitle =
                                         p.title.toLowerCase().contains(query);
                                     final matchDesc = (p.description ?? '')
                                         .toLowerCase()
                                         .contains(query);
                                     if (!matchTitle && !matchDesc) return false;
                                   }
                                  return _matchesCategory(p, _selectedCategory);
                                }).toList();

                                if (d2cProducts.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(48),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        const Icon(Icons.spa_outlined,
                                            size: 48, color: storeMuted),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'No items found in this collection.',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: storeGreen),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () => setState(() =>
                                              _selectedCategory = 'All Ghee'),
                                          child: const Text('View All Ghee'),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    int crossAxisCount = 4;
                                    if (constraints.maxWidth < 600) {
                                      crossAxisCount = 1;
                                    } else if (constraints.maxWidth < 900) {
                                      crossAxisCount = 2;
                                    } else if (constraints.maxWidth < 1200) {
                                      crossAxisCount = 3;
                                    }

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 20,
                                        crossAxisSpacing: 20,
                                        childAspectRatio: 0.72,
                                      ),
                                      itemCount: d2cProducts.length,
                                      itemBuilder: (ctx, i) {
                                        final prod = d2cProducts[i];
                                        return StoreProductCard(
                                          packs: [prod],
                                          onOpen: (p) => context
                                              .push('/product/${p.id}'),
                                          onAdd: (p) async {
                                            await ref
                                                .read(cartProvider.notifier)
                                                .add(p.id, 1, p);
                                            if (context.mounted) {
                                              showStoreCart(context);
                                            }
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Vedic Bilona Craftsmanship Education Section
                  _buildBilonaProcessSection(),

                  // Minimal Footer
                  const MilterraStoreFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff12352c), storeGreen, Color(0xff1b4537)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth >= 768;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Text Column
                    Expanded(
                      flex: isWide ? 6 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: storeGold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: storeGold.withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'ANCIENT VEDIC AYURVEDA',
                              style: TextStyle(
                                color: storeGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Pure A2 Desi Gir Cow & Rich Buffalo Bilona Ghee',
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: storeWhite,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Handcrafted by churning whole curd using wooden churners (Bilona) in brass pots. Rich in natural butyric acid, gut-friendly enzymes, and authentic golden aroma.',
                            style: TextStyle(
                              color: StorePalette.onDark,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 14,
                            runSpacing: 10,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: storeGold,
                                  foregroundColor: storeGreen,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24)),
                                ),
                                onPressed: () => setState(() =>
                                    _selectedCategory = 'A2 Desi Cow Ghee'),
                                child: const Text('Explore A2 Cow Ghee',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900)),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: storeWhite,
                                  side: const BorderSide(color: storeGold),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24)),
                                ),
                                onPressed: () => setState(() =>
                                    _selectedCategory = 'Rich Buffalo Ghee'),
                                child: const Text('Rich Buffalo Ghee',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: 40)
                    else const SizedBox(height: 24),

                    // Right Badges / Image
                    Expanded(
                      flex: isWide ? 5 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: storeGold.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.eco_rounded,
                                size: 54, color: storeGold),
                            const SizedBox(height: 12),
                            const Text(
                              'The 5-Step Vedic Bilona Standard',
                              style: TextStyle(
                                color: storeWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '1. Grass-fed A2 Milk • 2. Curd Fermentation • 3. Bilva Churning • 4. Makhan Separation • 5. Slow Wood-Fired Simmer',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: StorePalette.onDark,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: storeGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'NABL Lab Certified 0% Palm Oil / Adulterants',
                                style: TextStyle(
                                  color: storeGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVedicValueStrip() {
    return Container(
      color: storeGold.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _ValuePill(icon: Icons.check_circle_outline, text: 'A2 Beta-Casein Certified'),
              SizedBox(width: 24),
              _ValuePill(icon: Icons.shield_outlined, text: 'No Preservatives or Chemicals'),
              SizedBox(width: 24),
              _ValuePill(icon: Icons.wb_sunny_outlined, text: 'Traditional Wooden Churner'),
              SizedBox(width: 24),
              _ValuePill(icon: Icons.local_shipping_outlined, text: 'Fast Nationwide Delivery in Glass Jars'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBilonaProcessSection() {
    return Container(
      width: double.infinity,
      color: storeWhite,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Column(
            children: [
              const Text(
                'WHY MILTERRA BILONA GHEE?',
                style: TextStyle(
                  color: storeGold,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ancient Wisdom vs Industrial Cream Heating',
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: storeGreen,
                ),
              ),
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 768;
                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: _processCard(
                          title: 'Milterra Traditional Bilona Ghee',
                          isPositive: true,
                          points: const [
                            'Cultured from whole A2 Gir Cow & Murrah Buffalo curd.',
                            'Bi-directional wooden churning retains natural probiotics.',
                            'Simmered over low wood-fire for granular (Danedaar) texture.',
                            'Rich in Butyric acid & natural fat-soluble vitamins (A, D, E, K).',
                          ],
                        ),
                      ),
                      if (isWide) const SizedBox(width: 24)
                      else const SizedBox(height: 16),
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: _processCard(
                          title: 'Commercial Industrial Ghee',
                          isPositive: false,
                          points: const [
                            'Direct centrifugal cream separation without curd fermentation.',
                            'High-heat steam boiling destroys natural aroma & vitamins.',
                            'Often blended with artificial color and synthetic flavouring.',
                            'Lacks natural enzymatic and gut-soothing properties.',
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _processCard({
    required String title,
    required bool isPositive,
    required List<String> points,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xfff0fdf4) : const Color(0xfffef2f2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPositive ? const Color(0xffbbf7d0) : const Color(0xfffecaca),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.check_circle : Icons.cancel_outlined,
                color: isPositive ? storeGreen : storeError,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPositive ? storeGreen : storeError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isPositive ? '✓ ' : '✗ ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isPositive ? storeGreen : storeError)),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(fontSize: 13, color: storeText),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: storeGreen),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: storeGreen,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
