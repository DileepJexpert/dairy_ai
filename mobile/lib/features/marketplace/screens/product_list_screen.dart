import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/storefront_highlight_strip.dart';
import '../widgets/store_product_card.dart';
import '../widgets/hero_split_showcase.dart';
import '../models/hero_showcase_config.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../../commerce/models/taxonomy.dart';
import '../../commerce/providers/commerce_provider.dart';
import '../widgets/rfq_quote_dialog.dart';
import '../../../core/analytics_service.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen(
      {super.key,
      this.category,
      this.initialQuery = '',
      this.initialCategory = 'All Organic Essentials',
      this.initialSort = 'Featured'});
  final ProductCategory? category;
  final String initialQuery, initialCategory, initialSort;
  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _search = TextEditingController();
  final _catalogueKey = GlobalKey();
  final _minPriceCtrl = TextEditingController();
  final _maxPriceCtrl = TextEditingController();

  String _category = 'All Organic Essentials', _sort = 'Featured';
  bool _inStock = false;
  final Set<String> _packs = {};
  double _priceMin = 0, _priceMax = 0;
  final Set<String> _adding = {};
  TaxonomyCatalogue? _taxonomy;

  String _label(String value) {
    if (value == 'All products' ||
        value == 'All' ||
        value == 'All Organic Essentials') {
      return 'All Organic Essentials';
    }
    if (_taxonomy?.enabled == true) {
      final node = _taxonomy!.findNode(value);
      if (node != null) {
        return node.name;
      }
    }
    final lower = value.toLowerCase().trim();
    if (lower.contains('pure pantry') || lower == 'pantry' || lower == 'pure-pantry') {
      return '🌾 The Pure Pantry (Adulteration-Free Staples)';
    }
    if (lower.contains('botanical living') || lower == 'botanical' || lower == 'botanical-living') {
      return '🌿 The Botanical Living (Living Greens & Bio-Soil)';
    }
    if (lower.contains('aloe') || lower == 'pure-aloe-botanicals') {
      return '🌵 Pure Aloe Vera & Living Botanicals';
    }
    if (lower.contains('microgreen') ||
        lower.contains('living-harvest') ||
        lower.contains('living harvest') ||
        lower.contains('punnet') ||
        lower.contains('shoots')) {
      return '🌱 Fresh Living Harvest (Microgreens)';
    }
    if (lower.contains('chakki') ||
        lower.contains('flour') ||
        lower.contains('atta') ||
        lower.contains('sattu') ||
        lower.contains('khapli') ||
        lower.contains('sharbati') ||
        lower.contains('millet')) {
      return '🌾 Stone-Ground Chakki Atta & Flours';
    }
    if (lower.contains('honey') ||
        lower.contains('sweetener') ||
        lower.contains('gur') ||
        lower.contains('khand') ||
        lower.contains('mishri') ||
        lower.contains('shakkar')) {
      return '🍯 Wood-Pressed Oils & Pure Sweeteners';
    }
    if (lower.contains('salt') ||
        lower.contains('sendha') ||
        lower.contains('haldi') ||
        lower.contains('turmeric') ||
        lower.contains('spices') ||
        lower.contains('terroir')) {
      return '🧂 Terroir Salts & Native Spices';
    }
    if (lower.contains('balcony') ||
        lower.contains('booster') ||
        lower.contains('potting') ||
        lower.contains('fungicide') ||
        lower.contains('seeds')) {
      return '🪴 Apartment Balcony & Living Soil';
    }
    if (lower.contains('combo') ||
        lower.contains('curated') ||
        lower.contains('starter box') ||
        lower.contains('starter') ||
        lower.contains('box') ||
        lower.contains('duo') ||
        lower.contains('kit')) {
      return '🎁 Curated Kitchen & Wellness Boxes';
    }
    if (lower.contains('sarso') ||
        lower.contains('mustard') ||
        (lower.contains('oil') && !lower.contains('soil'))) {
      return '🌻 Wood-Pressed Oils & Pure Sweeteners';
    }
    if (lower.contains('agarbatti') || lower.contains('dhoop')) {
      return '🌸 Natural Agarbatti & Dhoop';
    }
    if (lower.contains('puja') ||
        lower.contains('hawan') ||
        lower.contains('samagri') ||
        lower.contains('diya') ||
        lower.contains('kanda')) {
      return '🪔 Puja & Hawan: Sacred Essentials';
    }
    if (lower.contains('earth') ||
        lower.contains('vermicompost') ||
        lower.contains('manure') ||
        lower.contains('compost') ||
        lower.contains('soil') ||
        lower == 'milterra-earth' ||
        lower == 'cat-earth') {
      return '🌱 Vermicompost & Living Soil';
    }
    if (lower.contains('shata') ||
        lower.contains('skincare') ||
        lower.contains('soap') ||
        lower.contains('ubtan')) {
      return '🌿 Vedic Skincare & Soaps';
    }
    if (lower.contains('milk') ||
        lower.contains('chhachh') ||
        lower.contains('chaas') ||
        lower.contains('paneer') ||
        lower.contains('makhan') ||
        lower.contains('mattha') ||
        lower.contains('curd chilli') ||
        lower.contains('mor milagai') ||
        lower.contains('dairy foods') ||
        lower.contains('artisanal dairy')) {
      return '🧈 Artisanal Dairy & Cultured';
    }
    if (lower.contains('ghee')) {
      return '🧈 Vedic Bilona Ghee';
    }
    if (lower.contains('animal') ||
        lower.contains('cattle nutrition') ||
        lower == 'animal-nutrition' ||
        lower == 'cat-animal-nutrition') {
      return 'MILTERRA Cattle Nutrition Solutions';
    }
    return switch (value) {
      'Vedic Bilona Ghee' || 'All Ghee' || 'all-ghee' || 'Ghee' =>
        '🧈 Vedic Bilona Ghee',
      'Fresh Milk & Dairy' || 'Dairy Foods' =>
        '🥛 Fresh Milk & Dairy (Chhachh & Paneer)',
      'Puja & Hawan Samagri' || 'puja-hawan-samagri' =>
        '🪔 Puja & Hawan: Sacred Essentials',
      'Natural Agarbatti & Dhoop' || 'dhoop-agarbatti' =>
        '🌸 Natural Agarbatti & Dhoop',
      'Vermicompost & Living Soil' ||
      'MILTERRA Earth' ||
      'milterra-earth' ||
      'Earth' =>
        '🌱 Vermicompost & Living Soil',
      'Cold-Pressed Sarso (Mustard) Oil' || 'sarso-oil' =>
        '🌻 Cold-Pressed Sarso (Mustard) Oil',
      'Cow ghee' => 'A2 Desi Cow Ghee',
      'Buffalo ghee' => 'Rich Buffalo Ghee',
      'Herbal Ghee' || 'Herbal ghee' || 'herbal-ghee' => 'Herbal Infused Ghee',
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
    _sort = widget.initialSort;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(productsProvider);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProductListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.initialCategory != widget.initialCategory ||
        oldWidget.initialSort != widget.initialSort) {
      setState(() {
        _search.text = widget.initialQuery;
        _category = widget.initialCategory;
        _sort = widget.initialSort;
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

  void _browse(String category, {String? sort}) {
    ref.read(analyticsServiceProvider).trackButtonClick(
          'category_filter',
          'Category: $category',
          metadata: {'category': category, if (sort != null) 'sort': sort},
        );
    setState(() {
      if (_category != category) {
        _priceMin = 0;
        _priceMax = 0;
        _inStock = false;
        _packs.clear();
        _minPriceCtrl.clear();
        _maxPriceCtrl.clear();
      }
      _category = category;
      if (sort != null) _sort = sort;
    });
    final target = _catalogueKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 350));
    }
    final params = <String, String>{};
    if (category != 'All products' &&
        category != 'All' &&
        category != 'All Organic Essentials') {
      params['category'] = category;
    }
    if (_search.text.trim().isNotEmpty) {
      params['query'] = _search.text.trim();
    }
    if (_sort != 'Featured') {
      params['sort'] = _sort;
    }
    context.go(Uri(
      path: '/shop',
      queryParameters: params.isEmpty ? null : params,
    ).toString());
  }

  void _reset() {
    setState(() {
      _search.clear();
      _packs.clear();
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
    if (p.isConcept) return;
    ref.read(analyticsServiceProvider).trackAddToCart(
          p.id,
          p.title,
          p.minOrderQuantity,
          p.price,
        );
    if (ref.read(currentUserProvider) == null) {
      context.go('/login?next=/shop/product/${p.id}');
      return;
    }
    setState(() => _adding.add(p.id));
    try {
      await ref.read(cartProvider.notifier).add(p.id, p.minOrderQuantity, p);
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
              isFarmerHub: widget.category == ProductCategory.equipment ||
                  widget.category == ProductCategory.feedNutrition,
            ),
            StoreCategoryNavigation(
              selected: _category,
              onSelected: _browse,
              legacyEquipment: widget.category == ProductCategory.equipment,
            ),
            if (widget.category != ProductCategory.equipment &&
                widget.category != ProductCategory.feedNutrition)
              const StorefrontHighlightStrip(),

            // Main Scrollable Content Area
            Expanded(
              child: SingleChildScrollView(
                key: const PageStorageKey('store-catalogue-scroll'),
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: StoreLayout.maxWidth,
                          minHeight:
                              (size.maxHeight - 200).clamp(520.0, 3000.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 24,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero Banner (Home / Unfiltered view)
                              if (_search.text.isEmpty &&
                                  (_category == 'All products' ||
                                      _category == 'All' ||
                                      _category == 'All Organic Essentials')) ...[
                                _hero(size.maxWidth),
                                const SizedBox(height: 20),
                              ],

                              // Visual Department Quick Navigation (Fast 1-tap browsing across all devices)
                              if (widget.category != ProductCategory.equipment &&
                                  widget.category != ProductCategory.feedNutrition) ...[
                                _buildVisualCategoryBar(isMobile),
                                const SizedBox(height: 12),
                              ],

                              // Brand Specials & New Launch Offers (Front & Center on Home Landing)
                              if (_search.text.isEmpty &&
                                  (_category == 'All products' ||
                                      _category == 'All' ||
                                      _category == 'All Organic Essentials') &&
                                  widget.category != ProductCategory.equipment &&
                                  widget.category != ProductCategory.feedNutrition) ...[
                                catalogue.maybeWhen(
                                  data: (items) =>
                                      _buildBrandSpecialsSection(isMobile, items),
                                  orElse: () => const SizedBox.shrink(),
                                ),
                              ],

                              // IndiaMART-Style RFQ Banner & Live Demand (exclusive to Farmer Hub)
                              if (widget.category == ProductCategory.equipment ||
                                  widget.category == ProductCategory.feedNutrition) ...[
                                _buildRFQBanner(isMobile),
                                _buildLiveRequirementTicker(),
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
                                        width: 285,
                                        child: _filters(() => setState(() {})),
                                      ),
                                      const SizedBox(width: 24),
                                    ],

                                    // Products Grid Column
                                    Expanded(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                            minHeight: 460),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Dedicated Category/Department Landing Banner (when filtered)
                                            if (_category != 'All products' &&
                                                _category != 'All' &&
                                                _category !=
                                                    'All Organic Essentials') ...[
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
                                        'Delivery',
                                        'Availability shown at checkout.'),
                                    _benefit(
                                        Icons.verified_user_outlined,
                                        'Quality & Research',
                                        'Published information, without assumed certifications.'),
                                    _benefit(
                                        Icons.lock_outline,
                                        'Secure Payments',
                                        'UPI, Cards, NetBanking & COD.'),
                                    _benefit(
                                        Icons.support_agent_outlined,
                                        'Order Support',
                                        'Help with your order enquiries.'),
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
                  if (_sort == 'Best Sellers') {
                    return const Text(
                      'BEST SELLERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: storeAmber,
                      ),
                    );
                  }
                  if (_sort == 'Newest Arrivals') {
                    return const Text(
                      'NEW RELEASES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: storeGreen,
                      ),
                    );
                  }
                  if (_sort == 'Trending') {
                    return const Text(
                      'MOVERS & SHAKERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: storeAmber,
                      ),
                    );
                  }
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
                  _sort == 'Best Sellers'
                      ? 'Best Sellers in Milterra'
                      : (_sort == 'Newest Arrivals'
                          ? 'Hot New Releases & Recent Arrivals'
                          : (_sort == 'Trending'
                              ? 'Movers & Shakers: Trending in Store'
                              : (query.isNotEmpty
                                  ? 'Results for “$query”'
                                  : (_category == 'All products' ||
                                          _category == 'All' ||
                                          _category ==
                                              'All Organic Essentials'
                                      ? 'Showing all products'
                                      : _label(_category))))),
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
              itemBuilder: (_) => _sortOptions
                  .map((v) => PopupMenuItem(value: v, child: Text(v)))
                  .toList(),
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
                    value: _sortOptions.contains(_sort) ? _sort : 'Featured',
                    icon: const Icon(Icons.arrow_drop_down,
                        size: 18, color: storeGreen),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: storeGreen,
                    ),
                    items: _sortOptions
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
    final allGroups = storeProductGroups(ref
                .watch(productsProvider(null))
                .valueOrNull
                ?.where((p) => !p.isConcept)
                .toList() ??
            []);
    // Sort product groups so that MILTERRA A2 Cow Bilona Ghee leads first,
    // followed by Murrah Buffalo Ghee, Fresh Dairy, and then Pantry products.
    allGroups.sort((a, b) {
      final pA = a.first;
      final pB = b.first;
      int score(Product p) {
        final t = p.title.toLowerCase();
        final c = storeCategory(p).toLowerCase();
        if (t.contains('a2') && t.contains('cow') && t.contains('ghee')) return 0;
        if (t.contains('bilona') && t.contains('ghee')) return 1;
        if (t.contains('ghee')) return 2;
        if (c.contains('ghee')) return 3;
        if (t.contains('milk') || t.contains('paneer') || t.contains('mattha')) return 4;
        if (t.contains('mustard') || t.contains('oil')) return 5;
        if (t.contains('honey') || t.contains('atta')) return 6;
        return 10;
      }
      return score(pA).compareTo(score(pB));
    });

    return HeroSplitShowcase(
      screenWidth: screenWidth,
      onExploreCategory: _browse,
      productSlides: allGroups.take(4).map((g) {
        final p = g.first;
        return HeroProductSlide(
            id: p.id,
            category: storeCategory(p),
            badge: p.title.toLowerCase().contains('ghee') ? 'HERITAGE BILONA' : '',
            name: p.title,
            packSize: p.packSize ?? p.unit,
            price: p.price,
            description: p.description ?? '',
            imagePath:
                p.media.firstOrNull ?? StoreImages.productArtwork(p) ?? '',
            targetRoute: '/shop/product/${p.id}');
      }).toList(),
    );
  }

  ({String subtitle, String badge}) _categoryHighlights(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('ghee')) {
      return (
        subtitle:
            'Hand-churned from cultured curd of grass-fed indigenous cows · Clarified over slow firewood flame · 100% Pure, Zero Chemicals',
        badge: '★ HERITAGE BILONA',
      );
    }
    if (lower.contains('milk') ||
        lower.contains('dairy') ||
        lower.contains('paneer') ||
        lower.contains('chhachh')) {
      return (
        subtitle:
            'Direct farm-fresh raw milk, artisan malai paneer & probiotic buttermilk · Shipped chilled within hours of milking',
        badge: '🥛 FRESH HARVEST',
      );
    }
    if (lower.contains('oil') || lower.contains('sarso')) {
      return (
        subtitle:
            'Traditional wood-pressed (Lakdi Ghani) cold extraction under 40°C · Unrefined, unbleached, zero argemone',
        badge: '🪵 WOOD-PRESSED KOLHU',
      );
    }
    if (lower.contains('atta') ||
        lower.contains('flour') ||
        lower.contains('khapli')) {
      return (
        subtitle:
            'Stone-ground ancient grains and Emmer (Khapli) wheat · High fiber, low GI, stone-milled cold to retain germ nutrition',
        badge: '🌾 STONE-GROUND',
      );
    }
    if (lower.contains('pantry') ||
        lower.contains('honey') ||
        lower.contains('sweetener')) {
      return (
        subtitle:
            'Single-origin raw forest honey, organic unrefined jaggery & hand-pounded terroir spices for daily culinary wellness',
        badge: '🍯 SINGLE-ORIGIN',
      );
    }
    if (lower.contains('skincare') ||
        lower.contains('soap') ||
        lower.contains('botanical')) {
      return (
        subtitle:
            'Traditional 100x washed ghee (Shata Dhauta Ghrita) & cold-processed goat milk soaps · Clean Ayurvedic radiance',
        badge: '🌿 VEDIC BOTANICALS',
      );
    }
    if (lower.contains('puja') ||
        lower.contains('hawan') ||
        lower.contains('sacred')) {
      return (
        subtitle:
            'Pure desi cow hawan ghee, handcrafted cow dung diyas & natural dhoop · Crafted with devotion and Vedic purity',
        badge: '🪔 VEDIC SACRED',
      );
    }
    if (lower.contains('soil') ||
        lower.contains('compost') ||
        lower.contains('earth')) {
      return (
        subtitle:
            'Naturally processed cow-dung bio-compost, odor-free potting soil & balcony vitality boosters',
        badge: '🌱 LIVING SOIL',
      );
    }
    return (
      subtitle:
          '100% authentic farm staples · Ethically sourced, lab verified and delivered direct from verified producers',
      badge: '✨ VERIFIED PURITY',
    );
  }

  Widget _buildDepartmentLandingBanner(bool isMobile) {
    if (_conceptOnly) {
      return StorePanel(
        title: _label(_category),
        child: const Text(Product.conceptExplanation),
      );
    }
    final hl = _categoryHighlights(_category);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 18,
        vertical: isMobile ? 10 : 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfffdfbf7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe8e2d4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(_category),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    color: storeGreen,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hl.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff4b5563),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xfffef3c7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xfff59e0b)),
              ),
              child: Text(
                hl.badge,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff92400e),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisualCategoryBar(bool isMobile) {
    final quickCategories = [
      (
        key: 'All products',
        label: 'All Items',
        sub: 'Full Store',
        icon: '🛒',
        asset: null,
        bgGradient: const [Color(0xfff8fafc), Color(0xfff1f5f9)],
        accentColor: const Color(0xff475569),
      ),
      (
        key: 'Vedic Bilona Ghee',
        label: 'A2 Bilona Ghee',
        sub: 'Vedic Bilona',
        icon: '🧈',
        asset: 'assets/store/cow-ghee.png',
        bgGradient: const [Color(0xfffffdf0), Color(0xfffef3c7)],
        accentColor: const Color(0xffb45309),
      ),
      (
        key: 'Fresh Milk & Dairy',
        label: 'Fresh Dairy',
        sub: 'Farm Fresh',
        icon: '🥛',
        asset: 'assets/store/paneer.png',
        bgGradient: const [Color(0xfff0fdf4), Color(0xffdcfce7)],
        accentColor: const Color(0xff15803d),
      ),
      (
        key: 'Cold-Pressed Sarso (Mustard) Oil',
        label: 'Cold-Pressed Oils',
        sub: 'Lakdi Ghani',
        icon: '🌻',
        asset: 'assets/store/sarso-oil.jpg',
        bgGradient: const [Color(0xfffff7ed), Color(0xffffedd5)],
        accentColor: const Color(0xffc2410c),
      ),
      (
        key: 'Stone-Ground Chakki Atta & Flours',
        label: 'Khapli Atta',
        sub: 'Stone-Ground',
        icon: '🌾',
        asset: 'assets/store/khapli-atta.jpg',
        bgGradient: const [Color(0xfffefce8), Color(0xfffef08a)],
        accentColor: const Color(0xffa16207),
      ),
      (
        key: 'The Pure Pantry',
        label: 'Raw Honey & Pantry',
        sub: 'Raw & Pure',
        icon: '🍯',
        asset: 'assets/store/raw-mustard-honey.jpg',
        bgGradient: const [Color(0xfffffbeb), Color(0xfffed7aa)],
        accentColor: const Color(0xffb45309),
      ),
      (
        key: 'botanical-skincare',
        label: 'Vedic Skincare',
        sub: '100x Washed Ghee',
        icon: '🌿',
        asset: 'assets/store/shata-dhauta-ghrita.jpg',
        bgGradient: const [Color(0xfffdf2f8), Color(0xfffce7f3)],
        accentColor: const Color(0xffbe185d),
      ),
      (
        key: 'Puja & Hawan Samagri',
        label: 'Puja Sacred',
        sub: 'Hawan & Diyas',
        icon: '🪔',
        asset: 'assets/store/earth-cakes.jpg',
        bgGradient: const [Color(0xfffff7ed), Color(0xffffedd5)],
        accentColor: const Color(0xffea580c),
      ),
      (
        key: 'Vermicompost & Living Soil',
        label: 'Living Soil',
        sub: 'Bio-Compost',
        icon: '🌱',
        asset: 'assets/store/earth-vermicompost.jpg',
        bgGradient: const [Color(0xfff0fdf4), Color(0xffbbf7d0)],
        accentColor: const Color(0xff166534),
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Explore by Department',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: storeDarkGreenNav,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (_category != 'All products' &&
                  _category != 'All' &&
                  _category != 'All Organic Essentials')
                InkWell(
                  onTap: () => _browse('All products'),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Clear Filter ✕',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xffdc2626),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: isMobile ? 132 : 148,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickCategories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = quickCategories[index];
                final isSelected = (_category == item.key) ||
                    (item.key == 'Vedic Bilona Ghee' &&
                        _category.toLowerCase().contains('ghee')) ||
                    (item.key == 'All products' &&
                        (_category == 'All' ||
                            _category == 'All Organic Essentials'));

                return InkWell(
                  onTap: () => _browse(item.key),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isMobile ? 104 : 124,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xfff59e0b)
                            : const Color(0xffe5e7eb),
                        width: isSelected ? 2.5 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              const BoxShadow(
                                color: Color(0x24f59e0b),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              )
                            ]
                          : const [
                              BoxShadow(
                                color: Color(0x0a000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              )
                            ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Large, vibrant visual canvas showing the actual product prominently
                        SizedBox(
                          height: isMobile ? 80 : 92,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: item.bgGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (item.asset != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: StoreMediaImage(
                                      source: item.asset!,
                                      fit: BoxFit.contain,
                                      fallbackIconSize: 32,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.storefront_rounded,
                                    size: isMobile ? 32 : 38,
                                    color: item.accentColor,
                                  ),
                                if (isSelected)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xfff59e0b),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Title & Micro-badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          color: isSelected
                              ? const Color(0xfffffbeb)
                              : Colors.white,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: isSelected
                                      ? const Color(0xff78350f)
                                      : const Color(0xff111827),
                                  height: 1.15,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.sub,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: item.accentColor,
                                  height: 1.1,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSpecialsSection(bool isMobile, List<Product> all) {
    if (all.isEmpty) return const SizedBox.shrink();

    final nonConceptProds =
        all.where((p) => !p.isConcept && !p.isDraft).toList();
    if (nonConceptProds.isEmpty) return const SizedBox.shrink();

    final allGroups = storeProductGroups(nonConceptProds);
    allGroups.sort((a, b) {
      final pA = a.first;
      final pB = b.first;
      int score(Product p) {
        final t = p.title.toLowerCase();
        if (t.contains('a2') && t.contains('cow') && t.contains('ghee')) return 0;
        if (t.contains('buffalo') && t.contains('ghee')) return 1;
        if (t.contains('bilona') && t.contains('ghee')) return 2;
        if (t.contains('sarso') || (t.contains('mustard') && t.contains('oil'))) return 3;
        if (t.contains('shata') || t.contains('washed ghee')) return 4;
        if (t.contains('khapli') || t.contains('atta')) return 5;
        if (t.contains('honey')) return 6;
        if (t.contains('ghee')) return 7;
        return 10;
      }
      return score(pA).compareTo(score(pB));
    });

    final specials = allGroups.take(5).toList();
    if (specials.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: const Color(0xfffffdf8),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: const Color(0xfff3eedf)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffdc2626),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 13, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'NEW LAUNCH OFFERS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xfffef3c7),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xfff59e0b)),
                ),
                child: const Text(
                  '★ SIGNATURE SPECIALS',
                  style: TextStyle(
                    color: Color(0xff92400e),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _browse('Vedic Bilona Ghee'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All Ghee',
                      style: TextStyle(
                        color: storeGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios, size: 10, color: storeGreen),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Special Brand Items & Harvest Specials',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xff111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Direct from pastoralists & organic farms · Introductory launch discounts on heritage Vedic staples',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xff6b7280),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: isMobile ? 440 : 485,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: specials.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final packs = specials[index];
                return SizedBox(
                  width: isMobile ? 220 : 255,
                  child: StoreProductCard(
                    key: ValueKey('brand-special-${packs.first.id}'),
                    packs: packs,
                    compact: isMobile,
                    busyIds: _adding,
                    onAdd: _add,
                    onOpen: (p) {
                      ref.read(analyticsServiceProvider).trackProductView(
                            p.id,
                            p.title,
                            price: p.price,
                          );
                      context.push('/shop/product/${p.id}');
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRFQBanner(bool isMobile) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 768;
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xff064e3b), Color(0xff047857)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1a047857),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.request_quote_rounded,
                          color: Color(0xfffef08a),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Looking for Farm Machinery or Bulk Feeds?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Post your requirement & receive direct quotes from verified manufacturers & OEMs.',
                    style: TextStyle(
                      color: Color(0xffa7f3d0),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xff064e3b)),
                      label: const Text(
                        'Post Buy Requirement / Get Quotes',
                        style: TextStyle(
                          color: Color(0xff064e3b),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xfffef08a),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => showRFQQuoteDialog(
                        context,
                        defaultTitle: _category == 'All products' || _category == 'All' ? null : _category,
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.request_quote_rounded,
                      color: Color(0xfffef08a),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Looking for Farm Machinery, Equipment, or Bulk Animal Feeds?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Post your requirement & receive instant quotes from verified manufacturers, distributors & FPOs.',
                          style: TextStyle(
                            color: Color(0xffa7f3d0),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 16, color: Color(0xff064e3b)),
                    label: const Text(
                      'Post Buy Requirement (RFQ)',
                      style: TextStyle(
                        color: Color(0xff064e3b),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xfffef08a),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => showRFQQuoteDialog(
                      context,
                      defaultTitle: _category == 'All products' || _category == 'All' ? null : _category,
                    ),
                  ),
                ],
              ),
      );
    });
  }

  Widget _buildLiveRequirementTicker() {
    final rfqsAsync = ref.watch(recentRFQsProvider);
    final rfqs = rfqsAsync.valueOrNull ?? [];

    final displayItems = rfqs.isNotEmpty
        ? rfqs
        : [
            {
              'buyer_name': 'Ramesh P.',
              'city': 'Anand, GJ',
              'product_title': '3HP Heavy Duty Chaff Cutter',
              'quantity': 2,
              'unit': 'Units',
            },
            {
              'buyer_name': 'Balwant S.',
              'city': 'Karnal, HR',
              'product_title': 'High Protein Cattle Feed Pellets',
              'quantity': 50,
              'unit': 'Bags',
            },
            {
              'buyer_name': 'Santosh M.',
              'city': 'Kolhapur, MH',
              'product_title': '2-Bucket Portable Milking Machine',
              'quantity': 1,
              'unit': 'Unit',
            },
            {
              'buyer_name': 'Dairy Producer Co.',
              'city': 'Mehsana, GJ',
              'product_title': 'Solar Agri Pump 5HP & Inverter',
              'quantity': 3,
              'unit': 'Sets',
            },
          ];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffbbf7d0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xffdc2626),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'LIVE RFQ FEED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: displayItems.map((item) {
                  final name = item['buyer_name'] ?? 'Buyer';
                  final city = item['city'] ?? 'India';
                  final title = item['product_title'] ?? 'Equipment';
                  final qty = item['quantity'] ?? 1;
                  final unit = item['unit'] ?? 'units';

                  return Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: InkWell(
                      onTap: () => showRFQQuoteDialog(
                        context,
                        defaultTitle: title.toString(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on, size: 14, color: Color(0xff16a34a)),
                          const SizedBox(width: 4),
                          Text(
                            '$name ($city): ',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff14532d),
                            ),
                          ),
                          Text(
                            '$title ($qty $unit)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff166534),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('•', style: TextStyle(color: Color(0xff86efac))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
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

  Widget _filters(VoidCallback refresh) {
    final groups = <String, Map<String, String>>{
      '🧈 Vedic Bilona Ghee': {
        'Vedic Bilona Ghee': 'All Vedic Bilona Ghee',
        'Cow ghee': 'A2 Desi Cow Ghee',
        'Buffalo ghee': 'Rich Murrah Buffalo Ghee',
        'Herbal Ghee': 'Herbal Infused Ghee',
      },
      '🥛 Fresh Milk & Dairy': {
        'Fresh Milk & Dairy': 'All Fresh Dairy',
        'milk': 'A2 Raw Chilled Milk',
        'chhachh': 'Masala Chhachh (Chaas)',
        'Paneer': 'Fresh Malai Paneer',
        'Other products': 'Cultured White Butter (Makhan)',
      },
      '🪔 Puja & Hawan Samagri': {
        'Puja & Hawan Samagri': 'All Puja & Hawan Items',
        'Hawan & Yajna Ghee': 'Pure Desi Cow Hawan Ghee',
        'Cow Dung Sacred Products': 'Cow Dung Diyas & Kanda',
        'Bhimseni Kapoor & Samagri': 'Shuddha Bhimseni Kapoor',
      },
      '🌸 Natural Agarbatti & Dhoop': {
        'Natural Agarbatti & Dhoop': 'All Agarbatti & Dhoop',
        'dhoop-agarbatti': 'Cow Dung Agarbatti Sticks',
        'dhoop': 'Panchagavya Herbal Dhoop',
      },
      '🌱 Vermicompost & Living Soil': {
        'Vermicompost & Living Soil': 'All Living Soil & Compost',
        'Vermicompost': 'Bio-Vermicompost',
        'Farm Manure': 'Composted Cow Farm Manure',
        'Organic Compost': 'Enriched Organic Compost',
        'Garden Soil Mix': 'Living Garden Soil Mix',
      },
      '🌻 Cold-Pressed Sarso Oil': {
        'Cold-Pressed Sarso (Mustard) Oil': 'All Cold-Pressed Oils',
        'sarso': 'Kachi Ghani Sarso Oil (1L & 5L)',
        'til': 'Wood-Pressed Til (Sesame) Oil',
      },
      '🌿 Vedic Skincare & Soaps': {
        'botanical-skincare': 'All Vedic Skincare & Soaps',
        'shata-dhauta-ghrita-category': 'Shata Dhauta Ghrita (100x Washed Ghee)',
        'skincare': 'Ayurvedic Skincare',
        'soap': 'Cold-Process Goat Milk & Honey Soap',
      },
    };
    if (widget.category == ProductCategory.equipment ||
        widget.category == ProductCategory.feedNutrition) {
      groups['🌾 Cattle Nutrition'] = {
        'Animal nutrition': 'All Cattle Nutrition',
        'Pashu Aahar / Cattle Feed': 'Pashu Aahar / Cattle Feed',
        'Stage-Based Nutrition': 'Stage-Based Nutrition',
        'Supplements': 'Supplements & Minerals',
      };
      groups['⚙️ Farm Machinery'] = {
        'Equipment': 'Dairy & Farm Equipment',
      };
    }
    if (_taxonomy?.enabled == true) {
      for (final dept in _taxonomy!.nodes
          .where((n) => n.kind == 'department' && n.isActive)) {
        // When on Milterra consumer storefront (/shop), strictly filter out B2B Farm Essentials, Animal nutrition, Equipment
        if (widget.category == null) {
          final dName = dept.name.toLowerCase();
          final dSlug = dept.slug.toLowerCase();
          if (dName.contains('farm essential') ||
              dSlug.contains('farm-essential') ||
              dName.contains('equipment') ||
              dName.contains('machinery') ||
              dName.contains('animal nutrition') ||
              dName.contains('cattle nutrition') ||
              dName.contains('feed')) {
            continue;
          }
        }
        final existingKey = groups.keys.firstWhere(
          (k) =>
              k.toLowerCase() == dept.name.toLowerCase() ||
              k
                  .replaceAll(RegExp(r'[^\w\s&]'), '')
                  .trim()
                  .toLowerCase() ==
                  dept.name.toLowerCase(),
          orElse: () => dept.name,
        );
        final group =
            groups.putIfAbsent(existingKey, () => {dept.id: 'All ${dept.name}'});
        for (final node in _taxonomy!.nodes
            .where((n) => n.parentId == dept.id && n.isActive)) {
          if (widget.category == null) {
            final nName = node.name.toLowerCase();
            final nSlug = node.slug.toLowerCase();
            if (nName.contains('equipment') ||
                nName.contains('machinery') ||
                nName.contains('animal nutrition') ||
                nName.contains('cattle nutrition') ||
                nName.contains('cattle feed') ||
                nSlug.contains('equipment') ||
                nSlug.contains('animal-nutrition')) {
              continue;
            }
          }
          final nLower = node.name.toLowerCase();
          final nSlug = node.slug.toLowerCase();
          final isSkincareNode = nLower.contains('skincare') ||
              nLower.contains('shata') ||
              nLower.contains('soap') ||
              nSlug.contains('skincare') ||
              nSlug.contains('shata');

          // Ensure Ayurvedic Skincare is strictly placed in Vedic Skincare & Soaps, not in Dairy Foods
          if (isSkincareNode &&
              (dept.name.toLowerCase().contains('dairy') ||
                  dept.name.toLowerCase().contains('artisanal'))) {
            final skincareGroup = groups.putIfAbsent(
                '🌿 Vedic Skincare & Soaps',
                () => {'botanical-skincare': 'All Vedic Skincare & Soaps'});
            if (!skincareGroup.keys
                .any((key) => key.toLowerCase() == node.name.toLowerCase())) {
              skincareGroup[node.id] = node.name;
            }
            continue;
          }

          if (!group.keys
              .any((key) => key.toLowerCase() == node.name.toLowerCase())) {
            group[node.id] = node.name;
          }
        }
      }
    }
    final packs = _scope
        .map((p) => p.packSize ?? p.unit)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final activeDepartments =
        _scope.map((p) => p.taxonomy?['department_name']).toSet();
    final isAll = _category == 'All products' ||
        _category == 'All' ||
        _category == 'All Organic Essentials';
    final orderedGroups = groups.entries.toList()
      ..sort((a, b) {
        bool relevant(MapEntry<String, Map<String, String>> g) =>
            g.value.containsKey(_category) || activeDepartments.contains(g.key);
        return (relevant(b) ? 1 : 0) - (relevant(a) ? 1 : 0);
      });
    return StorePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Filters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            TextButton(
                onPressed: () {
                  _reset();
                  refresh();
                },
                child: const Text('Clear all'))
          ]),
      _categoryFilterItem('All Organic Essentials', 'All Organic Essentials', refresh,
          icon: Icons.grid_view_rounded),
      for (final group in orderedGroups)
        ExpansionTile(
          key: PageStorageKey('department-${group.key}-$_category'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          initiallyExpanded: isAll ||
              group.value.containsKey(_category) ||
              activeDepartments.contains(group.key),
          title: Text(group.key,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          children: group.value.entries
              .map((e) =>
                  _categoryFilterItem(e.key, e.value, refresh, indent: true))
              .toList(),
        ),
      if (!isAll && packs.isNotEmpty)
        ExpansionTile(
            key: PageStorageKey('pack-filter-$_category'),
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: true,
            title: const Text('Pack size', style: TextStyle(fontSize: 13)),
            children: packs
                .map((pack) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(pack),
                      value: _packs.contains(pack),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _packs.add(pack);
                          } else {
                            _packs.remove(pack);
                          }
                        });
                        refresh();
                      },
                    ))
                .toList()),
      if (!_conceptOnly)
        ExpansionTile(
          key: PageStorageKey('price-filter-$_category'),
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
          title: const Text('Price & Availability',
              style: TextStyle(fontSize: 13)),
          children: [
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
                      final min = double.tryParse(_minPriceCtrl.text.trim()) ?? 0;
                      final max = double.tryParse(_maxPriceCtrl.text.trim()) ?? 0;
                      setState(() {
                        _priceMin = min;
                        _priceMax = max;
                      });
                      refresh();
                    },
                    child: const Text('Go',
                        style:
                            TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('In Stock only'),
                value: _inStock,
                onChanged: (v) {
                  setState(() => _inStock = v ?? false);
                  refresh();
                }),
          ],
        ),
    ]));
  }

  Widget _categoryFilterItem(String value, String title, VoidCallback refresh,
      {bool indent = false, IconData? icon}) {
    final catLower = _category.toLowerCase();
    final valLower = value.toLowerCase();
    final selectedNode = _taxonomy?.nodes
        .where((n) => n.id == _category || n.slug == _category)
        .firstOrNull;
    final isSelected = _category == value ||
        catLower == valLower ||
        (selectedNode != null &&
            (selectedNode.id == value ||
                selectedNode.slug == value ||
                selectedNode.name.toLowerCase() == valLower)) ||
        (value == 'Animal nutrition' &&
            (catLower.contains('animal') ||
                catLower.contains('cattle nutrition') ||
                catLower == 'cat-animal-nutrition' ||
                catLower == 'animal-nutrition'));
    return InkWell(
      key: ValueKey((value == 'All Organic Essentials' || value == 'All products')
          ? 'category-filter-All products'
          : 'category-filter-$value'),
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
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Product> _categoryProducts(List<Product> all) {
    final query = _search.text.trim().toLowerCase();
    final selectedNode = _taxonomy?.nodes
        .where((n) => n.id == _category || n.slug == _category)
        .firstOrNull;
    final catLower = (selectedNode?.name ?? _category).toLowerCase();

    final isAllCategory = catLower == 'all products' ||
        catLower == 'all' ||
        catLower == 'all organic essentials';
    final isGheeCategory = catLower.contains('ghee') ||
        catLower == 'all ghee' ||
        catLower == 'all-ghee' ||
        catLower == 'ghee collection';
    final isCowGheeCategory = catLower.contains('cow ghee') || catLower == 'cow-ghee';
    final isBuffGheeCategory =
        catLower.contains('buffalo ghee') || catLower == 'buffalo-ghee';
    final isHerbalGheeCategory = catLower.contains('herbal ghee') ||
        catLower == 'herbal-ghee' ||
        catLower.contains('herbal infused');

    final isSkincareCategory = catLower.contains('skincare') ||
        catLower.contains('shata') ||
        catLower.contains('soap') ||
        catLower.contains('ubtan');

    final isMilkDairyCategory = (catLower.contains('fresh milk') ||
        catLower.contains('dairy foods') ||
        catLower.contains('chhachh') ||
        catLower.contains('chaas') ||
        catLower.contains('paneer') ||
        catLower.contains('makhan') ||
        catLower.contains('butter') ||
        catLower == 'milk' ||
        catLower == 'doodh' ||
        catLower == 'other products') &&
        !isSkincareCategory;

    final isPujaSacredCategory = catLower.contains('puja') ||
        catLower.contains('hawan') ||
        catLower.contains('samagri') ||
        catLower.contains('kanda') ||
        catLower.contains('uple') ||
        catLower.contains('kapoor') ||
        catLower.contains('camphor') ||
        catLower.contains('diya');

    final isAgarbattiCategory = catLower.contains('agarbatti') ||
        catLower.contains('dhoop') ||
        catLower.contains('incense');

    final isEarthCategory = catLower.contains('vermicompost') ||
        catLower.contains('living soil') ||
        catLower.contains('earth') ||
        catLower.contains('manure') ||
        catLower.contains('compost') ||
        catLower.contains('soil mix');

    final isSarsoOilCategory = catLower.contains('sarso') ||
        catLower.contains('mustard') ||
        (catLower.contains('oil') && !catLower.contains('soil')) ||
        catLower.contains('til') ||
        catLower.contains('groundnut') ||
        catLower.contains('peanut');

    final isMicrogreenCategory = catLower.contains('microgreen') ||
        catLower.contains('living harvest') ||
        catLower.contains('living-harvest') ||
        catLower.contains('punnet') ||
        catLower.contains('shoots');

    final isFlourCategory = catLower.contains('flour') ||
        catLower.contains('atta') ||
        catLower.contains('chakki') ||
        catLower.contains('khapli') ||
        catLower.contains('sharbati') ||
        catLower.contains('sattu') ||
        catLower.contains('millet');

    final isSaltCategory = (catLower.contains('salt') ||
            catLower.contains('sendha') ||
            catLower.contains('namak')) &&
        !catLower.contains('spice');

    final isSpiceCategory = catLower.contains('spice') ||
        catLower.contains('haldi') ||
        catLower.contains('turmeric') ||
        catLower.contains('jeera') ||
        catLower.contains('dhania') ||
        catLower.contains('chilli');

    final isSaltSpiceCategory = catLower.contains('terroir') ||
        (catLower.contains('salt') && catLower.contains('spice'));

    final isBalconyCategory = catLower.contains('balcony') ||
        catLower.contains('booster') ||
        catLower.contains('potting') ||
        catLower.contains('fungicide') ||
        catLower.contains('seeds') ||
        catLower.contains('bio-defense');

    final isComboCategory = catLower.contains('combo') ||
        catLower.contains('curated') ||
        catLower.contains('starter box') ||
        catLower.contains('starter') ||
        catLower.contains('duo') ||
        catLower.contains('kit');

    final isSweetenerCategory = catLower.contains('honey') ||
        catLower.contains('sweetener') ||
        catLower.contains('gur') ||
        catLower.contains('khand') ||
        catLower.contains('mishri') ||
        catLower.contains('shakkar');

    final isPurePantryHub = catLower.contains('pure pantry') ||
        catLower == 'pantry' ||
        catLower == 'the pure pantry' ||
        catLower == 'pure-pantry';

    final isBotanicalHub = catLower.contains('botanical living') ||
        catLower == 'botanical' ||
        catLower == 'the botanical living' ||
        catLower == 'botanical-living';

    final isAloeCategory = catLower.contains('aloe') || catLower == 'pure-aloe-botanicals';

    final isAllNutrition = catLower == 'animal nutrition' ||
        catLower == 'cattle nutrition' ||
        catLower == 'milterra cattle nutrition solutions' ||
        catLower == 'animal-nutrition' ||
        catLower == 'cat-animal-nutrition' ||
        catLower == 'farm-essentials' ||
        catLower == 'farm essentials';

    final isEquipmentCategory = catLower == 'equipment' ||
        catLower == 'farm machinery' ||
        catLower == 'cat-machinery';

    return all.where((p) {
      if (p.isDraft) return false;

      // On consumer storefront (/shop), strictly hide farm machinery & cattle feeds
      if (widget.category == null) {
        final cat = storeCategory(p);
        if (cat == 'Animal nutrition' ||
            cat == 'Equipment' ||
            p.category == ProductCategory.equipment) {
          return false;
        }
      }

      // Dynamic backend taxonomy node resolution
      if (_taxonomy?.enabled == true && !isAllCategory) {
        final node = _taxonomy!.findNode(_category);
        if (node != null) {
          final descendants = _taxonomy!.descendants(node.id);
          final matchesNode = descendants.contains(p.taxonomy?['category_id']) ||
              descendants.contains(p.taxonomy?['subcategory_id']) ||
              p.taxonomy?['category_name']?.toString().toLowerCase() ==
                  node.name.toLowerCase() ||
              p.taxonomy?['department_name']?.toString().toLowerCase() ==
                  node.name.toLowerCase() ||
              storeCategory(p).toLowerCase() == node.name.toLowerCase();
          if (matchesNode) {
            return query.isEmpty ||
                '${p.title} ${p.packSize ?? ''} ${p.brand ?? ''}'
                    .toLowerCase()
                    .contains(query);
          }
        }
      }

      final pCategory = storeCategory(p);
      final pTitle = p.title.toLowerCase();

      // Category filter
      final bool matchesCategory;
      if (isAllCategory) {
        matchesCategory = true;
      } else if (isCowGheeCategory) {
        matchesCategory = pCategory == 'Cow ghee' ||
            (pTitle.contains('cow') && pTitle.contains('ghee'));
      } else if (isBuffGheeCategory) {
        matchesCategory = pCategory == 'Buffalo ghee' ||
            (pTitle.contains('buffalo') && pTitle.contains('ghee'));
      } else if (isHerbalGheeCategory) {
        matchesCategory = pCategory == 'Herbal Ghee' ||
            pTitle.contains('herbal') ||
            pTitle.contains('brahmi') ||
            pTitle.contains('tulsi');
      } else if (isGheeCategory) {
        matchesCategory = pCategory == 'Cow ghee' ||
            pCategory == 'Buffalo ghee' ||
            pCategory == 'Herbal Ghee' ||
            pTitle.contains('ghee');
      } else if (isMilkDairyCategory) {
        if (catLower == 'milk' || catLower == 'doodh') {
          matchesCategory = pTitle.contains('milk') || pTitle.contains('doodh');
        } else if (catLower == 'chhachh' || catLower == 'chaas') {
          matchesCategory = pTitle.contains('chhachh') ||
              pTitle.contains('chaas') ||
              pTitle.contains('buttermilk');
        } else if (catLower == 'paneer') {
          matchesCategory = pCategory == 'Paneer' || pTitle.contains('paneer');
        } else if (catLower == 'other products' ||
            catLower == 'makhan' ||
            catLower == 'butter') {
          matchesCategory = pCategory == 'Other products' ||
              pTitle.contains('butter') ||
              pTitle.contains('makhan');
        } else {
          matchesCategory = (pCategory == 'Fresh Milk & Dairy' ||
                  pCategory == 'Paneer' ||
                  pCategory == 'Other products' ||
                  pTitle.contains('milk') ||
                  pTitle.contains('chhachh') ||
                  pTitle.contains('paneer') ||
                  pTitle.contains('makhan') ||
                  pTitle.contains('butter')) &&
              !pTitle.contains('soap') &&
              !pTitle.contains('shata') &&
              !pTitle.contains('ubtan') &&
              !pTitle.contains('skin');
        }
      } else if (isSkincareCategory) {
        matchesCategory = pTitle.contains('soap') ||
            pTitle.contains('shata') ||
            pTitle.contains('ghrita') ||
            pTitle.contains('ubtan') ||
            pTitle.contains('skin') ||
            pCategory.toLowerCase().contains('skincare') ||
            pCategory.toLowerCase().contains('soap');
      } else if (isPujaSacredCategory) {
        matchesCategory = pCategory == 'Puja & Hawan Samagri' ||
            pTitle.contains('hawan') ||
            pTitle.contains('yajna') ||
            pTitle.contains('puja') ||
            pTitle.contains('diya') ||
            pTitle.contains('kanda') ||
            pTitle.contains('uple') ||
            pTitle.contains('kapoor') ||
            pTitle.contains('camphor') ||
            pTitle.contains('samagri');
      } else if (isAgarbattiCategory) {
        matchesCategory = pCategory == 'Natural Agarbatti & Dhoop' ||
            pTitle.contains('agarbatti') ||
            pTitle.contains('dhoop') ||
            pTitle.contains('incense') ||
            pTitle.contains('loban') ||
            pTitle.contains('guggal') ||
            pTitle.contains('sambrani');
      } else if (isEarthCategory) {
        matchesCategory = pCategory == 'Vermicompost & Living Soil' ||
            p.taxonomy?['is_earth'] == true ||
            pTitle.contains('earth') ||
            pTitle.contains('vermicompost') ||
            pTitle.contains('manure') ||
            pTitle.contains('compost') ||
            pTitle.contains('soil');
      } else if (isSarsoOilCategory) {
        if (pTitle.contains('soil') ||
            pTitle.contains('compost') ||
            pTitle.contains('vermicompost') ||
            pTitle.contains('manure') ||
            pCategory.toLowerCase().contains('soil') ||
            pCategory.toLowerCase().contains('vermicompost')) {
          matchesCategory = false;
        } else {
          matchesCategory = pCategory == 'Cold-Pressed Sarso (Mustard) Oil' ||
              pCategory.toLowerCase().contains('sarso') ||
              pCategory.toLowerCase().contains('mustard') ||
              (pCategory.toLowerCase().contains('oil') &&
                  !pCategory.toLowerCase().contains('soil')) ||
              pTitle.contains('sarso') ||
              pTitle.contains('mustard') ||
              pTitle.contains('kachi ghani') ||
              pTitle.contains('til') ||
              pTitle.contains('sesame') ||
              (pTitle.contains('oil') && !pTitle.contains('soil'));
        }
      } else if (isMicrogreenCategory) {
        matchesCategory = (pTitle.contains('microgreen') ||
                pTitle.contains('punnet') ||
                pTitle.contains('radish micro') ||
                pTitle.contains('sunflower micro') ||
                pTitle.contains('pea shoot') ||
                pTitle.contains('sweet pea') ||
                pTitle.contains('broccoli & mustard micro') ||
                pCategory.toLowerCase().contains('microgreen')) &&
            !pTitle.contains('oil');
      } else if (isFlourCategory) {
        matchesCategory = pTitle.contains('atta') ||
            pTitle.contains('flour') ||
            pTitle.contains('khapli') ||
            pTitle.contains('sharbati') ||
            pTitle.contains('sattu') ||
            pTitle.contains('millet') ||
            pCategory.toLowerCase().contains('flour') ||
            pCategory.toLowerCase().contains('atta');
      } else if (isSaltCategory) {
        matchesCategory = pTitle.contains('salt') ||
            pTitle.contains('sendha') ||
            pTitle.contains('namak') ||
            (pCategory.toLowerCase().contains('salt') &&
                !pCategory.toLowerCase().contains('spice'));
      } else if (isSpiceCategory) {
        matchesCategory = pTitle.contains('haldi') ||
            pTitle.contains('turmeric') ||
            pTitle.contains('jeera') ||
            pTitle.contains('cumin') ||
            pTitle.contains('dhania') ||
            pTitle.contains('coriander') ||
            pTitle.contains('mathania') ||
            pTitle.contains('chilli') ||
            pTitle.contains('spice') ||
            pCategory.toLowerCase().contains('spice');
      } else if (isSaltSpiceCategory) {
        matchesCategory = pTitle.contains('salt') ||
            pTitle.contains('sendha') ||
            pTitle.contains('namak') ||
            pTitle.contains('haldi') ||
            pTitle.contains('turmeric') ||
            pTitle.contains('jeera') ||
            pTitle.contains('cumin') ||
            pTitle.contains('dhania') ||
            pTitle.contains('coriander') ||
            pTitle.contains('mathania') ||
            pTitle.contains('chilli') ||
            pCategory.toLowerCase().contains('salt') ||
            pCategory.toLowerCase().contains('spice');
      } else if (isBalconyCategory) {
        matchesCategory = pTitle.contains('balcony') ||
            pTitle.contains('potting') ||
            pTitle.contains('booster') ||
            pTitle.contains('spray') ||
            pTitle.contains('fungicide') ||
            pTitle.contains('seed') ||
            pTitle.contains('odorless') ||
            pCategory.toLowerCase().contains('balcony') ||
            pCategory.toLowerCase().contains('soil');
      } else if (isComboCategory) {
        matchesCategory = pTitle.contains('box') ||
            pTitle.contains('kit') ||
            pTitle.contains('duo') ||
            pTitle.contains('combo') ||
            pTitle.contains('starter') ||
            pCategory.toLowerCase().contains('combo') ||
            pCategory.toLowerCase().contains('box');
      } else if (isSweetenerCategory) {
        matchesCategory = pTitle.contains('honey') ||
            pTitle.contains('gur') ||
            pTitle.contains('khand') ||
            pTitle.contains('mishri') ||
            pTitle.contains('sweetener') ||
            pCategory.toLowerCase().contains('honey') ||
            pCategory.toLowerCase().contains('sweetener');
      } else if (isPurePantryHub) {
        matchesCategory = isGheeCategory ||
            isMilkDairyCategory ||
            isSarsoOilCategory ||
            isFlourCategory ||
            isSaltSpiceCategory ||
            isSweetenerCategory ||
            pTitle.contains('ghee') ||
            pTitle.contains('oil') ||
            pTitle.contains('atta') ||
            pTitle.contains('flour') ||
            pTitle.contains('salt') ||
            pTitle.contains('haldi') ||
            pTitle.contains('honey') ||
            pTitle.contains('mattha') ||
            pTitle.contains('sattu') ||
            pTitle.contains('jeera') ||
            pTitle.contains('dhania') ||
            pTitle.contains('chilli');
      } else if (isBotanicalHub) {
        matchesCategory = isMicrogreenCategory ||
            isBalconyCategory ||
            isEarthCategory ||
            isAloeCategory ||
            pTitle.contains('microgreen') ||
            pTitle.contains('vermicompost') ||
            pTitle.contains('potting') ||
            pTitle.contains('spray') ||
            pTitle.contains('seed') ||
            pTitle.contains('fungicide') ||
            pTitle.contains('soap') ||
            pTitle.contains('ghrita') ||
            pTitle.contains('ubtan') ||
            pTitle.contains('skin') ||
            pTitle.contains('aloe');
      } else if (isAloeCategory) {
        matchesCategory = pTitle.contains('aloe') ||
            pCategory.toLowerCase().contains('aloe') ||
            (p.taxonomy?['category_name']?.toString().toLowerCase().contains('aloe') ?? false);
      } else if (isEquipmentCategory) {
        matchesCategory = pCategory == 'Equipment' ||
            p.category == ProductCategory.equipment;
      } else if (isAllNutrition) {
        matchesCategory = pCategory == 'Animal nutrition' ||
            p.category == ProductCategory.feedNutrition;
      } else {
        final catName = p.taxonomy?['category_name']?.toString().toLowerCase() ?? '';
        final subcatName = p.taxonomy?['subcategory_name']?.toString().toLowerCase() ?? '';
        final deptName = p.taxonomy?['department_name']?.toString().toLowerCase() ?? '';
        final collectionName = p.taxonomy?['collection']?.toString().toLowerCase() ?? '';
        final specCollection = p.specifications['collection']?.toString().toLowerCase() ?? '';
        final specDept = p.specifications['department']?.toString().toLowerCase() ?? '';

        matchesCategory = pCategory.toLowerCase() == catLower ||
            collectionName == catLower ||
            collectionName.contains(catLower) ||
            deptName == catLower ||
            deptName.contains(catLower) ||
            catName == catLower ||
            catName.contains(catLower) ||
            subcatName == catLower ||
            subcatName.contains(catLower) ||
            specCollection == catLower ||
            specDept == catLower ||
            pTitle.contains(catLower);
      }

      if (!matchesCategory) return false;
      return query.isEmpty ||
          '${p.title} ${p.packSize ?? ''} ${p.brand ?? ''}'
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  List<Product> get _scope => _categoryProducts(
      ref.watch(productsProvider(widget.category)).valueOrNull ?? []);
  bool get _conceptOnly =>
      _scope.isNotEmpty && _scope.every((p) => p.isConcept);
  List<String> get _sortOptions => [
        'Featured',
        'Best Sellers',
        'Newest Arrivals',
        'Trending',
        if (!_conceptOnly) ...['Price: low to high', 'Price: high to low'],
        'Name: A to Z',
      ];

  Widget _products(List<Product> all, bool small) {
    final items = _categoryProducts(all).where((p) {
      if (_packs.isNotEmpty && !_packs.contains(p.packSize ?? p.unit)) {
        return false;
      }
      if (!_conceptOnly) {
        if (_inStock && (p.isConcept || !p.inStock)) return false;
        if ((_priceMin > 0 || _priceMax > 0) && p.isConcept) return false;
        if (_priceMin > 0 && p.price < _priceMin) return false;
        if (_priceMax > 0 && p.price > _priceMax) return false;
      }
      return true;
    }).toList();
    if (_sort == 'Best Sellers') {
      items.sort((a, b) {
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        return b.rating.compareTo(a.rating);
      });
    } else if (_sort == 'Newest Arrivals') {
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sort == 'Trending') {
      items.sort((a, b) {
        if (a.isFeatured != b.isFeatured) return a.isFeatured ? -1 : 1;
        return (b.reviewCount).compareTo(a.reviewCount);
      });
    } else if (!_conceptOnly && _sort.startsWith('Price:')) {
      items.sort((a, b) {
        if (a.isConcept != b.isConcept) return a.isConcept ? 1 : -1;
        return _sort == 'Price: low to high'
            ? a.price.compareTo(b.price)
            : b.price.compareTo(a.price);
      });
    } else if (_sort == 'Name: A to Z') {
      items.sort((a, b) => a.title.compareTo(b.title));
    }
    final groups = storeProductGroups(items);

    if (items.isEmpty) {
      if (_search.text.isNotEmpty ||
          _priceMin > 0 ||
          _priceMax > 0 ||
          _inStock ||
          _packs.isNotEmpty) {
        return _message(
            Icons.search_off,
            'No products matched your filters',
            'Try clearing price or department filters to see more results.',
            'Clear all filters',
            _reset);
      }

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

      final isSarsoOil = _category.toLowerCase().contains('sarso') ||
          _category.toLowerCase().contains('mustard') ||
          (_category.toLowerCase().contains('oil') &&
              !_category.toLowerCase().contains('soil')) ||
          _category.toLowerCase().contains('til');

      if (isSarsoOil) {
        return _buildSarsoOilEmptyState(small);
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
                    onOpen: (p) {
                      ref.read(analyticsServiceProvider).trackProductView(
                            p.id,
                            p.title,
                            price: p.price,
                          );
                      context.push('/shop/product/${p.id}');
                    },
                  ),
                ),
              )
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

  Widget _buildSarsoOilEmptyState(bool small) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 380),
      padding: EdgeInsets.all(small ? 20 : 32),
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: const Color(0xfffde68a), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0cd97706),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xfffef3c7), Color(0xfffde68a)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xfff59e0b), width: 2),
            ),
            child: const Icon(
              Icons.local_florist_rounded,
              size: 36,
              color: Color(0xffb45309),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xfffef3c7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xfff59e0b)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_rounded, size: 13, color: Color(0xffb45309)),
                SizedBox(width: 5),
                Text(
                  'FRESH KACHI GHANI HARVEST BATCH',
                  style: TextStyle(
                    color: Color(0xffb45309),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Cold-Pressed Sarso (Mustard) Oil\nFresh Batch in Preparation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xff78350f),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const Text(
              'Our organic yellow & black mustard seeds are undergoing traditional wooden Kolhu (< 40°C) cold pressing and natural sedimentation. Zero chemical refining, 100% authentic pungency.\n\nFresh harvest bottles (1L glass & 5L tin) are being prepared!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xff92400e),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildOilFeaturePill('🪵 Wood-Pressed Kolhu (< 40°C)'),
              _buildOilFeaturePill('🌾 100% Organically Grown'),
              _buildOilFeaturePill('🛡️ Zero Argemone / Chemicals'),
              _buildOilFeaturePill('🏺 Food-Grade Glass & Tin'),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xffb45309),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.explore_outlined, size: 16),
                label: const Text(
                  'Explore Vedic Bilona Ghee',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () => _browse('Vedic Bilona Ghee'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff78350f),
                  side: const BorderSide(color: Color(0xffd97706)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.storefront_outlined, size: 16),
                label: const Text(
                  'Browse All Products',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _reset,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOilFeaturePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xfffde68a)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xff92400e),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String description,
          String action, VoidCallback onTap) =>
      Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 320),
          padding: const EdgeInsets.all(StoreLayout.xl),
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              ),
            ],
          ));

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
