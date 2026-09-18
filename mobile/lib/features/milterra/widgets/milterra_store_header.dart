import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/store_theme.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/providers/wishlist_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';

/// Minimal, elegant luxury header exclusively for Milterra D2C Ghee & Vedic Dairy.
class MilterraStoreHeader extends ConsumerWidget {
  const MilterraStoreHeader({
    super.key,
    this.selectedCategory = 'All',
    this.onSearch,
    this.searchController,
  });

  final String selectedCategory;
  final ValueChanged<String>? onSearch;
  final TextEditingController? searchController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItemCount = ref.watch(cartItemCountProvider);
    final wishlist = ref.watch(wishlistProvider);
    final authState = ref.watch(authProvider);
    final user = authState.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );

    return Container(
      decoration: const BoxDecoration(
        color: storeGreen,
        border: Border(bottom: BorderSide(color: Color(0xff1f4d41), width: 1)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Minimal Milterra Brand Logo
                InkWell(
                  onTap: () => context.go('/shop'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: storeGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.spa, color: storeGold, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'MILTERRA',
                            style: TextStyle(
                              color: storeGold,
                              fontFamily: 'CormorantGaramond',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'VEDIC BILONA GHEE & PURE DAIRY',
                            style: TextStyle(
                              color: StorePalette.onDark,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Search Bar (Flexible)
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: storeWhite,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      onSubmitted: onSearch,
                      style: const TextStyle(fontSize: 13, color: storeText),
                      decoration: const InputDecoration(
                        hintText: 'Search A2 Gir Cow Ghee, Buffalo Bilona Ghee, Malai Paneer...',
                        hintStyle: TextStyle(fontSize: 12, color: storeMuted),
                        prefixIcon: Icon(Icons.search, size: 18, color: storeGreen),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Switch to Farmer Hub link
                InkWell(
                  onTap: () => context.go('/marketplace'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: storeGold.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.agriculture, color: storeGold, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Farmer Hub (Machinery & Mandi) →',
                          style: TextStyle(
                            color: storeGold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Account
                InkWell(
                  onTap: () {
                    if (user == null) {
                      context.push('/login');
                    } else {
                      context.push('/profile');
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.person_outline, color: storeWhite, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        user != null ? (user.name ?? 'Account') : 'Sign In',
                        style: const TextStyle(
                          color: storeWhite,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Wishlist
                InkWell(
                  onTap: () => context.push('/wishlist'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.favorite_outline, color: storeWhite, size: 20),
                      if (wishlist.isNotEmpty)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: storeOrange,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${wishlist.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Cart Drawer Trigger
                InkWell(
                  onTap: () => showStoreCart(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: storeGold,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: storeGreen, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$cartItemCount',
                          style: const TextStyle(
                            color: storeGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
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
}

/// Minimal, clean category sub-navigation for Milterra Ghee storefront
class MilterraCategoryNav extends StatelessWidget {
  const MilterraCategoryNav({
    super.key,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  static const List<Map<String, dynamic>> categories = [
    {'name': 'All Ghee', 'icon': Icons.local_fire_department_outlined},
    {'name': 'A2 Desi Cow Ghee', 'icon': Icons.spa_outlined},
    {'name': 'Rich Buffalo Ghee', 'icon': Icons.water_drop_outlined},
    {'name': 'Herbal Infused Ghee', 'icon': Icons.eco_outlined},
    {'name': 'Malai Paneer & Makhan', 'icon': Icons.lunch_dining_outlined},
    {'name': 'Puja & Hawan Samagri', 'icon': Icons.wb_sunny_outlined},
    {'name': '🌱 MILTERRA Earth Soil', 'icon': Icons.yard_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: storeDarkGreenNav,
        border: Border(bottom: BorderSide(color: storeSubNav)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: categories.map((cat) {
                final name = cat['name'] as String;
                final icon = cat['icon'] as IconData;
                final isSelected = selectedCategory == name ||
                    (selectedCategory == 'All products' && name == 'All Ghee');

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onSelectCategory(name),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? storeGold
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: isSelected ? storeGreen : StorePalette.onDark,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: TextStyle(
                              color: isSelected ? storeGreen : StorePalette.onDark,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
