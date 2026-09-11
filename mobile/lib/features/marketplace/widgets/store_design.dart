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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (title != null) ...[
          Text(title!, style: StoreType.title),
          StoreLayout.panelGap
        ],
        child,
      ]));
}

String storeCategory(Product p) {
  if (p.taxonomy?['category_name'] != null) {
    return p.taxonomy!['category_name'].toString();
  }
  if (p.taxonomyEnabled) return 'Uncategorized';
  final name = p.title.toLowerCase();
  if (p.taxonomy?['is_earth'] == true ||
      name.contains('earth') ||
      name.contains('vermicompost') ||
      name.contains('manure') ||
      name.contains('compost') ||
      name.contains('soil mix')) {
    return 'MILTERRA Earth';
  }
  if (p.category == ProductCategory.equipment) return 'Equipment';
  if (name.contains('paneer')) return 'Paneer';
  if (name.contains('ghee') && name.contains('buffalo')) return 'Buffalo ghee';
  if (name.contains('ghee')) return 'Cow ghee';
  if (name.contains('butter')) return 'Other products';
  if (name.contains('feed') ||
      name.contains('pellet') ||
      name.contains('mineral') ||
      name.contains('calcium') ||
      name.contains('fat') ||
      name.contains('seed') ||
      name.contains('nutrition')) {
    return 'Animal nutrition';
  }
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

void storeBrowse(BuildContext context, {String? category, String? query}) =>
    context.go(Uri(path: '/shop', queryParameters: {
      if (category != null && category != 'All products' && category != 'All')
        'category': category,
      if (query != null && query.isNotEmpty) 'query': query,
    }).toString());

/// Rating stars component mimicking Amazon's 5-star customer rating presentation.
class AmazonRatingStars extends StatelessWidget {
  const AmazonRatingStars({
    super.key,
    this.rating = 4.8,
    this.reviewCount = 38,
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
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.4;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            if (index < fullStars) {
              return Icon(Icons.star, size: size, color: storeStarGold);
            } else if (index == fullStars && hasHalf) {
              return Icon(Icons.star_half, size: size, color: storeStarGold);
            } else {
              return Icon(Icons.star_border, size: size, color: storeStarGold);
            }
          }),
        ),
        if (showCount) ...[
          const SizedBox(width: 6),
          Text(
            '$reviewCount',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xff007185),
            ),
          ),
        ],
      ],
    );

    if (interactive && onTap != null) {
      return InkWell(onTap: onTap, child: content);
    }
    return content;
  }
}

