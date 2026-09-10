import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../models/product_models.dart';
import '../../../app/store_theme.dart';
import '../../commerce/providers/commerce_provider.dart';
export '../../../app/store_theme.dart';

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
  if (p.category == ProductCategory.equipment) return 'Equipment';
  final name = p.title.toLowerCase();
  if (name.contains('paneer')) return 'Paneer';
  if (name.contains('ghee') && name.contains('buffalo')) return 'Buffalo ghee';
  if (name.contains('ghee')) return 'Cow ghee';
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
      if (category != null && category != 'All products') 'category': category,
      if (query != null && query.isNotEmpty) 'query': query,
    }).toString());

class StoreHeader extends ConsumerWidget {
  const StoreHeader({super.key, this.search});
  final Widget? search;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final count = user == null ? 0 : ref.watch(cartItemCountProvider);
    final canAdmin = user != null &&
        ref.watch(commerceAccessProvider).valueOrNull?['can_manage_taxonomy'] ==
            true;
    final searchField = search ??
        TextField(
            key: const ValueKey('store-search'),
            style: StoreType.body,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) => storeBrowse(context, query: value.trim()),
            decoration: const InputDecoration(
                hintText: 'Search ghee, paneer and more…',
                prefixIcon: Icon(Icons.search, size: 20),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8)));
    return ColoredBox(
        color: storeCream,
        child: SafeArea(
            bottom: false,
            child: Center(
                child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                    child: LayoutBuilder(builder: (context, bounds) {
                      final small = bounds.maxWidth < StoreLayout.tablet;
                      return Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: small ? 16 : 32, vertical: 10),
                          child: Column(children: [
                            Row(children: [
                              Flexible(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Semantics(
                                          button: true,
                                          label: 'Milterra home',
                                          child: InkWell(
                                              onTap: () => context.go('/shop'),
                                              child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                        Icons.spa_outlined,
                                                        color: storeGold,
                                                        size: 24),
                                                    const SizedBox(width: 7),
                                                    Text('milterra',
                                                        style: StoreType.logo
                                                            .copyWith(
                                                                fontSize: small
                                                                    ? 32
                                                                    : 37)),
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                top: 12),
                                                        child: Text('.in',
                                                            style: StoreType
                                                                .logoSuffix)),
                                                  ]))))),
                              const Spacer(),
                              if (!small) ...[
                                SizedBox(
                                    width: bounds.maxWidth > 1100
                                        ? StoreLayout.headerSearchWidth
                                        : 250,
                                    height: 43,
                                    child: searchField),
                                const SizedBox(width: StoreLayout.lg),
                              ],
                              if (bounds.maxWidth > 1120)
                                TextButton(
                                    onPressed: () => storeAccountRoute(
                                        context, ref, '/marketplace/orders'),
                                    child: const Text('Your orders')),
                              IconButton(
                                  tooltip:
                                      user == null ? 'Sign in' : 'Your account',
                                  onPressed: () => storeAccountRoute(
                                      context, ref, '/marketplace/orders'),
                                  icon: const Icon(Icons.person_outline,
                                      color: storeGreen)),
                              if (canAdmin)
                                IconButton(
                                    tooltip: 'Commerce admin',
                                    onPressed: () =>
                                        context.go('/admin/commerce'),
                                    icon: const Icon(
                                        Icons.admin_panel_settings_outlined,
                                        color: storeGreen)),
                              IconButton(
                                  tooltip: 'Shopping cart',
                                  onPressed: () {
                                    if (user == null) {
                                      storeAccountRoute(
                                          context, ref, '/marketplace/cart');
                                    } else {
                                      showStoreCart(context);
                                    }
                                  },
                                  icon: Badge(
                                      isLabelVisible: count > 0,
                                      label: Text('$count'),
                                      backgroundColor: storeGreen,
                                      textColor: storeWhite,
                                      child: const Icon(
                                          Icons.shopping_bag_outlined,
                                          color: storeGreen,
                                          size: 24))),
                            ]),
                            if (small) ...[
                              const SizedBox(height: 8),
                              SizedBox(height: 43, child: searchField)
                            ],
                          ]));
                    })))));
  }
}

/// Identical category navigation on collection and product pages.
class StoreCategoryNavigation extends ConsumerWidget {
  const StoreCategoryNavigation(
      {super.key,
      this.selected = 'All products',
      this.onSelected,
      this.legacyEquipment = false});
  final String selected;
  final ValueChanged<String>? onSelected;
  final bool legacyEquipment;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taxonomy = ref.watch(taxonomyProvider).valueOrNull;
    final entries = <String, String>{
      'All products': 'All products',
      if (taxonomy?.enabled == true)
        for (final node in taxonomy!.nodes) node.id: node.name
      else if (legacyEquipment)
        'Equipment': 'Equipment'
      else ...{
        'Cow ghee': 'Cow ghee',
        'Buffalo ghee': 'Buffalo ghee',
        'Paneer': 'Paneer',
        'Other products': 'Other products'
      }
    };
    return Container(
        height: 45,
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: storeBorder))),
        child: Center(
            child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: entries.entries
                        .map((entry) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: TextButton(
                                  onPressed: () => onSelected != null
                                      ? onSelected!(entry.key)
                                      : storeBrowse(context,
                                          category: entry.key),
                                  child: Text(entry.value,
                                      style: StoreType.navigation(
                                          entry.key == selected))),
                            ))
                        .toList()))));
  }
}

abstract final class StoreImages {
  static const hero = 'assets/store/hero.png';
  static String? category(String kind) => switch (kind.toLowerCase()) {
        'cow ghee' || 'cow-ghee' => 'assets/store/cow-ghee.png',
        'buffalo ghee' || 'buffalo-ghee' => 'assets/store/buffalo-ghee.png',
        'paneer' => 'assets/store/paneer.png',
        _ => null,
      };
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
    final asset = StoreImages.category(p == null ? kind : storeCategory(p));
    Widget placeholder() => const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, size: 42, color: storeMuted),
          SizedBox(height: 8),
          Text('Photo not available', style: StoreType.caption)
        ]));
    Widget concept() => asset == null
        ? placeholder()
        : Stack(fit: StackFit.expand, children: [
            Image.asset(asset,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => placeholder()),
            if (showCaption)
              const Positioned(
                  bottom: 5,
                  left: 4,
                  right: 4,
                  child: Text('Packaging concept',
                      textAlign: TextAlign.center, style: StoreType.caption)),
          ]);
    return p == null || p.media.isEmpty
        ? concept()
        : Image.network(p.media[imageIndex.clamp(0, p.media.length - 1)],
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => concept());
  }
}

class StoreFooter extends StatelessWidget {
  const StoreFooter({super.key});
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      color: storeGreen,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
              child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 40,
                  runSpacing: 28,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('milterra.in',
                              style:
                                  StoreType.logo.copyWith(color: storeWhite)),
                          const SizedBox(height: 8),
                          const Text('Good food. Thoughtfully chosen.',
                              style: StoreType.onDark),
                        ]),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EXPLORE', style: StoreType.footerLabel),
                          TextButton(
                              onPressed: () => context.go('/shop'),
                              child: const Text('Shop the collection',
                                  style: StoreType.inverseLabel)),
                        ]),
                    const SizedBox(
                        width: 280,
                        child: Text(
                            'Browse products, compare pack sizes and find something for your everyday kitchen.',
                            style: StoreType.onDark)),
                  ]))));
}
