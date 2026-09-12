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
import '../models/hero_showcase_config.dart';
import '../widgets/product_information.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../../commerce/models/taxonomy.dart';
import '../../commerce/providers/commerce_provider.dart';

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
  final Set<String> _packs = {};
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
    });
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

  Widget _buildTrustAndQualityStrip(bool isMobile) => const StorePanel(
        child: Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  'Explore dairy foods, farm essentials and product concepts.'),
              ProductQualityLink()
            ]),
      );

  Widget _buildDepartmentLandingBanner(bool isMobile) => StorePanel(
        title: _label(_category),
        child: Text(_conceptOnly
            ? Product.conceptExplanation
            : 'Browse products and compare the available pack sizes. Concept previews are labelled and not for sale.'),
      );

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
      'Dairy Foods': {
        'Dairy Foods': 'All Dairy Foods',
        'Cow ghee': 'Cow ghee',
        'Buffalo ghee': 'Buffalo ghee',
        'Paneer': 'Paneer',
        'Other products': 'White Butter (Makhan)'
      },
      'Farm Essentials': {
        'Farm Essentials': 'All Farm Essentials',
        'Animal nutrition': 'All Cattle Nutrition',
        'Pashu Aahar / Cattle Feed': 'Pashu Aahar / Cattle Feed',
        'Stage-Based Nutrition': 'Stage-Based Nutrition',
        'Supplements': 'Supplements & Minerals',
        'Equipment': 'Dairy & Farm Equipment'
      },
      'MILTERRA Earth': {
        'MILTERRA Earth': 'All MILTERRA Earth',
        'Vermicompost': 'Vermicompost',
        'Farm Manure': 'Farm Manure',
        'Organic Compost': 'Organic Compost',
        'Compost Cakes': 'Compost Cakes',
        'Compost Starter': 'Compost Starter',
        'Garden Soil Mix': 'Garden Soil Mix'
      },
    };
    for (final dept in _taxonomy?.nodes
            .where((n) => n.kind == 'department' && n.isActive) ??
        <TaxonomyNode>[]) {
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
    final isAll = _category == 'All products' || _category == 'All';
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
      _categoryFilterItem('All products', 'All Departments', refresh,
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
                        setState(() =>
                            v == true ? _packs.add(pack) : _packs.remove(pack));
                        refresh();
                      },
                    ))
                .toList()),
      if (!_conceptOnly) ...[
        const Divider(),
        const Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold)),
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
    ]));
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

  List<Product> _categoryProducts(List<Product> all) {
    final query = _search.text.trim().toLowerCase();
    final selectedNode = _taxonomy?.nodes
        .where((n) => n.id == _category || n.slug == _category)
        .firstOrNull;
    final catLower = (selectedNode?.name ?? _category).toLowerCase();

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

    final isAllNutrition = catLower == 'animal nutrition' ||
        catLower == 'cattle nutrition' ||
        catLower == 'milterra cattle nutrition solutions' ||
        catLower == 'animal-nutrition' ||
        catLower == 'cat-animal-nutrition' ||
        catLower == 'farm-essentials' ||
        catLower == 'farm essentials';

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

    return all.where((p) {
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
      } else if (catLower == 'farm essentials' ||
          catLower == 'farm-essentials') {
        matchesCategory = p.taxonomy?['department_name'] == 'Farm Essentials' ||
            p.category == ProductCategory.equipment;
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
        if (!_conceptOnly) ...['Price: low to high', 'Price: high to low'],
        'Name: A to Z',
      ];

  Widget _products(List<Product> all, bool small) {
    final items = _categoryProducts(all).where((p) {
      if (_packs.isNotEmpty && !_packs.contains(p.packSize ?? p.unit))
        return false;
      if (!_conceptOnly) {
        if (_inStock && (p.isConcept || !p.inStock)) return false;
        if ((_priceMin > 0 || _priceMax > 0) && p.isConcept) return false;
        if (_priceMin > 0 && p.price < _priceMin) return false;
        if (_priceMax > 0 && p.price > _priceMax) return false;
      }
      return true;
    }).toList();
    if (!_conceptOnly && _sort.startsWith('Price:')) {
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
