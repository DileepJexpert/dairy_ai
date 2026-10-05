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
import '../widgets/storefront_carousel.dart';

/// MILTERRA D2C Storefront — Farm Foods, Earth Essentials & Sacred Living.
class MilterraStoreScreen extends ConsumerStatefulWidget {
  const MilterraStoreScreen({
    super.key,
    this.initialCategory = 'All Organic Essentials',
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
    // Exclude farm machinery from Milterra storefront
    if (p.category == ProductCategory.equipment) return false;
    if (t.contains('cutter') ||
        t.contains('chaff') ||
        t.contains('milker') ||
        t.contains('machine')) {
      return false;
    }

    if (cat == 'All Organic Essentials' ||
        cat == 'All Ghee' ||
        cat == 'All products' ||
        cat == 'All') {
      return true;
    }
    switch (cat) {
      case 'Vedic Bilona Ghee':
        return t.contains('ghee');
      case 'Fresh Milk & Dairy':
        return t.contains('milk') ||
            t.contains('doodh') ||
            t.contains('chhachh') ||
            t.contains('chaas') ||
            t.contains('buttermilk') ||
            t.contains('paneer') ||
            t.contains('makhan') ||
            t.contains('butter') ||
            t.contains('dahi') ||
            t.contains('curd');
      case 'Puja & Hawan Samagri':
        return t.contains('hawan') ||
            t.contains('yajna') ||
            t.contains('puja') ||
            t.contains('samagri') ||
            t.contains('diya') ||
            t.contains('kanda') ||
            t.contains('uple');
      case 'Natural Agarbatti & Dhoop':
        return t.contains('agarbatti') ||
            t.contains('dhoop') ||
            t.contains('sambrani') ||
            t.contains('kapoor') ||
            t.contains('camphor') ||
            t.contains('incense');
      case 'Vermicompost & Living Soil':
        return t.contains('vermicompost') ||
            t.contains('earth') ||
            t.contains('manure') ||
            t.contains('khad') ||
            t.contains('soil') ||
            t.contains('compost');
      case 'Cold-Pressed Sarso (Mustard) Oil':
        if (t.contains('soil') ||
            t.contains('compost') ||
            t.contains('vermicompost') ||
            t.contains('manure')) {
          return false;
        }
        return t.contains('sarso') ||
            t.contains('mustard') ||
            (t.contains('oil') && !t.contains('soil')) ||
            t.contains('kachi ghani') ||
            t.contains('tel') ||
            t.contains('sesame') ||
            t.contains('til');
      default:
        return true;
    }
  }

  String _categorySubtitle(String cat) {
    switch (cat) {
      case 'Vedic Bilona Ghee':
        return 'Handcrafted using traditional wooden Bilona churning of whole cultured A2 Gir Cow & Buffalo curd.';
      case 'Fresh Milk & Dairy':
        return 'Pure grass-fed A2 chilled raw milk, fresh masala chhachh (buttermilk), malai paneer & makhan.';
      case 'Puja & Hawan Samagri':
        return 'Pure Cow Dung Diyas, Hawan Ghee, Yajna Samagri & sacred Cow Dung sticks.';
      case 'Natural Agarbatti & Dhoop':
        return '100% charcoal-free, organic cow-dung & herbal incense sticks, dhoop cones & sambrani.';
      case 'Vermicompost & Living Soil':
        return 'Living bio-organic vermicompost & composted cow manure for healthy organic farming & gardening.';
      case 'Cold-Pressed Sarso (Mustard) Oil':
        return 'Traditional wood-pressed (Kachi Ghani) pure yellow & black mustard oil with authentic aroma.';
      default:
        return '100% Pure, Chemical-Free Farm Direct Vedic Foods, Living Soil & Sacred Essentials.';
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
                  // Dynamic Showcase Carousel (Powered by Backend Cards)
                  StorefrontCarousel(
                    onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
                  ),

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
                                    Text(
                                      _categorySubtitle(_selectedCategory),
                                      style: const TextStyle(
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
                              error: (_, __) {
                                final d2cProducts = defaultMilterraProducts.where((p) {
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
                                return _buildProductGrid(d2cProducts);
                              },
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
                                              _selectedCategory =
                                                  'All Organic Essentials'),
                                          child: const Text('Explore All Essentials'),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                return _buildProductGrid(d2cProducts);
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

  final Set<String> _addingIds = {};

  Future<void> _addToCart(Product p, int qty) async {
    setState(() => _addingIds.add(p.id));
    try {
      await ref.read(cartProvider.notifier).add(p.id, qty, p);
      if (mounted) {
        showStoreCart(context);
      }
    } finally {
      if (mounted) {
        setState(() => _addingIds.remove(p.id));
      }
    }
  }

  Widget _buildProductGrid(List<Product> products) {
    final groups = storeProductGroups(products);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      int columns = 1;
      if (width >= 1024) {
        columns = 4;
      } else if (width >= 680) {
        columns = 3;
      } else if (width >= 440) {
        columns = 2;
      }

      const gap = 16.0;
      final cardWidth = ((width - (gap * (columns - 1))) / columns)
          .clamp(140.0, 320.0);

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: groups.map((packs) {
          return SizedBox(
            width: cardWidth,
            child: StoreProductCard(
              key: ValueKey(packs.first.id),
              packs: packs,
              compact: columns > 2,
              busyIds: _addingIds,
              onAdd: (p) => _addToCart(p, 1),
              onOpen: (p) => context.push('/shop/product/${p.id}'),
            ),
          );
        }).toList(),
      );
    });
  }

  // ignore: unused_element
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
                              'KNOW YOUR SOURCE — FARM TO FAMILY',
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
                            'Pure A2 Bilona Ghee, Cold-Pressed Oils & Earth Essentials',
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
                            'Traceable farm products you can trust — from handcrafted Vedic Bilona Ghee and Kachi Ghani Mustard Oil to pure Vermicompost and sacred Cow Dung essentials. Every batch, every source, verified.',
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
                                    _selectedCategory = 'Vedic Bilona Ghee'),
                                child: const Text('Explore Bilona Ghee',
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
                                    _selectedCategory = 'All Organic Essentials'),
                                child: const Text('Explore All Essentials',
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
              _ValuePill(icon: Icons.qr_code_2_outlined, text: 'QR Traceable — Know Your Source'),
              SizedBox(width: 24),
              _ValuePill(icon: Icons.shield_outlined, text: 'No Preservatives or Chemicals'),
              SizedBox(width: 24),
              _ValuePill(icon: Icons.agriculture_outlined, text: 'Direct from Our Farms'),
              SizedBox(width: 24),
              _ValuePill(icon: Icons.local_shipping_outlined, text: 'Fast Nationwide Delivery'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBilonaProcessSection() {
    final stages = [
      {
        'step': '01',
        'title': 'Ethical A2 Milking',
        'desc': 'Grass-fed indigenous cows grazing freely in open pastures. Cruelty-free Ahimsa care — calf is fed first.',
        'icon': Icons.favorite_outline,
      },
      {
        'step': '02',
        'title': 'Clay Pot Boiling',
        'desc': 'Slow-boiled in earthen and brass vessels over low flame to protect heat-sensitive enzymes.',
        'icon': Icons.local_fire_department_outlined,
      },
      {
        'step': '03',
        'title': 'Curd Culturing',
        'desc': 'Inoculated with natural probiotic dahi starter and set overnight into rich, live whole curd.',
        'icon': Icons.hourglass_top_outlined,
      },
      {
        'step': '04',
        'title': 'Wooden Bilona',
        'desc': 'Hand-churned with bi-directional wooden madhani to extract nutrient-dense golden makkhan.',
        'icon': Icons.sync_outlined,
      },
      {
        'step': '05',
        'title': 'Slow Clarification',
        'desc': 'Simmered over low wood fire (<100°C) into aromatic golden Danedar ghee packed in glass jars.',
        'icon': Icons.auto_awesome_outlined,
      },
    ];

    final comparisonRows = [
      {
        'param': 'Cow Breed & Care',
        'milterra': '100% Desi A2 Cows (Sahiwal & Gir). Free-grazing, grass-fed, calf nourished first.',
        'commercial': 'High-yield crossbred Jersey/HF cows confined in industrial sheds with hormone injections.',
      },
      {
        'param': 'Base Ingredient',
        'milterra': 'Cultured live curd (Dahi) fermented overnight with active probiotic cultures.',
        'commercial': 'Leftover industrial raw cream separated via high-speed mechanical centrifuges.',
      },
      {
        'param': 'Milk per 1 kg',
        'milterra': '28 to 30 Litres of 100% pure A2 milk boiled, curdled, and slow-churned.',
        'commercial': 'Synthesized from factory cream derivatives and recombined milk fats.',
      },
      {
        'param': 'Heating Method',
        'milterra': 'Slow-simmered over low wood & cow-dung flame (<100°C), preserving enzymes.',
        'commercial': 'Heated at high pressure (180°C+) in industrial steel steam boilers, killing nutrients.',
      },
      {
        'param': 'Texture & Aroma',
        'milterra': 'Rich golden crystalline Danedar texture with an authentic, sweet nutty aroma.',
        'commercial': 'Smooth, greasy, oily consistency. Often added with synthetic flavoring & color.',
      },
      {
        'param': 'Digestibility',
        'milterra': 'A2 Beta-Casein, 100% lactose-free, rich in gut-soothing Butyric acid & Vitamin K2.',
        'commercial': 'Contains inflammatory A1 Beta-Casein peptide (BCM-7), often triggering bloating.',
      },
      {
        'param': 'Purity Guarantee',
        'milterra': 'FSSAI & NABL lab-certified 0% palm oil. Packed in lead-free food-grade glass jars.',
        'commercial': 'Mass aggregated, non-traceable supply chains with high adulteration risk.',
      },
    ];

    return Container(
      width: double.infinity,
      color: storeWhite,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: storeGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: storeGold.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'WHY MILTERRA — KNOW YOUR SOURCE',
                  style: TextStyle(
                    color: storeGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The Sacred 5-Stage Vedic Bilona Standard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'CormorantGaramond',
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: storeGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Handcrafted according to ancient Ayurvedic texts — Churned from curd, never from cream.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: storeMuted),
              ),
              const SizedBox(height: 36),

              // 5 Stages Grid
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 768;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: stages.map((s) {
                      return SizedBox(
                        width: isWide ? (constraints.maxWidth - 56) / 5 : constraints.maxWidth,
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: storeGreen),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s['desc'] as String,
                                style: const TextStyle(fontSize: 11, color: storeMuted, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 48),

              // Comparison Matrix
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: storeCream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: storeBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Milterra Vedic Bilona vs Commercial Factory Ghee',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: storeGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Understand why 30 litres of pure A2 milk makes all the difference for your health and vitality.',
                      style: TextStyle(fontSize: 12.5, color: storeMuted),
                    ),
                    const SizedBox(height: 20),
                    // Table Header
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: storeGreen),
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
                                      style: const TextStyle(fontSize: 11.5, color: storeText, height: 1.3),
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
                                      style: const TextStyle(fontSize: 11.5, color: storeMuted, height: 1.3),
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
              ),
              const SizedBox(height: 32),

              // Lab Testing & FSSAI Trust Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffbbf7d0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xff16a34a), size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NABL Lab Tested & Certified Purity (Batch MIL-GHEE-2026-10)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff166534))),
                          SizedBox(height: 2),
                          Text('99.9% Purity Score • 99.85% Milk Fat • 0.0% Palm Oil / Adulteration • FSSAI Certified',
                              style: TextStyle(fontSize: 12, color: Color(0xff15803d))),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff16a34a),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => context.go('/balance'),
                      child: const Text('Verify Lab Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
