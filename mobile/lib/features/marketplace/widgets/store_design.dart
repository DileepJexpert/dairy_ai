import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../models/product_models.dart';
import '../../cart/providers/wishlist_provider.dart';
import '../../../app/store_theme.dart';
import '../../commerce/providers/commerce_provider.dart';
import 'product_information.dart';
import 'pincode_selector_dialog.dart';
import 'store_account_menu.dart';
import 'lab_purity_dialog.dart';
import '../../../core/analytics_service.dart';
import 'store_category_mega_menu.dart';
import 'store_search_dropdown_overlay.dart';
import '../../../core/storage.dart';
export 'store_category_mega_menu.dart';
export 'store_search_dropdown_overlay.dart';
export '../../../app/store_theme.dart';

// Natural Earth Palette for MILTERRA Earth
const storeEarthDarkGreen = Color(0xff1e3a2b);
const storeEarthCream = Color(0xfff9f7f2);
const storeEarthWarmBrown = Color(0xff6e4a27);
const storeEarthTerracotta = Color(0xffc86d51);
const storeEarthSage = Color(0xffe8ede4);

String storeMoney(double amount) => NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: amount % 1 == 0 ? 0 : 2)
    .format(amount);

class StorePanel extends StatelessWidget {
  const StorePanel({super.key, required this.child, this.title});
  final Widget child;
  final String? title;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: StoreLayout.panelPadding,
      decoration: StoreLayout.panel,
      child: Material(
          color: storeWhite,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Text(title!, style: StoreType.title),
              StoreLayout.panelGap
            ],
            child,
          ])));
}

String storeCategory(Product p) {
  if (p.taxonomy?['category_name'] != null) {
    return p.taxonomy!['category_name'].toString();
  }
  if (p.taxonomyEnabled) return 'Uncategorized';
  final name =
      '${p.title} ${p.taxonomy?['subcategory_name'] ?? ''} ${p.taxonomy?['category_name'] ?? ''} ${p.taxonomy?['department_name'] ?? ''}'
          .toLowerCase();
  if (p.category == ProductCategory.equipment) return 'Equipment';
  if (name.contains('feed') ||
      name.contains('pellet') ||
      name.contains('mineral') ||
      name.contains('calcium') ||
      name.contains('fat') ||
      name.contains('seed') ||
      name.contains('rumen') ||
      name.contains('janam') ||
      name.contains('nutrition') ||
      name.contains('supplement') ||
      name.contains('cattle') ||
      p.category == ProductCategory.feedNutrition && p.isConcept) {
    return 'Animal nutrition';
  }
  if (name.contains('sarso') ||
      name.contains('mustard') ||
      name.contains('til oil') ||
      name.contains('sesame') ||
      name.contains('kachi ghani') ||
      (name.contains('oil') &&
          !name.contains('ghee') &&
          !name.contains('soil'))) {
    return 'Cold-Pressed Sarso (Mustard) Oil';
  }
  if (name.contains('agarbatti') ||
      name.contains('dhoop') ||
      name.contains('incense') ||
      name.contains('loban') ||
      name.contains('guggal') ||
      name.contains('sambrani')) {
    return 'Natural Agarbatti & Dhoop';
  }
  if (name.contains('hawan') ||
      name.contains('yajna') ||
      name.contains('puja') ||
      name.contains('diya') ||
      name.contains('deepam') ||
      name.contains('samidha') ||
      name.contains('camphor') ||
      name.contains('kapoor') ||
      (name.contains('kanda') &&
          !name.contains('vermicompost') &&
          !name.contains('manure') &&
          !name.contains('compost'))) {
    return 'Puja & Hawan Samagri';
  }
  if (p.taxonomy?['is_earth'] == true ||
      name.contains('earth') ||
      name.contains('vermicompost') ||
      name.contains('manure') ||
      name.contains('compost') ||
      name.contains('soil mix') ||
      name.contains('khad')) {
    return 'Vermicompost & Living Soil';
  }
  if (name.contains('milk') ||
      name.contains('doodh') ||
      name.contains('chhachh') ||
      name.contains('chaas') ||
      name.contains('buttermilk') ||
      name.contains('paneer') ||
      name.contains('butter') ||
      name.contains('makhan') ||
      name.contains('dahi') ||
      name.contains('curd')) {
    return 'Fresh Milk & Dairy';
  }
  if (name.contains('tulsi') ||
      name.contains('brahmi') ||
      name.contains('ashwagandha') ||
      (name.contains('ghee') && name.contains('herbal'))) {
    return 'Herbal Ghee';
  }
  if (name.contains('ghee') && name.contains('buffalo')) return 'Buffalo ghee';
  if (name.contains('ghee')) return 'Cow ghee';
  if (name.contains('milking') ||
      name.contains('milker') ||
      name.contains('analyzer') ||
      name.contains('cutter') ||
      name.contains('chaff') ||
      name.contains('can') ||
      name.contains('mat') ||
      name.contains('machine')) {
    return 'Equipment';
  }
  return 'Other products';
}

void storeAccountRoute(
    BuildContext context, WidgetRef ref, String destination) {
  if (ref.read(currentUserProvider) == null) {
    context.go(
        Uri(path: '/login', queryParameters: {'next': destination}).toString());
  } else {
    context.push(destination);
  }
}

void storeBackToShop(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/shop');
  }
}

void storeBrowse(BuildContext context,
        {String? category, String? query, String? sort}) =>
    context.go(Uri(path: '/shop', queryParameters: {
      if (category != null &&
          category != 'All products' &&
          category != 'All' &&
          category != 'All Organic Essentials')
        'category': category,
      if (query != null && query.isNotEmpty) 'query': query,
      if (sort != null && sort.isNotEmpty) 'sort': sort,
    }).toString());

