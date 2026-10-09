import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import 'store_design.dart';

/// Popular search queries reflecting Milterra's organic & pure catalogue
const List<String> kStoreTrendingSearches = [
  'A2 Cow Bilona Ghee',
  'Cold-Pressed Mustard Oil',
  'Fresh Malai Paneer',
  'Raw Mustard Honey',
  'Murrah Buffalo Ghee',
  'Single-Origin Lakadong Turmeric',
  'Khapli Emmer Wheat Atta',
  'Shata Dhauta Ghrita 100x',
  'A2 Gir Cow Milk',
  'NMR Tested Honey',
];

/// Curated trending products displayed when search is empty
class StoreTrendingProductItem {
  final String id;
  final String sku;
  final String title;
  final double price;
  final double compareAtPrice;
  final String image;
  final String category;

  const StoreTrendingProductItem({
    required this.id,
    required this.sku,
    required this.title,
    required this.price,
    required this.compareAtPrice,
    required this.image,
    required this.category,
  });

  int get discountPercent => compareAtPrice > price
      ? (((compareAtPrice - price) / compareAtPrice) * 100).round()
      : 0;
}

const List<StoreTrendingProductItem> kStoreDefaultTrendingProducts = [
  StoreTrendingProductItem(
    id: 'ffd7186f-6cee-4b8e-9a87-6af173aabffd',
    sku: 'MIL-GHEE-500',
    title: 'A2 Cultured Sahiwal Cow Bilona Ghee (500 ml Glass Jar)',
    price: 899,
    compareAtPrice: 1050,
    image: 'assets/store/bilona-cow-ghee.jpg',
    category: 'Artisanal Dairy & Cultured',
  ),
  StoreTrendingProductItem(
    id: '54b52256-c0d6-436c-b8aa-737b35ab1636',
    sku: 'MIL-OIL-MUSTARD-1L',
    title: 'Kacchi Ghani Black Mustard Oil (Lakdi Ghani 1 Litre)',
    price: 220,
    compareAtPrice: 250,
    image: 'assets/store/sarso-oil.jpg',
    category: 'Wood-Pressed Oils & Pure Sweeteners',
  ),
  StoreTrendingProductItem(
    id: 'ad431721-27f9-477b-85ce-53def61d7f36',
    sku: 'MIL-BUFF-500',
    title: 'Murrah Buffalo Danedar Bilona Ghee (500 ml Glass Jar)',
    price: 849,
    compareAtPrice: 990,
    image: 'assets/store/ghee-jar-500ml.jpg',
    category: 'Artisanal Dairy & Cultured',
  ),
  StoreTrendingProductItem(
    id: 'dcef1775-f5b4-4014-b21e-e1f1558792cd',
    sku: 'MIL-HONEY-500',
    title: 'Raw Unpasteurized Mustard Honey (NMR Tested 500 g Glass Jar)',
    price: 350,
    compareAtPrice: 420,
    image: 'assets/store/raw-mustard-honey.jpg',
    category: 'Wood-Pressed Oils & Pure Sweeteners',
  ),
];

/// Dropdown panel attached beneath the storefront search box.
/// Displays Recent Searches, Trending Searches, Trending Products,
/// and live auto-complete matching suggestions as the user types.
class StoreSearchDropdownOverlay extends ConsumerStatefulWidget {
  const StoreSearchDropdownOverlay({
    super.key,
    required this.headerKey,
    required this.searchBarKey,
    required this.searchController,
    required this.searchFocusNode,
    required this.recentSearches,
    required this.onRemoveRecent,
    required this.onClearAllRecent,
    required this.onSelectQuery,
    required this.onSelectProduct,
    required this.onClose,
  });

  final GlobalKey headerKey;
  final GlobalKey searchBarKey;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final List<String> recentSearches;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearAllRecent;
  final ValueChanged<String> onSelectQuery;
  final ValueChanged<String> onSelectProduct;
  final VoidCallback onClose;

  @override
  ConsumerState<StoreSearchDropdownOverlay> createState() =>
      _StoreSearchDropdownOverlayState();
}

