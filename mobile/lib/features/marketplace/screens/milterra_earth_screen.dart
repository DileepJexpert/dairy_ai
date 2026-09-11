import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/store_product_card.dart';

/// Dedicated Landing Page for MILTERRA Earth category:
/// "From Farm Waste to Living Soil"
class MilterraEarthScreen extends ConsumerStatefulWidget {
  const MilterraEarthScreen({super.key});

  @override
  ConsumerState<MilterraEarthScreen> createState() => _MilterraEarthScreenState();
}

class _MilterraEarthScreenState extends ConsumerState<MilterraEarthScreen> {
  final _emailPhoneCtrl = TextEditingController();
  String _selectedSubcategory = 'All';
  String _sort = 'Featured';

  @override
  void dispose() {
    _emailPhoneCtrl.dispose();
    super.dispose();
  }

  void _handleNotifySubmit() {
    final input = _emailPhoneCtrl.text.trim();
    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeEarthTerracotta,
          content: Text('Please enter your WhatsApp number or email address.'),
        ),
      );
      return;
    }

    _emailPhoneCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: storeEarthDarkGreen,
        duration: Duration(seconds: 4),
        content: Text(
          '🌱 Thank you! You have been added to the MILTERRA Earth priority launch list.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));

    return Scaffold(
      backgroundColor: storeEarthCream,
      body: LayoutBuilder(builder: (context, size) {
        final isDesktop = size.maxWidth >= StoreLayout.desktop;
        final isMobile = size.maxWidth < StoreLayout.mobile;

        return Column(
          children: [
            const StoreHeader(currentCategory: 'MILTERRA Earth'),
            StoreCategoryNavigation(
              selected: 'MILTERRA Earth',
              onSelected: (cat) {
                if (cat == 'MILTERRA Earth') return;
                context.go(Uri(
                  path: '/shop',
                  queryParameters: {'category': cat},
                ).toString());
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Main Hero & Story Header
                    _buildHeroHeader(isDesktop, isMobile),

                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 24,
                            vertical: 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Circular Farm Composting Story Banner
                              _buildCompostingStoryBanner(isMobile),
                              const SizedBox(height: 28),

                              // Educational Cards: Vermicompost vs Manure vs Enriched Compost
                              _buildEducationalSection(isDesktop, isMobile),
                              const SizedBox(height: 32),

                              // Products Catalogue Section Header & Filter Tabs
                              _buildCatalogueHeader(isMobile),
                              const SizedBox(height: 16),

                              // Product Grid
                              productsAsync.when(
                                loading: () => const SizedBox(
                                  height: 280,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                                error: (_, __) => const Center(
                                  child: Text('Could not load Earth catalogue.'),
                                ),
                                data: (items) {
                                  final earthProducts = items.where((p) {
                                    final t = p.title.toLowerCase();
                                    final isEarth = p.taxonomy?['is_earth'] == true ||
                                        p.taxonomy?['category_name'] == 'MILTERRA Earth' ||
                                        t.contains('earth') ||
                                        t.contains('vermicompost') ||
                                        t.contains('manure') ||
                                        t.contains('compost') ||
                                        t.contains('soil mix');
                                    if (!isEarth) return false;

                                    if (_selectedSubcategory == 'Vermicompost') {
                                      return t.contains('vermicompost');
                                    } else if (_selectedSubcategory == 'Manure') {
                                      return t.contains('manure');
                                    } else if (_selectedSubcategory == 'Compost & Cakes') {
                                      return t.contains('compost') || t.contains('cake');
                                    } else if (_selectedSubcategory == 'Soil & Starters') {
                                      return t.contains('soil') || t.contains('starter');
                                    }
                                    return true;
                                  }).toList();

                                  if (_sort == 'Price: low to high') {
                                    earthProducts.sort((a, b) => a.price.compareTo(b.price));
                                  } else if (_sort == 'Price: high to low') {
                                    earthProducts.sort((a, b) => b.price.compareTo(a.price));
                                  } else if (_sort == 'Name: A to Z') {
                                    earthProducts.sort((a, b) => a.title.compareTo(b.title));
                                  }

                                  return _buildProductGrid(earthProducts, isMobile);
                                },
                              ),

                              const SizedBox(height: 40),

                              // Launch Priority Notification Bar
                              _buildNotifySignupBanner(isMobile),
                              const SizedBox(height: 36),

                              // FAQ Section
                              _buildFaqSection(isMobile),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const StoreFooter(),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildHeroHeader(bool isDesktop, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 32 : 54,
      ),
      decoration: const BoxDecoration(
        color: storeEarthDarkGreen,
        image: DecorationImage(
          image: AssetImage('assets/store/farm-pasture.jpg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Color(0xd91e3a2b),
            BlendMode.darken,
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: storeEarthTerracotta,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'MILTERRA EARTH · NATURAL BY-PRODUCTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Main Heading
              Text(
                'From Farm Waste to Living Soil',
                style: TextStyle(
                  fontSize: isMobile ? 26 : 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),

              // Subheading
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  'Thoughtfully processed natural products for gardens and farms.',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 18,
                    color: const Color(0xffe8ede4),
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Feature Tags
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _heroPill(Icons.check_circle_outline, '100% Odorless & Cured'),
                  _heroPill(Icons.biotech_outlined, 'Batch-Tested Organic Carbon'),
                  _heroPill(Icons.shield_outlined, 'Pathogen & Weed-Seed Free'),
                  _heroPill(Icons.local_shipping_outlined, 'Coming Soon Across India'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: storeGold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompostingStoryBanner(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: const Color(0xfff5f0e6),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: const Color(0xffdcd1bf)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: storeEarthDarkGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.recycling_rounded, color: storeGold, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Circular Farm Ecology',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: storeEarthDarkGreen,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Every cow on our partner dairy farms generates valuable organic biomass. Instead of treating it as waste, our biological composting process uses solarization, fine rotary screening, and Eisenia fetida earthworm digestion to transform raw manure into living soil conditioners rich in beneficial micro-organisms.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xff443e37),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalSection(bool isDesktop, bool isMobile) {
    final concepts = [
      (
        title: 'Premium Vermicompost',
        desc: 'Earthworm-digested bio-humus with billions of living microbes. Best for houseplant potting mixes and vegetable beds.',
        icon: Icons.yard_outlined,
        color: storeEarthDarkGreen,
        bg: const Color(0xfff0f5ee),
      ),
      (
        title: 'Aged Farm Manure',
        desc: 'Solarized and screened 120+ days cattle manure for deep soil aeration, seasonal conditioning, and lawn top-dressing.',
        icon: Icons.nature_outlined,
        color: storeEarthWarmBrown,
        bg: const Color(0xfff7f3ee),
      ),
      (
        title: 'Enriched Compost & Soil',
        desc: 'Fortified with cold-pressed neem cake and rock phosphate to protect root zones and provide sustained natural nutrition.',
        icon: Icons.eco_outlined,
        color: storeEarthTerracotta,
        bg: const Color(0xfffcf5f0),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Understanding Natural Soil Conditioning',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeEarthDarkGreen,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Each product is tailored for specific stages of plant care and soil revitalization.',
          style: TextStyle(fontSize: 13, color: storeMuted),
        ),
        const SizedBox(height: 14),
        if (isMobile)
          Column(
            children: concepts.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _educationalCard(c.title, c.desc, c.icon, c.color, c.bg),
            )).toList(),
          )
        else
          Row(
            children: concepts.map((c) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: c == concepts.last ? 0 : 14),
                child: _educationalCard(c.title, c.desc, c.icon, c.color, c.bg),
              ),
            )).toList(),
          ),
      ],
    );
  }

  Widget _educationalCard(String title, String desc, IconData icon, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xff4b5563),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogueHeader(bool isMobile) {
    final subcategories = ['All', 'Vermicompost', 'Manure', 'Compost & Cakes', 'Soil & Starters'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'MILTERRA Earth Catalogue (6 Products)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: storeEarthDarkGreen,
                ),
              ),
            ),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: storeWhite,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: storeBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sort,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: storeEarthDarkGreen,
                  ),
                  items: [
                    'Featured',
                    'Price: low to high',
                    'Price: high to low',
                    'Name: A to Z',
                  ].map((s) => DropdownMenuItem(value: s, child: Text('Sort: $s'))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _sort = v);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: subcategories.map((sub) {
              final isSelected = _selectedSubcategory == sub;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(sub),
                  selected: isSelected,
                  selectedColor: storeEarthDarkGreen,
                  backgroundColor: storeWhite,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : storeEarthDarkGreen,
                  ),
                  side: BorderSide(
                    color: isSelected ? storeEarthDarkGreen : storeBorder,
                  ),
                  onSelected: (_) => setState(() => _selectedSubcategory = sub),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(List<Product> products, bool isMobile) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: const Text('No products matched the selected subcategory filter.'),
      );
    }

    final groups = storeProductGroups(products);

    return LayoutBuilder(builder: (context, bounds) {
      final int columns;
      if (bounds.maxWidth >= 960) {
        columns = 3;
      } else if (bounds.maxWidth >= 600) {
        columns = 2;
      } else {
        columns = 1;
      }

      final gap = isMobile ? 12.0 : 18.0;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: groups
            .map((packs) => SizedBox(
                width: ((bounds.maxWidth - gap * (columns - 1)) / columns)
                    .clamp(160.0, 360.0),
                child: StoreProductCard(
                    key: ValueKey(packs.first.id),
                    packs: packs,
                    compact: isMobile,
                    busyIds: const {},
                    onAdd: (_) {},
                    onOpen: (p) => context.go('/shop/product/${p.id}'))))
            .toList(),
      );
    });
  }

  Widget _buildNotifySignupBanner(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 28),
      decoration: BoxDecoration(
        color: storeEarthDarkGreen,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeEarthTerracotta.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: storeEarthTerracotta,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Join the MILTERRA Earth Priority Launch List',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to receive notifications when our initial batch of premium vermicompost and aged cow-dung manure opens for online orders.',
            style: TextStyle(fontSize: 13, color: Color(0xffd5ded2), height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    controller: _emailPhoneCtrl,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Enter WhatsApp phone number or email',
                      hintStyle: TextStyle(fontSize: 12, color: storeMuted),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: storeAmber,
                    foregroundColor: storeEarthDarkGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  onPressed: _handleNotifySubmit,
                  child: const Text('Notify Me', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection(bool isMobile) {
    final faqs = [
      (
        q: 'Is MILTERRA Earth vermicompost and manure odorless?',
        a: 'Yes. Through aerobic windrow composting, solarization, and earthworm decomposition, volatile odors are eliminated, leaving a pleasant, natural earthy forest smell that is safe for indoors.',
      ),
      (
        q: 'Is it safe for indoor houseplants and balcony potted greens?',
        a: 'Absolutely. All batches undergo thermal heat solarization to ensure they are 100% free from weed seeds, insect larvae, pathogens, and synthetic chemicals.',
      ),
      (
        q: 'How does vermicompost differ from raw cow dung manure?',
        a: 'Vermicompost is pre-digested by specialized earthworms (Eisenia fetida), making its nutrients immediately bio-available to plant roots without risking nitrogen burn.',
      ),
      (
        q: 'How can I trace the origin of my soil conditioner batch?',
        a: 'Each package will feature a batch QR code linked directly to the Dairy AI partner farm network and organic carbon lab analysis certificate.',
      ),
      (
        q: 'When will home delivery and farm dispatch start?',
        a: 'Initial batch dispatches are launching soon across India via our nationwide logistics network.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently Asked Questions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeEarthDarkGreen,
          ),
        ),
        const SizedBox(height: 12),
        ...faqs.map((f) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: storeWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: storeBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, size: 16, color: storeEarthTerracotta),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f.q,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff111111),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      f.a,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xff4b5563),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
