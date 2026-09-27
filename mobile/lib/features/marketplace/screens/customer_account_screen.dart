import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/screens/orders_screen.dart';
import '../../cart/screens/order_tracking_screen.dart';
import '../../cart/screens/delivery_addresses_screen.dart';
import '../../cart/screens/wishlist_screen.dart';
import '../../finance/screens/milterra_wallet_screen.dart';
import '../widgets/store_design.dart';
import '../widgets/account_workspace.dart';
import 'help_support_screen.dart';

/// One persistent customer workspace; section URLs remain shareable and work
/// with browser Back, while the sidebar and visited panels stay mounted.
class CustomerAccountScreen extends ConsumerWidget {
  const CustomerAccountScreen(
      {super.key, this.section = AccountSection.overview, this.orderId});
  final AccountSection section;
  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final name = user?.name?.trim();
    final greeting =
        name == null || name.isEmpty ? 'Your account' : 'Hello, $name';
    void select(AccountSection value) => context.go(Uri(
            path: '/account',
            queryParameters: value == AccountSection.overview
                ? null
                : {'section': value.name})
        .toString());

    Widget panel(AccountSection value) => switch (value) {
          AccountSection.overview => _overview(context, greeting, select),
          AccountSection.orders => Column(children: [
              if (orderId != null)
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                        onPressed: () => select(AccountSection.orders),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Back to orders'))),
              Expanded(
                  child:
                      IndexedStack(index: orderId == null ? 0 : 1, children: [
                const OrdersScreen(embedded: true),
                if (orderId != null)
                  OrderTrackingScreen(
                      key: ValueKey(orderId),
                      orderId: orderId!,
                      embedded: true),
              ])),
            ]),
          AccountSection.addresses =>
            const DeliveryAddressesScreen(embedded: true),
          AccountSection.profile =>
            ListView(padding: const EdgeInsets.all(24), children: [
              const Text('Personal information', style: StoreType.heading),
              const SizedBox(height: 8),
              const Text('Details for your signed-in account.',
                  style: TextStyle(color: storeMuted)),
              const SizedBox(height: 24),
              _detail(
                  'Name', name == null || name.isEmpty ? 'Not provided' : name),
              _detail('Mobile number', user?.phone ?? 'Not provided'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                  onPressed: () => context.push('/profile'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile')),
            ]),
          AccountSection.wallet => AppConstants.separateCustomerAuth
              ? const _UnavailablePanel(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Wallet is currently unavailable',
                  message:
                      'Wallet balance and transaction history are currently unavailable.')
              : const MilterraWalletScreen(embedded: true),
          AccountSection.wishlist => AppConstants.separateCustomerAuth
              ? const _UnavailablePanel(
                  icon: Icons.favorite_border,
                  title: 'Wishlist is currently unavailable',
                  message:
                      'You can keep products in your basket while browsing.')
              : const WishlistScreen(embedded: true),
          AccountSection.help => const HelpSupportScreen(embedded: true),
        };

    return Scaffold(
        backgroundColor: storeCream,
        body: Column(children: [
          const StoreHeader(currentCategory: 'All'),
          Expanded(
              child: AccountWorkspace(
            key: ValueKey(user?.id),
            section: section,
            name: greeting,
            onSelect: select,
            panelBuilder: panel,
            onShop: () => context.go('/shop'),
            onSignOut: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          )),
        ]));
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: storeMuted, fontSize: 13)),
          const SizedBox(height: 6),
          Text(value, style: StoreType.body),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ]),
      );

  Widget _overview(BuildContext context, String greeting,
          ValueChanged<AccountSection> select) =>
      SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: StoreType.title),
            const SizedBox(height: 8),
            const Text('Everything for your shopping, in one place.',
                style: TextStyle(color: storeMuted)),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, bounds) {
              final columns = bounds.maxWidth >= 700 ? 2 : 1;
              return Wrap(spacing: 16, runSpacing: 16, children: [
                for (final value in AccountSection.values
                    .where((s) => s != AccountSection.overview))
                  SizedBox(
                    width: (bounds.maxWidth - (columns - 1) * 16) / columns,
                    child: Material(
                      color: storeWhite,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: storeBorder)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('account-card-${value.name}'),
                        onTap: () => select(value),
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: const Color(0xffeaf2ef),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(value.icon,
                                      color: storeGreen, size: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(value.label,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(value.description,
                                        style: const TextStyle(
                                            color: storeMuted, fontSize: 12))
                                  ])),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: storeMuted),
                            ])),
                      ),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 24),
            FilledButton.icon(
                onPressed: () => context.go('/shop'),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Continue shopping')),
          ],
        ),
      );
}

class _UnavailablePanel extends StatelessWidget {
  const _UnavailablePanel(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 40, color: storeGreen),
            const SizedBox(height: 20),
            Text(title, style: StoreType.heading),
            const SizedBox(height: 12),
            Text(message,
                style: const TextStyle(color: storeMuted, height: 1.6)),
          ],
        ),
      );
}