class _StoreSearchDropdownOverlayState
    extends ConsumerState<StoreSearchDropdownOverlay> {
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.width < 768;

    // Calculate header bottom coordinate so backdrop starts beneath header
    final headerBox =
        widget.headerKey.currentContext?.findRenderObject() as RenderBox?;
    final headerOffset =
        headerBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final headerHeight = headerBox?.size.height ?? 64.0;
    final headerBottom = headerOffset.dy + headerHeight;

    // Calculate search bar box geometry
    final searchBox =
        widget.searchBarKey.currentContext?.findRenderObject() as RenderBox?;
    final searchOffset =
        searchBox?.localToGlobal(Offset.zero) ?? Offset(16, headerBottom - 48);
    final searchSize =
        searchBox?.size ?? Size(screenSize.width - 32, 42);

    double dropdownLeft;
    double dropdownWidth;
    final double dropdownTop = searchOffset.dy + searchSize.height + 6;

    if (isMobile) {
      dropdownLeft = 12.0;
      dropdownWidth = screenSize.width - 24.0;
    } else {
      // Desktop: align with search box and ensure generous comfortable width
      dropdownWidth = math.max(searchSize.width, 580.0);
      if (dropdownWidth > screenSize.width - 32) {
        dropdownWidth = screenSize.width - 32;
      }
      dropdownLeft = searchOffset.dx;
      if (dropdownLeft + dropdownWidth > screenSize.width - 16) {
        dropdownLeft =
            math.max(8.0, screenSize.width - dropdownWidth - 16);
      }
    }

    final availableHeight = screenSize.height - dropdownTop - 20;
    final maxHeight = availableHeight.clamp(200.0, 560.0);

    return FocusScope(
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                widget.onClose();
                return null;
              },
            ),
          },
          child: Stack(
            children: [
              // 1. Dimmed backdrop covering content below header
              Positioned(
                top: headerBottom,
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),

              // 2. Dropdown Card positioned directly beneath search input
              Positioned(
                top: dropdownTop,
                left: dropdownLeft,
                width: dropdownWidth,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xffe5e7eb), width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1a000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                        BoxShadow(
                          color: Color(0x0a000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedBuilder(
                        animation: widget.searchController,
                        builder: (context, _) => _buildDropdownContent(context),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContent(BuildContext context) {
    final query = widget.searchController.text.trim();
    final catalogue = ref.watch(staticCatalogueProvider).valueOrNull;
    final allProducts = catalogue?.products ?? const <Product>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: query.isEmpty
          ? _buildDefaultSections(context, allProducts)
          : _buildLiveMatchSections(context, query, allProducts),
    );
  }

  /// Default view when search box is empty: Recent Searches, Trending searches, Trending Products
  Widget _buildDefaultSections(BuildContext context, List<Product> allProducts) {
    // Enrich default trending products with live catalogue if available
    final trendingProducts = <StoreTrendingProductItem>[];
    for (final def in kStoreDefaultTrendingProducts) {
      Product? matched;
      for (final p in allProducts) {
        if (p.id == def.id ||
            p.variants.any((v) => v.sku.toLowerCase() == def.sku.toLowerCase())) {
          matched = p;
          break;
        }
      }
      if (matched != null) {
        final catName =
            matched.taxonomy?['category_name']?.toString() ?? def.category;
        trendingProducts.add(
          StoreTrendingProductItem(
            id: matched.id,
            sku: def.sku,
            title: matched.title,
            price: matched.price,
            compareAtPrice: matched.compareAtPrice ?? def.compareAtPrice,
            image: matched.media.isNotEmpty ? matched.media.first : def.image,
            category: catName,
          ),
        );
      } else {
        trendingProducts.add(def);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Section 1: Recent Searches ---
        if (widget.recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1f2937),
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: widget.onClearAllRecent,
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff4b5563),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in widget.recentSearches)
                _buildRecentSearchChip(item),
            ],
          ),
          const SizedBox(height: 22),
        ],

        // --- Section 2: Trending searches ---
        const Text(
          'Trending searches',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xff1f2937),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in kStoreTrendingSearches)
              _buildTrendingSearchPill(term),
          ],
        ),
        const SizedBox(height: 22),

        // --- Section 3: Trending Products ---
        const Text(
          'Trending Products',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xff1f2937),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: [
            for (final item in trendingProducts)
              _buildTrendingProductCard(item),
          ],
        ),
      ],
    );
  }

  /// Real-time search auto-complete results when typing
  Widget _buildLiveMatchSections(
      BuildContext context, String query, List<Product> allProducts) {
    final lowerQuery = query.toLowerCase();

    final matched = allProducts.where((p) {
      final t = p.title.toLowerCase();
      final d = p.description?.toLowerCase() ?? '';
      final b = p.brand?.toLowerCase() ?? '';
      final dept =
          p.taxonomy?['department_name']?.toString().toLowerCase() ?? '';
      final cat =
          p.taxonomy?['category_name']?.toString().toLowerCase() ?? '';
      final hasVariant = p.variants
          .any((v) => v.sku.toLowerCase().contains(lowerQuery));
      return t.contains(lowerQuery) ||
          d.contains(lowerQuery) ||
          b.contains(lowerQuery) ||
          dept.contains(lowerQuery) ||
          cat.contains(lowerQuery) ||
          hasVariant;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Matching Products for "$query"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff1f2937),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => widget.onSelectQuery(query),
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'See All →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff16a34a),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (matched.isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.search_off_outlined,
                      size: 40, color: Color(0xff9ca3af)),
                  const SizedBox(height: 10),
                  Text(
                    'No direct matches found for "$query"',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xff374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Press Enter to browse all departments, or tap a trending search below:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xff6b7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final term in kStoreTrendingSearches.take(6))
                        _buildTrendingSearchPill(term),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Column(
            children: [
              for (final p in matched.take(5))
                _buildLiveMatchProductCard(p),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => widget.onSelectQuery(query),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xfff0fdf4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffbbf7d0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: Color(0xff16a34a)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'View all ${matched.length} matching results for "$query"',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff15803d),
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward,
                      size: 16, color: Color(0xff16a34a)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Recent search chip with history clock icon and 'x' remove button
  Widget _buildRecentSearchChip(String item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelectQuery(item),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffe5e7eb)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history,
                size: 15,
                color: Color(0xff9ca3af),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff374151),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => widget.onRemoveRecent(item),
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Color(0xff6b7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Trending search pill with trending-up arrow icon
  Widget _buildTrendingSearchPill(String term) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelectQuery(term),
        borderRadius: BorderRadius.circular(20),
        hoverColor: const Color(0xfff3f4f6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6.5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xffe5e7eb)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.trending_up,
                size: 15,
                color: Color(0xff9ca3af),
              ),
              const SizedBox(width: 6),
              Text(
                term,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Product row card for trending products
  Widget _buildTrendingProductCard(StoreTrendingProductItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelectProduct(item.id),
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xfff9fafb),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xfff3f4f6)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: StoreMediaImage(
                    source: item.image,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${item.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff111827),
                          ),
                        ),
                        if (item.compareAtPrice > item.price) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${item.compareAtPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              color: Color(0xff9ca3af),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.discountPercent}% off',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff16a34a),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: Color(0xffd1d5db),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Live matching product row card
  Widget _buildLiveMatchProductCard(Product p) {
    final imageSrc = p.media.isNotEmpty
        ? p.media.first
        : (StoreImages.productArtwork(p) ?? 'assets/store/sarso-oil.jpg');
    final compareAt = p.compareAtPrice;
    final int discount = (compareAt != null && compareAt > p.price)
        ? (((compareAt - p.price) / compareAt) * 100).round()
        : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onSelectProduct(p.id),
        borderRadius: BorderRadius.circular(8),
        hoverColor: const Color(0xfff9fafb),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xfff3f4f6)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: StoreMediaImage(
                    source: imageSrc,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '₹${p.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff111827),
                          ),
                        ),
                        if (compareAt != null && compareAt > p.price) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${compareAt.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              color: Color(0xff9ca3af),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$discount% off',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff16a34a),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: Color(0xffd1d5db),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
