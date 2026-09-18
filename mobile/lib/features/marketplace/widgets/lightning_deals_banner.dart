import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../providers/merchandising_provider.dart';
import 'store_product_card.dart';
import 'store_design.dart';

/// All promoted products, prices and campaign dates come from the backend.
class LightningDealsRail extends ConsumerWidget {
  const LightningDealsRail(
      {super.key, this.title = "Today's Deals & Lightning Offers"});
  final String title;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(storefrontPlacementsProvider);
    return result.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => TextButton(
          onPressed: () => ref.invalidate(storefrontPlacementsProvider),
          child: const Text('Could not load offers. Retry')),
      data: (placements) {
        final deals = placements
            .where((p) =>
                p.placementType == 'deal' ||
                p.placementType == 'festival_offer')
            .toList();
        if (deals.isEmpty) return const SizedBox.shrink();
        return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: deals
                          .map((deal) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                    width: 260,
                                    child: StoreProductCard(
                                      packs: [deal.product],
                                      onOpen: (p) =>
                                          context.push('/shop/product/${p.id}'),
                                      onAdd: (p) async {
                                        if (ref.read(currentUserProvider) ==
                                            null) {
                                          context.push(
                                              '/login?next=/shop/product/${p.id}');
                                          return;
                                        }
                                        try {
                                          await ref
                                              .read(cartProvider.notifier)
                                              .add(p.id, p.minOrderQuantity, p);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content:
                                                        Text('Added to cart'),
                                                    backgroundColor:
                                                        storeGreen));
                                          }
                                        } catch (_) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Could not add this product. Please retry.')));
                                          }
                                        }
                                      },
                                    )),
                              ))
                          .toList(),
                    )),
              ],
            ));
      },
    );
  }
}
