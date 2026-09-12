import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/store_product_card.dart';
import '../widgets/hero_split_showcase.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../../commerce/models/taxonomy.dart';
import '../../commerce/providers/commerce_provider.dart';
import '../../admin/providers/admin_marketplace_provider.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen(
      {super.key,
      this.category,
      this.initialQuery = '',
      this.initialCategory = 'All products'});
  final ProductCategory? category;
  final String initialQuery, initialCategory;
  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _search = TextEditingController();
  final _catalogueKey = GlobalKey();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  String _category = 'All products', _sort = 'Featured';
  bool _inStock = false;
  double _minRating = 0;
  double _priceMin = 0, _priceMax = 0;
  final Set<String> _adding = {};
  TaxonomyCatalogue? _taxonomy;

  String _label(String value) {
    final lower = value.toLowerCase();
    if (_taxonomy?.enabled == true && value != 'All products') {
      for (final node in _taxonomy!.nodes) {
        if (node.id == value || node.slug == value) {
          final nLower = node.name.toLowerCase();
          if (nLower.contains('animal') ||
              nLower.contains('nutrition') ||
              nLower.contains('feed')) {
            return 'MILTERRA Cattle Nutrition Solutions';
          }
          return node.name;
        }
      }
    }
    if (lower.contains('earth') ||
        lower == 'milterra-earth' ||
        lower == 'cat-earth') {
      return '🌱 MILTERRA Earth: Living Soil';
    }
    if (lower.contains('animal') ||
        lower.contains('cattle nutrition') ||
        lower == 'animal-nutrition' ||
        lower == 'cat-animal-nutrition') {
      return 'MILTERRA Cattle Nutrition Solutions';
    }
    return switch (value) {
      'Dairy Foods' => 'Dairy Foods',
      'MILTERRA Earth' || 'milterra-earth' || 'Earth' => '🌱 MILTERRA Earth',
      'Vermicompost' => 'Premium Vermicompost',
      'Farm Manure' => 'Cow-Dung Farm Manure',
      'Organic Compost' => 'Enriched Organic Compost',
      'Compost Cakes' => 'Dried Compost Cakes',
      'Compost Starter' => 'Compost Starter',
      'Garden Soil Mix' => 'Garden Soil Mix',
      'Animal nutrition' ||
      'Cattle Nutrition' ||
      'MILTERRA Cattle Nutrition Solutions' =>
        'MILTERRA Cattle Nutrition Solutions',
      'Pashu Aahar / Cattle Feed' => 'Pashu Aahar / Cattle Feed',
      'Stage-Based Nutrition Courses' ||
      'Stage-Based Nutrition' =>
        'Stage-Based Nutrition',
      'Supplements' || 'Supplements & Minerals' => 'Supplements & Minerals',
      'Equipment' => 'Dairy & Farm Equipment',
      'Cow ghee' => 'A2 Desi Cow Ghee',
      'Buffalo ghee' => 'Rich Buffalo Ghee',
      'Paneer' => 'Fresh Malai Paneer',
      'Other products' => 'White Butter (Makhan)',
      _ => value,
    };
  }

  @override
  void initState() {
    super.initState();
    _search.text = widget.initialQuery;
    _category = widget.initialCategory;
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialCategory != widget.initialCategory) {
      _search.text = widget.initialQuery;
      _category = widget.initialCategory;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _browse(_category);
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  void _browse(String category) {
    setState(() => _category = category);
    final target = _catalogueKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 350));
    }
    final params = <String, String>{};
    if (category != 'All products' && category != 'All') {
      params['category'] = category;
    }
    if (_search.text.trim().isNotEmpty) {
      params['query'] = _search.text.trim();
    }
    context.go(Uri(
      path: '/shop',
      queryParameters: params.isEmpty ? null : params,
    ).toString());
  }

  void _reset() {
    setState(() {
      _search.clear();
      _category = 'All products';
      _priceMin = 0;
      _priceMax = 0;
      _minPriceCtrl.clear();
      _maxPriceCtrl.clear();
      _inStock = false;
      _sort = 'Featured';
    });
    context.go('/shop');
  }

  Future<void> _add(Product p) async {
    if (ref.read(currentUserProvider) == null) {
      context.go('/login?next=/shop/product/${p.id}');
      return;
    }
    setState(() => _adding.add(p.id));
    try {
      await ref.read(cartProvider.notifier).add(p.id, p.minOrderQuantity);
      if (mounted) {
        await showStoreCart(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not add this item. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _adding.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    _taxonomy = ref.watch(taxonomyProvider).valueOrNull;
    final catalogue = ref.watch(productsProvider(widget.category));

    return Scaffold(
      backgroundColor: storeCream,
      body: LayoutBuilder(builder: (context, size) {
        final isDesktop = size.maxWidth >= StoreLayout.desktop;
        final isMobile = size.maxWidth < StoreLayout.mobile;

        return Column(
          children: [
            // Top Amazon Header & Subnav
            StoreHeader(
              currentCategory: _label(_category),
              initialSearch: _search.text,
            ),
            StoreCategoryNavigation(
              selected: _category,
              onSelected: _browse,
              legacyEquipment: widget.category == ProductCategory.equipment,
            ),

            // Main Scrollable Content Area
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey('store-catalogue-scroll'),
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: StoreLayout.maxWidth),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 24,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero Banner & Purity Trust Strip (Home / Unfiltered view)
                              if (_search.text.isEmpty &&
                                  (_category == 'All products' ||
                                      _category == 'All')) ...[
                                _hero(size.maxWidth),
                                const SizedBox(height: 14),
                                _buildTrustAndQualityStrip(isMobile),
                                const SizedBox(height: 18),
                              ],

                              // Amazon Catalogue Section (Results Bar + Sidebar + Grid)
                              Container(
                                key: _catalogueKey,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Desktop Faceted Filter Sidebar
                                    if (isDesktop) ...[
                                      SizedBox(
                                        width: 260,
                                        child: _filters(() => setState(() {})),
                                      ),
                                      const SizedBox(width: 24),
                                    ],

                                    // Products Grid Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Dedicated Category/Department Landing Banner (when filtered)
                                          if (_category != 'All products' &&
                                              _category != 'All') ...[
                                            _buildDepartmentLandingBanner(
                                                isMobile),
                                            const SizedBox(height: 14),
                                          ],

                                          // Amazon Results & Sort Header Bar
                                          _buildResultsHeader(isDesktop),
                                          const SizedBox(height: 14),

                                          // Catalogue State
                                          catalogue.when(
                                            loading: () => const SizedBox(
                                              height: 320,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                            error: (_, __) => _message(
                                              Icons.cloud_off_outlined,
                                              'We couldn’t load the collection',
                                              'Please check your connection and try again.',
                                              'Try again',
                                              () => ref.invalidate(
                                                  productsProvider(
                                                      widget.category)),
                                            ),
                                            data: (items) =>
                                                _products(items, isMobile),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 36),
                              _editorial(isMobile),
                              const SizedBox(height: 24),

                              // Amazon-style Assurance Footer Strip
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 20),
                                decoration: BoxDecoration(
                                  color: storeSage,
                                  borderRadius:
                                      BorderRadius.circular(StoreLayout.radius),
                                  border: Border.all(color: storeBorder),
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 24,
                                  runSpacing: 16,
                                  children: [
                                    _benefit(
                                        Icons.local_shipping_outlined,
                                        'Fast & Pure Delivery',
                                        'Direct from verified dairy farms.'),
                                    _benefit(
                                        Icons.verified_user_outlined,
                                        '100% Quality Guaranteed',
                                        'Rigorous laboratory purity testing.'),
                                    _benefit(
                                        Icons.lock_outline,
                                        'Secure Payments',
                                        'UPI, Cards, NetBanking & COD.'),
                                    _benefit(
                                        Icons.support_agent_outlined,
                                        '24/7 Dedicated Support',
                                        'Help on orders & subscriptions.'),
                                  ],
                                ),
                              ),
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

  Widget _buildResultsHeader(bool isDesktop) {
    final query = _search.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.controlRadius),
        border: Border.all(color: storeBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(builder: (_) {
                  final isNutrition =
                      _category.toLowerCase().contains('animal') ||
                          _category.toLowerCase().contains('nutrition') ||
                          _category.toLowerCase().contains('feed') ||
                          _category.toLowerCase().contains('supplement') ||
                          _category.toLowerCase().contains('pashu') ||
                          _category.toLowerCase().contains('stage');
                  return Text(
                    isNutrition ? 'FEATURED NUTRITION CONCEPTS' : 'RESULTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isNutrition
                          ? storeGreen
                          : storeGreen.withValues(alpha: 0.8),
                    ),
                  );
                }),
                const SizedBox(height: 2),
                Text(
                  _category == 'All products'
                      ? (query.isEmpty
                          ? 'Showing all products'
                          : 'Results for “$query”')
                      : '${_label(_category)}${query.isEmpty ? '' : ' · “$query”'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff111111),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isDesktop)
            IconButton(
              tooltip: 'Filter Products',
              onPressed: _showFilters,
              icon: const Icon(Icons.tune, color: storeGreen),
            ),
          const SizedBox(width: 8),
          if (!isDesktop)
            PopupMenuButton<String>(
              tooltip: 'Sort products',
              icon: const Icon(Icons.sort, color: storeGreen),
              initialValue: _sort,
              onSelected: (value) => setState(() => _sort = value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'Featured', child: Text('Featured')),
                PopupMenuItem(
                    value: 'Price: low to high',
                    child: Text('Price: low to high')),
                PopupMenuItem(
                    value: 'Price: high to low',
                    child: Text('Price: high to low')),
                PopupMenuItem(
                    value: 'Name: A to Z', child: Text('Name: A to Z')),
              ],
            )
          else
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: storeCream,
                borderRadius: BorderRadius.circular(StoreLayout.controlRadius),
                border: Border.all(color: storeBorder),
              ),
              child: Material(
                color: Colors.transparent,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: const [
                      'Featured',
                      'Price: low to high',
                      'Price: high to low',
                      'Name: A to Z',
                    ].contains(_sort)
                        ? _sort
                        : 'Featured',
                    icon: const Icon(Icons.arrow_drop_down,
                        size: 18, color: storeGreen),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: storeGreen,
                    ),
                    items: const [
                      'Featured',
                      'Price: low to high',
                      'Price: high to low',
                      'Name: A to Z',
                    ]
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text('Sort: $v'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _sort = value);
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hero(double screenWidth) {
    return HeroSplitShowcase(
      screenWidth: screenWidth,
      onExploreCategory: _browse,
    );
  }

  Widget _buildTrustAndQualityStrip(bool isMobile) {
    final pillars = [
      (
        title: 'Clear product details',
        subtitle: 'Compare pack size, price and stock',
        badge: 'Easy choice',
        icon: Icons.fact_check_outlined,
        iconBg: const Color(0xffe8f5e9),
        iconColor: const Color(0xff1e8e3e),
        actionLabel: 'Browse products →',
        onTap: () => _browse('All products'),
      ),
      (
        title: 'Seller information',
        subtitle: 'Know who lists and fulfils each item',
        badge: 'Visible',
        icon: Icons.storefront_outlined,
        iconBg: const Color(0xfffef3d6),
        iconColor: const Color(0xffb7791f),
        actionLabel: 'Explore catalogue →',
        onTap: () => _browse('All products'),
      ),
      (
        title: 'Delivery at checkout',
        subtitle: 'Timing and charges use your location',
        badge: 'Confirmed',
        icon: Icons.ac_unit_rounded,
        iconBg: const Color(0xffe0f2fe),
        iconColor: const Color(0xff0284c7),
        actionLabel: 'Shop now →',
        onTap: () => _browse('All products'),
      ),
      (
        title: 'Documents when supplied',
        subtitle: 'Certificates appear only when attached',
        badge: 'Verified data',
        icon: Icons.verified_outlined,
        iconBg: const Color(0xfffef9c3),
        iconColor: const Color(0xffa16207),
        actionLabel: 'View products →',
        onTap: () => _browse('All products'),
      ),
    ];

    Widget buildCard({
      required String title,
      required String subtitle,
      required String badge,
      required IconData icon,
      required Color iconBg,
      required Color iconColor,
      required String actionLabel,
      required VoidCallback onTap,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffe2e8f0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Icon Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),

                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: storeGreen,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff64748b),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: storeOrange,
                        ),
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

    if (isMobile) {
      return Column(
        children: pillars.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: buildCard(
              title: p.title,
              subtitle: p.subtitle,
              badge: p.badge,
              icon: p.icon,
              iconBg: p.iconBg,
              iconColor: p.iconColor,
              actionLabel: p.actionLabel,
              onTap: p.onTap,
            ),
          );
        }).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, bounds) {
        final columns = bounds.maxWidth < 1000 ? 2 : 4;
        const gap = 12.0;
        final cardWidth = (bounds.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: pillars
              .map((p) => SizedBox(
                    width: cardWidth,
                    child: buildCard(
                      title: p.title,
                      subtitle: p.subtitle,
                      badge: p.badge,
                      icon: p.icon,
                      iconBg: p.iconBg,
                      iconColor: p.iconColor,
                      actionLabel: p.actionLabel,
                      onTap: p.onTap,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  void _showPurityGuaranteeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.science, color: storeGreen, size: 24),
            SizedBox(width: 10),
            Text('Milterra 99.4% Purity Guarantee',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Every jar of Milterra A2 Desi Cow Bilona Ghee undergoes independent 7-stage analytical lab tests:',
                style: TextStyle(fontSize: 13, color: Color(0xff334155)),
              ),
              SizedBox(height: 12),
              Text(
                  '• Zero Vegetable / Palm Oil Adulteration (Baudouin Test Negative)'),
              Text('• Free Fatty Acids (FFA) strictly below 0.2%'),
              Text('• 100% Genuine Gir Cow DNA & A2 Beta-Casein certified'),
              Text(
                  '• Zero synthetic preservatives, colorants, or chemical aromas'),
              SizedBox(height: 12),
              Text(
                'Tested at National Dairy Research & Quality Laboratories, Karnal.',
                style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: storeMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              Navigator.pop(ctx);
              _browse('Cow ghee');
            },
            child: const Text('Shop Tested Ghee'),
          ),
        ],
      ),
    );
  }

  void _showColdChainDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.ac_unit, color: storeGreen, size: 24),
            SizedBox(width: 10),
            Text('Farm-to-Doorstep Cold-Chain',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fresh dairy products like Malai Paneer and Vedic White Makhan require strict temperature regulation to stay fresh without chemicals:',
                style: TextStyle(fontSize: 13, color: Color(0xff334155)),
              ),
              SizedBox(height: 12),
              Text(
                  '• Insulated food-grade thermocol packaging with gel ice packs'),
              Text(
                  '• Monitored at continuous 4°C storage throughout linehaul transit'),
              Text(
                  '• Express courier dispatch via DTDC & Delhivery cold-chain network'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showBatchCertificatesModal() {
    final certificates = ref.watch(adminMarketplaceProvider).batchCertificates;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: storeGreen, size: 24),
            SizedBox(width: 10),
            Text('Verified Batch Lab Certificates',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inspect official laboratory test results for active batches dispatched to customers:',
                style: TextStyle(fontSize: 12, color: Color(0xff475569)),
              ),
              const SizedBox(height: 12),
              for (final cert in certificates)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: const Color(0xfff8fafc),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.science, color: storeGreen),
                    title: Text('${cert.batchNumber} · ${cert.productTitle}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Purity: ${cert.purityPercent}% | FSSAI: ${cert.fssaiLicense}',
                        style:
                            const TextStyle(fontSize: 10.5, color: storeMuted)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentLandingBanner(bool isMobile) {
    final catLower = _category.toLowerCase();
    final labelLower = _label(_category).toLowerCase();
    final isNutrition = catLower.contains('animal') ||
        catLower.contains('nutrition') ||
        catLower.contains('feed') ||
        catLower.contains('supplement') ||
        catLower.contains('course') ||
        catLower.contains('janam') ||
        catLower.contains('aahar') ||
        labelLower.contains('nutrition') ||
        catLower == 'cat-animal-nutrition' ||
        catLower == 'animal-nutrition';

    final isDairy = catLower.contains('dairy') ||
        catLower.contains('ghee') ||
        catLower.contains('paneer') ||
        catLower.contains('butter') ||
        catLower.contains('makhan') ||
        labelLower.contains('dairy') ||
        labelLower.contains('ghee');

    final isEquip = catLower.contains('equip') ||
        catLower.contains('machine') ||
        catLower.contains('machinery') ||
        labelLower.contains('equipment');

    final isEarth = catLower.contains('earth') ||
        catLower.contains('vermicompost') ||
        catLower.contains('manure') ||
        catLower.contains('compost') ||
        catLower.contains('soil') ||
        labelLower.contains('earth') ||
        catLower == 'milterra-earth';

    final (title, subtitle, icon, bannerColor, borderColor, tags) = isEarth
        ? (
            '🌱 FROM FARM WASTE TO LIVING SOIL',
            'Thoughtfully processed natural products for gardens and farms made from responsibly processed cow-dung by-products.',
            Icons.yard_outlined,
            const Color(0xfff7f5f0),
            const Color(0xffd4c7b8),
            const [
              'Coming Soon',
              '100% Pathogen Free',
              'Solarized & Screened',
              'Batch Traceable',
              'Zero Chemicals',
            ],
          )
        : isNutrition
            ? (
                '🌾 MILTERRA CATTLE NUTRITION SOLUTIONS',
                'Explore MILTERRA Cattle Nutrition Solutions—feeds, supplements, and stage-based nutrition concepts for healthier livestock.',
                Icons.grass_rounded,
                const Color(0xfff4f9f4),
                const Color(0xffc5e1c7),
                const [
                  'Concept Preview',
                  'In Development',
                  'Farmer Feedback Open',
                ],
              )
            : isDairy
                ? (
                    '🥛 Gourmet Farm Dairy Collection',
                    'Single-origin A2 Vedic Gir cow ghee, granular Murrah buffalo ghee, artisan fresh malai paneer, and cultured makhan — traditional bilona churned and delivered fresh from cooperative dairy farms.',
                    Icons.eco_rounded,
                    const Color(0xfffdfaf3),
                    const Color(0xffe8d8b5),
                    const [
                      '100% Bilona Churned',
                      'Zero Chemical Preservatives',
                      'A2 & Murrah Milk Origin',
                      'Direct Farm Delivery',
                    ],
                  )
                : isEquip
                    ? (
                        '⚙️ Modern Farm & Dairy Machinery',
                        'Single & dual-bucket automatic milking machines, ultrasonic digital milk fat & SNF analyzers, heavy-duty electric chaff cutters, and SS 304 food-grade milk cans engineered for farm productivity.',
                        Icons.precision_manufacturing_rounded,
                        const Color(0xfff3f7fb),
                        const Color(0xffbfd7ee),
                        const [
                          'SS 304 Food-Grade Metal',
                          'Energy-Efficient Motors',
                          '1-Year Comprehensive Warranty',
                          'On-Farm Service Support',
                        ],
                      )
                    : (
                        _label(_category),
                        'Browse our curated collection of verified dairy products, farm nutrition, and certified equipment.',
                        Icons.storefront_outlined,
                        const Color(0xfffaf9f6),
                        storeBorder,
                        const [
                          'Direct Farm Fresh',
                          'Cooperative Sourced',
                        ],
                      );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: storeWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, color: storeGreen, size: isMobile ? 20 : 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 20,
                    fontWeight: FontWeight.w800,
                    color: storeGreen,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _browse('All products'),
                icon: const Icon(Icons.close, size: 14, color: storeMuted),
                label: const Text(
                  'All Categories',
                  style: TextStyle(fontSize: 12, color: storeMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13.5,
              color: const Color(0xff444444),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: storeWhite.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor.withValues(alpha: 0.7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 12, color: storeGreen),
                    const SizedBox(width: 5),
                    Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: storeGreen,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _filters(VoidCallback refresh) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: storeWhite,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          border: Border.all(color: storeBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Header & Reset
            Row(
              children: [
                const Text('Filters',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: storeGreen)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    _reset();
                    refresh();
                  },
                  child: const Text('Clear all',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xff007185),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const Divider(height: 20),

            // Department Section
            const Text('DEPARTMENT',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: storeGreen)),
            const SizedBox(height: 8),
            _categoryFilterItem('All products', 'All Departments', refresh,
                icon: Icons.grid_view_rounded),
            const SizedBox(height: 6),
            const Text('🥛 Household Dairy Foods',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: storeMuted)),
            const SizedBox(height: 4),
            _categoryFilterItem('Dairy Foods', 'All Dairy Foods', refresh,
                indent: true),
            _categoryFilterItem('Cow ghee', 'A2 Desi Cow Ghee', refresh,
                indent: true),
            _categoryFilterItem('Buffalo ghee', 'Rich Buffalo Ghee', refresh,
                indent: true),
            _categoryFilterItem('Paneer', 'Fresh Malai Paneer', refresh,
                indent: true),
            _categoryFilterItem(
                'Other products', 'White Butter (Makhan)', refresh,
                indent: true),
            const SizedBox(height: 6),
            const Text('🌱 Living Soil: MILTERRA Earth',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: storeMuted)),
            const SizedBox(height: 4),
            _categoryFilterItem('MILTERRA Earth', 'All MILTERRA Earth', refresh,
                indent: true),
            _categoryFilterItem('Vermicompost', 'Premium Vermicompost', refresh,
                indent: true),
            _categoryFilterItem('Farm Manure', 'Cow-Dung Farm Manure', refresh,
                indent: true),
            _categoryFilterItem(
                'Organic Compost', 'Enriched Organic Compost', refresh,
                indent: true),
            _categoryFilterItem('Compost Cakes', 'Dried Compost Cakes', refresh,
                indent: true),
            _categoryFilterItem('Compost Starter', 'Compost Starter', refresh,
                indent: true),
            _categoryFilterItem('Garden Soil Mix', 'Garden Soil Mix', refresh,
                indent: true),
            const SizedBox(height: 6),
            const Text("🌾 Farmer's Hub: Cattle Nutrition",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: storeMuted)),
            const SizedBox(height: 4),
            _categoryFilterItem(
                'Animal nutrition', 'All Cattle Nutrition', refresh,
                indent: true),
            _categoryFilterItem('Pashu Aahar / Cattle Feed',
                'Pashu Aahar / Cattle Feed', refresh,
                indent: true),
            _categoryFilterItem(
                'Stage-Based Nutrition', 'Stage-Based Nutrition', refresh,
                indent: true),
            _categoryFilterItem(
                'Supplements', 'Supplements & Minerals', refresh,
                indent: true),
            const SizedBox(height: 6),
            const Text('⚙️ Modern Farm Machinery',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: storeMuted)),
            const SizedBox(height: 4),
            _categoryFilterItem('Equipment', 'Dairy & Farm Equipment', refresh,
                indent: true),
            const Divider(height: 20),

            // Customer Reviews Section
            const Text('CUSTOMER REVIEWS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: storeGreen)),
            const SizedBox(height: 8),
            _ratingOption(4.0, refresh),
            _ratingOption(3.0, refresh),
            _ratingOption(2.0, refresh),
            if (_minRating > 0) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () {
                  setState(() => _minRating = 0);
                  refresh();
                },
                child: const Text('Clear rating filter',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xff007185),
                        fontWeight: FontWeight.w600)),
              ),
            ],
            const Divider(height: 20),

            // Price Range Section
            const Text('PRICE',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: storeGreen)),
            const SizedBox(height: 8),
            _priceOption('Under ₹500', 0, 500, refresh),
            _priceOption('₹500 - ₹2,000', 500, 2000, refresh),
            _priceOption('₹2,000 - ₹10,000', 2000, 10000, refresh),
            _priceOption('Over ₹10,000', 10000, 0, refresh),
            const SizedBox(height: 8),

            // Custom Min/Max Price Inputs
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _minPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: '₹ Min',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _maxPriceCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: '₹ Max',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () {
                      final min =
                          double.tryParse(_minPriceCtrl.text.trim()) ?? 0;
                      final max =
                          double.tryParse(_maxPriceCtrl.text.trim()) ?? 0;
                      setState(() {
                        _priceMin = min;
                        _priceMax = max;
                      });
                      refresh();
                    },
                    child: const Text('Go',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Availability
            const Text('AVAILABILITY',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: storeGreen)),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                dense: true,
                value: _inStock,
                onChanged: (v) {
                  setState(() => _inStock = v ?? false);
                  refresh();
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title:
                    const Text('In Stock only', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      );

  Widget _priceOption(
      String title, double min, double max, VoidCallback refresh) {
    final isSelected = _priceMin == min && _priceMax == max;
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _priceMin = 0;
            _priceMax = 0;
          } else {
            _priceMin = min;
            _priceMax = max;
          }
        });
        refresh();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
            color: isSelected ? storeGreen : const Color(0xff333333),
          ),
        ),
      ),
    );
  }

  Widget _categoryFilterItem(String value, String title, VoidCallback refresh,
      {bool indent = false, IconData? icon}) {
    final catLower = _category.toLowerCase();
    final valLower = value.toLowerCase();
    final isSelected = _category == value ||
        catLower == valLower ||
        (value == 'Animal nutrition' &&
            (catLower.contains('animal') ||
                catLower.contains('cattle nutrition') ||
                catLower == 'cat-animal-nutrition' ||
                catLower == 'animal-nutrition'));
    return InkWell(
      key: ValueKey('category-filter-$value'),
      onTap: () {
        _browse(value);
        refresh();
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: EdgeInsets.only(
          left: indent ? 14 : 0,
          top: 3,
          bottom: 3,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? storeGreen : storeMuted),
              const SizedBox(width: 6),
            ] else ...[
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 13,
                color: isSelected ? storeGreen : storeMuted,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: indent ? 12 : 13,
                  fontWeight: isSelected
                      ? FontWeight.w800
                      : (indent ? FontWeight.w500 : FontWeight.w600),
                  color: isSelected ? storeGreen : const Color(0xff222222),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingOption(double rating, VoidCallback refresh) {
    final isSelected = _minRating == rating;
    return InkWell(
      onTap: () {
        setState(() => _minRating = isSelected ? 0 : rating);
        refresh();
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            for (int i = 1; i <= 5; i++)
              Icon(
                i <= rating.floor()
                    ? Icons.star_rounded
                    : (i - rating < 1
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded),
                size: 18,
                color: const Color(0xffde7921),
              ),
            const SizedBox(width: 6),
            Text(
              '& Up',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? storeGreen : const Color(0xff333333),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: storeWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
          builder: (context, refresh) => SafeArea(
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(StoreLayout.md),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _filters(() => refresh(() {})),
                        const SizedBox(height: StoreLayout.sm),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: storeAmber,
                                  foregroundColor: storeGreen),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Apply Filters',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800))),
                        )
                      ]))))));

  Widget _products(List<Product> all, bool small) {
    final query = _search.text.trim().toLowerCase();
    final catLower = _category.toLowerCase();

    final isAllCategory = catLower == 'all products' || catLower == 'all';
    final isDairyFoodsCategory = catLower == 'dairy foods' ||
        catLower == 'dairy-foods' ||
        catLower == 'cat-dairy-foods';
    final isCowGheeCategory = catLower == 'cow ghee' || catLower == 'cow-ghee';
    final isBuffGheeCategory =
        catLower == 'buffalo ghee' || catLower == 'buffalo-ghee';
    final isPaneerCategory = catLower == 'paneer';
    final isButterCategory = catLower == 'other products' ||
        catLower == 'butter' ||
        catLower == 'makhan';

    bool isAllNutrition = catLower == 'animal nutrition' ||
        catLower == 'cattle nutrition' ||
        catLower == 'milterra cattle nutrition solutions' ||
        catLower == 'animal-nutrition' ||
        catLower == 'cat-animal-nutrition' ||
        catLower == 'farm-essentials' ||
        catLower == 'farm essentials';

    if (!isAllNutrition && _taxonomy?.enabled == true) {
      for (final node in _taxonomy!.nodes) {
        if (node.id == _category || node.slug == _category) {
          final nLower = node.name.toLowerCase();
          if (nLower.contains('animal') ||
              nLower.contains('nutrition') ||
              nLower.contains('feed')) {
            isAllNutrition = true;
            break;
          }
        }
      }
    }

    final isPashuAaharCategory = catLower == 'pashu aahar / cattle feed' ||
        catLower == 'cattle feed' ||
        catLower == 'cattle-feed' ||
        catLower == 'pashu aahar';
    final isStageNutritionCategory =
        catLower == 'stage-based nutrition courses' ||
            catLower == 'stage-based nutrition' ||
            catLower == 'janam-42';
    final isSupplementsCategory = catLower == 'supplements' ||
        catLower == 'supplements & minerals' ||
        catLower == 'minerals';

    final isEquipmentCategory = catLower == 'equipment' ||
        catLower == 'farm machinery' ||
        catLower == 'cat-machinery';

    final isEarthAllCategory = catLower == 'milterra earth' ||
        catLower == 'milterra-earth' ||
        catLower == 'earth' ||
        catLower == 'living soil' ||
        catLower == 'compost';
    final isVermicompostCategory = catLower == 'vermicompost';
    final isManureCategory = catLower == 'farm manure' || catLower == 'manure';
    final isEnrichedCompostCategory = catLower == 'organic compost' ||
        catLower == 'enriched organic compost' ||
        catLower == 'enriched compost';
    final isCakesCategory = catLower == 'compost cakes' || catLower == 'cakes';
    final isStarterCategory =
        catLower == 'compost starter' || catLower == 'starter';
    final isSoilMixCategory = catLower == 'garden soil mix' ||
        catLower == 'soil mix' ||
        catLower == 'soil';

    final items = all.where((p) {
      // Category filter
      final bool matchesCategory;
      if (isAllCategory) {
        matchesCategory = true;
      } else if (isEarthAllCategory) {
        matchesCategory = p.taxonomy?['is_earth'] == true ||
            p.taxonomy?['category_name'] == 'MILTERRA Earth' ||
            p.title.toLowerCase().contains('earth') ||
            p.title.toLowerCase().contains('vermicompost') ||
            p.title.toLowerCase().contains('manure') ||
            p.title.toLowerCase().contains('compost') ||
            p.title.toLowerCase().contains('soil mix');
      } else if (isVermicompostCategory) {
        matchesCategory = p.title.toLowerCase().contains('vermicompost');
      } else if (isManureCategory) {
        matchesCategory = p.title.toLowerCase().contains('manure');
      } else if (isEnrichedCompostCategory) {
        matchesCategory =
            p.title.toLowerCase().contains('enriched organic compost') ||
                (p.title.toLowerCase().contains('compost') &&
                    !p.title.toLowerCase().contains('vermicompost') &&
                    !p.title.toLowerCase().contains('cake') &&
                    !p.title.toLowerCase().contains('starter'));
      } else if (isCakesCategory) {
        matchesCategory = p.title.toLowerCase().contains('cake');
      } else if (isStarterCategory) {
        matchesCategory = p.title.toLowerCase().contains('starter');
      } else if (isSoilMixCategory) {
        matchesCategory = p.title.toLowerCase().contains('soil mix') ||
            (p.title.toLowerCase().contains('soil') &&
                p.title.toLowerCase().contains('garden'));
      } else if (isDairyFoodsCategory) {
        matchesCategory = storeCategory(p) == 'Cow ghee' ||
            storeCategory(p) == 'Buffalo ghee' ||
            storeCategory(p) == 'Paneer' ||
            storeCategory(p) == 'Other products' ||
            p.taxonomy?['department_name'] == 'Dairy Foods';
      } else if (isCowGheeCategory) {
        matchesCategory = storeCategory(p) == 'Cow ghee' ||
            p.title.toLowerCase().contains('cow ghee');
      } else if (isBuffGheeCategory) {
        matchesCategory = storeCategory(p) == 'Buffalo ghee' ||
            p.title.toLowerCase().contains('buffalo ghee');
      } else if (isPaneerCategory) {
        matchesCategory = storeCategory(p) == 'Paneer' ||
            p.title.toLowerCase().contains('paneer');
      } else if (isButterCategory) {
        matchesCategory = storeCategory(p) == 'Other products' ||
            p.title.toLowerCase().contains('butter') ||
            p.title.toLowerCase().contains('makhan');
      } else if (isAllNutrition) {
        final title = p.title.toLowerCase();
        final isFood = title.contains('ghee') ||
            title.contains('paneer') ||
            title.contains('butter') ||
            title.contains('makhan');
        final isEquip = title.contains('milking') ||
            title.contains('analyzer') ||
            title.contains('cutter') ||
            title.contains('can') ||
            title.contains('mat') ||
            p.category == ProductCategory.equipment;
        final isEarth = p.taxonomy?['is_earth'] == true ||
            p.taxonomy?['department_name'] == 'MILTERRA Earth' ||
            p.taxonomy?['category_name'] == 'MILTERRA Earth' ||
            p.taxonomy?['department_id'] == 'milterra-earth' ||
            title.contains('earth') ||
            title.contains('vermicompost') ||
            title.contains('manure') ||
            title.contains('compost') ||
            title.contains('soil mix');
        matchesCategory = !isFood &&
            !isEquip &&
            !isEarth &&
            (p.category == ProductCategory.feedNutrition ||
                p.taxonomy?['concept'] == true ||
                p.taxonomy?['category_id'] == 'animal-nutrition' ||
                p.taxonomy?['department_id'] == 'farm-essentials');
      } else if (isPashuAaharCategory) {
        final title = p.title.toLowerCase();
        final isEarth = p.taxonomy?['is_earth'] == true ||
            title.contains('earth') ||
            title.contains('vermicompost') ||
            title.contains('manure') ||
            title.contains('compost');
        matchesCategory = !isEarth &&
            (p.taxonomy?['category_name'] == 'Pashu Aahar / Cattle Feed' ||
                p.taxonomy?['subcategory_name'] ==
                    'Pashu Aahar / Cattle Feed' ||
                title.contains('feed') ||
                title.contains('pellet') ||
                title.contains('aahar'));
      } else if (isStageNutritionCategory) {
        final title = p.title.toLowerCase();
        final isEarth = p.taxonomy?['is_earth'] == true ||
            title.contains('earth') ||
            title.contains('vermicompost') ||
            title.contains('manure') ||
            title.contains('compost');
        matchesCategory = !isEarth &&
            (p.taxonomy?['category_name'] == 'Stage-Based Nutrition Courses' ||
                p.taxonomy?['subcategory_name'] ==
                    'Stage-Based Nutrition Courses' ||
                title.contains('janam') ||
                title.contains('course'));
      } else if (isSupplementsCategory) {
        final title = p.title.toLowerCase();
        final isEarth = p.taxonomy?['is_earth'] == true ||
            title.contains('earth') ||
            title.contains('vermicompost') ||
            title.contains('manure') ||
            title.contains('compost');
        matchesCategory = !isEarth &&
            (p.taxonomy?['category_name'] == 'Supplements' ||
                p.taxonomy?['subcategory_name'] == 'Supplements' ||
                title.contains('mineral') ||
                title.contains('supplement') ||
                title.contains('calcium') ||
                title.contains('calci-') ||
                title.contains('drench') ||
                title.contains('minera-') ||
                title.contains('lacta-') ||
                title.contains('rumen-') ||
                title.contains('heat-guard') ||
                title.contains('bypass fat'));
      } else if (isEquipmentCategory) {
        matchesCategory = storeCategory(p) == 'Equipment' ||
            p.category == ProductCategory.equipment;
      } else {
        matchesCategory = (_taxonomy?.enabled == true
            ? (_taxonomy!
                    .descendants(_category)
                    .contains(p.taxonomy?['category_id']) ||
                storeCategory(p) == _category)
            : storeCategory(p) == _category);
      }
      if (!matchesCategory) return false;

      // Stock filter
      if (_inStock && !p.inStock) return false;

      // Price filter
      if (_priceMin > 0 && p.price < _priceMin) return false;
      if (_priceMax > 0 && p.price > _priceMax) return false;

      // Rating filter
      // Rating data is not part of the current backend product contract.
      if (_minRating > 0) return false;

      // Keyword query filter
      if (query.isNotEmpty) {
        final text =
            '${p.title} ${p.packSize ?? ''} ${p.brand ?? ''}'.toLowerCase();
        if (!text.contains(query)) return false;
      }

      return true;
    }).toList();

    // Sort order
    if (_sort == 'Price: low to high') {
      items.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == 'Price: high to low') {
      items.sort((a, b) => b.price.compareTo(a.price));
    } else if (_sort == 'Name: A to Z') {
      items.sort((a, b) => a.title.compareTo(b.title));
    }

    final groups = storeProductGroups(items);

    if (items.isEmpty) {
      final isNutrition = _category == 'Animal nutrition' ||
          _category == 'Cattle Nutrition' ||
          _category == 'MILTERRA Cattle Nutrition Solutions' ||
          _category == 'Pashu Aahar / Cattle Feed' ||
          _category == 'Stage-Based Nutrition Courses' ||
          _category == 'Supplements';

      final isEarth = _category.toLowerCase().contains('earth') ||
          _category.toLowerCase().contains('vermicompost') ||
          _category.toLowerCase().contains('manure') ||
          _category.toLowerCase().contains('compost') ||
          _category.toLowerCase().contains('soil');

      if (isEarth) {
        return _message(
          Icons.yard_outlined,
          'MILTERRA Earth: Living Soil',
          'Naturally processed cow-dung compost and soil mixes are coming soon. Join our launch notification list.',
          'Explore All Products',
          _reset,
        );
      }

      if (isNutrition) {
        return _message(
          Icons.grass_rounded,
          'Cattle Nutrition Concepts',
          'New Milterra cattle-nutrition concepts are coming soon. Explore upcoming formulations and share your feedback.',
          'Explore All Products',
          _reset,
        );
      }

      return _message(
          Icons.search_off,
          'No products matched your filters',
          'Try clearing price or department filters to see more results.',
          'Clear all filters',
          _reset);
    }

    return LayoutBuilder(builder: (context, bounds) {
      // Fluid column distribution for big monitors, laptops, tablets, and phones
      final int columns;
      if (bounds.maxWidth >= 960) {
        columns = 4;
      } else if (bounds.maxWidth >= 650) {
        columns = 3;
      } else if (bounds.maxWidth >= 380) {
        columns = 2;
      } else {
        columns = 1;
      }

      final gap = small ? 12.0 : 18.0;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: groups
            .map((packs) => SizedBox(
                width: ((bounds.maxWidth - gap * (columns - 1)) / columns)
                    .clamp(140.0, 320.0),
                child: StoreProductCard(
                    key: ValueKey(packs.first.id),
                    packs: packs,
                    compact: small,
                    busyIds: _adding,
                    onAdd: _add,
                    onOpen: (p) => context.push('/shop/product/${p.id}'))))
            .toList(),
      );
    });
  }

  Widget _editorial(bool small) {
    final copy = Padding(
        padding: StoreLayout.panelPadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Good food. Thoughtfully chosen.',
              style: StoreType.heading),
          const SizedBox(height: 12),
          const Text(
              'Browse products, compare pack sizes and find something for your everyday kitchen.',
              style: StoreType.body),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => _browse('All products'),
              child: const Text('Explore all →',
                  style: TextStyle(
                      color: storeGreen, fontWeight: FontWeight.bold))),
        ]));
    final photo = SizedBox(
        width: small ? double.infinity : 350,
        height: 240,
        child: Image.asset(StoreImages.hero,
            fit: BoxFit.cover, alignment: Alignment.centerRight));
    return ClipRRect(
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        child: ColoredBox(
            color: storeSage,
            child: small
                ? Column(children: [photo, copy])
                : Row(children: [photo, Expanded(child: copy)])));
  }

  Widget _message(IconData icon, String title, String description,
          String action, VoidCallback onTap) =>
      Container(
          width: double.infinity,
          padding: const EdgeInsets.all(StoreLayout.xl),
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: Column(children: [
            Icon(icon, size: 48, color: storeMuted),
            const SizedBox(height: StoreLayout.md),
            Text(title, style: StoreType.title),
            const SizedBox(height: StoreLayout.xs),
            Text(description,
                textAlign: TextAlign.center, style: StoreType.muted),
            const SizedBox(height: StoreLayout.md),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: storeAmber, foregroundColor: storeGreen),
              onPressed: onTap,
              child: Text(action,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          ]));

  Widget _benefit(IconData icon, String title, String subtitle) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 28, color: storeGreen),
        const SizedBox(width: StoreLayout.md),
        Flexible(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: storeGreen)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(fontSize: 11, color: storeMuted)),
        ]))
      ]);
}
