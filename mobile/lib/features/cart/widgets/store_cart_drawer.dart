import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/cart_provider.dart';
import '../../marketplace/widgets/store_design.dart';

Future<void> showStoreCart(BuildContext context) async {
  final destination = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close shopping bag',
    barrierColor: storeGreen.withValues(alpha: .25),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : StoreLayout.motion,
    pageBuilder: (_, __, ___) => const _CartDrawer(),
    transitionBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(animation),
        child: child),
  );
  if (destination != null && context.mounted) context.push(destination);
}

class _CartDrawer extends ConsumerWidget {
  const _CartDrawer();
  @override
  Widget build(BuildContext context, WidgetRef ref) => Align(
      alignment: Alignment.centerRight,
      child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.pop(context),
          },
          child: Focus(
              autofocus: true,
              child: Material(
                  color: storeCream,
                  child: SizedBox(
                      width: MediaQuery.sizeOf(context).width.clamp(0, 440),
                      height: double.infinity,
                      child: SafeArea(
                          child: Padding(
                              padding: StoreLayout.panelPadding,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Expanded(
                                          child: Text('Your shopping bag',
                                              style: StoreType.heading)),
                                      IconButton(
                                          tooltip: 'Close shopping bag',
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          icon: const Icon(Icons.close)),
                                    ]),
                                    const Divider(),
                                    Expanded(
                                        child: ref.watch(cartProvider).when(
                                              loading: () => const Center(
                                                  child:
                                                      CircularProgressIndicator()),
                                              error: (_, __) => Center(
                                                  child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                    const Text(
                                                        'Your bag could not be loaded.',
                                                        style: StoreType.body),
                                                    TextButton(
                                                        onPressed: () => ref
                                                            .read(cartProvider
                                                                .notifier)
                                                            .refresh(),
                                                        child: const Text(
                                                            'Try again')),
                                                  ])),
                                              data: (cart) => cart.items.isEmpty
                                                  ? const Center(
                                                      child: Text(
                                                          'Your bag is waiting for something good.',
                                                          style:
                                                              StoreType.body))
                                                  : ListView.separated(
                                                      itemCount:
                                                          cart.items.length,
                                                      separatorBuilder:
                                                          (_, __) =>
                                                              const Divider(),
                                                      itemBuilder: (_, index) {
                                                        final item =
                                                            cart.items[index];
                                                        return Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Container(
                                                                  width: 64,
                                                                  height: 76,
                                                                  color:
                                                                      storeWarm,
                                                                  child: item.primaryImage ==
                                                                          null
                                                                      ? const Icon(
                                                                          Icons
                                                                              .shopping_bag_outlined,
                                                                          color:
                                                                              storeMuted)
                                                                      : Image.network(
                                                                          item
                                                                              .primaryImage!,
                                                                          fit: BoxFit
                                                                              .contain,
                                                                          errorBuilder: (_, __, ___) =>
                                                                              const Icon(Icons.shopping_bag_outlined))),
                                                              const SizedBox(
                                                                  width: 16),
                                                              Expanded(
                                                                  child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                    Text(
                                                                        item
                                                                            .title,
                                                                        style: StoreType
                                                                            .cardTitle),
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    Text(
                                                                        'Quantity: ${item.quantity}',
                                                                        style: StoreType
                                                                            .muted),
                                                                    if (item
                                                                        .priceChanged)
                                                                      const Text(
                                                                          'Price changed. Review your cart.',
                                                                          style:
                                                                              StoreType.muted),
                                                                    if (!item
                                                                        .inStock)
                                                                      const Text(
                                                                          'Currently unavailable',
                                                                          style:
                                                                              StoreType.muted),
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    Text(
                                                                        storeMoney(item
                                                                            .lineTotal),
                                                                        style: StoreType
                                                                            .label),
                                                                  ])),
                                                            ]);
                                                      }),
                                            )),
                                    ref.watch(cartProvider).maybeWhen(
                                        data: (cart) => cart.items.isEmpty
                                            ? const SizedBox.shrink()
                                            : Column(children: [
                                                const Divider(),
                                                Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      const Text('Subtotal',
                                                          style:
                                                              StoreType.body),
                                                      Text(
                                                          storeMoney(
                                                              cart.subtotal),
                                                          style:
                                                              StoreType.price),
                                                    ]),
                                                const SizedBox(height: 8),
                                                const Text(
                                                    'Select your address and review your order at checkout.',
                                                    style: StoreType.muted),
                                                const SizedBox(height: 20),
                                                SizedBox(
                                                    width: double.infinity,
                                                    child: FilledButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context,
                                                                '/marketplace/checkout'),
                                                        child: const Text(
                                                            'Proceed to checkout'))),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context,
                                                            '/marketplace/cart'),
                                                    child: const Text(
                                                        'View and edit cart')),
                                              ]),
                                        orElse: () => const SizedBox.shrink()),
                                    SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                                'Continue shopping'))),
                                  ]))))))));
}
