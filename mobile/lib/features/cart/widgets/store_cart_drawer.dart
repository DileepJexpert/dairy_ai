import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/widgets/store_design.dart';

Future<void> showStoreCart(BuildContext context) async {
  final destination = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close cart',
    barrierColor: storeGreen.withValues(alpha: .3),
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : StoreLayout.motion,
    pageBuilder: (_, __, ___) => const _CartDrawer(),
    transitionBuilder: (_, animation, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero)
          .animate(animation),
      child: child,
    ),
  );
  if (destination != null && context.mounted) context.go(destination);
}

class _CartDrawer extends ConsumerWidget {
  const _CartDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);

    return Align(
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
              width: MediaQuery.sizeOf(context).width.clamp(0, 460),
              height: double.infinity,
              child: SafeArea(
                child: Column(
                  children: [
                    // Drawer Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: storeWhite,
                        border: Border(bottom: BorderSide(color: storeBorder)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_cart_outlined,
                              color: storeGreen, size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cartAsync.maybeWhen(
                                data: (cart) =>
                                    'Shopping Cart (${cart.itemCount} items)',
                                orElse: () => 'Shopping Cart',
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: storeGreen,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close cart',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: storeGreen),
                          ),
                        ],
                      ),
                    ),

                    // Quick Checkout & Free Delivery Banner (If cart has items)
                    cartAsync.maybeWhen(
                      data: (cart) {
                        if (cart.items.isEmpty) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xfff7faf9),
                            border:
                                Border(bottom: BorderSide(color: storeBorder)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      size: 16, color: Color(0xff067d62)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: RichText(
                                      text: const TextSpan(
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xff067d62)),
                                        children: [
                                          TextSpan(
                                            text: 'FREE Delivery ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(
                                              text: 'applied on this order'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    'Subtotal (${cart.itemCount} items): ',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xff0f1111),
                                    ),
                                  ),
                                  Text(
                                    storeMoney(cart.subtotal),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: storeOrange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 40,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: storeAmber,
                                    foregroundColor: storeGreen,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(
                                      context, '/marketplace/checkout'),
                                  child: Text(
                                    'Proceed to Checkout (${cart.itemCount} items)',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: storeGreen,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),

                    // Item List Body
                    Expanded(
                      child: cartAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Your cart could not be loaded.',
                                  style: StoreType.body),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () =>
                                    ref.read(cartProvider.notifier).refresh(),
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                        data: (cart) {
                          if (cart.items.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shopping_cart_outlined,
                                        size: 64, color: storeMuted),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Your Milterra Cart is empty',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Explore fresh A2 dairy foods, farm supplements, or modern machinery.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13, color: storeMuted),
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: storeAmber,
                                        foregroundColor: storeGreen,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, '/shop'),
                                      child: const Text('Start Shopping',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            itemCount: cart.items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 20),
                            itemBuilder: (context, index) {
                              final item = cart.items[index];
                              return _CartItemTile(item: item);
                            },
                          );
                        },
                      ),
                    ),

                    // Bottom Navigation Footer
                    cartAsync.maybeWhen(
                      data: (cart) => cart.items.isEmpty
                          ? const SizedBox.shrink()
                          : Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: storeWhite,
                                border:
                                    Border(top: BorderSide(color: storeBorder)),
                              ),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side:
                                            const BorderSide(color: storeBorder),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(
                                          context, '/marketplace/cart'),
                                      child: const Text(
                                        'View and Edit Full Cart',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: storeGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text(
                                      'Continue Shopping',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xff007185),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchedProduct = defaultMilterraProducts
        .where((x) => x.id == item.productId)
        .firstOrNull;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thumbnail Image
        InkWell(
          onTap: () =>
              Navigator.pop(context, '/shop/product/${item.productId}'),
          child: Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: storeWhite,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: storeBorder),
            ),
            child: item.primaryImage != null && item.primaryImage!.isNotEmpty
                ? Image.network(
                    item.primaryImage!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => matchedProduct != null
                        ? ProductArtwork(product: matchedProduct)
                        : const Icon(Icons.inventory_2_outlined,
                            color: storeMuted),
                  )
                : (matchedProduct != null
                    ? ProductArtwork(product: matchedProduct)
                    : const Icon(Icons.inventory_2_outlined,
                        color: storeMuted)),
          ),
        ),
        const SizedBox(width: 12),

        // Product Info Column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    Navigator.pop(context, '/shop/product/${item.productId}'),
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff007185),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                storeMoney(item.lineTotal),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: storeOrange,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.inStock ? 'In Stock' : 'Currently Unavailable',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.inStock
                      ? const Color(0xff067d62)
                      : const Color(0xffb12704),
                ),
              ),
              if (item.vendorName != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Sold by: ${item.vendorName}',
                  style: const TextStyle(fontSize: 11, color: storeMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),

              // Quantity Controls + Delete Action
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: storeWhite,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: storeBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: item.quantity > 1
                              ? () => ref
                                  .read(cartProvider.notifier)
                                  .update(item.id, item.quantity - 1)
                              : () => ref
                                  .read(cartProvider.notifier)
                                  .remove(item.id),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              item.quantity == 1
                                  ? Icons.delete_outline
                                  : Icons.remove,
                              size: 16,
                              color: storeGreen,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff0f1111),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: item.quantity < item.availableQuantity
                              ? () => ref
                                  .read(cartProvider.notifier)
                                  .update(item.id, item.quantity + 1)
                              : null,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.add,
                                size: 16, color: storeGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () =>
                        ref.read(cartProvider.notifier).remove(item.id),
                    child: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff007185),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