/// Rating stars component mimicking Amazon's 5-star customer rating presentation.
class AmazonRatingStars extends StatelessWidget {
  const AmazonRatingStars({
    super.key,
    this.rating = 0,
    this.reviewCount = 0,
    this.size = 14,
    this.showCount = true,
    this.interactive = false,
    this.onTap,
  });

  final double rating;
  final int reviewCount;
  final double size;
  final bool showCount;
  final bool interactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (reviewCount <= 0 || rating <= 0) return const SizedBox.shrink();
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.4;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Icon(
              i < fullStars
                  ? Icons.star_rate_rounded
                  : (i == fullStars && hasHalf
                      ? Icons.star_half_rounded
                      : Icons.star_border_rounded),
              color: storeAmber,
              size: size,
            ),
          ),
        ),
        if (showCount) ...[
          const SizedBox(width: 4),
          Text(
            NumberFormat.compact().format(reviewCount),
            style: TextStyle(
              fontSize: size * 0.85,
              fontWeight: FontWeight.w600,
              color: const Color(0xff007185),
            ),
          ),
        ],
      ],
    );

    if (interactive && onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Department Mega Menu / Slide-over Drawer
void showAmazonDepartmentDrawer(BuildContext context) {
  showCategoryDepartmentMenu(context);
}

/// Global state provider for user-selected delivery location
final selectedDeliveryLocationProvider =
    StateProvider<String>((ref) => 'New Delhi 110001');

/// Amazon-style Comprehensive Header
class StoreHeader extends ConsumerStatefulWidget {
  const StoreHeader({
    super.key,
    this.search,
    this.currentCategory,
    this.initialSearch = '',
    this.searchHint,
    this.isFarmerHub = false,
  });
  final Widget? search;
  final String? currentCategory;
  final String initialSearch;
  final String? searchHint;
  final bool isFarmerHub;

  @override
  ConsumerState<StoreHeader> createState() => _StoreHeaderState();
}

class _StoreHeaderState extends ConsumerState<StoreHeader>
    with WidgetsBindingObserver {
  late final TextEditingController _searchCtrl;
  String _selectedCategory = 'All';

  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _searchBarKey = GlobalKey();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _searchOverlayEntry;
  List<String> _recentSearches = const [
    'A2 Sahiwal Cow Ghee',
    'Lakdi Ghani Mustard Oil',
    'Raw Mustard Honey',
    'Fresh Malai Paneer',
  ];

  static String _normalizeCategory(String? cat) {
    if (cat == null || cat.trim().isEmpty) return 'All';
    final trimmed = cat.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'all' ||
        lower == 'all products' ||
        lower == 'all categories' ||
        lower == 'all departments') {
      return 'All';
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchCtrl = TextEditingController(text: widget.initialSearch);
    _selectedCategory = _normalizeCategory(widget.currentCategory);
    _searchFocusNode.addListener(_onSearchFocusChange);
    _loadRecentSearches();
  }

  @override
  void didChangeMetrics() {
    if (_searchOverlayEntry != null) {
      _closeSearchOverlay();
    }
  }

  @override
  void didUpdateWidget(covariant StoreHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSearch != widget.initialSearch &&
        _searchCtrl.text != widget.initialSearch) {
      _searchCtrl.text = widget.initialSearch;
    }
    if (oldWidget.currentCategory != widget.currentCategory) {
      setState(() {
        _selectedCategory = _normalizeCategory(widget.currentCategory);
      });
    }
  }

  @override
  void deactivate() {
    _closeSearchOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeSearchOverlay();
    _searchFocusNode.removeListener(_onSearchFocusChange);
    _searchFocusNode.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final saved =
          await ref.read(secureStorageServiceProvider).getRecentSearches();
      if (saved.isNotEmpty && mounted) {
        setState(() {
          _recentSearches = saved;
        });
      }
    } catch (_) {}
  }

  Future<void> _addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final updated = [
      trimmed,
      ..._recentSearches.where((s) => s.toLowerCase() != trimmed.toLowerCase())
    ].take(10).toList();
    if (mounted) {
      setState(() {
        _recentSearches = updated;
      });
    }
    try {
      await ref.read(secureStorageServiceProvider).setRecentSearches(updated);
    } catch (_) {}
  }

  Future<void> _removeRecentSearch(String query) async {
    final updated = _recentSearches.where((s) => s != query).toList();
    setState(() {
      _recentSearches = updated;
    });
    try {
      await ref.read(secureStorageServiceProvider).setRecentSearches(updated);
    } catch (_) {}
  }

  Future<void> _clearAllRecentSearches() async {
    setState(() {
      _recentSearches = const [];
    });
    try {
      await ref.read(secureStorageServiceProvider).setRecentSearches(const []);
    } catch (_) {}
  }

  void _onSearchFocusChange() {
    if (_searchFocusNode.hasFocus) {
      _openSearchOverlay();
    }
  }

  void _openSearchOverlay() {
    if (_searchOverlayEntry != null || !mounted) return;
    _searchOverlayEntry = OverlayEntry(
      builder: (ctx) => StoreSearchDropdownOverlay(
        headerKey: _headerKey,
        searchBarKey: _searchBarKey,
        searchController: _searchCtrl,
        searchFocusNode: _searchFocusNode,
        recentSearches: _recentSearches,
        onRemoveRecent: (item) {
          _removeRecentSearch(item);
          _searchOverlayEntry?.markNeedsBuild();
        },
        onClearAllRecent: () {
          _clearAllRecentSearches();
          _searchOverlayEntry?.markNeedsBuild();
        },
        onSelectQuery: (query) {
          _searchCtrl.text = query;
          _addRecentSearch(query);
          _closeSearchOverlay();
          _triggerSearch();
        },
        onSelectProduct: (productId) {
          _closeSearchOverlay();
          _searchFocusNode.unfocus();
          context.push('/shop/product/$productId');
        },
        onClose: () {
          _searchFocusNode.unfocus();
          _closeSearchOverlay();
        },
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_searchOverlayEntry!);
    if (mounted) setState(() {});
  }

  void _closeSearchOverlay() {
    if (_searchOverlayEntry != null) {
      _searchOverlayEntry?.remove();
      _searchOverlayEntry = null;
      if (mounted) setState(() {});
    }
  }

  void _triggerSearch() {
    final query = _searchCtrl.text.trim();
    final effectiveCat = _normalizeCategory(_selectedCategory);
    if (query.isNotEmpty) {
      _addRecentSearch(query);
      ref.read(analyticsServiceProvider).trackSearch(query, 0);
    }
    _closeSearchOverlay();
    _searchFocusNode.unfocus();
    storeBrowse(
      context,
      category: effectiveCat == 'All' ||
              effectiveCat == 'All Organic Essentials' ||
              effectiveCat == 'All Departments'
          ? null
          : effectiveCat,
      query: query.isEmpty ? null : query,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final count = ref.watch(cartItemCountProvider);
    final wishlistCount = ref.watch(wishlistItemCountProvider);
    final location = ref.watch(selectedDeliveryLocationProvider);
    final userRole = (user?.role ?? '').trim().toLowerCase();
    final canAdmin = user != null &&
        (userRole == 'admin' ||
            userRole == 'super_admin' ||
            ref.watch(commerceAccessProvider).valueOrNull?['can_manage_taxonomy'] ==
                true);

    return Container(
      key: _headerKey,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xfff0eee9), width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, bounds) {
          final isMobile = bounds.maxWidth < StoreLayout.tablet;
          final isCompact = bounds.maxWidth < 1100;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Pre-launch Official Announcement Banner Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xfffffbeb),
                  border: Border(bottom: BorderSide(color: Color(0xfffef3c7), width: 1)),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xffb45309), size: 15),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'OFFICIAL LAUNCH IN JANUARY 2027  ·  Explore our product range. Live orders begin at official launch.',
                          style: TextStyle(
                            fontSize: isMobile ? 10.5 : 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xff92400e),
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: isMobile ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Top Main Amazon Header Row
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 20,
                  vertical: 6,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Logo
                    InkWell(
                      onTap: () => context.go('/shop'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'assets/store/milterra-heritage-badge.jpg',
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.spa_outlined,
                                    color: storeGold,
                                    size: 22),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'milterrafoods',
                              style: StoreType.logo.copyWith(
                                color: const Color(0xff1b4d3e),
                                fontSize: isMobile ? 22 : 25,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                  '.com',
                                  style: TextStyle(
                                      color: Color(0xffc27803),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Amazon-Style Delivery Pincode Widget (Desktop / Tablet)
                    if (!isMobile) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _showLocationSelector(context),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  color: Color(0xff1f2937), size: 20),
                              const SizedBox(width: 4),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user != null
                                        ? 'Deliver to ${user.name?.split(' ').first}'
                                        : 'Deliver to',
                                    style: const TextStyle(
                                      color: Color(0xff6b7280),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.1,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        location,
                                        style: const TextStyle(
                                          color: Color(0xff111827),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down,
                                          color: Color(0xff6b7280), size: 14),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Storefront Search Box (Desktop / Tablet)
                    if (!isMobile) ...[
                      const SizedBox(width: 20),
                      Expanded(
                        child: widget.search ??
                            _buildStoreSearchBar(barKey: _searchBarKey),
                      ),
                      const SizedBox(width: 20),
                    ] else ...[
                      const Spacer(),
                    ],

                    StoreAccountMenu(
                      compact: isCompact,
                      signedIn: user != null,
                      firstName: user?.name?.split(' ').first ?? 'Customer',
                      cartCount: count,
                      wishlistCount: wishlistCount,
                      isAdmin: canAdmin,
                      onNavigate: (destination) {
                        if (destination.startsWith('/login') ||
                            destination.startsWith('/register') ||
                            destination == '/shop' ||
                            destination == '/shop/deals') {
                          context.go(destination);
                        } else {
                          storeAccountRoute(context, ref, destination);
                        }
                      },
                      onSignOut: () async {
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/shop');
                      },
                    ),

                    // Admin Button (if authorized)
                    if (canAdmin) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Commerce Fulfillment & Orders',
                        onPressed: () => context.go('/admin/commerce/orders'),
                        icon: const Icon(Icons.admin_panel_settings_outlined,
                            color: Color(0xffb45309), size: 22),
                      ),
                    ],

                    // Wishlist
                    InkWell(
                      onTap: () => context.go('/wishlist'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: wishlistCount > 0,
                              label: Text('$wishlistCount',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                              backgroundColor: storeAmberDark,
                              textColor: storeWhite,
                              offset: const Offset(8, -6),
                              child: const Icon(
                                Icons.favorite_border,
                                color: Color(0xff1f2937),
                                size: 24,
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 6),
                              const Text('Wishlist',
                                  style: StoreType.amazonBottomLine),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Shopping Cart
                    InkWell(
                      onTap: () => showStoreCart(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: count > 0,
                              label: Text('$count',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11)),
                              backgroundColor: storeAmberDark,
                              textColor: storeWhite,
                              offset: const Offset(8, -6),
                              child: const Icon(
                                Icons.shopping_cart_outlined,
                                color: Color(0xff1f2937),
                                size: 26,
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 6),
                              const Text('Cart',
                                  style: StoreType.amazonBottomLine),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mobile Search Bar & Location Strip (Below Logo row on small screens)
              if (isMobile) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: widget.search ??
                      _buildStoreSearchBar(barKey: _searchBarKey),
                ),
                InkWell(
                  onTap: () => _showLocationSelector(context),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xfffaf8f5),
                      border: Border(
                        top: BorderSide(color: Color(0xfff0eee9), width: 1),
                        bottom: BorderSide(color: Color(0xffeae7e0), width: 1),
                      ),
                    ),
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: Color(0xff4b5563), size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Deliver to $location ▾',
                            style: const TextStyle(
                              color: Color(0xff1f2937),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  void _showLocationSelector(BuildContext context) {
    showPincodeSelectorDialog(context, ref);
  }

  Widget _buildStoreSearchBar({Key? barKey}) {
    return Container(
      key: barKey,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xfff4f6f8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 13),
          const Icon(
            Icons.search,
            color: Color(0xff9ca3af),
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: const ValueKey('store-search-field'),
              focusNode: _searchFocusNode,
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onTap: _openSearchOverlay,
              onSubmitted: (_) => _triggerSearch(),
              style: const TextStyle(fontSize: 13.5, color: Color(0xff111827)),
              decoration: InputDecoration(
                hintText: widget.searchHint ??
                    'Search for products & brands...',
                hintStyle:
                    const TextStyle(color: Color(0xff9ca3af), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: Color(0xff9ca3af)),
                        splashRadius: 16,
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                          if (_searchOverlayEntry != null) {
                            _searchOverlayEntry?.markNeedsBuild();
                          }
                        },
                      )
                    : null,
              ),
              onChanged: (_) {
                setState(() {});
                if (_searchOverlayEntry == null && _searchFocusNode.hasFocus) {
                  _openSearchOverlay();
                } else if (_searchOverlayEntry != null) {
                  _searchOverlayEntry?.markNeedsBuild();
                }
              },
            ),
          ),
          // Amazon-style Yellow / Amber Search Action Button
          Material(
            color: const Color(0xfffebd69),
            child: InkWell(
              onTap: _triggerSearch,
              hoverColor: const Color(0xfff3a847),
              child: const Tooltip(
                message: 'Search',
                child: SizedBox(
                  width: 44,
                  height: 42,
                  child: Icon(
                    Icons.search,
                    color: Color(0xff111827),
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sub-Navigation Bar with "Shop By Category" hover & tap drawer and quick links
class StoreCategoryNavigation extends ConsumerStatefulWidget {
  const StoreCategoryNavigation({
    super.key,
    this.selected = 'All products',
    this.onSelected,
    this.onOurStoryPressed,
    this.legacyEquipment = false,
    this.qualityProduct,
  });

  final String selected;
  final ValueChanged<String>? onSelected;
  final VoidCallback? onOurStoryPressed;
  final bool legacyEquipment;
  final Product? qualityProduct;

  @override
  ConsumerState<StoreCategoryNavigation> createState() =>
      _StoreCategoryNavigationState();
}

class _StoreCategoryNavigationState
    extends ConsumerState<StoreCategoryNavigation> {
  final GlobalKey _categoryButtonKey = GlobalKey();
  OverlayEntry? _categoryMenuOverlay;
  Timer? _closeTimer;
  bool _isButtonHovered = false;
  bool _isMenuHovered = false;

  @override
  void deactivate() {
    _closeCategoryMenu();
    super.deactivate();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _closeCategoryMenu();
    super.dispose();
  }

  void _openCategoryMenu() {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 880) return; // On mobile, tap opens the slide drawer

    _closeTimer?.cancel();
    if (_categoryMenuOverlay != null) return;

    final buttonBox =
        _categoryButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final buttonOffset =
        buttonBox?.localToGlobal(Offset.zero) ?? const Offset(16, 106);
    final buttonSize = buttonBox?.size ?? const Size(160, 36);

    _categoryMenuOverlay = OverlayEntry(
      builder: (ctx) => CategoryMegaMenuOverlay(
        anchorOffset: buttonOffset,
        anchorSize: buttonSize,
        onClose: _closeCategoryMenu,
        onHoverEnter: () {
          _isMenuHovered = true;
          _cancelCloseCategoryMenu();
        },
        onHoverExit: () {
          _isMenuHovered = false;
          _scheduleCloseCategoryMenu();
        },
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_categoryMenuOverlay!);
    if (mounted) setState(() {});
  }

  void _scheduleCloseCategoryMenu() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isButtonHovered && !_isMenuHovered) {
        _closeCategoryMenu();
      }
    });
  }

  void _cancelCloseCategoryMenu() {
    _closeTimer?.cancel();
  }

  void _closeCategoryMenu() {
    _closeTimer?.cancel();
    if (_categoryMenuOverlay != null) {
      _categoryMenuOverlay?.remove();
      _categoryMenuOverlay = null;
      if (mounted) setState(() {});
    }
  }

  void _toggleCategoryMenu() {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 880) {
      showCategoryDepartmentMenu(context);
    } else {
      if (_categoryMenuOverlay != null) {
        _closeCategoryMenu();
      } else {
        _openCategoryMenu();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xfff0eee9), width: 1)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // "Shop By Category" Hover & Tap Dropdown Trigger Button
                MouseRegion(
                  onEnter: (_) {
                    _isButtonHovered = true;
                    if (mounted) setState(() {});
                    _openCategoryMenu();
                  },
                  onExit: (_) {
                    _isButtonHovered = false;
                    if (mounted) setState(() {});
                    _scheduleCloseCategoryMenu();
                  },
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    key: _categoryButtonKey,
                    onTap: _toggleCategoryMenu,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: (_isButtonHovered || _categoryMenuOverlay != null)
                            ? const Color(0xfff0fdf4)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (_isButtonHovered || _categoryMenuOverlay != null)
                              ? const Color(0xff0d9488)
                              : const Color(0xffd1d5db),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.menu,
                              color: Color(0xff0d9488), size: 17),
                          const SizedBox(width: 7),
                          const Text(
                            'Shop By Category',
                            style: TextStyle(
                              color: Color(0xff1f2937),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _categoryMenuOverlay != null
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: const Color(0xff64748b),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Quick Navigation Links (horizontal links)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildQuickLink(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xfff59e0b),
                          label: 'Best Sellers',
                          onTap: () => storeBrowse(context, sort: 'Best Sellers'),
                        ),
                        _buildQuickLink(
                          icon: Icons.spa_outlined,
                          iconColor: const Color(0xff166534),
                          label: 'Our Farm Story',
                          onTap: () {
                            if (widget.onOurStoryPressed != null) {
                              widget.onOurStoryPressed!();
                            } else {
                              context.push('/about');
                            }
                          },
                        ),
                        _buildQuickLink(
                          icon: Icons.science_outlined,
                          iconColor: const Color(0xff0284c7),
                          label: 'Lab Reports (NABL)',
                          onTap: () => showLabPurityDialog(context),
                        ),
                        _buildQuickLink(
                          icon: Icons.card_giftcard_rounded,
                          iconColor: const Color(0xffd97706),
                          label: 'Curated Boxes',
                          onTap: () => storeBrowse(context,
                              category: 'Curated Kitchen & Wellness Boxes'),
                        ),
                        _buildQuickLink(
                          icon: Icons.chat_bubble_outline_rounded,
                          iconColor: const Color(0xff059669),
                          label: 'Customer Support',
                          onTap: () => context.push('/contact'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLink({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xff374151),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AmazonQuadItem {
  const AmazonQuadItem({
    required this.label,
    this.image,
    this.icon,
    required this.onTap,
  });
  final String label;
  final String? image;
  final IconData? icon;
  final VoidCallback onTap;
}

/// Amazon-style 4-Quadrant Category Feature Card for homepage grid
class AmazonDepartmentQuadCard extends StatelessWidget {
  const AmazonDepartmentQuadCard({
    super.key,
    required this.title,
    required this.actionText,
    required this.onActionTap,
    required this.items,
  });

  final String title;
  final String actionText;
  final VoidCallback onActionTap;
  final List<AmazonQuadItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xff0f1111),
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // 2x2 Quadrant Grid
          Expanded(
            child: items.length < 4
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _quadTile(items[0])),
                            const SizedBox(width: 10),
                            Expanded(child: _quadTile(items[1])),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _quadTile(items[2])),
                            const SizedBox(width: 10),
                            Expanded(child: _quadTile(items[3])),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onActionTap,
            child: Text(
              actionText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xff007185),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quadTile(AmazonQuadItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xfff5f3ec),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(6),
              child: item.image != null
                  ? Image.asset(item.image!, fit: BoxFit.contain)
                  : Icon(item.icon ?? Icons.category_outlined,
                      color: storeGreen, size: 28),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xff111111),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

abstract final class StoreImages {
  static const hero = 'assets/store/hero.png';
  static String? category(String kind) => switch (kind.toLowerCase()) {
        'cow ghee' || 'cow-ghee' => 'assets/store/cow-ghee.png',
        'buffalo ghee' || 'buffalo-ghee' => 'assets/store/buffalo-ghee.png',
        'herbal ghee' ||
        'herbal-ghee' =>
          'assets/store/milterra-tulsi-ghee.webp',
        'paneer' => 'assets/store/paneer.png',
        'white butter' ||
        'other products' =>
          'assets/store/white-butter-concept.png',
        'janam-42' || 'janam' => 'assets/store/feed-janam-42.jpg',
        'minera-360' ||
        'mineral' ||
        'mineral supplement' =>
          'assets/store/minera-360-jar.jpg',
        'bovine gold' ||
        'cattle feed' ||
        'feed pellets' ||
        'pashu aahar' =>
          'assets/store/feed-bovine-gold.jpg',
        'bypass fat' || 'lacto-energy' => 'assets/store/feed-bypass-fat.jpg',
        'calci-boost' || 'calcium' => 'assets/store/calci-feed-combo.jpg',
        'animal nutrition' ||
        'cattle nutrition' =>
          'assets/store/nutrition-lineup.jpg',
        'milterra earth' ||
        'earth' ||
        'vermicompost' =>
          'assets/store/earth-vermicompost.jpg',
        'manure' || 'farm manure' => 'assets/store/earth-manure.jpg',
        'soil mix' || 'garden soil' => 'assets/store/earth-soil-mix.jpg',
        'compost cakes' || 'cakes' => 'assets/store/earth-cakes.jpg',
        'hawan & yajna ghee' ||
        'hawan ghee' ||
        'yajna ghee' =>
          'assets/store/cow-ghee.png',
        'cow dung sacred products' ||
        'cow dung cakes' ||
        'hawan kanda' ||
        'diya' ||
        'diyas' =>
          'assets/store/earth-cakes.jpg',
        'natural dhoop & agarbatti' ||
        'dhoop' ||
        'agarbatti' =>
          'assets/store/milterra-tulsi-ghee.webp',
        'bhimseni kapoor & samagri' ||
        'bhimseni kapoor' ||
        'kapoor' ||
        'camphor' ||
        'hawan samagri' =>
          'assets/store/farm-bilona.jpg',
        'puja & hawan samagri' ||
        'puja samagri' ||
        'puja' ||
        'hawan' =>
          'assets/store/earth-cakes.jpg',
        'equipment' ||
        'farm equipment' ||
        'farm machinery' ||
        'dairy equipment' =>
          'assets/store/equipment-milker.jpg',
        'milking machine' || 'milker' => 'assets/store/equipment-milker.jpg',
        'milk analyzer' || 'ultrascan' => 'assets/store/equipment-analyzer.jpg',
        'chaff cutter' ||
        'fodder cutter' =>
          'assets/store/equipment-chaff-cutter.jpg',
        'milk can' => 'assets/store/equipment-milk-can.jpg',
        'cow mat' || 'rubber mat' => 'assets/store/equipment-cow-mat.jpg',
        _ => null,
      };

  static String? productArtwork(Product? p) {
    if (p == null) return null;
    if (p.media.isNotEmpty && p.media.first.startsWith('assets/')) {
      return p.media.first;
    }
    final title = p.title.toLowerCase();
    final pack = (p.packSize ?? '').toLowerCase();

    // 1. Tin containers ("tin dabba" / 2L rectangular tin / 5L metal canisters)
    final isTin = title.contains('tin') ||
        title.contains('dabba') ||
        title.contains('canister') ||
        pack.contains('tin');
    final is2L = title.contains('2000') ||
        title.contains('2 litre') ||
        title.contains('2l') ||
        pack.contains('2000') ||
        pack.contains('2 litre') ||
        pack.contains('2 l');
    final is5L = title.contains('5000') ||
        title.contains('5 litre') ||
        title.contains('5l') ||
        pack.contains('5000') ||
        pack.contains('5 litre') ||
        pack.contains('5 l');

    if (isTin || is2L || is5L) {
      if (title.contains('mustard') || title.contains('sarso')) {
        if (is2L) {
          return 'assets/store/mustard-oil-tin-2l.jpg';
        }
        return 'assets/store/mustard-oil-tin-5l.jpg';
      }
      if (title.contains('peanut') || title.contains('groundnut')) {
        return 'assets/store/peanut-oil-tin-5l.jpg';
      }
      if (title.contains('ghee')) {
        return 'assets/store/ghee-tin-5l.jpg';
      }
    }

    // 3. Fresh Farm Milk & Dairy
    if (title.contains('milk') || title.contains('doodh')) {
      if (title.contains('buffalo') || title.contains('murrah')) {
        return 'assets/store/milk-buffalo-bottle-1l.jpg';
      }
      return 'assets/store/milk-cow-bottle-1l.jpg';
    }
    if (title.contains('paneer')) {
      return 'assets/store/paneer.png';
    }
    if (title.contains('butter') || title.contains('makhan')) {
      return 'assets/store/white-butter-concept.png';
    }
    if (title.contains('chhachh') ||
        title.contains('chaas') ||
        title.contains('mattha') ||
        title.contains('buttermilk')) {
      return 'assets/store/farm-pasture.jpg';
    }

    // 4. Curd Chillies & Dhoop
    if (title.contains('mor milagai') ||
        title.contains('curd chilli') ||
        title.contains('curd chillies')) {
      return 'assets/store/curd-chillies.jpg';
    }
    if (title.contains('dhoop') ||
        title.contains('agarbatti') ||
        title.contains('incense')) {
      return 'assets/store/panchagavya-dhoop.jpg';
    }
    if (title.contains('shata') || title.contains('washed ghee')) {
      return 'assets/store/shata-dhauta-ghrita.jpg';
    }

    // 5. Ghee Varieties by size, process & infusion
    if (title.contains('ghee') || title.contains('ghrita')) {
      if (title.contains('single-farm') || title.contains('single farm')) {
        return 'assets/store/ghee-single-farm.jpg';
      }
      if (title.contains('full moon') ||
          title.contains('purnima') ||
          title.contains('moon')) {
        return 'assets/store/ghee-full-moon.jpg';
      }
      if (title.contains('hawan') || title.contains('yajna')) {
        return 'assets/store/hawan-ghee-1l.jpg';
      }
      if (title.contains('tulsi')) {
        return 'assets/store/milterra-tulsi-ghee.webp';
      }
      if (title.contains('brahmi')) {
        return 'assets/store/milterra-brahmi-ghee.webp';
      }
      if (title.contains('ashwa')) {
        return 'assets/store/milterra-ashwagandha-ghee.webp';
      }
      if (title.contains('buffalo') || title.contains('murrah')) {
        return 'assets/store/buffalo-ghee.png';
      }
      if (title.contains('250') ||
          title.contains('trial') ||
          pack.contains('250')) {
        return 'assets/store/ghee-jar-250ml.jpg';
      }
      if (title.contains('1000') ||
          title.contains('1 litre') ||
          title.contains('1l') ||
          title.contains('kitchen jar') ||
          pack.contains('1000') ||
          pack.contains('1 litre') ||
          pack.contains('1 l')) {
        return 'assets/store/ghee-jar-1l.jpg';
      }
      if (title.contains('500') || pack.contains('500')) {
        return 'assets/store/ghee-jar-500ml.jpg';
      }
      return 'assets/store/ghee-jar-500ml.jpg';
    }

    final isEarth = p.taxonomy?['is_earth'] == true ||
        title.contains('earth') ||
        title.contains('vermicompost') ||
        title.contains('farm manure');

    if (isEarth) {
      if (title.contains('vermicompost')) {
        return 'assets/store/earth-vermicompost.jpg';
      }
      if (title.contains('manure')) {
        return 'assets/store/earth-manure.jpg';
      }
      if (title.contains('soil mix') || title.contains('soil')) {
        return 'assets/store/earth-soil-mix.jpg';
      }
      if (title.contains('cake')) {
        return 'assets/store/earth-cakes.jpg';
      }
      if (title.contains('starter') || title.contains('compost')) {
        return 'assets/store/earth-vermicompost.jpg';
      }
      return 'assets/store/earth-vermicompost.jpg';
    }

    final isSacred = p.taxonomy?['is_sacred'] == true ||
        p.taxonomy?['department_name'] == 'Puja & Hawan Samagri' ||
        title.contains('hawan') ||
        title.contains('kanda') ||
        title.contains('kapoor') ||
        title.contains('camphor') ||
        title.contains('diya');
    if (isSacred) {
      if (title.contains('kanda') ||
          title.contains('uple') ||
          title.contains('diya')) {
        return 'assets/store/earth-cakes.jpg';
      }
      if (title.contains('kapoor') || title.contains('camphor')) {
        return 'assets/store/farm-bilona.jpg';
      }
      if (title.contains('samagri')) {
        return 'assets/store/hawan-ghee-1l.jpg';
      }
      return 'assets/store/earth-cakes.jpg';
    }

    if (title.contains('milking') || title.contains('milker')) {
      return 'assets/store/equipment-milker.jpg';
    }
    if (title.contains('analyzer') || title.contains('ultrascan')) {
      return 'assets/store/equipment-analyzer.jpg';
    }
    if (title.contains('chaff') ||
        title.contains('cutter') ||
        title.contains('fodder cutter')) {
      return 'assets/store/equipment-chaff-cutter.jpg';
    }
    if (title.contains('can') || title.contains('milk can')) {
      return 'assets/store/equipment-milk-can.jpg';
    }
    if (title.contains('mat') ||
        title.contains('rubber mat') ||
        title.contains('comfort mat')) {
      return 'assets/store/equipment-cow-mat.jpg';
    }

    if (title.contains('janam')) return 'assets/store/feed-janam-42.jpg';
    if (title.contains('bovine gold') ||
        (title.contains('pellet') && title.contains('feed'))) {
      return 'assets/store/feed-bovine-gold.jpg';
    }
    if (title.contains('bypass fat') || title.contains('lacto-energy')) {
      return 'assets/store/feed-bypass-fat.jpg';
    }
    if (title.contains('minera-360') ||
        title.contains('mineral supplement') ||
        title.contains('mineral')) {
      return 'assets/store/minera-360-jar.jpg';
    }
    if (title.contains('calci-') ||
        title.contains('calcium') ||
        title.contains('cal-gold')) {
      return 'assets/store/calci-feed-combo.jpg';
    }
    if (title.contains('lacta') ||
        title.contains('rumen') ||
        title.contains('heat') ||
        title.contains('digest') ||
        title.contains('vitagrow') ||
        title.contains('milk-pro')) {
      return 'assets/store/nutrition-lineup.jpg';
    }

    // 1. Fresh Living Microgreens
    if (title.contains('microgreen') ||
        title.contains('punnet') ||
        title.contains('shoots') ||
        title.contains('radish micro') ||
        title.contains('sunflower micro') ||
        title.contains('broccoli')) {
      return 'assets/store/live-microgreens.jpg';
    }

    // 2. Wood-Pressed Cooking Oils
    if ((title.contains('sarso') ||
            title.contains('mustard') ||
            title.contains('til') ||
            title.contains('sesame') ||
            title.contains('groundnut') ||
            title.contains('peanut') ||
            title.contains('kacchi ghani') ||
            title.contains('lakdi ghani') ||
            (title.contains('oil') && !title.contains('soil'))) &&
        !title.contains('microgreen')) {
      if (is2L) {
        return 'assets/store/mustard-oil-tin-2l.jpg';
      }
      if (is5L) {
        return 'assets/store/mustard-oil-tin-5l.jpg';
      }
      return 'assets/store/sarso-oil.jpg';
    }

    // 3. Ancient Grains, Flours & Sattu
    if (title.contains('khapli') ||
        title.contains('sharbati') ||
        title.contains('atta')) {
      return 'assets/store/khapli-atta.jpg';
    }
    if (title.contains('millet') ||
        title.contains('sattu') ||
        title.contains('flour')) {
      return 'assets/store/nutrition-lineup.jpg';
    }

    // 4. Raw Honey & Heritage Sweeteners
    if (title.contains('honey')) {
      return 'assets/store/raw-mustard-honey.jpg';
    }
    if (title.contains('gur') ||
        title.contains('jaggery') ||
        title.contains('khand') ||
        title.contains('mishri') ||
        title.contains('sugar')) {
      return 'assets/store/organic-gur.jpg';
    }

    // 5. Mineral Salts & Native Spices
    if (title.contains('salt') ||
        title.contains('sendha') ||
        title.contains('namak')) {
      return 'assets/store/himalayan-pink-salt.jpg';
    }
    if (title.contains('haldi') ||
        title.contains('turmeric') ||
        title.contains('curcumin') ||
        title.contains('lakadong') ||
        title.contains('ubtan')) {
      return 'assets/store/lakadong-turmeric.jpg';
    }
    if (title.contains('jeera') || title.contains('cumin')) {
      return 'assets/store/jeera-seeds.jpg';
    }
    if (title.contains('dhania') || title.contains('coriander')) {
      return 'assets/store/dhania-seeds.jpg';
    }
    if (title.contains('mathania') || title.contains('chilli')) {
      return 'assets/store/mathania-chilli.jpg';
    }
    if (title.contains('spice')) {
      return 'assets/store/lakadong-turmeric.jpg';
    }

    // 6. Vedic Skincare & Soaps
    if (title.contains('soap') || title.contains('goat milk')) {
      return 'assets/store/goat-milk-soap.jpg';
    }
    if (title.contains('shata dhauta') ||
        title.contains('washed ghee') ||
        title.contains('moisturizer')) {
      return 'assets/store/shata-dhauta-ghrita.jpg';
    }

    // 7. Pure Aloe Vera Botanicals
    if (title.contains('aloe') || title.contains('ghritkumari')) {
      if (title.contains('juice') ||
          title.contains('amla') ||
          title.contains('tonic') ||
          title.contains('drink')) {
        return 'assets/store/aloe-vera-juice.jpg';
      }
      return 'assets/store/aloe-vera-gel.jpg';
    }

    // 8. Balcony Soil, Potting Mix & Garden Seed Kits
    if (title.contains('vermicompost')) {
      return 'assets/store/earth-vermicompost.jpg';
    }
    if (title.contains('spray') ||
        title.contains('bio-fungicide') ||
        title.contains('tamba chhachh')) {
      return 'assets/store/earth-cakes.jpg';
    }
    if (title.contains('potting') ||
        title.contains('booster') ||
        title.contains('balcony') ||
        title.contains('heirloom') ||
        title.contains('seed kit') ||
        title.contains('5-in-1') ||
        title.contains('soil mix') ||
        title.contains('potted') ||
        title.contains('plant')) {
      return 'assets/store/earth-soil-mix.jpg';
    }

    // 9. Combos & Starter Boxes
    if (title.contains('box') ||
        title.contains('kit') ||
        title.contains('combo') ||
        title.contains('duo') ||
        title.contains('starter') ||
        title.contains('wellness') ||
        title.contains('trio')) {
      return 'assets/store/hero.png';
    }
    if (title.contains('mattha') ||
        title.contains('chaas') ||
        title.contains('buttermilk')) {
      return 'assets/store/farm-pasture.jpg';
    }
    if (title.contains('chhachh') ||
        title.contains('milk') ||
        title.contains('doodh')) {
      return 'assets/store/farm-milking.jpg';
    }
    if (title.contains('chilli') || title.contains('shata dhauta')) {
      return 'assets/store/farm-bilona.jpg';
    }
    return null;
  }
}

/// Renders either a bundled storefront asset or a remotely hosted merchant image.
/// Keeping this decision here prevents individual cards and galleries from
/// accidentally treating asset paths as network URLs.
class StoreMediaImage extends StatelessWidget {
  const StoreMediaImage({
    super.key,
    required this.source,
    this.fit = BoxFit.contain,
    this.fallbackIconSize = 42,
    this.fallbackColor = storeMuted,
  });

  final String? source;
  final BoxFit fit;
  final double fallbackIconSize;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final src = source?.trim();
    Widget fallback() => Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: fallbackIconSize,
            color: fallbackColor,
          ),
        );

    if (src == null || src.isEmpty) return fallback();

    final isRemote = src.startsWith('https://') || src.startsWith('http://');
    return isRemote
        ? Image.network(
            src,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback(),
          )
        : Image.asset(
            src,
            fit: fit,
            errorBuilder: (_, __, ___) => fallback(),
          );
  }
}

/// Merchant images always take precedence. Generated packaging remains a concept.
class ProductArtwork extends StatelessWidget {
  const ProductArtwork(
      {super.key,
      this.product,
      this.kind = 'Cow ghee',
      this.pack = '500 ml',
      this.showCaption = false,
      this.fit = BoxFit.contain,
      this.imageIndex = 0});
  final Product? product;
  final String kind, pack;
  final bool showCaption;
  final BoxFit fit;
  final int imageIndex;
  @override
  Widget build(BuildContext context) {
    final p = product;
    final src = p != null && p.media.isNotEmpty
        ? p.media[imageIndex.clamp(0, p.media.length - 1)]
        : StoreImages.productArtwork(p) ??
            StoreImages.category(p != null ? storeCategory(p) : kind);
    final remote = src != null &&
        (src.startsWith('https://') || src.startsWith('http://'));
    final image = StoreMediaImage(source: src, fit: fit);
    return Column(children: [
      Expanded(child: SizedBox(width: double.infinity, child: image)),
      if (showCaption && src != null && !remote)
        const Text('Concept packaging image',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: storeMuted)),
    ]);
  }
}

class StoreFooter extends ConsumerWidget {
  const StoreFooter({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
      width: double.infinity,
      color: storeDarkGreenNav,
      child: Column(
        children: [
          // Back to top button
          InkWell(
            onTap: () {
              PrimaryScrollController.maybeOf(context)?.animateTo(
                0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: storeSubNav,
              alignment: Alignment.center,
              child: const Text(
                'Back to top',
                style: TextStyle(
                    color: storeWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // Main footer links
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Center(
                child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 40,
                        runSpacing: 28,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('milterrafoods.com',
                                    style: StoreType.logo
                                        .copyWith(color: storeWhite)),
                                const SizedBox(height: 8),
                                const Text('Good food. Thoughtfully chosen.',
                                    style: StoreType.onDark),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('GET TO KNOW US',
                                    style: StoreType.footerLabel),
                                const SizedBox(height: 8),
                                TextButton(
                                    onPressed: () {
                                      if (GoRouterState.of(context)
                                              .matchedLocation !=
                                          '/about') {
                                        context.push('/about');
                                      }
                                    },
                                    child: const Text('About Milterra',
                                        style: StoreType.inverseLabel)),
                                TextButton(
                                    onPressed: () =>
                                        showProductQuality(context),
                                    child: const Text('Quality & Research',
                                        style: StoreType.inverseLabel)),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CONNECT WITH US',
                                    style: StoreType.footerLabel),
                                const SizedBox(height: 8),
                                TextButton(
                                    onPressed: () => context.go('/shop'),
                                    child: const Text('Direct from Farmers',
                                        style: StoreType.inverseLabel)),
                                TextButton(
                                    onPressed: () =>
                                        context.go('/marketplace/sell'),
                                    child: const Text('Sell on Milterra',
                                        style: StoreType.inverseLabel)),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('LET US HELP YOU',
                                    style: StoreType.footerLabel),
                                const SizedBox(height: 8),
                                TextButton(
                                    onPressed: () => storeAccountRoute(
                                        context, ref, '/account'),
                                    child: const Text('Your Account',
                                        style: StoreType.inverseLabel)),
                                TextButton(
                                    onPressed: () => storeAccountRoute(
                                        context, ref, '/marketplace/addresses'),
                                    child: const Text('Delivery Addresses',
                                        style: StoreType.inverseLabel)),
                                TextButton(
                                    onPressed: () => context.go('/wishlist'),
                                    child: const Text('Your Wishlist',
                                        style: StoreType.inverseLabel)),
                                TextButton(
                                    onPressed: () => context.go('/help'),
                                    child: const Text('Help & Support',
                                        style: StoreType.inverseLabel)),
                              ]),
                        ]))),
          ),
          const Divider(color: Colors.white12, height: 1),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              '© 2026 Milterra Direct India. All rights reserved.',
              style: TextStyle(color: Color(0xff889988), fontSize: 12),
            ),
          ),
        ],
      ));
}
