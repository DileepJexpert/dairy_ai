import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/widgets/store_product_card.dart';
import '../../marketplace/widgets/rfq_quote_dialog.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';

/// Dedicated Farmer Hub & Multi-Vendor Marketplace (Toolsvilla + IndiaMART + OLX).
class FarmerMarketplaceScreen extends ConsumerStatefulWidget {
  const FarmerMarketplaceScreen({
    super.key,
    this.initialCategory = 'All Departments',
    this.initialQuery = '',
  });

  final String initialCategory;
  final String initialQuery;

  @override
  ConsumerState<FarmerMarketplaceScreen> createState() =>
      _FarmerMarketplaceScreenState();
}

class _FarmerMarketplaceScreenState
    extends ConsumerState<FarmerMarketplaceScreen> {
  late String _selectedCategory;
  late final TextEditingController _searchController;
  final _rfqReqController = TextEditingController();

  static const List<String> _departments = [
    'All Departments',
    'Machinery & Equipment',
    'Animal Nutrition & Feeds',
    'Dairy Farm Tools & Spares',
    'Pashu Mandi (Cattle Trade)',
    'Soil & Organic Inputs',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rfqReqController.dispose();
    super.dispose();
  }

  bool _matchesCategory(Product p, String cat) {
    if (cat == 'All Departments' || cat == 'All') return true;
    final t = p.title.toLowerCase();
    switch (cat) {
      case 'Machinery & Equipment':
        return t.contains('chaff') ||
            t.contains('milker') ||
            t.contains('separator') ||
            t.contains('machine') ||
            t.contains('equipment') ||
            p.category == ProductCategory.equipment;
      case 'Animal Nutrition & Feeds':
        return t.contains('feed') ||
            t.contains('calci') ||
            t.contains('minera') ||
            t.contains('nutrition') ||
            t.contains('lacta') ||
            p.category == ProductCategory.feedNutrition;
      case 'Dairy Farm Tools & Spares':
        return t.contains('can') ||
            t.contains('blade') ||
            t.contains('analyzer') ||
            t.contains('tool') ||
            t.contains('spares');
      case 'Soil & Organic Inputs':
        return t.contains('earth') ||
            t.contains('vermicompost') ||
            t.contains('manure');
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider(null));
    final rfqFeedAsync = ref.watch(recentRFQsProvider);
    final query = _searchController.text.trim().toLowerCase();

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          StoreHeader(
            currentCategory: _selectedCategory,
            isFarmerHub: true,
          ),
          StoreCategoryNavigation(
            selected: _selectedCategory,
            onSelected: (cat) => setState(() => _selectedCategory = cat),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Live IndiaMART RFQ Demand Ticker
                  _buildLiveRFQTicker(rfqFeedAsync),

                  // Toolsvilla & IndiaMART Hero Banner
                  _buildFarmerHero(),

                  // IndiaMART "Post Buy Requirement" Banner
                  _buildPostBuyRequirementBanner(),

                  // Main Catalog Grid
                  Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Department Filter Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _departments.map((dept) {
                                  final isSelected = _selectedCategory == dept;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      selected: isSelected,
                                      selectedColor: storeGreen,
                                      backgroundColor: storeWhite,
                                      label: Text(
                                        dept,
                                        style: TextStyle(
                                          color: isSelected
                                              ? storeWhite
                                              : storeText,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onSelected: (_) => setState(
                                          () => _selectedCategory = dept),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Product Grid
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
                                  child: Text('Unable to load catalog: $err',
                                      style: const TextStyle(color: storeText)),
                                ),
                              ),
                              data: (allProducts) {
                                final filtered = allProducts.where((p) {
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

                                if (filtered.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(48),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        const Icon(Icons.precision_manufacturing,
                                            size: 48, color: storeMuted),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'No machinery or supplies found in this department.',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: storeGreen),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () => setState(() =>
                                              _selectedCategory =
                                                  'All Departments'),
                                          child:
                                              const Text('View All Equipment'),
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
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: 16,
                                        childAspectRatio: 0.72,
                                      ),
                                      itemCount: filtered.length,
                                      itemBuilder: (ctx, i) {
                                        final prod = filtered[i];
                                        final isMachinery = prod.category ==
                                                ProductCategory.equipment ||
                                            prod.title
                                                .toLowerCase()
                                                .contains('chaff') ||
                                            prod.title
                                                .toLowerCase()
                                                .contains('milker');

                                         return StoreProductCard(
                                          packs: [prod],
                                          onOpen: (p) {
                                            if (isMachinery) {
                                              context.push(
                                                  '/machinery/${prod.id}');
                                            } else {
                                              context
                                                  .push('/product/${prod.id}');
                                            }
                                          },
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

                  // Vendor & Manufacturer Onboarding CTA Banner
                  _buildVendorOnboardingBanner(),

                  const StoreFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveRFQTicker(AsyncValue<List<dynamic>> rfqFeedAsync) {
    return Container(
      width: double.infinity,
      color: const Color(0xff0f2922),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: storeOrange,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'LIVE RFQ DEMAND',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: rfqFeedAsync.when(
                  loading: () => const Text('Connecting to live Mandi demand...',
                      style: TextStyle(color: StorePalette.onDark, fontSize: 11)),
                  error: (_, __) => const Text(
                      'Live B2B Requirement: 15 Chaff Cutters (3HP) requested in Karnal • 50 bags Cattle Feed needed in Anand',
                      style: TextStyle(color: StorePalette.onDark, fontSize: 11)),
                  data: (leads) {
                    if (leads.isEmpty) {
                      return const Text(
                          'Recent Demand: 3HP Heavy Chaff Cutters (Karnal) • High Milk Yield Cattle Feed 50kg (Anand)',
                          style: TextStyle(
                              color: StorePalette.onDark, fontSize: 11));
                    }
                    final tickerText = leads.map((l) {
                      final item = l['product_title'] ?? 'Farm Equipment';
                      final city = l['city'] ?? 'India';
                      final qty = l['quantity'] ?? '1';
                      return '📌 $item ($qty units) - $city';
                    }).join('  •  ');
                    return Text(
                      tickerText,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: StorePalette.onDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFarmerHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: storeGreen,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth >= 768;
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isWide ? 7 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: storeGold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'TOOLSVILLA + INDIAMART + OLX UNIFIED HUB',
                                  style: TextStyle(
                                      color: storeGold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Farm Machinery, Commercial Feed & Pashu Mandi',
                            style: TextStyle(
                              fontFamily: 'CormorantGaramond',
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: storeWhite,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Direct factory rates on heavy chaff cutters, milking machines, animal nutrition, and verified cattle classifieds with doorstep logistics.',
                            style: TextStyle(
                                color: StorePalette.onDark,
                                fontSize: 13,
                                height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: 24)
                    else const SizedBox(height: 16),
                    Expanded(
                      flex: isWide ? 4 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: storeGold.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Looking for pure Vedic Ghee?',
                              style: TextStyle(
                                  color: storeGold,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Visit our bare-minimal D2C store for A2 Gir Cow & Buffalo Bilona Ghee.',
                              style: TextStyle(
                                  color: StorePalette.onDark, fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: storeGold,
                                foregroundColor: storeGreen,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),
                              onPressed: () => context.go('/shop'),
                              child: const Text('Go to Milterra Ghee Store →',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
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

  Widget _buildPostBuyRequirementBanner() {
    return Container(
      color: storeCream,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: storeWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: storeBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xfffff7ed),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      color: storeOrange, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post Buy Requirement (IndiaMART RFQ)',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: storeGreen),
                      ),
                      Text(
                        'Get instant competitive quotes from verified OEMs & machinery distributors.',
                        style: TextStyle(fontSize: 11, color: storeMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: storeOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => showRFQQuoteDialog(context),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Submit RFQ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorOnboardingBanner() {
    return Container(
      width: double.infinity,
      color: storeDarkGreenNav,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you an Agri Machinery OEM or Cattle Feed Mill?',
                      style: TextStyle(
                          color: storeGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Join India\'s leading dairy & farm equipment marketplace. Reach over 50,000 dairy farmers nationwide.',
                      style:
                          TextStyle(color: StorePalette.onDark, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: storeGold,
                  foregroundColor: storeGreen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () => context.push('/marketplace/sell'),
                child: const Text('Register as Vendor / Post Ad',
                    style: TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
