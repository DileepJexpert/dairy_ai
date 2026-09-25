import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_provider.dart';
import '../widgets/store_design.dart';

/// Storefront entry point for customer-owned pages.
class CustomerAccountScreen extends ConsumerWidget {
  const CustomerAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final firstName = user?.name?.trim().split(' ').first;
    final greeting = firstName == null || firstName.isEmpty
        ? 'Your account'
        : 'Hello, $firstName';

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Your Account'),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final mobile = constraints.maxWidth < StoreLayout.tablet;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: StoreLayout.maxWidth),
                        child: Padding(
                          padding: EdgeInsets.all(mobile ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton(
                                onPressed: () => context.go('/shop'),
                                child: const Text('Milterra › Your Account'),
                              ),
                              const SizedBox(height: 12),
                              Text(greeting, style: StoreType.title),
                              const SizedBox(height: 6),
                              const Text(
                                'Manage your orders, delivery details, saved products, and account.',
                                style: TextStyle(color: storeMuted),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _tile(
                                      context,
                                      constraints.maxWidth,
                                      Icons.inventory_2_outlined,
                                      'Orders & returns',
                                      'Track orders and request a cancellation or return.',
                                      '/marketplace/orders'),
                                  _tile(
                                      context,
                                      constraints.maxWidth,
                                      Icons.location_on_outlined,
                                      'Delivery addresses',
                                      'Add, edit, or select your delivery address.',
                                      '/marketplace/addresses'),
                                  _tile(
                                      context,
                                      constraints.maxWidth,
                                      Icons.favorite_border,
                                      'Wishlist',
                                      'See the products in your wishlist.',
                                      '/wishlist'),
                                  _tile(
                                      context,
                                      constraints.maxWidth,
                                      Icons.bookmark_border,
                                      'Saved for later',
                                      'Resume items you moved out of your cart.',
                                      '/marketplace/cart'),
                                  _tile(
                                      context,
                                      constraints.maxWidth,
                                      Icons.account_balance_wallet_outlined,
                                      'Wallet & history',
                                      'Check wallet availability and transaction history.',
                                      '/balance'),
                                  _tile(
                                      context,
                                      constraints.maxWidth,
                                      Icons.person_outline,
                                      'Your profile',
                                      'Update your name and account preferences.',
                                      '/profile'),
                                  _tile(
                                      context,
                                      constraints.maxWidth,
                                      Icons.help_outline,
                                      'Help & support',
                                      'Get help with an order or your account.',
                                      '/help'),
                                ],
                              ),
                              const SizedBox(height: 24),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(authProvider.notifier)
                                      .logout();
                                  if (context.mounted) context.go('/shop');
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Sign out'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const StoreFooter(),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, double viewportWidth, IconData icon,
      String title, String subtitle, String route) {
    final width = viewportWidth < StoreLayout.tablet
        ? viewportWidth - 32
        : viewportWidth < 1150
            ? (viewportWidth - 64) / 2
            : (StoreLayout.maxWidth - 80) / 3;
    return SizedBox(
      width: width,
      child: Material(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        child: InkWell(
          key: ValueKey('account-tile-$route'),
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 118),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(color: storeBorder),
              borderRadius: BorderRadius.circular(StoreLayout.radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: storeGreen, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: storeGreen)),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style:
                              const TextStyle(fontSize: 13, color: storeMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: storeMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
