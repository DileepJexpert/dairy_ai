import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/coupon_provider.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/widgets/store_product_card.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isGift = false;
  final Set<String> _busyIds = {};
  final _couponCtrl = TextEditingController();
  String? _couponError;

  Future<void> _saveForLater(CartItem item) async {
    setState(() => _busyIds.add(item.id));
    try {
      await ref.read(cartProvider.notifier).remove(item.id);
      ref.read(savedForLaterProvider.notifier).save(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} moved to Saved for later.'),
            action: SnackBarAction(
              label: 'Move to Cart',
              onPressed: () => _moveToCart(item),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save item for later.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  Future<void> _moveToCart(CartItem item) async {
    setState(() => _busyIds.add(item.id));
    try {
      await ref.read(cartProvider.notifier).add(item.productId, item.quantity);
      ref.read(savedForLaterProvider.notifier).remove(item.productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text('${item.title} moved back to your cart.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not move item to cart.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(item.id));
    }
  }

  void _removeSavedItem(CartItem item) {
    ref.read(savedForLaterProvider.notifier).remove(item.productId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed ${item.title} from saved items.')),
    );
  }

  Future<void> _updateQty(String itemId, int qty) async {
    setState(() => _busyIds.add(itemId));
    try {
      if (qty <= 0) {
        await ref.read(cartProvider.notifier).remove(itemId);
      } else {
        await ref.read(cartProvider.notifier).update(itemId, qty);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update quantity. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(itemId));
    }
  }

  Future<void> _removeItem(String itemId) async {
    setState(() => _busyIds.add(itemId));
    try {
      await ref.read(cartProvider.notifier).remove(itemId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove item. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(itemId));
    }
  }

  Future<void> _addRecommendedItem(Product p) async {
    setState(() => _busyIds.add(p.id));
    try {
      await ref.read(cartProvider.notifier).add(p.id, p.minOrderQuantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text('Added ${p.title} to your cart.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add item to cart.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final savedForLater = ref.watch(savedForLaterProvider);

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Amazon Top Navigation
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Shopping Cart'),

          // Main Responsive Cart Body
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 960;
                final isMobile = constraints.maxWidth < StoreLayout.tablet;

                return cartAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Your cart could not be loaded.',
                          style: StoreType.heading,
                        ),
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
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: StoreLayout.maxWidth),
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 12 : 24),
                                child: cart.items.isEmpty
                                    ? _buildEmptyCart(context, savedForLater)
                                    : (isDesktop
                                        ? Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Left Column: Items List & Recommendations
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    _buildCartItemsCard(
                                                        cart, isMobile),
                                                    if (savedForLater
                                                        .isNotEmpty) ...[
                                                      const SizedBox(
                                                          height: 24),
                                                      _buildSavedForLaterCard(
                                                          isMobile, savedForLater),
                                                    ],
                                                    const SizedBox(height: 24),
                                                    _buildRecommendationsRail(
                                                        cart),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 24),

                                              // Right Column: Amazon Buy Box Sidebar
                                              SizedBox(
                                                width: 320,
                                                child: _buildAmazonBuyBox(
                                                    cart, context),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Mobile View: Buy Box on top
                                              _buildAmazonBuyBox(cart, context),
                                              const SizedBox(height: 16),
                                              _buildCartItemsCard(cart, isMobile),
                                              if (savedForLater
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 24),
                                                _buildSavedForLaterCard(
                                                    isMobile, savedForLater),
                                              ],
                                              const SizedBox(height: 24),
                                              _buildRecommendationsRail(cart),
                                            ],
                                          )),
                              ),
                            ),
                          ),
                          const StoreFooter(),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(
      BuildContext context, List<CartItem> savedForLater) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: Column(
            children: [
              const Icon(Icons.shopping_cart_outlined,
                  size: 72, color: storeMuted),
              const SizedBox(height: 16),
              const Text(
                'Your Milterra Cart is empty.',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Explore fresh pure A2 Desi Cow Ghee, high-protein cattle feed, or farm machinery.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: storeMuted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 42,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: storeAmber,
                    foregroundColor: storeGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21)),
                  ),
                  onPressed: () => context.go('/shop'),
                  child: const Text(
                    "Shop Today's Fresh Products",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (savedForLater.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSavedForLaterCard(false, savedForLater),
        ],
        const SizedBox(height: 32),
        const Text(
          'Popular products across Milterra',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 16),
        _buildPopularGrid(),
      ],
    );
  }

  Widget _buildCartItemsCard(Cart cart, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Shopping Cart',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
              if (!isMobile)
                const Text(
                  'Price',
                  style: TextStyle(fontSize: 13, color: storeMuted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => ref.read(cartProvider.notifier).clear(),
            child: const Text(
              'Deselect all items / Clear Cart',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xff007185),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 24),

          // List of cart items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => const Divider(height: 28),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              final matchedProduct = defaultMilterraProducts
                  .where((x) => x.id == item.productId)
                  .firstOrNull;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Thumbnail
                  InkWell(
                    onTap: () =>
                        context.go('/shop/product/${item.productId}'),
                    child: Container(
                      width: isMobile ? 80 : 110,
                      height: isMobile ? 80 : 110,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: storeWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: storeBorder),
                      ),
                      child: item.primaryImage != null &&
                              item.primaryImage!.isNotEmpty
                          ? Image.network(
                              item.primaryImage!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => matchedProduct !=
                                      null
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
                  const SizedBox(width: 16),

                  // Middle details column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () =>
                              context.go('/shop/product/${item.productId}'),
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff007185),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.inStock ? 'In Stock' : 'Currently Unavailable',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: item.inStock
                                ? const Color(0xff067d62)
                                : const Color(0xffb12704),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Eligible for FREE Shipping',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xff565959)),
                        ),
                        if (item.vendorName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Sold by: ${item.vendorName}',
                            style: const TextStyle(
                                fontSize: 11, color: storeMuted),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Stepper + Actions Row
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
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
                                    onTap: _busyIds.contains(item.id)
                                        ? null
                                        : () => _updateQty(
                                            item.id, item.quantity - 1),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: (_busyIds.contains(item.id) ||
                                            item.quantity >=
                                                item.availableQuantity)
                                        ? null
                                        : () => _updateQty(
                                            item.id, item.quantity + 1),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.add,
                                          size: 16, color: storeGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _busyIds.contains(item.id)
                                  ? null
                                  : () => _removeItem(item.id),
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff007185),
                                ),
                              ),
                            ),
                            const Text('|',
                                style: TextStyle(color: storeBorder)),
                            InkWell(
                              onTap: _busyIds.contains(item.id)
                                  ? null
                                  : () => _saveForLater(item),
                              child: const Text(
                                'Save for later',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff007185),
                                ),
                              ),
                            ),
                            if (!isMobile) ...[
                              const Text('|',
                                  style: TextStyle(color: storeBorder)),
                              InkWell(
                                onTap: () {},
                                child: const Text(
                                  'Share',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xff007185),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Price on Right
                  const SizedBox(width: 16),
                  Text(
                    storeMoney(item.lineTotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: storeOrange,
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 32),

          // Subtotal Footer
          Align(
            alignment: Alignment.centerRight,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xff0f1111),
                ),
                children: [
                  TextSpan(
                    text: 'Subtotal (${cart.itemCount} items): ',
                  ),
                  TextSpan(
                    text: storeMoney(cart.subtotal),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: storeOrange,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmazonBuyBox(Cart cart, BuildContext context) {
    final appliedCoupon = ref.watch(appliedCouponProvider);
    final discount = appliedCoupon?.calculateDiscount(cart.subtotal) ?? 0.0;
    final finalTotal = (cart.subtotal - discount).clamp(0.0, double.infinity);

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Free Delivery Indicator
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle,
                  size: 18, color: Color(0xff067d62)),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style:
                        TextStyle(fontSize: 12, color: Color(0xff067d62)),
                    children: [
                      TextSpan(
                        text: 'Your order qualifies for FREE Delivery. ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'Select this option at checkout.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subtotal & Discount breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items Subtotal (${cart.itemCount} items):',
                  style: const TextStyle(fontSize: 13, color: Color(0xff565959))),
              Text(storeMoney(cart.subtotal),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xff0f1111))),
            ],
          ),
          if (appliedCoupon != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_offer, size: 14, color: Color(0xff067d62)),
                    const SizedBox(width: 4),
                    Text('Promotion (${appliedCoupon.code}):',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff067d62))),
                  ],
                ),
                Text('-${storeMoney(discount)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xff067d62))),
              ],
            ),
          ],
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
              Text(
                storeMoney(finalTotal),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: storeOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Gift Checkbox
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _isGift,
                  activeColor: storeGreen,
                  onChanged: (val) => setState(() => _isGift = val ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'This order contains a gift',
                style: TextStyle(fontSize: 12, color: Color(0xff0f1111)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Proceed to Buy Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: storeAmber,
                foregroundColor: storeGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                ),
              ),
              onPressed: () => context.push('/marketplace/checkout'),
              child: Text(
                'Proceed to Buy (${cart.itemCount} items)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: storeGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Amazon Coupons & Vouchers Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff8faf9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: storeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.discount_outlined, size: 16, color: storeGreen),
                    SizedBox(width: 6),
                    Text('Promotions & Coupons',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                  ],
                ),
                const SizedBox(height: 8),
                if (appliedCoupon != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xffe8f5e9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xffa5d6a7)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Coupon: ${appliedCoupon.code}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff1b5e20))),
                              Text('Saved ${storeMoney(discount)} on this order',
                                  style: const TextStyle(fontSize: 11, color: Color(0xff2e7d32))),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(appliedCouponProvider.notifier).removeCoupon();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Coupon removed')),
                            );
                          },
                          child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: TextField(
                            controller: _couponCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: 'Enter promo code',
                              hintStyle: const TextStyle(fontSize: 11, color: storeMuted),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: storeBorder)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: storeGreen)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 34,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: storeWhite,
                            foregroundColor: storeGreen,
                            side: const BorderSide(color: storeGreen),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: () {
                            final success = ref.read(appliedCouponProvider.notifier).applyCoupon(_couponCtrl.text, cart.subtotal);
                            if (success) {
                              _couponCtrl.clear();
                              setState(() => _couponError = null);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Coupon applied successfully!'), backgroundColor: storeGreen),
                              );
                            } else {
                              setState(() => _couponError = 'Invalid code or minimum order not met.');
                            }
                          },
                          child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  if (_couponError != null) ...[
                    const SizedBox(height: 4),
                    Text(_couponError!, style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ],
                  const SizedBox(height: 8),
                  const Text('Available offers (Tap to apply):', style: TextStyle(fontSize: 10, color: storeMuted)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: availableStoreCoupons.map((c) {
                      return InkWell(
                        onTap: () {
                          final ok = ref.read(appliedCouponProvider.notifier).applyCoupon(c.code, cart.subtotal);
                          if (ok) {
                            setState(() => _couponError = null);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Applied ${c.code}!'), backgroundColor: storeGreen),
                            );
                          } else {
                            setState(() => _couponError = 'Min order for ${c.code} is ${storeMoney(c.minOrderAmount)}');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: storeAmber, width: 1),
                          ),
                          child: Text('${c.code} (${c.discountPercent > 0 ? "${c.discountPercent.toInt()}% Off" : "₹${c.discountAmount.toInt()} Off"})',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeGreen)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Trust & Protection
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfff7faf9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: storeBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: storeGreen),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% Purchase Protection with Milterra Guarantee',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: storeGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedForLaterCard(bool isMobile, List<CartItem> savedForLater) {
    if (savedForLater.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved for later (${savedForLater.length} ${savedForLater.length == 1 ? 'item' : 'items'})',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: storeGreen,
            ),
          ),
          const Divider(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: savedForLater.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final item = savedForLater[index];
              final matchedProduct = defaultMilterraProducts
                  .where((x) => x.id == item.productId)
                  .firstOrNull;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Artwork / Thumbnail
                  InkWell(
                    onTap: () =>
                        context.go('/shop/product/${item.productId}'),
                    child: Container(
                      width: isMobile ? 80 : 100,
                      height: isMobile ? 80 : 100,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: storeWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: storeBorder),
                      ),
                      child: item.primaryImage != null &&
                              item.primaryImage!.isNotEmpty
                          ? Image.network(
                              item.primaryImage!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => matchedProduct !=
                                      null
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
                  const SizedBox(width: 16),

                  // Item Details & Actions
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () =>
                              context.go('/shop/product/${item.productId}'),
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xff007185),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          storeMoney(item.currentPrice),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: storeOrange,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'In Stock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff067d62),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons: Move to cart & Delete
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: storeAmber,
                                foregroundColor: storeGreen,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _busyIds.contains(item.id)
                                  ? null
                                  : () => _moveToCart(item),
                              child: const Text('Move to cart'),
                            ),
                            InkWell(
                              onTap: _busyIds.contains(item.id)
                                  ? null
                                  : () => _removeSavedItem(item),
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
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsRail(Cart cart) {
    // Recommend products not currently in the cart
    final cartProductIds = cart.items.map((e) => e.productId).toSet();
    final recommended = defaultMilterraProducts
        .where((p) => !cartProductIds.contains(p.id))
        .take(4)
        .toList();

    if (recommended.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customers who bought items in your cart also bought',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: recommended.map((p) {
              final cardWidth = isMobile
                  ? ((constraints.maxWidth - 16) / 2).clamp(140.0, 300.0)
                  : ((constraints.maxWidth - 48) / 4).clamp(180.0, 320.0);

              return SizedBox(
                width: cardWidth,
                child: StoreProductCard(
                  packs: [p],
                  compact: isMobile,
                  busyIds: _busyIds,
                  onOpen: (item) => context.go('/shop/product/${item.id}'),
                  onAdd: (item) => _addRecommendedItem(item),
                ),
              );
            }).toList(),
          );
        }),
      ],
    );
  }

  Widget _buildPopularGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final products = defaultMilterraProducts.take(8).toList();

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: products.map((p) {
          final cardWidth = isMobile
              ? ((constraints.maxWidth - 16) / 2).clamp(140.0, 300.0)
              : ((constraints.maxWidth - 48) / 4).clamp(180.0, 320.0);

          return SizedBox(
            width: cardWidth,
            child: StoreProductCard(
              packs: [p],
              compact: isMobile,
              busyIds: _busyIds,
              onOpen: (item) => context.go('/shop/product/${item.id}'),
              onAdd: (item) => _addRecommendedItem(item),
            ),
          );
        }).toList(),
      );
    });
  }
}