/// Amazon-style Slide-over department drawer.
void showAmazonDepartmentDrawer(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close Menu',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, anim1, anim2) => const _AmazonDepartmentDrawer(),
    transitionBuilder: (ctx, anim1, anim2, child) => SlideTransition(
      position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _AmazonDepartmentDrawer extends ConsumerWidget {
  const _AmazonDepartmentDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: storeWhite,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width.clamp(280.0, 380.0),
          height: double.infinity,
          child: Column(
            children: [
              // Drawer Header (Amazon dark green styling)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                color: storeDarkGreenNav,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: storeSubNav,
                        child: Icon(Icons.person, color: storeWhite, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          user != null
                              ? 'Hello, ${user.name ?? 'Customer'}'
                              : 'Hello, Sign in',
                          style: const TextStyle(
                              color: storeWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close Menu',
                        icon: const Icon(Icons.close, color: storeWhite),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),

              // Drawer List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _sectionHeader('Trending'),
                    _drawerTile(context, 'Best Sellers',
                        () => storeBrowse(context, category: 'All products')),
                    _drawerTile(context, 'New Releases',
                        () => storeBrowse(context, category: 'All products')),
                    _drawerTile(context, 'Movers & Shakers',
                        () => storeBrowse(context, category: 'All products')),
                    const Divider(height: 16),
                    _sectionHeader('🥛 Household Dairy Collection'),
                    _drawerTile(context, 'All Dairy Foods',
                        () => storeBrowse(context, category: 'Dairy Foods')),
                    _drawerTile(context, 'A2 Desi Cow Ghee (Bilona)',
                        () => storeBrowse(context, category: 'Cow ghee')),
                    _drawerTile(context, 'Rich Granular Buffalo Ghee',
                        () => storeBrowse(context, category: 'Buffalo ghee')),
                    _drawerTile(context, 'Fresh Malai Paneer',
                        () => storeBrowse(context, category: 'Paneer')),
                    _drawerTile(context, 'Cultured White Butter (Makhan)',
                        () => storeBrowse(context, category: 'Other products')),
                    const Divider(height: 16),
                    _sectionHeader('🌱 MILTERRA Earth: Living Soil & Compost'),
                    _drawerTile(context, 'From Farm Waste to Living Soil (Overview)',
                        () {
                      Navigator.pop(context);
                      context.push('/earth');
                    }),
                    _drawerTile(context, 'All MILTERRA Earth Products',
                        () => storeBrowse(context, category: 'MILTERRA Earth')),
                    _drawerTile(context, 'Premium Vermicompost',
                        () => storeBrowse(context, category: 'MILTERRA Earth', query: 'vermicompost')),
                    _drawerTile(context, 'Cow-Dung Farm Manure',
                        () => storeBrowse(context, category: 'MILTERRA Earth', query: 'manure')),
                    _drawerTile(context, 'Enriched Organic Compost',
                        () => storeBrowse(context, category: 'MILTERRA Earth', query: 'compost')),
                    _drawerTile(context, 'Sun-Dried Compost Cakes',
                        () => storeBrowse(context, category: 'MILTERRA Earth', query: 'cakes')),
                    _drawerTile(context, 'Compost Starter & Inoculants',
                        () => storeBrowse(context, category: 'MILTERRA Earth', query: 'starter')),
                    _drawerTile(context, 'Garden Soil Mix',
                        () => storeBrowse(context, category: 'MILTERRA Earth', query: 'soil mix')),
                    const Divider(height: 16),
                    _sectionHeader("🌾 Farmer's Hub: Feed & Nutrition"),
                    _drawerTile(context, 'All Cattle Nutrition & Feed',
                        () => storeBrowse(context, category: 'Animal nutrition')),
                    _drawerTile(context, '20% Protein Compound Pellets',
                        () => storeBrowse(context, category: 'Animal nutrition')),
                    _drawerTile(context, 'Chelated Minerals & Yeast',
                        () => storeBrowse(context, category: 'Animal nutrition')),
                    _drawerTile(context, 'Calci-Boost High-Potency Drench',
                        () => storeBrowse(context, category: 'Animal nutrition')),
                    _drawerTile(context, '99% Pure Bypass Fat',
                        () => storeBrowse(context, category: 'Animal nutrition')),
                    const Divider(height: 16),
                    _sectionHeader('⚙️ Modern Farm & Dairy Machinery'),
                    _drawerTile(context, 'All Dairy & Farm Machinery',
                        () => storeBrowse(context, category: 'Equipment')),
                    _drawerTile(context, 'Single-Bucket Milking Machines',
                        () => storeBrowse(context, category: 'Equipment')),
                    _drawerTile(context, 'Digital Ultrasonic Milk Analyzers',
                        () => storeBrowse(context, category: 'Equipment')),
                    _drawerTile(context, 'High-Speed Motor Chaff Cutters',
                        () => storeBrowse(context, category: 'Equipment')),
                    _drawerTile(context, 'SS 304 Heavy-Duty Milk Cans',
                        () => storeBrowse(context, category: 'Equipment')),
                    _drawerTile(context, 'Interlocking Cow Comfort Mats',
                        () => storeBrowse(context, category: 'Equipment')),
                    const Divider(height: 16),
                    _sectionHeader('Programs & Features'),
                    _drawerTile(context, 'Milk Purity Checker', () {
                      Navigator.pop(context);
                      context.push('/purity');
                    }),
                    _drawerTile(context, 'Milterra Direct Express',
                        () => storeBrowse(context)),
                    const Divider(height: 16),
                    _sectionHeader('Help & Settings'),
                    _drawerTile(context, 'Your Account', () {
                      Navigator.pop(context);
                      storeAccountRoute(context, ref, '/profile');
                    }),
                    _drawerTile(context, 'Your Orders', () {
                      Navigator.pop(context);
                      storeAccountRoute(context, ref, '/marketplace/orders');
                    }),
                    _drawerTile(context, 'Milterra Balance & Wallet', () {
                      Navigator.pop(context);
                      storeAccountRoute(context, ref, '/balance');
                    }),
                    _drawerTile(context, 'Delivery Addresses', () {
                      Navigator.pop(context);
                      storeAccountRoute(context, ref, '/marketplace/addresses');
                    }),
                    if (user != null)
                      _drawerTile(context, 'Sign Out', () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/shop');
                      })
                    else
                      _drawerTile(context, 'Sign In', () {
                        Navigator.pop(context);
                        context.go('/login?next=/shop');
                      }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
      );

  Widget _drawerTile(
          BuildContext context, String title, VoidCallback onSelected) =>
      ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(title,
            style: const TextStyle(fontSize: 14, color: Color(0xff111111))),
        trailing: const Icon(Icons.chevron_right, size: 18, color: storeMuted),
        onTap: () {
          Navigator.pop(context);
          onSelected();
        },
      );
}

/// Amazon-style Comprehensive Header
class StoreHeader extends ConsumerStatefulWidget {
  const StoreHeader({super.key, this.search, this.currentCategory});
  final Widget? search;
  final String? currentCategory;

  @override
  ConsumerState<StoreHeader> createState() => _StoreHeaderState();
}

class _StoreHeaderState extends ConsumerState<StoreHeader> {
  late final TextEditingController _searchCtrl;
  String _selectedCategory = 'All';

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
    _searchCtrl = TextEditingController();
    _selectedCategory = _normalizeCategory(widget.currentCategory);
  }

  @override
  void didUpdateWidget(covariant StoreHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCategory != widget.currentCategory) {
      setState(() {
        _selectedCategory = _normalizeCategory(widget.currentCategory);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    final query = _searchCtrl.text.trim();
    final effectiveCat = _normalizeCategory(_selectedCategory);
    storeBrowse(
      context,
      category: effectiveCat == 'All' ? null : effectiveCat,
      query: query.isEmpty ? null : query,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final count = ref.watch(cartItemCountProvider);
    final wishlistCount = ref.watch(wishlistItemCountProvider);
    final canAdmin = user != null &&
        ref.watch(commerceAccessProvider).valueOrNull?['can_manage_taxonomy'] ==
            true;

    return Container(
      color: storeGreen,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, bounds) {
          final isMobile = bounds.maxWidth < StoreLayout.tablet;
          final isWide = bounds.maxWidth >= 960;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                            const Icon(Icons.spa_outlined,
                                color: storeGold, size: 22),
                            const SizedBox(width: 4),
                            Text(
                              'milterra',
                              style: StoreType.logo.copyWith(
                                color: storeWhite,
                                fontSize: isMobile ? 23 : 26,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text('.in',
                                  style: TextStyle(
                                      color: storeGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Deliver to Location Pill (Desktop)
                    if (isWide) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => _showLocationSelector(context),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on_outlined,
                                  color: storeWhite, size: 20),
                              SizedBox(width: 4),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Deliver to',
                                      style: StoreType.amazonTopLine),
                                  Text('Across India',
                                      style: StoreType.amazonBottomLine),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Search Box (Desktop / Tablet)
                    if (!isMobile) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: widget.search ?? _buildAmazonSearchBar(),
                      ),
                      const SizedBox(width: 14),
                    ] else ...[
                      const Spacer(),
                    ],

                    // Language / Region (Optional Desktop element)
                    if (isWide) ...[
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇮🇳', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 3),
                            Text('EN ▾', style: StoreType.amazonBottomLine),
                          ],
                        ),
                      ),
                    ],

                    // Account & Lists
                    InkWell(
                      onTap: () => storeAccountRoute(
                          context, ref, '/marketplace/orders'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              user != null
                                  ? 'Hello, ${user.name?.split(' ').first ?? 'User'}'
                                  : 'Hello, sign in',
                              style: StoreType.amazonTopLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text('Account & Lists ▾',
                                style: StoreType.amazonBottomLine),
                          ],
                        ),
                      ),
                    ),

                    // Returns & Orders (Desktop & Tablet)
                    if (!isMobile) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => storeAccountRoute(
                            context, ref, '/marketplace/orders'),
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Returns', style: StoreType.amazonTopLine),
                              Text('& Orders',
                                  style: StoreType.amazonBottomLine),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // Admin Button (if authorized)
                    if (canAdmin) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Commerce Admin',
                        onPressed: () => context.go('/admin/commerce'),
                        icon: const Icon(Icons.admin_panel_settings_outlined,
                            color: storeGold, size: 22),
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
                                color: storeWhite,
                                size: 24,
                              ),
                            ),
                            if (!isMobile) ...[
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
                                color: storeWhite,
                                size: 26,
                              ),
                            ),
                            if (!isMobile) ...[
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

              // Mobile Search Bar (Below Logo row on small screens)
              if (isMobile) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: widget.search ?? _buildAmazonSearchBar(),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  void _showLocationSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: storeWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_outlined,
                    color: storeGreen, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Choose Delivery Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: storeGreen,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff4fbf6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffc6ebd0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: storeGreen, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Milterra delivers across all 28 states & 19,000+ PIN codes in India via DTDC Express.',
                      style: TextStyle(
                        fontSize: 13,
                        color: storeGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: storeGreen,
                      side: const BorderSide(color: storeBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      storeAccountRoute(context, ref, '/marketplace/addresses');
                    },
                    icon: const Icon(Icons.bookmark_border, size: 18),
                    label: const Text('Manage Addresses'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: storeAmber,
                      foregroundColor: storeGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Continue Shopping',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmazonSearchBar() {
    final taxonomy = ref.watch(taxonomyProvider).valueOrNull;

    final baseCategories = <String, String>{
      'All': 'All Departments',
      'Dairy Foods': '🥛 Dairy Foods',
      'MILTERRA Earth': '🌱 MILTERRA Earth',
      'Cow ghee': 'Cow Ghee',
      'Buffalo ghee': 'Buffalo Ghee',
      'Paneer': 'Fresh Paneer',
      'Animal nutrition': '🌾 Cattle Nutrition',
      'Equipment': '⚙️ Farm Machinery',
    };

    if (taxonomy?.enabled == true) {
      for (final node in taxonomy!.nodes) {
        baseCategories[node.id] = node.name;
      }
    }

    final currentCat = _normalizeCategory(_selectedCategory);

    // If currentCat is a taxonomy node ID, resolve it to its name or keep the ID key
    String resolvedKey = currentCat;
    if (!baseCategories.containsKey(resolvedKey)) {
      if (taxonomy?.enabled == true) {
        for (final node in taxonomy!.nodes) {
          if (node.id == currentCat ||
              node.name.toLowerCase() == currentCat.toLowerCase()) {
            resolvedKey = node.id;
            baseCategories[node.id] = node.name;
            break;
          }
        }
      }
    }

    final items = <DropdownMenuItem<String>>[
      for (final entry in baseCategories.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(
            entry.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    if (!baseCategories.containsKey(resolvedKey)) {
      // If still unknown and looks like a UUID (contains hyphens), map to 'All'
      if (resolvedKey.contains('-')) {
        resolvedKey = 'All';
      } else {
        items.add(DropdownMenuItem(
          value: resolvedKey,
          child: Text(resolvedKey, maxLines: 1, overflow: TextOverflow.ellipsis),
        ));
      }
    }
    final dropdownValue =
        items.any((it) => it.value == resolvedKey) ? resolvedKey : 'All';

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.controlRadius),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Category Selector Dropdown Pill
          Container(
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: const BoxDecoration(
              color: Color(0xffe8e4da),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(StoreLayout.controlRadius),
                bottomLeft: Radius.circular(StoreLayout.controlRadius),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: dropdownValue,
                icon: const Icon(Icons.arrow_drop_down,
                    size: 17, color: storeGreen),
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: storeGreen),
                items: items,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                  }
                },
              ),
            ),
          ),

          // Search Input Field
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _triggerSearch(),
              style: const TextStyle(fontSize: 13, color: Color(0xff111111)),
              decoration: InputDecoration(
                hintText: 'Search Milterra.in (e.g. A2 Cow Ghee, Paneer)...',
                hintStyle:
                    const TextStyle(color: Color(0xff777777), fontSize: 12),
                filled: true,
                fillColor: storeWhite,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: storeMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Amber Search Button
          Material(
            color: storeAmber,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(StoreLayout.controlRadius),
              bottomRight: Radius.circular(StoreLayout.controlRadius),
            ),
            child: InkWell(
              onTap: _triggerSearch,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(StoreLayout.controlRadius),
                bottomRight: Radius.circular(StoreLayout.controlRadius),
              ),
              child: const SizedBox(
                width: 42,
                height: double.infinity,
                child: Icon(Icons.search, color: storeGreen, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amazon Sub-Navigation Bar with "☰ All" Drawer and category quick links
class StoreCategoryNavigation extends ConsumerWidget {
  const StoreCategoryNavigation({
    super.key,
    this.selected = 'All products',
    this.onSelected,
    this.legacyEquipment = false,
  });

  final String selected;
  final ValueChanged<String>? onSelected;
  final bool legacyEquipment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxonomy = ref.watch(taxonomyProvider).valueOrNull;

    final entries = <String, String>{
      'All products': 'All Products',
      if (taxonomy?.enabled == true)
        for (final node in taxonomy!.nodes) node.id: node.name
      else if (legacyEquipment)
        'Equipment': 'Equipment'
      else ...{
        'Dairy Foods': '🥛 Dairy Foods',
        'MILTERRA Earth': '🌱 MILTERRA Earth',
        'Animal nutrition': '🌾 Animal Nutrition',
        'Equipment': '⚙️ Farm Equipment',
      }
    };

    return Container(
      height: 36,
      color: storeDarkGreenNav,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Row(
            children: [
              // Amazon "☰ All" drawer button
              InkWell(
                onTap: () => showAmazonDepartmentDrawer(context),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu, color: storeWhite, size: 18),
                      SizedBox(width: 5),
                      Text('All',
                          style: TextStyle(
                              color: storeWhite,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),

              const VerticalDivider(
                  color: Colors.white24, indent: 8, endIndent: 8, width: 1),

              // Category links list
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    ...entries.entries.map((entry) {
                      final isCurrent = entry.key == selected;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 3),
                        child: InkWell(
                          onTap: () => onSelected != null
                              ? onSelected!(entry.key)
                              : storeBrowse(context, category: entry.key),
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? storeSubNav
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Center(
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isCurrent
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isCurrent
                                      ? storeGold
                                      : const Color(0xffe8eee2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Additional Amazon-style fast links
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 3),
                      child: InkWell(
                        onTap: () => context.go('/shop/deals'),
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected == 'Deals'
                                ? storeSubNav
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt, size: 14, color: storeGold),
                                const SizedBox(width: 3),
                                Text(
                                  "Today's Deals",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected == 'Deals'
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: selected == 'Deals'
                                        ? storeGold
                                        : const Color(0xffe8eee2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Right side direct tag (Desktop): Direct link to authentic laboratory test reports
              if (MediaQuery.sizeOf(context).width >= 960)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Builder(builder: (context) {
                    final catLower = selected.toLowerCase();
                    final isNutrition = catLower.contains('animal') ||
                        catLower.contains('nutrition') ||
                        catLower.contains('feed') ||
                        catLower.contains('supplement') ||
                        catLower.contains('pashu') ||
                        catLower.contains('stage');
                    final label = isNutrition
                        ? 'Quality & Research — Coming Soon'
                        : 'Lab Test Reports';

                    return InkWell(
                      onTap: () {
                        if (isNutrition) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: storeGreen,
                              duration: Duration(seconds: 3),
                              content: Text(
                                'Quality & Research validation reports will be published as farmer trials conclude.',
                              ),
                            ),
                          );
                        } else {
                          context.push('/purity');
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isNutrition
                                  ? Icons.biotech_outlined
                                  : Icons.science_outlined,
                              color: storeGold,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: const TextStyle(
                                color: Color(0xffd2ded6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
        'paneer' => 'assets/store/paneer.png',
        'janam-42' || 'janam' => 'assets/store/feed-janam-42.jpg',
        'minera-360' || 'mineral' || 'mineral supplement' => 'assets/store/minera-360-jar.jpg',
        'bovine gold' || 'cattle feed' || 'feed pellets' || 'pashu aahar' => 'assets/store/feed-bovine-gold.jpg',
        'bypass fat' || 'lacto-energy' => 'assets/store/feed-bypass-fat.jpg',
        'calci-boost' || 'calcium' => 'assets/store/calci-feed-combo.jpg',
        'animal nutrition' || 'cattle nutrition' => 'assets/store/nutrition-lineup.jpg',
        'milterra earth' || 'earth' || 'vermicompost' => 'assets/store/earth-vermicompost.jpg',
        'manure' || 'farm manure' => 'assets/store/earth-manure.jpg',
        'soil mix' || 'garden soil' => 'assets/store/earth-soil-mix.jpg',
        'compost cakes' || 'cakes' => 'assets/store/earth-cakes.jpg',
        _ => null,
      };

  static String? productArtwork(Product? p) {
    if (p == null) return null;
    final title = p.title.toLowerCase();
    if (title.contains('vermicompost')) return 'assets/store/earth-vermicompost.jpg';
    if (title.contains('manure')) return 'assets/store/earth-manure.jpg';
    if (title.contains('soil mix') || (title.contains('soil') && title.contains('earth'))) {
      return 'assets/store/earth-soil-mix.jpg';
    }
    if (title.contains('cake')) return 'assets/store/earth-cakes.jpg';
    if (title.contains('starter') || title.contains('compost')) return 'assets/store/earth-vermicompost.jpg';
    if (title.contains('janam')) return 'assets/store/feed-janam-42.jpg';
    if (title.contains('bovine gold') || (title.contains('pellet') && title.contains('feed'))) {
      return 'assets/store/feed-bovine-gold.jpg';
    }
    if (title.contains('bypass fat') || title.contains('lacto-energy')) {
      return 'assets/store/feed-bypass-fat.jpg';
    }
    if (title.contains('minera-360') || title.contains('mineral supplement') || title.contains('mineral')) {
      return 'assets/store/minera-360-jar.jpg';
    }
    if (title.contains('calci-') || title.contains('calcium') || title.contains('cal-gold')) {
      return 'assets/store/calci-feed-combo.jpg';
    }
    if (title.contains('lacta') || title.contains('rumen') || title.contains('heat') || title.contains('digest') || title.contains('vitagrow') || title.contains('milk-pro')) {
      return 'assets/store/nutrition-lineup.jpg';
    }
    if (title.contains('cow ghee')) return 'assets/store/cow-ghee.png';
    if (title.contains('buffalo ghee')) return 'assets/store/buffalo-ghee.png';
    if (title.contains('paneer')) return 'assets/store/paneer.png';
    return null;
  }
}

/// Merchant images always take precedence. Generated packaging remains a concept.
class ProductArtwork extends StatelessWidget {
  const ProductArtwork(
      {super.key,
      this.product,
      this.kind = 'Cow ghee',
      this.pack = '500 ml',
      this.showCaption = true,
      this.imageIndex = 0});
  final Product? product;
  final String kind, pack;
  final bool showCaption;
  final int imageIndex;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final explicitAsset = StoreImages.productArtwork(p);
    final asset = explicitAsset ?? StoreImages.category(p != null ? storeCategory(p) : kind);

    Widget departmentCard() {
      final title = p?.title.toLowerCase() ?? kind.toLowerCase();
      final IconData icon;
      final Color bg;
      final Color fg;
      final String tag;

      final isConcept = p?.taxonomy?['concept'] == true ||
          p?.category == ProductCategory.feedNutrition ||
          title.contains('janam') ||
          (p?.taxonomy?['status'] != null &&
              p!.taxonomy!['status'].toString().toLowerCase().contains('concept'));

      if (title.contains('vermicompost')) {
        icon = Icons.yard_outlined;
        bg = const Color(0xfff0f5ee);
        fg = storeEarthDarkGreen;
        tag = 'PREMIUM VERMICOMPOST';
      } else if (title.contains('manure')) {
        icon = Icons.nature_people_outlined;
        bg = const Color(0xfff7f3ee);
        fg = storeEarthWarmBrown;
        tag = 'FARM MANURE';
      } else if (title.contains('compost') && !title.contains('vermi')) {
        icon = Icons.recycling_outlined;
        bg = const Color(0xfff3f7f0);
        fg = const Color(0xff386641);
        tag = 'ORGANIC COMPOST';
      } else if (title.contains('cake')) {
        icon = Icons.wb_sunny_outlined;
        bg = const Color(0xfffaf4ed);
        fg = storeEarthTerracotta;
        tag = 'COMPOST CAKES';
      } else if (title.contains('starter')) {
        icon = Icons.science_outlined;
        bg = const Color(0xfffdf6f0);
        fg = storeEarthTerracotta;
        tag = 'COMPOST STARTER';
      } else if (title.contains('soil mix') || title.contains('soil')) {
        icon = Icons.park_outlined;
        bg = const Color(0xfff4f1ec);
        fg = const Color(0xff58402b);
        tag = 'GARDEN SOIL MIX';
      } else if (title.contains('janam')) {
        icon = Icons.timeline_outlined;
        bg = const Color(0xfff5f0fa);
        fg = const Color(0xff5c3b87);
        tag = 'CONCEPT PREVIEW';
      } else if (title.contains('milking') || title.contains('milker')) {
        icon = Icons.precision_manufacturing_outlined;
        bg = const Color(0xffedf4f2);
        fg = storeGreen;
        tag = 'MILKING MACHINE';
      } else if (title.contains('analyzer') || title.contains('scan')) {
        icon = Icons.science_outlined;
        bg = const Color(0xffeaf3f7);
        fg = const Color(0xff1d5b79);
        tag = 'MILK QUALITY LAB';
      } else if (title.contains('chaff') || title.contains('cutter')) {
        icon = Icons.agriculture_outlined;
        bg = const Color(0xfff3f5ea);
        fg = const Color(0xff49652a);
        tag = 'FARM MACHINERY';
      } else if (title.contains('can')) {
        icon = Icons.local_drink_outlined;
        bg = const Color(0xfff0f2f5);
        fg = const Color(0xff3f4d67);
        tag = 'SS 304 MILK CAN';
      } else if (title.contains('mat')) {
        icon = Icons.grid_view_rounded;
        bg = const Color(0xffeae7e1);
        fg = const Color(0xff4a3e2c);
        tag = 'COW COMFORT MAT';
      } else if (title.contains('pellet') || title.contains('feed') || title.contains('aahar')) {
        icon = Icons.grain_outlined;
        bg = const Color(0xfff7f2e7);
        fg = const Color(0xff7a591e);
        tag = isConcept ? 'CONCEPT PREVIEW' : 'HIGH-YIELD FEED';
      } else if (title.contains('mineral')) {
        icon = Icons.medication_liquid_outlined;
        bg = const Color(0xffedf4ea);
        fg = const Color(0xff326938);
        tag = isConcept ? 'CONCEPT PREVIEW' : 'CHELATED MINERALS';
      } else if (title.contains('calcium') || title.contains('calci') || title.contains('drench')) {
        icon = Icons.health_and_safety_outlined;
        bg = const Color(0xfff8ede8);
        fg = const Color(0xff8c3b24);
        tag = isConcept ? 'CONCEPT PREVIEW' : 'CALCIUM TONIC';
      } else if (title.contains('lacta')) {
        icon = Icons.water_drop_outlined;
        bg = const Color(0xffedf6f2);
        fg = const Color(0xff2d6a4f);
        tag = isConcept ? 'CONCEPT PREVIEW' : 'LACTATION BOOSTER';
      } else if (title.contains('rumen')) {
        icon = Icons.biotech_outlined;
        bg = const Color(0xfffbf2e6);
        fg = const Color(0xffb26a00);
        tag = isConcept ? 'CONCEPT PREVIEW' : 'RUMEN PREBIOTIC';
      } else if (title.contains('heat')) {
        icon = Icons.wb_sunny_outlined;
        bg = const Color(0xfffdf0ed);
        fg = const Color(0xffc84b31);
        tag = isConcept ? 'CONCEPT PREVIEW' : 'HEAT STRESS GUARD';
      } else if (title.contains('fat') || title.contains('energy')) {
        icon = Icons.bolt_outlined;
        bg = const Color(0xfffdf6e2);
        fg = const Color(0xff99710d);
        tag = isConcept ? 'CONCEPT PREVIEW' : 'BYPASS FAT ENERGY';
      } else if (title.contains('butter')) {
        icon = Icons.bakery_dining_outlined;
        bg = const Color(0xfffaf6e8);
        fg = const Color(0xffb38a2e);
        tag = 'WHITE BUTTER';
      } else {
        icon = Icons.inventory_2_outlined;
        bg = const Color(0xfff5f3ec);
        fg = storeGreen;
        tag = (p != null ? storeCategory(p) : kind).toUpperCase();
      }

      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52, color: fg),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: fg,
                  ),
                ),
              ),
              if (showCaption && p?.packSize != null) ...[
                const SizedBox(height: 6),
                Text(
                  p!.packSize!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: fg.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    Widget loadAssetWithWebFallback(String src) {
      final cleanPath = src.startsWith('/') ? src.substring(1) : src;
      return ClipRRect(
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        child: Image.network(
          cleanPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.network(
            'assets/$cleanPath',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              cleanPath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => departmentCard(),
            ),
          ),
        ),
      );
    }

    if (p != null && p.media.isNotEmpty) {
      final rawSrc = p.media[imageIndex.clamp(0, p.media.length - 1)];
      if (rawSrc.startsWith('http://') || rawSrc.startsWith('https://')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          child: Image.network(
            rawSrc,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => departmentCard(),
          ),
        );
      }
      return loadAssetWithWebFallback(rawSrc);
    }

    if (asset != null) {
      return loadAssetWithWebFallback(asset);
    }

    return departmentCard();
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
                                Text('milterra.in',
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
                                    onPressed: () => context.go('/about'),
                                    child: const Text('About Milterra',
                                        style: StoreType.inverseLabel)),
                                TextButton(
                                    onPressed: () => context.push('/purity'),
                                    child: const Text('Milk Purity Standards',
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
                                        context,
                                        ref,
                                        '/marketplace/orders'),
                                    child: const Text('Your Account & Orders',
                                        style: StoreType.inverseLabel)),
                                TextButton(
                                    onPressed: () => storeAccountRoute(
                                        context,
                                        ref,
                                        '/marketplace/addresses'),
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
