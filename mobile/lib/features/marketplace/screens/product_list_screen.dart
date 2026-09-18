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
    final lower = value.toLowerCase();
    if (lower.contains('sarso') ||
        lower.contains('mustard') ||
        lower.contains('oil')) {
      return '🌻 Cold-Pressed Sarso (Mustard) Oil';
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
    if (lower.contains('milk') ||
        lower.contains('chhachh') ||
        lower.contains('chaas') ||
        lower.contains('paneer') ||
        lower.contains('makhan') ||
        lower.contains('dairy foods')) {
      return '🥛 Fresh Milk & Dairy (Chhachh & Paneer)';
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
                              // Hero Banner (Home / Unfiltered view)
                              if (_search.text.isEmpty &&
                                  (_category == 'All products' ||
                                      _category == 'All' ||
                                      _category == 'All Organic Essentials')) ...[
                                _hero(size.maxWidth),
                                const SizedBox(height: 24),
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
                                              _category != 'All' &&
                                              _category != 'All Organic Essentials') ...[
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
    return HeroSplitShowcase(
      screenWidth: screenWidth,
      onExploreCategory: _browse,
      productSlides: storeProductGroups(ref
                  .watch(productsProvider(null))
                  .valueOrNull
                  ?.where((p) => !p.isConcept)
                  .toList() ??
              [])
          .take(4)
          .map((g) {
        final p = g.first;
        return HeroProductSlide(
            id: p.id,
            category: storeCategory(p),
            badge: '',
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

  Widget _buildDepartmentLandingBanner(bool isMobile) => StorePanel(
        title: _label(_category),
        child: Text(_conceptOnly
            ? Product.conceptExplanation
            : 'Browse products and compare the available pack sizes. Concept previews are labelled and not for sale.'),
      );

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
    for (final dept in _taxonomy?.nodes
            .where((n) => n.kind == 'department' && n.isActive) ??
        <TaxonomyNode>[]) {
      if (widget.category == null && (_taxonomy?.nodes.length ?? 0) > 3) {
        if (dept.name.toLowerCase() == 'dairy foods' ||
            dept.name.toLowerCase() == 'farm essentials' ||
            dept.name.toLowerCase() == 'ayurvedic skincare') {
          continue;
        }
      }
      final group =
          groups.putIfAbsent(dept.name, () => {dept.id: 'All ${dept.name}'});
      for (final node in _taxonomy!.nodes
          .where((n) => n.parentId == dept.id && n.isActive)) {
        if (!group.keys
            .any((key) => key.toLowerCase() == node.name.toLowerCase())) {
          group[node.id] = node.name;
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

  List<Product> _categoryProducts(List<Product> all) {
    final query = _search.text.trim().toLowerCase();
    final selectedNode = _taxonomy?.nodes
        .where((n) => n.id == _category || n.slug == _category)
        .firstOrNull;
    final catLower = (selectedNode?.name ?? _category).toLowerCase();

    final isAllCategory = catLower == 'all products' ||
        catLower == 'all' ||
        catLower == 'all organic essentials';
    final isGheeCategory = catLower == 'vedic bilona ghee' ||
        catLower == 'all ghee' ||
        catLower == 'all-ghee' ||
        catLower == 'ghee' ||
        catLower == 'ghee collection' ||
        catLower == 'cow ghee' ||
        catLower == 'buffalo ghee' ||
        catLower == 'herbal ghee';
    final isCowGheeCategory = catLower == 'cow ghee' || catLower == 'cow-ghee';
    final isBuffGheeCategory =
        catLower == 'buffalo ghee' || catLower == 'buffalo-ghee';
    final isHerbalGheeCategory = catLower == 'herbal ghee' ||
        catLower == 'herbal-ghee' ||
        catLower == 'herbal infused ghee';

    final isMilkDairyCategory = catLower == 'fresh milk & dairy' ||
        catLower == 'dairy foods' ||
        catLower == 'milk' ||
        catLower == 'doodh' ||
        catLower == 'chhachh' ||
        catLower == 'chaas' ||
        catLower == 'paneer' ||
        catLower == 'other products' ||
        catLower == 'makhan' ||
        catLower == 'butter';

    final isPujaSacredCategory = catLower == 'puja & hawan samagri' ||
        catLower == 'puja-hawan-samagri' ||
        catLower == 'hawan & yajna ghee' ||
        catLower == 'cow dung sacred products' ||
        catLower == 'bhimseni kapoor & samagri';

    final isAgarbattiCategory = catLower == 'natural agarbatti & dhoop' ||
        catLower == 'dhoop-agarbatti' ||
        catLower == 'agarbatti' ||
        catLower == 'dhoop';

    final isEarthCategory = catLower == 'vermicompost & living soil' ||
        catLower == 'milterra earth' ||
        catLower == 'milterra-earth' ||
        catLower == 'earth' ||
        catLower == 'living soil' ||
        catLower == 'vermicompost' ||
        catLower == 'farm manure' ||
        catLower == 'organic compost' ||
        catLower == 'compost cakes' ||
        catLower == 'compost starter' ||
        catLower == 'garden soil mix';

    final isSarsoOilCategory = catLower == 'cold-pressed sarso (mustard) oil' ||
        catLower == 'sarso-oil' ||
        catLower == 'sarso' ||
        catLower == 'mustard' ||
        catLower == 'oil' ||
        catLower == 'til';

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

      // On consumer storefront (/shop), hide farm machinery & cattle feed unless explicitly selected/searched
      if (widget.category == null && !isEquipmentCategory && !isAllNutrition && catLower != 'stage-based nutrition') {
        if ((p.category == ProductCategory.equipment ||
                p.category == ProductCategory.feedNutrition ||
                (p.isConcept && (storeCategory(p) == 'Animal nutrition' || storeCategory(p) == 'Equipment')) ||
                storeCategory(p) == 'Animal nutrition' ||
                storeCategory(p) == 'Equipment') &&
            query.isEmpty) {
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
          matchesCategory = pCategory == 'Fresh Milk & Dairy' ||
              pCategory == 'Paneer' ||
              pCategory == 'Other products' ||
              pTitle.contains('milk') ||
              pTitle.contains('chhachh') ||
              pTitle.contains('paneer') ||
              pTitle.contains('makhan') ||
              pTitle.contains('butter');
        }
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
        matchesCategory = pCategory == 'Cold-Pressed Sarso (Mustard) Oil' ||
            pTitle.contains('sarso') ||
            pTitle.contains('mustard') ||
            pTitle.contains('kachi ghani') ||
            pTitle.contains('til') ||
            pTitle.contains('sesame') ||
            pTitle.contains('oil');
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
