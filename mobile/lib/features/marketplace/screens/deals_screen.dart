import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/store_product_card.dart';
import '../../cart/providers/cart_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Published stock is authoritative. No synthetic discounts or countdowns.
class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        backgroundColor: storeCream,
        body: Column(children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Deals'),
          Expanded(
              child: SingleChildScrollView(
                  child: Column(children: [
            Center(
                child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Today's Deals",
                                  style: StoreType.title),
                              const SizedBox(height: 12),
                              const Text(
                                  'No verified promotional offers are published yet. Browse current catalogue prices below.'),
                              const SizedBox(height: 20),
                              ref.watch(productsProvider(null)).when(
                                    loading: () => const Center(
                                        child: CircularProgressIndicator()),
                                    error: (_, __) => TextButton(
                                        onPressed: () => ref
                                            .invalidate(productsProvider(null)),
                                        child: const Text('Retry catalogue')),
                                    data: (products) => LayoutBuilder(
                                        builder: (context, space) {
                                      final columns = space.maxWidth >= 960
                                          ? 4
                                          : space.maxWidth >= 650
                                              ? 3
                                              : space.maxWidth >= 380
                                                  ? 2
                                                  : 1;
                                      return Wrap(
                                          spacing: 16,
                                          runSpacing: 16,
                                          children: storeProductGroups(products
                                                  .where((p) => !p.isConcept)
                                                  .toList())
                                              .map((group) => SizedBox(
                                                  width: (space.maxWidth -
                                                          16 * (columns - 1)) /
                                                      columns,
                                                  child: StoreProductCard(
                                                    packs: group,
                                                    onOpen: (p) => context.push(
                                                        '/shop/product/${p.id}'),
                                                    onAdd: (p) async {
                                                      if (ref.read(
                                                              currentUserProvider) ==
                                                          null) {
                                                        context.go(
                                                            '/login?next=/deals');
                                                        return;
                                                      }
                                                      try {
                                                        await ref
                                                            .read(cartProvider
                                                                .notifier)
                                                            .add(
                                                                p.id,
                                                                p.minOrderQuantity,
                                                                p);
                                                        if (context.mounted)
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                                  const SnackBar(
                                                                      content: Text(
                                                                          'Added to cart')));
                                                      } catch (_) {
                                                        if (context.mounted)
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                                  const SnackBar(
                                                                      content: Text(
                                                                          'Could not add item. Please try again.')));
                                                      }
                                                    },
                                                  )))
                                              .toList());
                                    }),
                                  ),
                            ])))),
            const StoreFooter(),
          ]))),
        ]),
      );
}
