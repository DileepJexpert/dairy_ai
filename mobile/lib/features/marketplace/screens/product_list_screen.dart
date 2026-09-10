import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/store_product_card.dart';
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
  String _category = 'All products', _sort = 'Featured';
  bool _inStock = false;
  double _price = 0;
  final Set<String> _adding = {};
  TaxonomyCatalogue? _taxonomy;
  String _label(String value) {
    if (_taxonomy?.enabled == true && value != 'All products') {
      for (final node in _taxonomy!.nodes) {
        if (node.id == value) return node.name;
      }
    }
    return value;
  }

  List<String> get _categories => _taxonomy?.enabled == true
      ? ['All products', ..._taxonomy!.nodes.map((n) => n.id)]
      : widget.category == ProductCategory.equipment
          ? ['All products', 'Equipment']
          : [
              'All products',
              'Cow ghee',
              'Buffalo ghee',
              'Paneer',
              'Other products'
            ];

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
    super.dispose();
  }

  void _browse(String category) {
    setState(() => _category = category);
    final target = _catalogueKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 350));
    }
  }

  void _reset() => setState(() {
        _search.clear();
        _category = 'All products';
        _price = 0;
        _inStock = false;
        _sort = 'Featured';
      });
  Future<void> _add(Product p) async {
    if (ref.read(currentUserProvider) == null) {
      context.go('/login?next=/marketplace/product/${p.id}');
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
    return Scaffold(body: LayoutBuilder(builder: (context, size) {
      final desktop = size.maxWidth >= StoreLayout.desktop;
      final small = size.maxWidth < StoreLayout.mobile;
      return Column(children: [
        StoreHeader(
            search: SizedBox(
                height: 43,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _browse(_category),
                  style: StoreType.body,
                  decoration: InputDecoration(
                      hintText: 'Search ghee, paneer and more…',
                      filled: true,
                      fillColor: storeWhite,
                      prefixIcon:
                          const Icon(Icons.search, color: storeMuted, size: 22),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _search.clear())),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: StoreLayout.md),
                      border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius:
                              BorderRadius.circular(StoreLayout.controlRadius)),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(
                              StoreLayout.controlRadius))),
                ))),
        StoreCategoryNavigation(
            selected: _category,
            onSelected: _browse,
            legacyEquipment: widget.category == ProductCategory.equipment),
        Expanded(
            child: SingleChildScrollView(
                key: const PageStorageKey('store-catalogue-scroll'),
                child: Column(children: [
                  Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: StoreLayout.maxWidth),
                          child: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      small ? StoreLayout.md : StoreLayout.xl),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: StoreLayout.lg),
                                    if (_search.text.isEmpty &&
                                        _category == 'All products') ...[
                                      _hero(size.maxWidth <
                                          StoreLayout.heroDesktop),
                                      const SizedBox(height: StoreLayout.lg),
                                    ],
                                    const SizedBox(height: StoreLayout.lg),
                                    Row(children: [
                                      const Expanded(
                                          child: Text('Shop by category',
                                              style: StoreType.title)),
                                      TextButton(
                                          onPressed: () {
                                            _reset();
                                            _browse('All products');
                                          },
                                          child: const Text('Explore all →'))
                                    ]),
                                    const SizedBox(height: StoreLayout.sm),
                                    _categoryCards(small),
                                    const SizedBox(height: StoreLayout.xl),
                                    Container(
                                        key: _catalogueKey,
                                        child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (desktop) ...[
                                                SizedBox(
                                                    width: 185,
                                                    child: _filters(() {})),
                                                const SizedBox(
                                                    width: StoreLayout.lg)
                                              ],
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    Row(children: [
                                                      Expanded(
                                                          child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                            const Text(
                                                                'THE MILTERRA COLLECTION',
                                                                style: StoreType
                                                                    .eyebrow),
                                                            const SizedBox(
                                                                height:
                                                                    StoreLayout
                                                                        .xs),
                                                            Text(
                                                                _category ==
                                                                        'All products'
                                                                    ? 'Goodness for your kitchen'
                                                                    : _label(
                                                                        _category),
                                                                style: StoreType
                                                                    .collectionHeading(
                                                                        small)),
                                                          ])),
                                                      if (!desktop)
                                                        IconButton(
                                                            tooltip:
                                                                'Filter products',
                                                            onPressed:
                                                                _showFilters,
                                                            icon: const Icon(
                                                                Icons.tune))
                                                    ]),
                                                    const SizedBox(
                                                        height: StoreLayout.md),
                                                    catalogue.when(
                                                        loading: () =>
                                                            const SizedBox(
                                                                height: 280,
                                                                child: Center(
                                                                    child:
                                                                        CircularProgressIndicator())),
                                                        error: (_, __) => _message(
                                                            Icons
                                                                .cloud_off_outlined,
                                                            'We couldn’t load the collection',
                                                            'Please check your connection and try again.',
                                                            'Try again',
                                                            () => ref.invalidate(
                                                                productsProvider(
                                                                    widget
                                                                        .category))),
                                                        data: (items) =>
                                                            _products(
                                                                items, small)),
                                                  ])),
                                            ])),
                                    const SizedBox(
                                        height: StoreLayout.sectionSpace),
                                    _editorial(small),
                                    const SizedBox(height: StoreLayout.xl),
                                    Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(
                                            StoreLayout.lg),
                                        decoration: BoxDecoration(
                                            color: storeSage,
                                            borderRadius: StoreLayout.corners),
                                        child: Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            spacing: 30,
                                            runSpacing: 20,
                                            children: [
                                              _benefit(
                                                  Icons.inventory_2_outlined,
                                                  'Find your perfect pack',
                                                  'Compare sizes before you choose.'),
                                              _benefit(
                                                  Icons.storefront_outlined,
                                                  'Know your seller',
                                                  'Seller details on every product.'),
                                              _benefit(
                                                  Icons.receipt_long_outlined,
                                                  'Keep track of your orders',
                                                  'Your purchases, all in one place.'),
                                            ])),
                                    const SizedBox(height: StoreLayout.xl),
                                  ])))),
                  const StoreFooter(),
                ]))),
      ]);
    }));
  }

  Widget _hero(bool small) {
    Widget copy() => Padding(
        padding: EdgeInsets.all(small ? 24 : 44),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('WELCOME TO MILTERRA', style: StoreType.eyebrow),
              const SizedBox(height: 20),
              Text('A spoonful of goodness.\nA kitchen full of joy.',
                  style: StoreType.heroHeading(small)),
              const SizedBox(height: 18),
              const Text(
                  'Explore ghee and dairy essentials\nfor the food you love to make.',
                  style: StoreType.heroBody),
              const SizedBox(height: 26),
              FilledButton(
                  onPressed: () => _browse('All products'),
                  child: const Text('Shop the collection   →')),
            ]));
    return ClipRRect(
        borderRadius: StoreLayout.corners,
        child: ColoredBox(
            color: storeWarm,
            child: small
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        copy(),
                        SizedBox(
                            height: 250,
                            child: Image.asset(StoreImages.hero,
                                fit: BoxFit.cover,
                                alignment: Alignment.centerRight)),
                      ])
                : SizedBox(
                    height: StoreLayout.heroHeight,
                    child: Row(children: [
                      Expanded(flex: 5, child: copy()),
                      Expanded(
                          flex: 6,
                          child: Image.asset(StoreImages.hero,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight)),
                    ]))));
  }

  Widget _categoryCards(bool small) {
    final entries = _taxonomy?.enabled == true
        ? _taxonomy!.nodes
            .map((n) => (
                  n.id,
                  n.description.isEmpty
                      ? n.kind == 'department'
                          ? 'Explore department'
                          : 'Explore products'
                      : n.description,
                  n.kind == 'department'
                      ? Icons.storefront_outlined
                      : Icons.category_outlined,
                  StorePalette.categoryAll
                ))
            .toList()
        : widget.category == ProductCategory.equipment
            ? [
                (
                  'Equipment',
                  'Explore equipment',
                  Icons.agriculture_outlined,
                  StorePalette.categoryAll
                )
              ]
            : [
                (
                  'All products',
                  'Explore the collection',
                  Icons.grid_view_rounded,
                  StorePalette.categoryAll
                ),
                (
                  'Cow ghee',
                  'For everyday cooking',
                  Icons.bakery_dining_outlined,
                  StorePalette.categoryCow
                ),
                (
                  'Buffalo ghee',
                  'Discover a richer flavour',
                  Icons.water_drop_outlined,
                  StorePalette.categoryBuffalo
                ),
                (
                  'Paneer',
                  'Fresh ideas for mealtimes',
                  Icons.restaurant_outlined,
                  StorePalette.categoryPaneer
                ),
              ];
    return LayoutBuilder(builder: (context, bounds) {
      final columns = small ? 2 : 4;
      return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entries
              .map((e) => SizedBox(
                  width: (bounds.maxWidth - 12 * (columns - 1)) / columns,
                  child: Material(
                      color: storeWhite,
                      borderRadius: StoreLayout.corners,
                      child: InkWell(
                          onTap: () => _browse(e.$1),
                          borderRadius: StoreLayout.corners,
                          child: Container(
                              padding: const EdgeInsets.all(StoreLayout.md),
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: _category == e.$1
                                          ? storeGreen
                                          : storeBorder),
                                  borderRadius: StoreLayout.corners),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                        height: small ? 110 : 150,
                                        width: double.infinity,
                                        child: StoreImages.category(
                                                    _label(e.$1)) !=
                                                null
                                            ? ProductArtwork(
                                                kind: _label(e.$1),
                                                showCaption: false)
                                            : _label(e.$1) == 'All products' ||
                                                    _label(e.$1) ==
                                                        'Dairy Foods'
                                                ? ClipRRect(
                                                    borderRadius:
                                                        StoreLayout.corners,
                                                    child: Image.asset(
                                                        StoreImages.hero,
                                                        fit: BoxFit.cover))
                                                : Icon(e.$3,
                                                    color: storeGreen,
                                                    size: 40)),
                                    const SizedBox(height: StoreLayout.sm),
                                    Text(_label(e.$1),
                                        style: StoreType.cardTitle),
                                    const SizedBox(height: StoreLayout.xxs),
                                    Text(e.$2, style: StoreType.caption),
                                  ]))))))
              .toList());
    });
  }

  Widget _filters(VoidCallback refresh) => Container(
      padding: const EdgeInsets.all(StoreLayout.md),
      decoration:
          BoxDecoration(color: storeWhite, borderRadius: StoreLayout.corners),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Filters', style: StoreType.cardTitle)),
          TextButton(
              onPressed: () {
                _reset();
                refresh();
              },
              child: const Text('Reset', style: StoreType.muted))
        ]),
        const Divider(),
        const Text('CATEGORY', style: StoreType.eyebrow),
        const SizedBox(height: StoreLayout.xs),
        for (final category in _categories)
          InkWell(
              onTap: () {
                setState(() => _category = category);
                refresh();
              },
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: StoreLayout.xs),
                  child: Row(children: [
                    Icon(
                        _category == category
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 17,
                        color: _category == category ? storeGreen : storeMuted),
                    const SizedBox(width: StoreLayout.xs),
                    Expanded(
                        child: Text(_label(category), style: StoreType.muted))
                  ]))),
        const Divider(),
        const Text('PRICE', style: StoreType.eyebrow),
        const SizedBox(height: StoreLayout.xs),
        DropdownButton<double>(
            value: _price,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: StoreType.label,
            items: const [
              DropdownMenuItem(value: 0, child: Text('Any price')),
              DropdownMenuItem(value: 500, child: Text('Under ₹500')),
              DropdownMenuItem(value: 1000, child: Text('Under ₹1,000'))
            ],
            onChanged: (v) {
              setState(() => _price = v ?? 0);
              refresh();
            }),
        const Divider(),
        const Text('AVAILABILITY', style: StoreType.eyebrow),
        Material(
            color: storeWhite,
            child: CheckboxListTile(
                value: _inStock,
                onChanged: (v) {
                  setState(() => _inStock = v ?? false);
                  refresh();
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('In stock only', style: StoreType.muted))),
      ]));
  void _showFilters() => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
          builder: (context, refresh) => SafeArea(
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(StoreLayout.md),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        _filters(() => refresh(() {})),
                        const SizedBox(height: StoreLayout.sm),
                        FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Show products'))
                      ]))))));

  Widget _products(List<Product> all, bool small) {
    final query = _search.text.trim().toLowerCase();
    final items = all
        .where((p) =>
            (_category == 'All products' ||
                (_taxonomy?.enabled == true
                    ? _taxonomy!
                        .descendants(_category)
                        .contains(p.taxonomy?['category_id'])
                    : storeCategory(p) == _category)) &&
            (!_inStock || p.inStock) &&
            (_price == 0 || p.price < _price) &&
            '${p.title} ${p.packSize ?? ''} ${p.brand ?? ''}'
                .toLowerCase()
                .contains(query))
        .toList();
    if (_sort == 'Price: low to high') {
      items.sort((a, b) => a.price.compareTo(b.price));
    }
    if (_sort == 'Price: high to low') {
      items.sort((a, b) => b.price.compareTo(a.price));
    }
    if (_sort == 'Name: A to Z') {
      items.sort((a, b) => a.title.compareTo(b.title));
    }
    final groups = storeProductGroups(items);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 22,
          runSpacing: 8,
          children: [
            Text(
                '${groups.length} products${query.isEmpty ? '' : ' for “${_search.text.trim()}”'}',
                style: StoreType.muted),
            SizedBox(
                width: 205,
                height: 38,
                child: DropdownButtonFormField<String>(
                    initialValue: _sort,
                    key: ValueKey(_sort),
                    isExpanded: true,
                    decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: StoreLayout.xs, vertical: 0),
                        filled: true,
                        fillColor: storeWhite,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                                StoreLayout.controlRadius),
                            borderSide: const BorderSide(color: storeBorder))),
                    style: StoreType.label,
                    items: [
                      'Featured',
                      'Price: low to high',
                      'Price: high to low',
                      'Name: A to Z'
                    ]
                        .map((v) =>
                            DropdownMenuItem(value: v, child: Text('Sort: $v')))
                        .toList(),
                    onChanged: (v) => setState(() => _sort = v ?? 'Featured'))),
          ]),
      const SizedBox(height: StoreLayout.md),
      if (items.isEmpty)
        _message(
            Icons.search_off,
            'No products found',
            'Try another category or clear your filters.',
            'Clear filters',
            _reset)
      else
        LayoutBuilder(builder: (context, bounds) {
          final columns = bounds.maxWidth >= 710
              ? 3
              : bounds.maxWidth >= 340
                  ? 2
                  : 1;
          final gap = small ? 16.0 : 28.0;
          return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: groups
                  .map((packs) => SizedBox(
                      width: (bounds.maxWidth - gap * (columns - 1)) / columns,
                      child: StoreProductCard(
                          key: ValueKey(packs.first.id),
                          packs: packs,
                          compact: small,
                          busyIds: _adding,
                          onAdd: _add,
                          onOpen: (p) =>
                              context.push('/marketplace/product/${p.id}'))))
                  .toList());
        }),
    ]);
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
              child: const Text('Explore all →')),
        ]));
    final photo = SizedBox(
        width: small ? double.infinity : 350,
        height: 250,
        child: Image.asset(StoreImages.hero,
            fit: BoxFit.cover, alignment: Alignment.centerRight));
    return ClipRRect(
        borderRadius: StoreLayout.corners,
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
          child: Column(children: [
            Icon(icon, size: 40, color: storeMuted),
            const SizedBox(height: StoreLayout.md),
            Text(title, style: StoreType.title),
            const SizedBox(height: StoreLayout.xs),
            Text(description,
                textAlign: TextAlign.center, style: StoreType.muted),
            const SizedBox(height: StoreLayout.md),
            OutlinedButton(onPressed: onTap, child: Text(action))
          ]));
  Widget _benefit(IconData icon, String title, String subtitle) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 29),
        const SizedBox(width: StoreLayout.md),
        Flexible(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: StoreType.label),
          const SizedBox(height: StoreLayout.xxs),
          Text(subtitle, style: StoreType.caption)
        ]))
      ]);
}
