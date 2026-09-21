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
import '../../admin/providers/admin_marketplace_provider.dart';
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
      (name.contains('oil') && !name.contains('ghee') && !name.contains('soil'))) {
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
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          if (user != null) {
                            context.push('/profile');
                          } else {
                            context.go('/login?next=/shop');
                          }
                        },
                        child: const CircleAvatar(
                          radius: 16,
                          backgroundColor: storeSubNav,
                          child:
                              Icon(Icons.person, color: storeWhite, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            if (user != null) {
                              context.push('/profile');
                            } else {
                              context.go('/login?next=/shop');
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
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
                        () => storeBrowse(context, sort: 'Best Sellers')),
                    _drawerTile(context, 'New Releases',
                        () => storeBrowse(context, sort: 'Newest Arrivals')),
                    _drawerTile(context, 'Movers & Shakers',
                        () => storeBrowse(context, sort: 'Trending')),
                      const Divider(height: 16),
                      _sectionHeader('🧈 Artisanal Dairy & Cultured'),
                      _drawerTile(context, 'All Artisanal Dairy',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured')),
                      _drawerTile(context, 'Vedic Bilona Cow Ghee (Amber Glass)',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured', query: 'bilona')),
                      _drawerTile(context, 'Spiced Probiotic Mattha (Live Buttermilk)',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured', query: 'mattha')),
                      _drawerTile(context, 'Traditional Curd Chillies (Mor Milagai)',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured', query: 'chilli')),
                      _drawerTile(context, 'Cold-Process Goat Milk & Honey Soap',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured', query: 'soap')),
                      _drawerTile(context, 'Shata Dhauta Ghrita (100x Washed Ghee Cream)',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured', query: 'shata dhauta')),
                      _drawerTile(context, 'A2 Gir Cow Chilled Raw Milk',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured', query: 'milk')),
                      _drawerTile(context, 'Fresh Malai Paneer & Makhan',
                          () => storeBrowse(context, category: 'Artisanal Dairy & Cultured', query: 'paneer')),

                      const Divider(height: 16),
                      _sectionHeader('🌱 Fresh Living Harvest (Microgreens)'),
                      _drawerTile(context, 'All Living Microgreen Punnets',
                          () => storeBrowse(context, category: 'Fresh Living Harvest (Microgreens)')),
                      _drawerTile(context, 'Live Radish Microgreens (Mooli)',
                          () => storeBrowse(context, category: 'Fresh Living Harvest (Microgreens)', query: 'radish')),
                      _drawerTile(context, 'Live Sunflower Protein Crunch Trays',
                          () => storeBrowse(context, category: 'Fresh Living Harvest (Microgreens)', query: 'sunflower')),
                      _drawerTile(context, 'Live Sweet Pea Shoots (Kids Favorite)',
                          () => storeBrowse(context, category: 'Fresh Living Harvest (Microgreens)', query: 'pea')),
                      _drawerTile(context, 'Live Broccoli & Mustard Sulforaphane Detox',
                          () => storeBrowse(context, category: 'Fresh Living Harvest (Microgreens)', query: 'broccoli')),

                      const Divider(height: 16),
                      _sectionHeader('🌻 Wood-Pressed Oils & Pure Sweeteners'),
                      _drawerTile(context, 'All Oils & Heritage Sweeteners',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners')),
                      _drawerTile(context, 'Lakdi Ghani Black Mustard Oil (1L & 5L)',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'mustard')),
                      _drawerTile(context, 'Cold-Pressed Yellow Mustard Oil (Mild)',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'yellow')),
                      _drawerTile(context, 'Cold-Pressed Black Til (Sesame) Oil',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'til')),
                      _drawerTile(context, 'Cold-Pressed Groundnut Frying Oil',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'groundnut')),
                      _drawerTile(context, 'Raw Unpasteurized Mustard Honey (NMR-Tested)',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'honey')),
                      _drawerTile(context, 'Unbleached Organic Gur (Zero Hydros)',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'gur')),
                      _drawerTile(context, 'Artisanal Desi Khand (Bone-Char Free)',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'khand')),
                      _drawerTile(context, 'Dhage Wali Mishri (Rock Sugar Crystals)',
                          () => storeBrowse(context, category: 'Wood-Pressed Oils & Pure Sweeteners', query: 'mishri')),

                      const Divider(height: 16),
                      _sectionHeader('🌾 Stone-Ground Chakki Atta & Flours'),
                      _drawerTile(context, 'All Fresh Chakki Atta & Flours',
                          () => storeBrowse(context, category: 'Stone-Ground Chakki Atta & Flours')),
                      _drawerTile(context, 'Khapli Emmer Stone-Ground Atta (Low GI)',
                          () => storeBrowse(context, category: 'Stone-Ground Chakki Atta & Flours', query: 'khapli')),
                      _drawerTile(context, 'Sharbati Whole Wheat (Milled-On-Demand 72h)',
                          () => storeBrowse(context, category: 'Stone-Ground Chakki Atta & Flours', query: 'sharbati')),
                      _drawerTile(context, 'Multi-Millet Diabetic Flour Superblend',
                          () => storeBrowse(context, category: 'Stone-Ground Chakki Atta & Flours', query: 'millet')),
                      _drawerTile(context, 'Chana Sattu (Clay-Oven Roasted)',
                          () => storeBrowse(context, category: 'Stone-Ground Chakki Atta & Flours', query: 'sattu')),

                      const Divider(height: 16),
                      _sectionHeader('🧂 Terroir Salts & Native Spices'),
                      _drawerTile(context, 'All Terroir Salts & Spices',
                          () => storeBrowse(context, category: 'Terroir Salts & Native Spices')),
                      _drawerTile(context, 'Crushed Himalayan Pink Salt (Sendha Namak)',
                          () => storeBrowse(context, category: 'Terroir Salts & Native Spices', query: 'pink salt')),
                      _drawerTile(context, 'Natural Black Salt Powder (Wild Harad Kala Namak)',
                          () => storeBrowse(context, category: 'Terroir Salts & Native Spices', query: 'black salt')),
                      _drawerTile(context, 'High-Curcumin Turmeric (>5% Curcumin Haldi)',
                          () => storeBrowse(context, category: 'Terroir Salts & Native Spices', query: 'turmeric')),
                      _drawerTile(context, 'Unpolished Whole Cumin (Patan Jeera)',
                          () => storeBrowse(context, category: 'Terroir Salts & Native Spices', query: 'jeera')),
                      _drawerTile(context, 'Whole Coriander Seeds (Guntur Dhania)',
                          () => storeBrowse(context, category: 'Terroir Salts & Native Spices', query: 'dhania')),
                      _drawerTile(context, 'Mathania Whole Red Chillies (Sun-Dried)',
                          () => storeBrowse(context, category: 'Terroir Salts & Native Spices', query: 'mathania')),

                      const Divider(height: 16),
                      _sectionHeader('🪴 Apartment Balcony & Living Soil'),
                      _drawerTile(context, 'All Balcony Soil & Bio-Inputs',
                          () => storeBrowse(context, category: 'Apartment Balcony & Living Soil')),
                      _drawerTile(context, 'Odorless Granular Vermicompost (Elevator-Safe)',
                          () => storeBrowse(context, category: 'Apartment Balcony & Living Soil', query: 'vermicompost')),
                      _drawerTile(context, 'Balcony Potting Booster Mix (Lightweight)',
                          () => storeBrowse(context, category: 'Apartment Balcony & Living Soil', query: 'potting')),
                      _drawerTile(context, 'Tamba Chhachh Copper Bio-Fungicide Spray',
                          () => storeBrowse(context, category: 'Apartment Balcony & Living Soil', query: 'spray')),
                      _drawerTile(context, 'Heirloom Balcony Kitchen Seeds (5-in-1 Kit)',
                          () => storeBrowse(context, category: 'Apartment Balcony & Living Soil', query: 'seeds')),

                      const Divider(height: 16),
                      _sectionHeader('🌵 Pure Aloe Vera & Living Botanicals'),
                      _drawerTile(context, 'All Pure Aloe Vera & Botanicals',
                          () => storeBrowse(context, category: 'Pure Aloe Vera & Living Botanicals')),
                      _drawerTile(context, 'Pure Aloe Inner-Leaf Gel (99% Clear)',
                          () => storeBrowse(context, category: 'Pure Aloe Vera & Living Botanicals', query: 'aloe gel')),
                      _drawerTile(context, 'Raw Aloe Vera Digestive Juice (Pulp-Rich)',
                          () => storeBrowse(context, category: 'Pure Aloe Vera & Living Botanicals', query: 'aloe juice')),
                      _drawerTile(context, 'Live Potted Balcony Aloe Vera Succulent',
                          () => storeBrowse(context, category: 'Pure Aloe Vera & Living Botanicals', query: 'aloe plant')),

                      const Divider(height: 16),
                      _sectionHeader('🎁 Curated Kitchen & Wellness Boxes'),
                      _drawerTile(context, 'All Curated Bundles',
                          () => storeBrowse(context, category: 'Curated Kitchen & Wellness Boxes')),
                      _drawerTile(context, "★ 'The Clean Kitchen' Starter Box (₹1,499)",
                          () => storeBrowse(context, category: 'Curated Kitchen & Wellness Boxes', query: 'kitchen')),
                      _drawerTile(context, "★ 'Pantry & Botanical' Restock Box (₹2,799)",
                          () => storeBrowse(context, category: 'Curated Kitchen & Wellness Boxes', query: 'restock')),
                      _drawerTile(context, "★ 'Living Balcony' Herb & Salad Kit (₹399)",
                          () => storeBrowse(context, category: 'Curated Kitchen & Wellness Boxes', query: 'balcony')),
                      _drawerTile(context, "★ 'Daily Gut Health' Duo (₹499)",
                          () => storeBrowse(context, category: 'Curated Kitchen & Wellness Boxes', query: 'gut health')),

                      const Divider(height: 16),
                      _sectionHeader('🪔 Puja & Hawan: Sacred Essentials'),
                      _drawerTile(context, 'All Puja & Hawan Samagri',
                          () => storeBrowse(context, category: 'Puja & Hawan Samagri')),
                      _drawerTile(context, 'Pure Desi Cow Hawan Ghee',
                          () => storeBrowse(context,
                              category: 'Puja & Hawan Samagri', query: 'hawan ghee')),
                      _drawerTile(context, 'Vedic Cow Dung Cakes (Hawan Kanda)',
                          () => storeBrowse(context,
                              category: 'Puja & Hawan Samagri', query: 'kanda')),
                      _drawerTile(context, 'Handcrafted Cow Dung Diyas',
                          () => storeBrowse(context,
                              category: 'Puja & Hawan Samagri', query: 'diya')),
                      _drawerTile(context, 'Shuddha Bhimseni Kapoor & Hawan Herbs',
                          () => storeBrowse(context,
                              category: 'Puja & Hawan Samagri', query: 'kapoor')),
                      const Divider(height: 16),
                      _sectionHeader('🌸 Natural Agarbatti & Dhoop'),
                      _drawerTile(context, 'All Incense & Dhoop',
                          () => storeBrowse(context, category: 'Natural Agarbatti & Dhoop')),
                      _drawerTile(context, 'Charcoal-Free Cow Dung Agarbatti',
                          () => storeBrowse(context,
                              category: 'Natural Agarbatti & Dhoop', query: 'agarbatti')),
                      _drawerTile(context, 'Panchagavya Herbal Dhoop Cones',
                          () => storeBrowse(context,
                              category: 'Natural Agarbatti & Dhoop', query: 'dhoop')),
                      _drawerTile(context, 'Guggal & Loban Sacred Sambrani Cups',
                          () => storeBrowse(context,
                              category: 'Natural Agarbatti & Dhoop', query: 'loban')),
                      const Divider(height: 16),
                      _sectionHeader('🚜 Katixo Farmer Hub (Machinery & Feed)'),
                      _drawerTile(context, 'Visit Katixo Farmer Marketplace →', () {
                        Navigator.pop(context);
                        context.go('/marketplace');
                      }),
                    _sectionHeader('Programs & Features'),
                    _drawerTile(context, 'Quality & Research', () {
                      Navigator.pop(context);
                      showProductQuality(context);
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
                    const Divider(height: 16),
                    _sectionHeader('Portals & Access'),
                    _drawerTile(context, '🛡️ Milterra Admin Portal', () {
                      Navigator.pop(context);
                      context.go('/admin/ecommerce');
                    }),
                    _drawerTile(context, '🏪 Seller / Vendor Portal', () {
                      Navigator.pop(context);
                      context.go('/seller/login');
                    }),
                    const Divider(height: 16),
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
    _searchCtrl = TextEditingController(text: widget.initialSearch);
    _selectedCategory = _normalizeCategory(widget.currentCategory);
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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _triggerSearch() {
    final query = _searchCtrl.text.trim();
    final effectiveCat = _normalizeCategory(_selectedCategory);
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
    final canAdmin = user != null &&
        ref.watch(commerceAccessProvider).valueOrNull?['can_manage_taxonomy'] ==
            true;

    return Container(
      color: storeGreen,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, bounds) {
          final isMobile = bounds.maxWidth < StoreLayout.tablet;
          final isCompact = bounds.maxWidth < 1100;
          final isWide = bounds.maxWidth >= 1200;

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
                      onTap: () => context.go(widget.isFarmerHub ? '/marketplace' : '/shop'),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.isFarmerHub
                                ? const Icon(Icons.agriculture,
                                    color: storeGold, size: 22)
                                : ClipOval(
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
                              widget.isFarmerHub ? 'katixo' : 'milterra',
                              style: StoreType.logo.copyWith(
                                color: storeWhite,
                                fontSize: isMobile ? 23 : 26,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(widget.isFarmerHub ? '.farmer' : '.in',
                                  style: const TextStyle(
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
                    if (isCompact)
                      IconButton(
                        tooltip: user == null ? 'Sign in' : 'Your account',
                        onPressed: () => storeAccountRoute(
                            context, ref, '/marketplace/orders'),
                        icon: const Icon(Icons.person_outline,
                            color: storeWhite, size: 24),
                      )
                    else
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
                    if (!isCompact) ...[
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
                                color: storeWhite,
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
            const SizedBox(height: 14),
            const Text(
              'Filter Classifieds & Deliveries by Location / Radius:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: storeGreen,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.my_location, size: 14, color: Color(0xff064e3b)),
                  label: const Text('Near Me (Within 25 km)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xffdcfce7),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ActionChip(
                  avatar: const Icon(Icons.location_city, size: 14, color: Color(0xff064e3b)),
                  label: const Text('Anand & Kheda (GJ)', style: TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xfff1f5f9),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ActionChip(
                  avatar: const Icon(Icons.location_city, size: 14, color: Color(0xff064e3b)),
                  label: const Text('Kolhapur & Sangli (MH)', style: TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xfff1f5f9),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ActionChip(
                  avatar: const Icon(Icons.location_city, size: 14, color: Color(0xff064e3b)),
                  label: const Text('Karnal & Rohtak (HR)', style: TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xfff1f5f9),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ActionChip(
                  avatar: const Icon(Icons.public, size: 14, color: Color(0xff064e3b)),
                  label: const Text('All India (Nationwide)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xfffef08a),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
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
      'All': 'All Organic Essentials',
      'Vedic Bilona Ghee': '🧈 Vedic Bilona Ghee',
      'Fresh Milk & Dairy': '🥛 Fresh Milk & Dairy',
      'Puja & Hawan Samagri': '🪔 Puja & Hawan Samagri',
      'Natural Agarbatti & Dhoop': '🌸 Agarbatti & Dhoop',
      'Vermicompost & Living Soil': '🌱 Vermicompost & Soil',
      'Cold-Pressed Sarso (Mustard) Oil': '🌻 Cold-Pressed Sarso Oil',
    };
    if (widget.isFarmerHub) {
      baseCategories['All'] = 'All Departments';
      baseCategories['Equipment'] = '⚙️ Farm Machinery';
      baseCategories['Animal nutrition'] = '🌾 Cattle Nutrition';
      if (taxonomy?.enabled == true) {
        for (final node in taxonomy!.nodes) {
          baseCategories[node.id] = node.name;
        }
      }
    }

    final currentCat = _normalizeCategory(_selectedCategory);

    // If currentCat is a taxonomy node ID, resolve it to its name or keep the ID key
    String resolvedKey = currentCat;
    if (!baseCategories.containsKey(resolvedKey)) {
      if (widget.isFarmerHub && taxonomy?.enabled == true) {
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
      if (widget.isFarmerHub) {
        if (resolvedKey.contains('-')) {
          resolvedKey = 'All';
        } else {
          items.add(DropdownMenuItem(
            value: resolvedKey,
            child:
                Text(resolvedKey, maxLines: 1, overflow: TextOverflow.ellipsis),
          ));
        }
      } else {
        resolvedKey = 'All';
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
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Category Selector Dropdown Pill
          Container(
            height: double.infinity,
            constraints: const BoxConstraints(maxWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(
              color: Color(0xffe8e4da),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(StoreLayout.controlRadius),
                bottomLeft: Radius.circular(StoreLayout.controlRadius),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  isDense: true,
                  value: dropdownValue,
                  icon: const Icon(Icons.arrow_drop_down,
                      size: 16, color: storeGreen),
                  style: const TextStyle(
                      fontSize: 11,
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
          ),

          // Search Input Field
          Expanded(
            child: TextField(
              key: const ValueKey('store-search-field'),
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _triggerSearch(),
              style: const TextStyle(fontSize: 13, color: Color(0xff111111)),
              decoration: InputDecoration(
                hintText: widget.searchHint ??
                    (widget.isFarmerHub
                        ? 'Search Katixo (e.g. Chaff Cutter, Milking Machine, Feeds)...'
                        : 'Search Milterra.in (e.g. A2 Cow Ghee, Paneer)...'),
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
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear,
                            size: 16, color: storeMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          _triggerSearch();
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
    this.qualityProduct,
  });

  final String selected;
  final ValueChanged<String>? onSelected;
  final bool legacyEquipment;
  final Product? qualityProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxonomy = ref.watch(taxonomyProvider).valueOrNull;

    final entries = <String, String>{
      'All Organic Essentials': 'All Organic Essentials',
    };

    if (legacyEquipment) {
      entries['Equipment'] = 'Farm Machinery';
      entries['Animal nutrition'] = 'Feed & Cattle Nutrition';
      if (taxonomy?.enabled == true && taxonomy!.departments.isNotEmpty) {
        for (final dept in taxonomy.departments) {
          entries[dept.id] = dept.name;
          for (final child in taxonomy.categoriesFor(dept.id)) {
            entries[child.id] = child.name;
          }
        }
      }
    } else {
      if (taxonomy?.enabled == true && taxonomy!.departments.isNotEmpty) {
        for (final dept in taxonomy.departments) {
          final dName = dept.name.toLowerCase();
          if (dName.contains('farm essential') ||
              dName.contains('equipment') ||
              dName.contains('machinery') ||
              dName.contains('animal nutrition') ||
              dName.contains('feed')) {
            continue;
          }
          entries[dept.id] = dept.name;
        }
      } else {
        entries['Artisanal Dairy & Cultured'] = 'Artisanal Dairy';
        entries['Fresh Living Harvest (Microgreens)'] = 'Living Microgreens';
        entries['Wood-Pressed Oils & Pure Sweeteners'] = 'Cold-Pressed Oils & Honey';
        entries['Stone-Ground Chakki Atta & Flours'] = 'Chakki Atta & Flours';
        entries['Terroir Salts & Native Spices'] = 'Native Salts & Spices';
        entries['Apartment Balcony & Living Soil'] = 'Living Balcony & Soil';
        entries['Pure Aloe Vera & Living Botanicals'] = 'Pure Aloe & Botanicals';
        entries['Curated Kitchen & Wellness Boxes'] = 'Starter Boxes & Combos';
        entries['Puja & Hawan Samagri'] = 'Puja & Hawan';
      }
    }

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
                              color:
                                  isCurrent ? storeSubNav : Colors.transparent,
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
                                const Icon(Icons.bolt,
                                    size: 14, color: storeGold),
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

              // Right side direct tags (Desktop)
              if (MediaQuery.sizeOf(context).width >= 960) ...[
                if (legacyEquipment)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      key: const ValueKey('subnav-post-ad-btn'),
                      onTap: () => context.push('/marketplace/sell'),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xfffef08a),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle, color: Color(0xff064e3b), size: 14),
                            SizedBox(width: 4),
                            Text(
                              '+ Post Free Ad',
                              style: TextStyle(
                                color: Color(0xff064e3b),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Lab Test Reports
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Consumer(builder: (context, ref, _) {
                    final label = ref
                                .watch(publicCertificatesProvider(
                                    qualityProduct?.id))
                                .valueOrNull
                                ?.isNotEmpty ==
                            true
                        ? 'Lab Test Reports'
                        : 'Quality & Research';
                    return InkWell(
                      onTap: () =>
                          showProductQuality(context, product: qualityProduct),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.science_outlined,
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
        'hawan & yajna ghee' || 'hawan ghee' || 'yajna ghee' => 'assets/store/cow-ghee.png',
        'cow dung sacred products' || 'cow dung cakes' || 'hawan kanda' || 'diya' || 'diyas' => 'assets/store/earth-cakes.jpg',
        'natural dhoop & agarbatti' || 'dhoop' || 'agarbatti' => 'assets/store/milterra-tulsi-ghee.webp',
        'bhimseni kapoor & samagri' || 'bhimseni kapoor' || 'kapoor' || 'camphor' || 'hawan samagri' => 'assets/store/farm-bilona.jpg',
        'puja & hawan samagri' || 'puja samagri' || 'puja' || 'hawan' => 'assets/store/earth-cakes.jpg',
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
    if (title.contains('butter') || title.contains('makhan')) {
      return 'assets/store/white-butter-concept.png';
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
        title.contains('dhoop') ||
        title.contains('kapoor') ||
        title.contains('camphor') ||
        title.contains('diya');
    if (isSacred) {
      if (title.contains('ghee')) return 'assets/store/cow-ghee.png';
      if (title.contains('kanda') ||
          title.contains('uple') ||
          title.contains('diya')) {
        return 'assets/store/earth-cakes.jpg';
      }
      if (title.contains('dhoop') || title.contains('agarbatti')) {
        return 'assets/store/milterra-tulsi-ghee.webp';
      }
      if (title.contains('kapoor') || title.contains('camphor')) {
        return 'assets/store/farm-bilona.jpg';
      }
      if (title.contains('samagri')) {
        return 'assets/store/nutrition-lineup.jpg';
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
    if (title.contains('tulsi')) return 'assets/store/milterra-tulsi-ghee.webp';
    if (title.contains('brahmi')) {
      return 'assets/store/milterra-brahmi-ghee.webp';
    }
    if (title.contains('ashwagandha')) {
      return 'assets/store/milterra-ashwagandha-ghee.webp';
    }
    if (title.contains('bilona') || title.contains('sahiwal')) {
      return 'assets/store/bilona-cow-ghee.jpg';
    }
    if (title.contains('buffalo')) return 'assets/store/buffalo-ghee.png';
    if (title.contains('ghee')) return 'assets/store/cow-ghee.png';
    if (title.contains('paneer')) return 'assets/store/paneer.png';

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
    if (title.contains('aloe gel') || title.contains('aloe vera gel')) {
      return 'assets/store/aloe-vera-gel.jpg';
    }
    if (title.contains('aloe juice') ||
        title.contains('aloe amla') ||
        title.contains('aloe tonic')) {
      return 'assets/store/aloe-vera-juice.jpg';
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
      this.showCaption = true,
      this.imageIndex = 0});
  final Product? product;
  final String kind, pack;
  final bool showCaption;
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
    final image = StoreMediaImage(source: src);
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
                                        context, ref, '/marketplace/orders'),
                                    child: const Text('Your Account & Orders',
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
