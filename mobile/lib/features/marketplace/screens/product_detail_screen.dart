import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/providers/coupon_provider.dart';
import '../../cart/providers/wishlist_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/store_product_card.dart';
import '../widgets/product_information.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1, _image = 0;
  bool _busy = false;
  bool _bundleItem1Selected = true;
  bool _bundleItem2Selected = true;
  bool _couponApplied = false;

  @override
  void initState() {
    super.initState();
    final currentCoupon = ref.read(appliedCouponProvider);
    if (currentCoupon != null && currentCoupon.code == 'MILTERRA10') {
      _couponApplied = true;
    }
  }

  bool _isConceptProduct(Product p) => p.isConcept;

  bool _isEarthProduct(Product p) {
    if (p.taxonomy?['is_earth'] == true) return true;
    final cat = p.taxonomy?['category_id']?.toString() ?? '';
    if (cat.startsWith('earth_')) return true;
    return storeCategory(p) == 'MILTERRA Earth';
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _quantity = 1;
      _image = 0;
      _bundleItem1Selected = true;
      _bundleItem2Selected = true;
    }
  }

  bool _available(Product p) =>
      !p.isConcept && p.inStock && p.availableQuantity >= p.minOrderQuantity;

  Future<void> _purchase(Product p,
      {bool checkout = false, int? quantity}) async {
    if (p.isConcept) return;
    if (ref.read(currentUserProvider) == null) {
      final destination = checkout
          ? '/marketplace/checkout'
          : GoRouterState.of(context).uri.toString();
      context.go(
        Uri(path: '/login', queryParameters: {'next': destination}).toString(),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (_couponApplied) {
        ref.read(appliedCouponProvider.notifier).applyCoupon(
              'MILTERRA10',
              p.price * (quantity ?? _quantity),
            );
      }
      await ref.read(cartProvider.notifier).add(p.id, quantity ?? _quantity, p);
      if (!mounted) return;
      if (checkout) {
        context.push('/marketplace/checkout');
      } else {
        await showStoreCart(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not add this item. Check stock and try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(productDetailProvider(widget.productId));
    final product = result.valueOrNull;

    if (product != null && _quantity < product.minOrderQuantity) {
      _quantity = product.minOrderQuantity;
    }

    return Scaffold(
      backgroundColor: storeCream,
      body: LayoutBuilder(builder: (context, screenConstraints) {
        final isDesktop = screenConstraints.maxWidth >= 960;
        final isMobile = screenConstraints.maxWidth < StoreLayout.tablet;

        return Column(
          children: [
            // Top Amazon Header & Subnav
            StoreHeader(
              currentCategory: product == null ? 'All' : storeCategory(product),
            ),
            StoreCategoryNavigation(
              selected: product?.taxonomy?['category_id']?.toString() ??
                  (product == null ? 'All products' : storeCategory(product)),
            ),

            // Content Area
            Expanded(
              child: result.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('This product could not be loaded.',
                        style: StoreType.title),
                    StoreLayout.panelGap,
                    OutlinedButton(
                        onPressed: () => ref.invalidate(
                            productDetailProvider(widget.productId)),
                        child: const Text('Try again')),
                    TextButton(
                        onPressed: () => storeBackToShop(context),
                        child: const Text('Back to shop')),
                  ]),
                ),
                data: (p) {
                  final allCatalog =
                      ref.watch(productsProvider(null)).valueOrNull ??
                          <Product>[];
                  final others =
                      ref.watch(productsProvider(p.category)).valueOrNull ??
                          <Product>[];
                  final packs =
                      others.where((x) => x.familyKey == p.familyKey).toList();
                  if (!packs.any((x) => x.id == p.id)) packs.add(p);
                  packs.sort((a, b) => a.price.compareTo(b.price));

                  final related = storeProductGroups(others
                          .where((x) => x.familyKey != p.familyKey)
                          .toList())
                      .take(4)
                      .toList();

                  return SingleChildScrollView(
                    key: ValueKey(p.id),
                    child: Column(
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: StoreLayout.maxWidth),
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 12 : 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Breadcrumb Path
                                  _buildBreadcrumbs(p),
                                  const SizedBox(height: 16),

                                  // Amazon 3-Column Layout on Desktop / Stacked on Mobile
                                  if (isDesktop)
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Column 1: Left Gallery (Flex 4)
                                        Expanded(
                                          flex: 4,
                                          child: _gallery(p, isMobile),
                                        ),
                                        const SizedBox(width: 28),

                                        // Column 2: Center Product Details & Features (Flex 5)
                                        Expanded(
                                          flex: 5,
                                          child: _centerDetails(
                                            p,
                                            packs,
                                          ),
                                        ),
                                        const SizedBox(width: 24),

                                        // Column 3: Right Amazon Buy Box (Flex 3)
                                        SizedBox(
                                          width: 280,
                                          child: _amazonBuyBox(p),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    // Mobile / Tablet Stacked View
                                    _gallery(p, isMobile),
                                    const SizedBox(height: 20),
                                    _centerDetails(
                                      p,
                                      packs,
                                    ),
                                    const SizedBox(height: 24),
                                    _amazonBuyBox(p),
                                  ],

                                  const SizedBox(height: 24),
                                  if (!p.isConcept) ...[
                                    _buildFrequentlyBoughtTogether(
                                        p,
                                        allCatalog
                                            .where((item) => !item.isConcept)
                                            .toList(),
                                        !isDesktop),
                                    const SizedBox(height: 24),
                                  ],
                                  _buildProductSpecsSection(p),
                                  if (!p.isConcept) ...[
                                    const SizedBox(height: 24),
                                    _buildCompareWithSimilarItems(
                                        p, allCatalog, isMobile),
                                  ],
                                  const SizedBox(height: 24),

                                  // Related Products Carousel / Grid
                                  if (related.isNotEmpty) ...[
                                    const Text(
                                      'Products related to this item',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: storeGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    LayoutBuilder(builder: (context, space) {
                                      final columns = isMobile
                                          ? (space.maxWidth < 360 ? 1 : 2)
                                          : (space.maxWidth >= 1000 ? 4 : 2);
                                      return Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: related
                                            .map((group) => SizedBox(
                                                  width: ((space.maxWidth -
                                                              16 *
                                                                  (columns -
                                                                      1)) /
                                                          columns)
                                                      .clamp(140.0,
                                                          space.maxWidth),
                                                  child: StoreProductCard(
                                                    packs: group,
                                                    compact: isMobile,
                                                    busyIds: _busy
                                                        ? group
                                                            .map((x) => x.id)
                                                            .toSet()
                                                        : {},
                                                    onOpen: (item) => context.push(
                                                        '/shop/product/${item.id}'),
                                                    onAdd: (item) => _purchase(
                                                        item,
                                                        quantity: item
                                                            .minOrderQuantity),
                                                  ),
                                                ))
                                            .toList(),
                                      );
                                    }),
                                    const SizedBox(height: 36),
                                    const Divider(),
                                    const SizedBox(height: 24),
                                  ],

                                  if (!p.isConcept) ...[
                                    _buildCustomerQnA(p, isMobile),
                                    const SizedBox(height: 24),
                                    _buildCustomerReviews(p, isMobile),
                                  ],
                                  const SizedBox(
                                      height: StoreLayout.sectionSpace),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const StoreFooter(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBreadcrumbs(Product p) => Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InkWell(
            onTap: () => context.go('/shop'),
            child: const Text('Home',
                style: TextStyle(fontSize: 12, color: storeMuted)),
          ),
          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
          InkWell(
            onTap: () => storeBrowse(context, category: storeCategory(p)),
            child: Text(storeCategory(p),
                style: const TextStyle(fontSize: 12, color: storeMuted)),
          ),
          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
          Text(
            p.title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );

  Widget _gallery(Product p, bool mobile) {
    final mediaList = p.media;
    final totalImages = mediaList.isNotEmpty ? mediaList.length : 1;
    final hasMultiple = totalImages > 1;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _ProductImageLightboxDialog(
                  product: p,
                  initialIndex: _image,
                  onIndexChanged: (newIdx) {
                    setState(() => _image = newIdx);
                  },
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: mobile ? 1.08 : 1,
                    child: Padding(
                      padding: EdgeInsets.all(mobile ? 16 : 28),
                      child: ProductArtwork(product: p, imageIndex: _image),
                    ),
                  ),
                  if (hasMultiple) ...[
                    Positioned(
                      left: 6,
                      child: Material(
                        color: const Color(0xe0ffffff),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() {
                              _image = (_image - 1 + totalImages) % totalImages;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.chevron_left,
                                size: 22, color: Color(0xff222222)),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 6,
                      child: Material(
                        color: const Color(0xe0ffffff),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            setState(() {
                              _image = (_image + 1) % totalImages;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.chevron_right,
                                size: 22, color: Color(0xff222222)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.zoom_in, size: 16, color: storeMuted),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Click or tap image to zoom in & slide all images',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: storeMuted),
              ),
            ),
          ],
        ),
        if (p.media.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: p.media.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Semantics(
                selected: _image == i,
                label: 'Product image ${i + 1}',
                child: InkWell(
                  onTap: () => setState(() => _image = i),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 64,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: storeWhite,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _image == i ? storeGreen : storeBorder,
                        width: _image == i ? 2 : 1,
                      ),
                    ),
                    child: Image.network(
                      p.media[i],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _centerDetails(Product p, List<Product> packs) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (p.isConcept) const Chip(label: Text('Concept Preview')),
        Text(p.title, style: StoreType.title),
        const SizedBox(height: 8),
        Text(p.brand ?? '', style: const TextStyle(color: storeMuted)),
        const SizedBox(height: 12),
        if (!p.isConcept)
          Text(storeMoney(p.price),
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: storeGreen))
        else
          const Text('In development · Not for sale',
              style: TextStyle(fontWeight: FontWeight.w700, color: storeGreen)),
        const SizedBox(height: 12),
        Text(p.isConcept ? 'Proposed pack' : 'Pack size',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: packs
                .map((pack) => ChoiceChip(
                      key: ValueKey('detail-pack-${pack.id}'),
                      selected: pack.id == p.id,
                      label: Text(pack.packSize ?? pack.unit),
                      onSelected: (_) =>
                          context.pushReplacement('/shop/product/${pack.id}'),
                    ))
                .toList()),
        const SizedBox(height: 16),
        Text(p.isConcept ? Product.conceptExplanation : (p.description ?? ''),
            style: const TextStyle(height: 1.5)),
        if (p.isConcept) ...[
          const SizedBox(height: 12),
          const Text(
              'Price has not been announced. Concept feedback is separate from '
              'reviews of purchased products. Packaging and proposed packs may change.',
              style: TextStyle(color: storeMuted, height: 1.5)),
        ],
        ProductQualityLink(product: p),
      ]);

  Widget _amazonBuyBox(Product p) {
    if (_isConceptProduct(p)) {
      return _buildConceptBuyBox(p);
    }
    final available = _available(p);
    final maxQuantity = p.availableQuantity.clamp(1, 10);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0a000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Purchase Subtotal Summary
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Subtotal ($_quantity ${_quantity == 1 ? 'item' : 'items'}):',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff565959),
                ),
              ),
              Text(
                storeMoney(p.price * _quantity),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff0f1111),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Delivery Promise
          const Text(
            'Delivery date and charges are confirmed at checkout',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xff007185),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Dispatch timing depends on inventory and delivery location.',
            style: TextStyle(fontSize: 12, color: storeMuted),
          ),
          const SizedBox(height: 12),

          // Location Deliver To Pill
          const Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: storeGreen),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Deliver across India',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff007185),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stock Status
          Text(
            available
                ? (p.availableQuantity <= 5 && p.availableQuantity > 0
                    ? 'Only ${p.availableQuantity} left in stock - order soon.'
                    : 'In Stock.')
                : 'Currently unavailable.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: available ? storeSuccess : storeError,
            ),
          ),
          const SizedBox(height: 12),

          // Quantity Selector Dropdown
          if (available) ...[
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: storeCream,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: storeBorder),
              ),
              child: Row(
                children: [
                  const Text('Quantity: ',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _quantity.clamp(1, maxQuantity),
                      icon: const Icon(Icons.arrow_drop_down,
                          size: 18, color: storeGreen),
                      items: List.generate(
                        maxQuantity,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      onChanged: _busy
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() => _quantity = val);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Button 1: Add to Cart (Amber)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                key: const ValueKey('detail-add-to-cart'),
                style: StoreTheme.addToCartButton,
                onPressed: !available || _busy ? null : () => _purchase(p),
                child: Text(
                  _busy ? 'Adding…' : 'Add to Cart',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Button 2: Buy Now (Orange)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: FilledButton(
                key: const ValueKey('detail-buy-now'),
                style: StoreTheme.buyNowButton,
                onPressed: !available || _busy
                    ? null
                    : () => _purchase(p, checkout: true),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Direct Cooperative Sourcing Assurance
          const Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Icon(Icons.verified_user_outlined, size: 15, color: storeGreen),
              Text(
                'Direct from Cooperative Farm',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: storeGreen),
              ),
            ],
          ),
          const Divider(height: 20),

          // Ships from / Sold by
          _buyBoxDetailRow('Ships from', 'Milterra Direct'),
          _buyBoxDetailRow('Sold by',
              p.vendor?['business_name']?.toString() ?? 'Verified Partner'),

          const Divider(height: 20),

          // Add to Wishlist Link
          Consumer(
            builder: (context, ref, _) {
              final isWishlisted = ref.watch(isWishlistedProvider(p.id));
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(
                      color:
                          isWishlisted ? const Color(0xffd9383a) : storeBorder,
                    ),
                  ),
                  onPressed: () {
                    final added = ref.read(wishlistProvider.notifier).toggle(p);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 2),
                        backgroundColor: storeGreen,
                        content: Text(
                          added
                              ? 'Saved ${p.title} to your Wishlist.'
                              : 'Removed from your Wishlist.',
                        ),
                        action: SnackBarAction(
                          label: 'View',
                          textColor: storeGold,
                          onPressed: () => context.go('/wishlist'),
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: isWishlisted ? const Color(0xffd9383a) : storeGreen,
                  ),
                  label: Text(
                    isWishlisted ? 'In Your Wishlist' : 'Add to Wishlist',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isWishlisted ? const Color(0xffd9383a) : storeGreen,
                    ),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 20),

          // Multi-Seller Marketplace Offers Section
          _buildOtherSellerOffers(p),
        ],
      ),
    );
  }

  Widget _buildOtherSellerOffers(Product p) {
    final offers =
        (ref.watch(productsProvider(null)).valueOrNull ?? <Product>[])
            .where((other) =>
                !other.isConcept &&
                other.vendorId != p.vendorId &&
                other.title.toLowerCase() == p.title.toLowerCase() &&
                other.brand?.toLowerCase() == p.brand?.toLowerCase() &&
                other.packSize == p.packSize)
            .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Other Sellers on Milterra',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      if (offers.isEmpty)
        const Text('No other seller offers are published for this pack.',
            style: TextStyle(color: storeMuted, fontSize: 12)),
      for (final offer in offers)
        TextButton(
            onPressed: () => context.push('/shop/product/${offer.id}'),
            child: Text(
                '${offer.vendor?['business_name'] ?? 'Seller'} · ${storeMoney(offer.price)}')),
    ]);
  }

  Widget _buildConceptBuyBox(Product p) => StorePanel(
        title: 'Help shape this concept',
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(Product.conceptExplanation, style: TextStyle(height: 1.5)),
          const SizedBox(height: 12),
          ConceptActions(product: p),
          const SizedBox(height: 12),
          Row(children: [
            WishlistHeartButton(product: p),
            const SizedBox(width: 8),
            const Expanded(child: Text('Save concept to wishlist'))
          ]),
        ]),
      );

  Widget _buyBoxDetailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 70,
                child: Text(label,
                    style: const TextStyle(fontSize: 11, color: storeMuted))),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff007185),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _buildProductSpecsSection(Product p) => StorePanel(
        title: p.isConcept ? 'About this concept' : 'Product details',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (p.isConcept)
            const Text(Product.conceptExplanation)
          else ...[
            Text('Brand: ${p.brand ?? 'Not provided'}'),
            Text('Pack: ${p.packSize ?? p.unit}'),
            ...p.specifications.entries
                .where((e) => ![
                      'family_id',
                      'lab_reports',
                      'listing_status',
                      'concept',
                      'imagery'
                    ].contains(e.key))
                .map((e) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${e.key}: ${e.value}'))),
          ],
          ProductQualityLink(product: p),
        ]),
      );

  List<Product> _getSimilarComparisonProducts(
      Product current, List<Product> catalog) {
    if (_isEarthProduct(current)) {
      final earthProducts = catalog
          .where((x) => x.id != current.id && _isEarthProduct(x))
          .toList();
      return earthProducts.take(3).toList();
    }

    final currentDept = current.taxonomy?['department_name']?.toString() ?? '';
    final currentCat = current.category;

    final similar = catalog
        .where((x) =>
            x.id != current.id &&
            x.title != current.title &&
            (x.taxonomy?['department_name'] == currentDept ||
                x.category == currentCat))
        .toList();

    if (similar.length < 2) {
      for (final item in catalog) {
        if (item.id != current.id &&
            item.title != current.title &&
            !similar.any((s) => s.id == item.id)) {
          similar.add(item);
          if (similar.length >= 3) break;
        }
      }
    }
    return similar.take(3).toList();
  }

  Widget _buildCompareWithSimilarItems(
      Product current, List<Product> catalog, bool isMobile) {
    final similar = _getSimilarComparisonProducts(
        current, catalog.where((p) => !p.isConcept).toList());
    if (similar.isEmpty) return const SizedBox.shrink();

    final allCompared = [current, ...similar];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compare with similar items',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: isMobile ? 16 : 28,
              headingRowHeight: 0,
              dataRowMaxHeight: double.infinity,
              horizontalMargin: isMobile ? 12 : 20,
              columns: List.generate(
                allCompared.length + 1,
                (index) => const DataColumn(label: SizedBox.shrink()),
              ),
              rows: [
                // 1. Product Cards Header
                DataRow(
                  cells: [
                    const DataCell(
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Product',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    ...allCompared.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isCurrent = idx == 0;
                      return DataCell(
                        Container(
                          width: isMobile ? 150 : 190,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrent) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: storeGold.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color:
                                            storeGold.withValues(alpha: 0.5)),
                                  ),
                                  child: const Text(
                                    'This item',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: storeGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              InkWell(
                                onTap: isCurrent
                                    ? null
                                    : () =>
                                        context.go('/shop/product/${item.id}'),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: ProductArtwork(product: item),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: isCurrent
                                    ? null
                                    : () =>
                                        context.go('/shop/product/${item.id}'),
                                child: Text(
                                  item.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isCurrent
                                        ? const Color(0xff0f1111)
                                        : const Color(0xff007185),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // 3. Price
                DataRow(
                  cells: [
                    const DataCell(
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    ...allCompared.map((item) {
                      return DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            storeMoney(item.price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xff0f1111),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // 4. Sold By
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xfffaf8f5)),
                  cells: [
                    const DataCell(
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Sold By',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    ...allCompared.map((item) {
                      final brand = item.vendor?['business_name']?.toString() ??
                          'Seller not provided';
                      return DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            brand,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff007185),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // 5. Net Quantity / Pack Size
                DataRow(
                  cells: [
                    const DataCell(
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Pack Size',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    ...allCompared.map((item) {
                      return DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            item.packSize ?? item.unit,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xff333333),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // 6. Category / Department
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xfffaf8f5)),
                  cells: [
                    const DataCell(
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Department',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    ...allCompared.map((item) {
                      return DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            storeCategory(item),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff444444),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                // 7. Add to Cart action row
                DataRow(
                  cells: [
                    const DataCell(
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Action',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    ...allCompared.map((item) {
                      return DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 140,
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xffffd814),
                                foregroundColor: const Color(0xff0f1111),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: const BorderSide(
                                      color: Color(0xfffcd200)),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _purchase(item,
                                      quantity: item.minOrderQuantity),
                              child: const Text('Add to cart',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Product> _getBundleItems(Product p, List<Product> catalog) {
    final items = <Product>[];
    final cat = p.taxonomy?['category_id']?.toString() ?? '';
    final isFood = cat == 'cow_ghee' ||
        cat == 'buffalo_ghee' ||
        cat == 'paneer' ||
        cat == 'butter' ||
        cat == 'milk_testing';
    final isFeed = cat == 'cattle_feed' ||
        cat == 'mineral_mixture' ||
        cat == 'calcium_supplements' ||
        cat == 'bypass_fat';
    final isEquip = cat == 'milking_machines' ||
        cat == 'fat_testing' ||
        cat == 'chaff_cutters' ||
        cat == 'dairy_cans' ||
        cat == 'comfort_mats';

    if (isFood) {
      for (final id in [
        'fresh_paneer_200g',
        'cultured_butter_250g',
        'home_milk_purity_kit',
        'pure_cow_ghee_1l',
      ]) {
        if (id != p.id) {
          final match = catalog.where((x) => x.id == id).firstOrNull;
          if (match != null && !items.contains(match)) items.add(match);
        }
        if (items.length >= 2) break;
      }
    } else if (isFeed) {
      for (final id in [
        'milterra_chelated_minerals_5kg',
        'milterra_calcium_drench_5l',
        'milterra_bypass_fat_25kg',
        'milterra_bypass_pellets_50kg',
      ]) {
        if (id != p.id) {
          final match = catalog.where((x) => x.id == id).firstOrNull;
          if (match != null && !items.contains(match)) items.add(match);
        }
        if (items.length >= 2) break;
      }
    } else if (isEquip) {
      for (final id in [
        'ss304_milk_can_20l',
        'cow_comfort_mat',
        'milterra_milk_analyzer_pro',
        'single_bucket_milking_machine',
      ]) {
        if (id != p.id) {
          final match = catalog.where((x) => x.id == id).firstOrNull;
          if (match != null && !items.contains(match)) items.add(match);
        }
        if (items.length >= 2) break;
      }
    }

    if (items.isEmpty) {
      for (final x in catalog) {
        if (x.id != p.id && !items.contains(x)) {
          items.add(x);
        }
        if (items.length >= 2) break;
      }
    }
    return items;
  }

  Future<void> _addBundleToCart(Product p, List<Product> companionItems) async {
    if (ref.read(currentUserProvider) == null) {
      context.go('/login?next=/shop/product/${p.id}');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(cartProvider.notifier).add(p.id, p.minOrderQuantity);
      if (companionItems.isNotEmpty && _bundleItem1Selected) {
        await ref
            .read(cartProvider.notifier)
            .add(companionItems[0].id, companionItems[0].minOrderQuantity);
      }
      if (companionItems.length > 1 && _bundleItem2Selected) {
        await ref
            .read(cartProvider.notifier)
            .add(companionItems[1].id, companionItems[1].minOrderQuantity);
      }
      if (!mounted) return;
      final count = 1 +
          (companionItems.isNotEmpty && _bundleItem1Selected ? 1 : 0) +
          (companionItems.length > 1 && _bundleItem2Selected ? 1 : 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: storeGreen,
          content: Text('Added $count bundle items to your cart.'),
        ),
      );
      await showStoreCart(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add bundle items to cart.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildFrequentlyBoughtTogether(
      Product p, List<Product> catalog, bool isMobile) {
    if (_isEarthProduct(p) || _isConceptProduct(p)) {
      return const SizedBox.shrink();
    }
    final bundleItems = _getBundleItems(p, catalog);
    if (bundleItems.isEmpty) return const SizedBox.shrink();

    double totalPrice = p.price;
    int selectedCount = 1;
    if (bundleItems.isNotEmpty && _bundleItem1Selected) {
      totalPrice += bundleItems[0].price;
      selectedCount++;
    }
    if (bundleItems.length > 1 && _bundleItem2Selected) {
      totalPrice += bundleItems[1].price;
      selectedCount++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frequently bought together',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _bundleThumbnail(p, isMain: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.add, color: storeMuted, size: 22),
                      ),
                      if (bundleItems.isNotEmpty)
                        _bundleThumbnail(bundleItems[0],
                            isMain: false, isChecked: _bundleItem1Selected),
                      if (bundleItems.length > 1) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.add, color: storeMuted, size: 22),
                        ),
                        _bundleThumbnail(bundleItems[1],
                            isMain: false, isChecked: _bundleItem2Selected),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Total price: ',
                        style: TextStyle(fontSize: 14, color: storeMuted)),
                    Text(
                      storeMoney(totalPrice),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: storeOrange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: storeAmber,
                      foregroundColor: storeGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed:
                        _busy ? null : () => _addBundleToCart(p, bundleItems),
                    child: Text(
                      selectedCount == 1
                          ? 'Add to Cart'
                          : 'Add all $selectedCount to Cart',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _bundleThumbnail(p, isMain: true),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.add, color: storeMuted, size: 22),
                    ),
                    if (bundleItems.isNotEmpty)
                      _bundleThumbnail(bundleItems[0],
                          isMain: false, isChecked: _bundleItem1Selected),
                    if (bundleItems.length > 1) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.add, color: storeMuted, size: 22),
                      ),
                      _bundleThumbnail(bundleItems[1],
                          isMain: false, isChecked: _bundleItem2Selected),
                    ],
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Total price: ',
                                  style: TextStyle(
                                      fontSize: 15, color: Color(0xff565959))),
                              Text(
                                storeMoney(totalPrice),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: storeOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 38,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: storeAmber,
                                foregroundColor: storeGreen,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _addBundleToCart(p, bundleItems),
                              child: Text(
                                selectedCount == 1
                                    ? 'Add to Cart'
                                    : 'Add all $selectedCount to Cart',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const Divider(height: 28),
              _bundleItemCheckbox(
                title: p.title,
                price: p.price,
                isMain: true,
                isChecked: true,
                onChanged: null,
              ),
              if (bundleItems.isNotEmpty)
                _bundleItemCheckbox(
                  title: bundleItems[0].title,
                  price: bundleItems[0].price,
                  isMain: false,
                  isChecked: _bundleItem1Selected,
                  onChanged: (val) =>
                      setState(() => _bundleItem1Selected = val ?? false),
                ),
              if (bundleItems.length > 1)
                _bundleItemCheckbox(
                  title: bundleItems[1].title,
                  price: bundleItems[1].price,
                  isMain: false,
                  isChecked: _bundleItem2Selected,
                  onChanged: (val) =>
                      setState(() => _bundleItem2Selected = val ?? false),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bundleThumbnail(Product item,
          {bool isMain = false, bool isChecked = true}) =>
      Opacity(
        opacity: isChecked ? 1.0 : 0.4,
        child: Container(
          width: 90,
          height: 90,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMain ? storeAmber : storeBorder,
              width: isMain ? 2 : 1,
            ),
          ),
          child: ProductArtwork(product: item),
        ),
      );

  Widget _bundleItemCheckbox({
    required String title,
    required double price,
    required bool isMain,
    required bool isChecked,
    required ValueChanged<bool?>? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                activeColor: storeGreen,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xff0f1111)),
                  children: [
                    if (isMain)
                      const TextSpan(
                        text: 'This item: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    TextSpan(text: '$title '),
                    TextSpan(
                      text: '(${storeMoney(price)})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
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

  Widget _buildCustomerQnA(Product p, bool isMobile) => const StorePanel(
      title: 'Customer questions',
      child: Text('No verified answers are published for this product yet.'));
  Widget _buildCustomerReviews(Product p, bool isMobile) => const StorePanel(
      title: 'Customer reviews',
      child: Text('No verified product reviews are published yet.'));
}

class _ProductImageLightboxDialog extends StatefulWidget {
  const _ProductImageLightboxDialog({
    required this.product,
    required this.initialIndex,
    required this.onIndexChanged,
  });

  final Product product;
  final int initialIndex;
  final ValueChanged<int> onIndexChanged;

  @override
  State<_ProductImageLightboxDialog> createState() =>
      _ProductImageLightboxDialogState();
}

class _ProductImageLightboxDialogState
    extends State<_ProductImageLightboxDialog> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final total =
        widget.product.media.isNotEmpty ? widget.product.media.length : 1;
    _currentIndex = widget.initialIndex.clamp(0, total - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final total =
        widget.product.media.isNotEmpty ? widget.product.media.length : 1;
    if (index >= 0 && index < total) {
      setState(() => _currentIndex = index);
      widget.onIndexChanged(index);
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _previous() {
    final total =
        widget.product.media.isNotEmpty ? widget.product.media.length : 1;
    if (total <= 1) return;
    final nextIndex = (_currentIndex - 1 + total) % total;
    _goTo(nextIndex);
  }

  void _next() {
    final total =
        widget.product.media.isNotEmpty ? widget.product.media.length : 1;
    if (total <= 1) return;
    final nextIndex = (_currentIndex + 1) % total;
    _goTo(nextIndex);
  }

  @override
  Widget build(BuildContext context) {
    final mediaList = widget.product.media;
    final totalImages = mediaList.isNotEmpty ? mediaList.length : 1;
    final hasMultiple = totalImages > 1;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: storeWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 780),
        child: Column(
          children: [
            // Top Bar with Counter, Title and Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  if (hasMultiple)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: storeCream,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: storeBorder),
                      ),
                      child: Text(
                        'Image ${_currentIndex + 1} of $totalImages',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: storeGreen,
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.product.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff333333),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close dialog (Esc)',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Main Image with Left & Right Arrows in a Stack
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Swipable / Zoomable PageView
                  PageView.builder(
                    controller: _pageController,
                    itemCount: totalImages,
                    onPageChanged: (idx) {
                      setState(() => _currentIndex = idx);
                      widget.onIndexChanged(idx);
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 1,
                        maxScale: 3.5,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: ProductArtwork(
                              product: widget.product,
                              imageIndex: index,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Left Navigation Arrow (Only if multiple images)
                  if (hasMultiple)
                    Positioned(
                      left: 14,
                      child: Material(
                        color: const Color(0xeeffffff),
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _previous,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: storeBorder),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: Color(0xff111111),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Right Navigation Arrow (Only if multiple images)
                  if (hasMultiple)
                    Positioned(
                      right: 14,
                      child: Material(
                        color: const Color(0xeeffffff),
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _next,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: storeBorder),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 20,
                              color: Color(0xff111111),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Thumbnail Strip (if multiple images)
            if (hasMultiple) ...[
              const Divider(height: 1),
              Container(
                color: const Color(0xfffafafa),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                height: 76,
                child: Center(
                  child: ListView.separated(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    itemCount: totalImages,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final isSelected = _currentIndex == i;
                      return InkWell(
                        onTap: () => _goTo(i),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 54,
                          height: 54,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: storeWhite,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? storeGreen : storeBorder,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: mediaList.length > i
                                ? Image.network(
                                    mediaList[i],
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined,
                                        size: 20),
                                  )
                                : const Icon(Icons.image_outlined, size: 20),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
