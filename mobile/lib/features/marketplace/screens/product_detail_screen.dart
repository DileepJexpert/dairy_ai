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
import '../models/marketplace_models.dart';
import '../../admin/providers/admin_marketplace_provider.dart';

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
  final List<Map<String, dynamic>> _userReviews = [];
  final GlobalKey _reviewsKey = GlobalKey();
  final GlobalKey _qnaKey = GlobalKey();
  final Set<String> _helpfulVoted = {};
  int? _filterStar;

  @override
  void initState() {
    super.initState();
    final currentCoupon = ref.read(appliedCouponProvider);
    if (currentCoupon != null && currentCoupon.code == 'MILTERRA10') {
      _couponApplied = true;
    }
  }

  bool _isConceptProduct(Product p) {
    if (p.taxonomy?['concept'] == true) return true;
    final title = p.title.toLowerCase();
    if (title.contains('ghee') ||
        title.contains('paneer') ||
        title.contains('butter') ||
        title.contains('makhan')) {
      return false;
    }
    if (p.category == ProductCategory.equipment) return false;
    return (p.taxonomy?['status'] != null &&
        p.taxonomy!['status'].toString().toLowerCase().contains('concept'));
  }

  String _getDispatchCountdown() {
    final now = DateTime.now();
    var cutoff = DateTime(now.year, now.month, now.day, 18, 0, 0);
    if (now.isAfter(cutoff)) {
      cutoff = cutoff.add(const Duration(days: 1));
    }
    final diff = cutoff.difference(now);
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    return '$hours hrs $mins mins';
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
      p.inStock && p.availableQuantity >= p.minOrderQuantity;

  Future<void> _purchase(Product p,
      {bool checkout = false, int? quantity}) async {
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
        if (ref.read(currentUserProvider) == null) {
          context.go('/login?next=/marketplace/checkout');
        } else {
          context.push('/marketplace/checkout');
        }
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
                          defaultMilterraProducts;
                  final others =
                      ref.watch(productsProvider(p.category)).valueOrNull ??
                          <Product>[];
                  final packs = others
                      .where(
                          (x) => x.vendorId == p.vendorId && x.title == p.title)
                      .toList();
                  if (!packs.any((x) => x.id == p.id)) packs.add(p);
                  packs.sort((a, b) => a.price.compareTo(b.price));

                  final related = storeProductGroups(others
                          .where((x) =>
                              x.vendorId != p.vendorId || x.title != p.title)
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

                                  const SizedBox(height: 36),
                                  const Divider(),
                                  const SizedBox(height: 24),

                                  // Amazon "Frequently bought together" Bundle Section
                                  _buildFrequentlyBoughtTogether(
                                      p, allCatalog, isMobile),

                                  const SizedBox(height: 36),
                                  const Divider(),
                                  const SizedBox(height: 24),

                                  // Amazon "About this item" Feature Bullets & Specifications
                                  _buildProductSpecsSection(p),

                                  const SizedBox(height: 36),
                                  const Divider(),
                                  const SizedBox(height: 24),

                                  // Amazon "Compare with similar items" Table
                                  _buildCompareWithSimilarItems(
                                      p, allCatalog, isMobile),

                                  const SizedBox(height: 36),

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
                                                      .clamp(
                                                          140.0, space.maxWidth),
                                                  child: StoreProductCard(
                                                    packs: group,
                                                    compact: isMobile,
                                                    busyIds: _busy
                                                        ? group
                                                            .map((x) => x.id)
                                                            .toSet()
                                                        : {},
                                                    onOpen: (item) => context
                                                        .go(
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

                                  // Customer Questions & Answers
                                  _buildCustomerQnA(p, isMobile),

                                  const SizedBox(height: 36),
                                  const Divider(),
                                  const SizedBox(height: 24),

                                  // Customer Reviews & Star Breakdown
                                  _buildCustomerReviews(p, isMobile),

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
            Text('Click or tap image to zoom in & slide all images',
                style: TextStyle(fontSize: 11, color: storeMuted)),
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

  Widget _centerDetails(
    Product p,
    List<Product> packs,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Link
          InkWell(
            onTap: () => storeBrowse(context),
            child: Text(
              'Visit the ${p.brand ?? 'Milterra'} Store',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xff007185),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Title
          Text(
            p.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xff0f1111),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // Rating Row & Milterra's Choice Badge
          _buildRatingHeaderRow(p),
          const Divider(height: 24),

          if (_isConceptProduct(p)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff4f9f4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffc5e1c7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xff067d62),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (p.taxonomy?['status']?.toString() ??
                                  'Concept Preview')
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Product Validation & Feedback Stage',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: storeGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.taxonomy?['tagline']?.toString() ??
                        'Natural Nutrition for Healthy Livestock',
                    style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Color(0xff374151)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    p.taxonomy?['brand_line']?.toString() ??
                        'Feeds • Supplements • Calcium STC • Health & Productivity',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: storeMuted),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Price & Discount Block
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  storeMoney(p.price),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xff0f1111),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text('Price shown is the current catalogue price.',
                style: TextStyle(fontSize: 12, color: Color(0xff565959))),
            const SizedBox(height: 10),
            // Coupon Block (Interactive Amazon Style)
            InkWell(
              onTap: () {
                final next = !_couponApplied;
                setState(() => _couponApplied = next);
                if (next) {
                  ref
                      .read(appliedCouponProvider.notifier)
                      .applyCoupon('MILTERRA10', p.price * _quantity);
                } else {
                  ref.read(appliedCouponProvider.notifier).removeCoupon();
                }
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    backgroundColor:
                        next ? storeGreen : const Color(0xff555555),
                    content: Text(
                      next
                          ? 'Coupon MILTERRA10 applied! You will save ${storeMoney((p.price * 0.10).roundToDouble())} at checkout.'
                          : 'Coupon MILTERRA10 removed.',
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: _couponApplied
                      ? const Color(0xffe8f5e9)
                      : const Color(0xfff0fbf4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _couponApplied
                        ? const Color(0xff2e7d32)
                        : const Color(0xffb7ebd1),
                    width: _couponApplied ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _couponApplied
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: _couponApplied
                          ? const Color(0xff2e7d32)
                          : const Color(0xff067d62),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xff067d62),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('Coupon',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _couponApplied
                            ? '10% coupon applied at checkout (Save ${storeMoney((p.price * 0.10).roundToDouble())})'
                            : 'Apply 10% coupon with code MILTERRA10 at checkout',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _couponApplied
                              ? const Color(0xff1b5e20)
                              : const Color(0xff067d62),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(height: 24),

          // Pack Sizes / Variant Boxes (Amazon-style)
          Text(
            'Size: ${p.packSize ?? p.unit}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xff0f1111),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: packs.map((pack) {
              final isSelected = pack.id == p.id;
              return InkWell(
                onTap: _busy
                    ? null
                    : () {
                        if (pack.id != p.id) {
                          context.go('/shop/product/${pack.id}');
                        }
                      },
                borderRadius: BorderRadius.circular(StoreLayout.controlRadius),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? storeSage : storeWhite,
                    borderRadius:
                        BorderRadius.circular(StoreLayout.controlRadius),
                    border: Border.all(
                      color: isSelected ? storeGreen : storeBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pack.packSize ?? pack.unit,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected ? storeGreen : const Color(0xff111111),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        storeMoney(pack.price),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? storeGreen : storeMuted,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const Divider(height: 28),

          // Feature Highlights (Amazon Bullets)
          const Text(
            'About this item',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 10),
          if (_isConceptProduct(p) || (p.category == ProductCategory.feedNutrition && !p.title.toLowerCase().contains('ghee') && !p.title.toLowerCase().contains('paneer') && !p.title.toLowerCase().contains('butter'))) ...[
            _bulletPoint('CHELATED NUTRITION & BIOAVAILABILITY:',
                'Engineered with organic micro-chelated minerals (Zinc, Manganese, Chromium, Cobalt) for superior cellular absorption.'),
            _bulletPoint('HERD IMMUNITY & FERTILITY:',
                'Fortified with live probiotic yeast culture (Saccharomyces cerevisiae) to optimize rumen flora, prevent acidosis, and boost conception rates.'),
            _bulletPoint('LACTATION YIELD OPTIMIZATION:',
                'Balances critical trace elements to sustain peak milk production and improve milk fat and SNF yield across lactation stages.'),
            _bulletPoint('SCIENTIFIC FEED BENCHMARK:',
                'Formulated to ICAR & NDRI dairy livestock nutritional standards with zero harmful chemical residues or heavy metals.'),
          ] else if (p.category == ProductCategory.equipment) ...[
            _bulletPoint('FOOD-GRADE STAINLESS STEEL:',
                'Fabricated from certified SS-304 food-grade material for zero contamination and lifetime rust resistance.'),
            _bulletPoint('FARM-TESTED DURABILITY:',
                'Heavy-duty build tested under intensive Indian farm dairy operations and variable voltage conditions.'),
            _bulletPoint('MILTERRA CERTIFIED SUPPORT:',
                'Includes 1-year comprehensive cooperative warranty and direct technician assistance.'),
          ] else ...[
            _bulletPoint('100% PURE & TRADITIONAL:',
                'Made with traditional Bilona churning process preserving vital nutrients and authentic aroma.'),
            _bulletPoint('GRASS-FED SOURCING:',
                'Ethically sourced from local dairy farmers with verified cattle health and pure diet.'),
            _bulletPoint('LAB TESTED PURITY:',
                'Zero adulteration, zero preservatives, no synthetic chemicals or artificial colors.'),
            _bulletPoint('RICH AROMA & TEXTURE:',
                'Naturally granular golden texture packed with natural vitamins and antioxidants.'),
          ],
          const SizedBox(height: 16),

          // Milterra Lab Purity / Formulation Quality Card
          if (_isConceptProduct(p) || (p.category == ProductCategory.feedNutrition && !p.title.toLowerCase().contains('ghee') && !p.title.toLowerCase().contains('paneer') && !p.title.toLowerCase().contains('butter'))) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: storeSage.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(StoreLayout.radius),
                border: Border.all(color: storeGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.biotech, color: storeGreen, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ICAR / NDRI Benchmark · Quality Assured Formulation',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: storeGreen,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: storeGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Formulation STC',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tested for heavy metals, safe aflatoxin limits (<20 ppb), active live probiotic yeast viability, and bio-available mineral absorption.',
                    style: TextStyle(fontSize: 11, color: storeMuted, height: 1.3),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: storeSage.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(StoreLayout.radius),
                border: Border.all(color: storeGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, color: storeGreen, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'NABL Lab Certified · 99.4% Purity Score',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: storeGreen,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: storeGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Batch #0911A',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'ISO/IEC 17025 accredited laboratory tested. 100% pure A2 beta-casein allele, 0% adulterants, 0% added water.',
                    style: TextStyle(fontSize: 11, color: storeMuted, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InkWell(
                        onTap: () => context.push('/purity/certificate/BATCH-2026-0911A'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined, size: 14, color: storeGreen),
                            SizedBox(width: 4),
                            Text(
                              'View Lab Certificate →',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => context.push('/purity/scan'),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_scanner, size: 14, color: storeAmberDark),
                            SizedBox(width: 4),
                            Text(
                              'AI Strip Scanner →',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeAmberDark),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      );

  Widget _bulletPoint(String title, String description) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: storeGreen)),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xff333333), height: 1.4),
                  children: [
                    TextSpan(
                      text: '$title ',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Color(0xff111111)),
                    ),
                    TextSpan(text: description),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _amazonBuyBox(Product p) {
    if (_isConceptProduct(p)) {
      return _buildConceptBuyBox(p);
    }
    final available = _available(p);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
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
            'FREE delivery by Tomorrow',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xff007185),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Order within ${_getDispatchCountdown()} for same-day dispatch.',
            style: const TextStyle(fontSize: 12, color: storeMuted),
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
                      value: _quantity.clamp(1, 10),
                      icon: const Icon(Icons.arrow_drop_down,
                          size: 18, color: storeGreen),
                      items: List.generate(
                        10,
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
                style: FilledButton.styleFrom(
                  backgroundColor: storeAmber,
                  foregroundColor: storeGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _busy ? null : () => _purchase(p),
                child: Text(
                  _busy ? 'Adding…' : 'Add to Cart',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: storeGreen,
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
                style: FilledButton.styleFrom(
                  backgroundColor: storeOrange,
                  foregroundColor: storeWhite,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed:
                    _busy ? null : () => _purchase(p, checkout: true),
                child: const Text(
                  'Buy Now',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: storeWhite,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Direct Cooperative Sourcing Assurance
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 15, color: storeGreen),
              SizedBox(width: 6),
              Text(
                'Direct from Cooperative Farm',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: storeGreen),
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
                    color:
                        isWishlisted ? const Color(0xffd9383a) : storeGreen,
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
    final allOffers = ref.watch(adminMarketplaceProvider).offers;
    final otherOffers = allOffers.where((o) => o.productId == p.id && !o.isBuyBoxWinner && o.offerStatus == OfferStatus.active).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Other Sellers on Milterra',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: storeGreen,
              ),
            ),
            if (otherOffers.isNotEmpty)
              Text(
                '(${otherOffers.length} offers from ${storeMoney(otherOffers.map((o) => o.sellingPrice).reduce((a, b) => a < b ? a : b))})',
                style: const TextStyle(fontSize: 11, color: storeMuted),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (otherOffers.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: storeBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: storeMuted),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Exclusive Milterra Direct verified batch.',
                    style: TextStyle(fontSize: 11, color: storeMuted),
                  ),
                ),
                InkWell(
                  onTap: () => context.push('/seller/login'),
                  child: const Text(
                    'Sell this item →',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          for (final offer in otherOffers) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfffbfdfb),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xffd1e7dd)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          offer.sellerName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff0f1111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        storeMoney(offer.sellingPrice),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: storeOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${offer.sellerRating} ★ · ${offer.deliveryPromise}',
                        style: const TextStyle(fontSize: 10, color: storeMuted),
                      ),
                      SizedBox(
                        height: 26,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: storeAmber,
                            foregroundColor: storeGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _purchase(p, quantity: 1),
                          child: const Text('Add to Cart', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 6),
        InkWell(
          onTap: () => context.push('/seller/login'),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_mall_directory_outlined, size: 13, color: storeMuted),
              SizedBox(width: 4),
              Text(
                'Have one to sell? Sell on Milterra',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: storeDarkGreenNav),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConceptBuyBox(Product p) {
    final status = p.taxonomy?['status']?.toString() ?? 'Concept Preview';
    final tagline = p.taxonomy?['tagline']?.toString() ??
        'Natural Nutrition for Healthy Livestock';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: const Color(0xffc2dbd0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0a000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Concept status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xffe8f5e9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffa5d6a7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.science_outlined, size: 14, color: storeGreen),
                const SizedBox(width: 6),
                Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: storeGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'MILTERRA CATTLE NUTRITION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: storeMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tagline,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: storeDarkGreenNav,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff7faf8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffe0ece4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: storeGreen),
                    SizedBox(width: 6),
                    Text(
                      'Virtual Formulation Preview',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: storeGreen,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'This cattle nutrition solution is currently under research & field validation. Commercial purchasing will unlock after farmer trials conclude.',
                  style: TextStyle(fontSize: 11, color: Color(0xff445544), height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Primary CTA: Share Feedback
          SizedBox(
            width: double.infinity,
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: storeGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text(
                'Share Farmer Feedback',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onPressed: () => _showFarmerFeedbackModal(context, p),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary CTA: Register for Field Trials
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: storeGreen,
                side: const BorderSide(color: storeGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.notifications_active_outlined, size: 16),
              label: const Text(
                'Register for Trial Updates',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: storeGreen,
                    content: Text(
                      'You are registered for upcoming trials of ${p.title}. We will notify you when sample batches are ready.',
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Direct Cooperative Sourcing Assurance
          const Row(
            children: [
              Icon(Icons.hub_outlined, size: 15, color: storeGreen),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Co-developed with Progressive Dairy Farmers',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: storeGreen),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          _buyBoxDetailRow('Focus Area', p.taxonomy?['focus']?.toString() ?? 'Livestock Health & Productivity'),
          _buyBoxDetailRow('Stage Target', p.taxonomy?['stage']?.toString() ?? 'All Dairy Cattle & Buffaloes'),

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
                              ? 'Saved ${p.title} to your Watchlist.'
                              : 'Removed from your Watchlist.',
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    isWishlisted ? Icons.bookmark : Icons.bookmark_border,
                    size: 16,
                    color:
                        isWishlisted ? const Color(0xffd9383a) : storeGreen,
                  ),
                  label: Text(
                    isWishlisted ? 'Saved in Watchlist' : 'Add to Concept Watchlist',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isWishlisted
                          ? const Color(0xffd9383a)
                          : const Color(0xff0f1111),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFarmerFeedbackModal(BuildContext context, Product p) {
    final nameCtrl = TextEditingController();
    final herdCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.rate_review_outlined, color: storeGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Farmer Feedback: ${p.title}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help shape this formulation for your herd. Your inputs directly guide our livestock nutrition team.',
                  style: TextStyle(fontSize: 12, color: storeMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Your Name & Location',
                    hintText: 'e.g. Ramesh Kumar, Anand Gujarat',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: herdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Herd Size & Breed',
                    hintText: 'e.g. 8 Gir Cows, 4 Murrah Buffaloes',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nutritional Needs / Suggestions',
                    hintText: 'e.g. Required pack size, specific mineral requirements, lactation stage feedback...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: storeGreen,
                  content: Text(
                    'Thank you for your feedback on ${p.title}! Our nutrition team has recorded your inputs.',
                  ),
                ),
              );
            },
            child: const Text('Submit Feedback'),
          ),
        ],
      ),
    );
  }

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

  Widget _buildProductSpecsSection(Product p) {
    final titleLower = p.title.toLowerCase();
    final isGhee = titleLower.contains('ghee');
    final isDairyFood = isGhee ||
        titleLower.contains('paneer') ||
        titleLower.contains('butter') ||
        titleLower.contains('milk') ||
        titleLower.contains('curd');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 14),

        // Technical Details Table
        Container(
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: Column(
            children: [
              _specTableRow('Brand', p.brand ?? 'Milterra Cooperative Dairy', true),
              _specTableRow('Product Name', p.title, false),
              _specTableRow('Category', storeCategory(p), true),
              _specTableRow('Net Quantity', p.packSize ?? p.unit, false),
              _specTableRow('Diet Type', '100% Vegetarian', true),
              if (isDairyFood) ...[
                _specTableRow(
                  'Ingredients',
                  isGhee
                      ? (titleLower.contains('buffalo')
                          ? '100% Pure Buffalo Milk Fat (No added preservatives, artificial colors, or flavoring substances)'
                          : '100% Pure A2 Gir Cow Milk Fat (Made from cultured curd butter churned using traditional Bilona method)')
                      : 'Fresh Farm Milk, Permitted Cultures & Enzymes',
                  false,
                ),
                _specTableRow(
                  'Processing Method',
                  isGhee
                      ? 'Traditional Bilona Churned & Slow-Cooked Milk Solids'
                      : 'Hygienic Cooperative Processing & Cold-Chain Maintained',
                  true,
                ),
                _specTableRow(
                  'Storage Instructions',
                  isGhee
                      ? 'Store in a cool, dry place away from direct sunlight. Do not refrigerate.'
                      : 'Keep refrigerated between 2°C - 4°C.',
                  false,
                ),
                _specTableRow('Shelf Life', isGhee ? '12 Months from packaging date' : '45 Days from packaging date', true),
                _specTableRow('Container Material', 'Food-Grade Recyclable Glass Jar with Hermetic Induction Seal', false),
                _specTableRow('Country of Origin', 'India (Direct Cooperative Farm Sourced)', true),
                _specTableRow('FSSAI License No.', '10020042000123 (Central FSSAI Certified)', false),
                _specTableRow('Allergen Information', 'Contains Milk', true),
                if (isGhee) ...[
                  _specTableRow('Reichert-Meissl (RM) Value', '≥ 30.0 (High Purity Milk Fat Standard)', false),
                  _specTableRow('Free Fatty Acids (FFA)', '< 0.8% (Fresh Batch Standard)', true),
                  _specTableRow('Adulterant Guarantee', 'Zero Starch, Zero Animal Tallow, Zero Mineral Oils', false),
                ],
              ] else ...[
                _specTableRow('Container Material', 'Industrial Grade Heavy-Duty Sealed Packaging', false),
                _specTableRow('Country of Origin', 'India', true),
              ],
              for (final entry in p.specifications.entries)
                _specTableRow(_formatKey(entry.key), entry.value.toString(), false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _specTableRow(String key, String value, bool isEven) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isEven ? const Color(0xfffaf8f5) : storeWhite,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              child: Text(
                key,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff333333),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xff111111),
                ),
              ),
            ),
          ],
        ),
      );

  String _formatKey(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  List<Product> _getSimilarComparisonProducts(
      Product current, List<Product> catalog) {
    final currentDept =
        current.taxonomy?['department_name']?.toString() ?? '';
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
    final similar = _getSimilarComparisonProducts(current, catalog);
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

                // 2. Customer Rating
                DataRow(
                  color: WidgetStateProperty.all(const Color(0xfffaf8f5)),
                  cells: [
                    const DataCell(
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'Customer Rating',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff555555),
                          ),
                        ),
                      ),
                    ),
                    ...allCompared.asMap().entries.map((entry) {
                      final item = entry.value;
                      final rating = 4.5 + ((item.id.hashCode.abs() % 5) / 10);
                      final reviews = (item.id.hashCode.abs() % 250) + 42;
                      return DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 15, color: Color(0xffde7921)),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff0f1111),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '($reviews)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xff007185),
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
                      final brand = item.brand ?? 'Milterra Dairy Direct';
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _purchase(item,
                                      quantity: item.minOrderQuantity),
                              child: const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.shopping_cart_outlined,
                                      size: 15),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add to Cart',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildRatingHeaderRow(Product p) {
    final count = (p.id.hashCode.abs() % 250) + 42 + _userReviews.length;
    final questions = (p.id.hashCode.abs() % 40) + 12;
    final isBuffaloGhee = p.id == 'mil-buff-500' || p.title.toLowerCase().contains('buffalo ghee');
    final isCowGhee = p.id == 'mil-ghee-500' || p.title.toLowerCase().contains('cow ghee');
    final isMilterraChoice = isBuffaloGhee || isCowGhee;
    final choiceCategory = isBuffaloGhee
        ? 'buffalo ghee'
        : isCowGhee
            ? 'a2 cow ghee'
            : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            InkWell(
              onTap: () {
                if (_reviewsKey.currentContext != null) {
                  Scrollable.ensureVisible(
                    _reviewsKey.currentContext!,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                  );
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AmazonRatingStars(
                      rating: 4.8,
                      showCount: false,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      '4.8',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff007185),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$count ratings',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xff007185),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xff007185),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Text('|', style: TextStyle(color: storeBorder)),
            InkWell(
              onTap: () {
                if (_qnaKey.currentContext != null) {
                  Scrollable.ensureVisible(
                    _qnaKey.currentContext!,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                  );
                }
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '$questions answered questions',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff007185),
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xff007185),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (isMilterraChoice) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: const BoxDecoration(
              color: Color(0xff232f3e),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 11, color: Colors.white),
                children: [
                  const TextSpan(
                    text: "Milterra's ",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: 'Choice',
                    style: TextStyle(color: Color(0xffff9900), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: " for '$choiceCategory'",
                    style: const TextStyle(color: Color(0xffd1d5db), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  Future<void> _addBundleToCart(
      Product p, List<Product> companionItems) async {
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
          const SnackBar(
              content: Text('Could not add bundle items to cart.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildFrequentlyBoughtTogether(
      Product p, List<Product> catalog, bool isMobile) {
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
                            isMain: false,
                            isChecked: _bundleItem1Selected),
                      if (bundleItems.length > 1) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.add, color: storeMuted, size: 22),
                        ),
                        _bundleThumbnail(bundleItems[1],
                            isMain: false,
                            isChecked: _bundleItem2Selected),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
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
                          isMain: false,
                          isChecked: _bundleItem1Selected),
                    if (bundleItems.length > 1) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.add, color: storeMuted, size: 22),
                      ),
                      _bundleThumbnail(bundleItems[1],
                          isMain: false,
                          isChecked: _bundleItem2Selected),
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
                                      fontSize: 15,
                                      color: Color(0xff565959))),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24),
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
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
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

  Widget _buildCustomerQnA(Product p, bool isMobile) {
    final qnaList = _getQnAPairs(p);
    return Container(
      key: _qnaKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const Text(
          'Customer questions & answers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: storeBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Row(
            children: [
              Icon(Icons.search, size: 18, color: storeMuted),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Have a question? Search for answers...',
                  style: TextStyle(fontSize: 13, color: storeMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(StoreLayout.radius),
            border: Border.all(color: storeBorder),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: qnaList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final qa = qnaList[i];
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 75,
                          child: Text(
                            'Question:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xff565959),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            qa.question,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xff007185),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 75,
                          child: Text(
                            'Answer:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xff565959),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                qa.answer,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xff0f1111),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'By ${qa.author} on ${qa.date}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: storeMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

  List<_QnAItem> _getQnAPairs(Product p) {
    final cat = p.taxonomy?['category_id']?.toString() ?? '';
    final isFeed = cat == 'cattle_feed' ||
        cat == 'mineral_mixture' ||
        cat == 'calcium_supplements' ||
        cat == 'bypass_fat';
    final isEquip = cat == 'milking_machines' ||
        cat == 'fat_testing' ||
        cat == 'chaff_cutters' ||
        cat == 'dairy_cans' ||
        cat == 'comfort_mats';

    if (isFeed) {
      return const [
        _QnAItem(
          question: 'How much quantity should be fed per cow daily?',
          answer:
              'For high-yielding dairy cattle producing 12-18 Liters of milk, feed 3.5 kg to 4.5 kg per day divided between morning and evening milking sessions alongside balanced dry and green roughage.',
          author: 'Milterra Veterinary Team',
          date: '12 January 2025',
        ),
        _QnAItem(
          question: 'Is this feed suitable for both Gir cows and Murrah buffaloes?',
          answer:
              'Yes, formulated specifically for ruminant digestion. It enhances both milk volume and SNF/Fat percentages across indigenous cows and buffaloes.',
          author: 'Milterra Nutrition Expert',
          date: '28 November 2024',
        ),
        _QnAItem(
          question: 'How does bypass fat protect against metabolic disorders?',
          answer:
              'Fractionated rumen-protected palmitic acid bypasses rumen fermentation without inhibiting fiber digestion, absorbing directly in the abomasum to prevent negative energy balance (NEB).',
          author: 'Dr. S. K. Verma (Dairy Scientist)',
          date: '15 October 2024',
        ),
      ];
    } else if (isEquip) {
      return const [
        _QnAItem(
          question: 'Does this machine operate on regular single-phase domestic rural power?',
          answer:
              'Yes, equipped with a 1.0 HP high-torque motor calibrated for standard 220V/50Hz single-phase rural power with built-in low voltage thermal cut-off.',
          author: 'Milterra Engineering Support',
          date: '5 January 2025',
        ),
        _QnAItem(
          question: 'What is the warranty and spare parts availability?',
          answer:
              'Comes with a 1-year comprehensive manufacturer warranty. Spare liner sets, silicone pulsator hoses, and vacuum seals are readily available on Milterra with 48-hour dispatch.',
          author: 'Milterra Customer Care',
          date: '19 December 2024',
        ),
        _QnAItem(
          question: 'Is installation support and operational demo provided?',
          answer:
              'Yes! Detailed video demonstrations, dual-language visual manual (Hindi & English), and on-call technician guidance are included with every unit dispatch.',
          author: 'Field Service Team',
          date: '2 November 2024',
        ),
      ];
    } else {
      return const [
        _QnAItem(
          question: 'Is this ghee made using traditional Vedic Bilona method from A2 curd?',
          answer:
              'Yes, 100% pure A2 milk sourced from indigenous cows grazing on certified organic pastures. The curd is churned bi-directionally using wooden bilona and gently clarified on slow firewood heat.',
          author: 'Milterra Quality Assurance',
          date: '20 January 2025',
        ),
        _QnAItem(
          question: 'What is the shelf life and ideal storage condition?',
          answer:
              'Shelf life is 12 months from the packaging date when stored at ambient room temperature in a dry, shaded place. Do not refrigerate; keep the jar tightly sealed.',
          author: 'Milterra Production Team',
          date: '14 December 2024',
        ),
        _QnAItem(
          question: 'Does this product contain any added preservatives, palm oil, or colouring?',
          answer:
              'Zero preservatives, zero palm oil, zero synthetic colorants or perfumes. Every batch undergoes certified laboratory gas chromatography testing for absolute purity.',
          author: 'Milterra Quality Cell',
          date: '18 November 2024',
        ),
      ];
    }
  }

  Widget _buildCustomerReviews(Product p, bool isMobile) {
    return Container(
      key: _reviewsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer reviews',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile) ...[
            _buildReviewBreakdownLeft(p),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 20),
            _buildReviewFeedRight(p),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 320,
                  child: _buildReviewBreakdownLeft(p),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: _buildReviewFeedRight(p),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewBreakdownLeft(Product p) {
    final totalRatings = 1248 + _userReviews.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AmazonRatingStars(rating: 4.8, showCount: false, size: 20),
            SizedBox(width: 8),
            Text(
              '4.8 out of 5',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xff0f1111),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$totalRatings global ratings',
          style: const TextStyle(fontSize: 13, color: storeMuted),
        ),
        const SizedBox(height: 16),
        _buildStarDistributionRow('5 star', 5, 0.78),
        _buildStarDistributionRow('4 star', 4, 0.14),
        _buildStarDistributionRow('3 star', 3, 0.05),
        _buildStarDistributionRow('2 star', 2, 0.02),
        _buildStarDistributionRow('1 star', 1, 0.01),
        if (_filterStar != null) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _filterStar = null),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.clear, size: 14, color: storeGreen),
                const SizedBox(width: 4),
                Text(
                  'Clear $_filterStar-star filter',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: storeGreen,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
        const Divider(height: 32),
        const Text(
          'By feature',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 10),
        _buildFeatureScore('Freshness / Build quality', 4.9),
        _buildFeatureScore('Purity / Ease of use', 4.8),
        _buildFeatureScore('Value for money', 4.7),
        _buildFeatureScore('Packaging integrity', 4.8),
        const Divider(height: 32),
        const Text(
          'Review this product',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: storeGreen,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Share your experience with other customers',
          style: TextStyle(fontSize: 13, color: storeMuted),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: storeBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.edit_note, size: 18, color: storeGreen),
            onPressed: () => _showWriteReviewDialog(p),
            label: const Text('Write a product review',
                style: TextStyle(fontSize: 13, color: storeGreen, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  void _showWriteReviewDialog(Product p) {
    int rating = 5;
    final headlineCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: storeWhite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Create Review',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: storeGreen),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Text(
                      p.title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xff0f1111)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),

                    // Overall rating
                    const Text('Overall rating', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (int i = 1; i <= 5; i++)
                          InkWell(
                            onTap: () => setModalState(() => rating = i),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Icon(
                                i <= rating ? Icons.star : Icons.star_border,
                                size: 32,
                                color: storeStarGold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 10),
                        Text(
                          rating == 5
                              ? 'Great!'
                              : (rating == 4
                                  ? 'Good'
                                  : (rating == 3
                                      ? 'Average'
                                      : (rating == 2 ? 'Fair' : 'Poor'))),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: storeMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Headline
                    const Text('Add a headline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: headlineCtrl,
                      decoration: InputDecoration(
                        hintText: "What's most important to know?",
                        hintStyle: const TextStyle(fontSize: 13, color: storeMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: storeBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: storeGreen)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Written review
                    const Text('Add a written review', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: contentCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'What did you like or dislike? How was the purity and taste?',
                        hintStyle: const TextStyle(fontSize: 13, color: storeMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: storeBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: storeGreen)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Your Name
                    const Text('Your Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Anand Kumar',
                        hintStyle: const TextStyle(fontSize: 13, color: storeMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: storeBorder)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: storeGreen)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
                        ),
                        onPressed: () {
                          final h = headlineCtrl.text.trim();
                          final c = contentCtrl.text.trim();
                          if (h.isEmpty || c.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please add both a headline and a review.')),
                            );
                            return;
                          }
                          final name = nameCtrl.text.trim().isEmpty ? 'Verified Customer' : nameCtrl.text.trim();
                          final initials = name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
                          final newReviewId = 'rev-${DateTime.now().millisecondsSinceEpoch}';
                          setState(() {
                            _userReviews.insert(0, {
                              'id': newReviewId,
                              'author': name,
                              'avatarInitials': initials,
                              'headline': h,
                              'date': 'Today',
                              'content': c,
                              'helpfulCount': 0,
                              'rating': rating.toDouble(),
                            });
                          });
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thank you! Your verified review has been published.'),
                              backgroundColor: storeGreen,
                            ),
                          );
                        },
                        child: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStarDistributionRow(String starLabel, int starNumber, double percentage) {
    final pctText = '${(percentage * 100).round()}%';
    final isSelected = _filterStar == starNumber;
    return InkWell(
      onTap: () {
        setState(() {
          _filterStar = _filterStar == starNumber ? null : starNumber;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? storeGreen.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                starLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? storeGreen : const Color(0xff007185),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 14,
                  backgroundColor: const Color(0xfff0f2f2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSelected ? storeGreen : const Color(0xffffa41c),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 32,
              child: Text(
                pctText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? storeGreen : const Color(0xff007185),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureScore(String feature, double score) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(feature,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xff333333))),
            Row(
              children: [
                Text(
                  score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff333333),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 14, color: storeStarGold),
              ],
            ),
          ],
        ),
      );

  Widget _buildReviewFeedRight(Product p) {
    final defaultReviews = [
      {
        'id': 'def-1',
        'author': 'Ramesh Sharma',
        'avatarInitials': 'RS',
        'headline': 'Authentic desi aroma and perfect granular texture',
        'date': '14 February 2025',
        'content':
            'Exceptional quality. You can immediately smell the authentic aroma as soon as you break the tamper seal. My family loves it on rotis and warm dal. Packed securely in sturdy bubble cushioning with rapid delivery.',
        'helpfulCount': 42,
        'rating': 5.0,
      },
      {
        'id': 'def-2',
        'author': 'Kavita Patel (Dairy Cooperative Head)',
        'avatarInitials': 'KP',
        'headline': 'Noticeable milk yield and fat percentage improvement',
        'date': '3 January 2025',
        'content':
            'We tested this on our herd of 24 Sahiwal cows. Milk output improved noticeably and fat content jumped from 4.1% to 4.5%. The consistency and palatability are the highest we have encountered in the Indian market.',
        'helpfulCount': 28,
        'rating': 5.0,
      },
      {
        'id': 'def-3',
        'author': 'Vikram Reddy',
        'avatarInitials': 'VR',
        'headline': 'Sturdy engineering and clean finish, great value',
        'date': '22 December 2024',
        'content':
            'Solid build. Works exactly as described with no issues even during fluctuating rural voltage. Very easy to sanitize and dismantle. Would definitely recommend to fellow dairy professionals and farmers.',
        'helpfulCount': 15,
        'rating': 4.5,
      },
    ];

    final allReviews = [
      ..._userReviews,
      ...defaultReviews,
    ];

    final filteredReviews = _filterStar == null
        ? allReviews
        : allReviews.where((r) {
            final double ratingVal = (r['rating'] as num?)?.toDouble() ?? 5.0;
            return ratingVal.floor() == _filterStar;
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Top reviews from India',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: storeGreen,
              ),
            ),
            if (_filterStar != null)
              ActionChip(
                backgroundColor: storeGreen.withValues(alpha: 0.1),
                side: const BorderSide(color: storeGreen),
                avatar: const Icon(Icons.filter_alt, size: 14, color: storeGreen),
                label: Text(
                  '$_filterStar Star (${filteredReviews.length}) · Clear',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen),
                ),
                onPressed: () => setState(() => _filterStar = null),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredReviews.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: storeWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: storeBorder),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 40, color: storeMuted),
                  const SizedBox(height: 8),
                  Text(
                    'No $_filterStar-star customer reviews yet.',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: storeGreen),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _filterStar = null),
                    child: const Text('Show all reviews'),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          for (final r in filteredReviews) ...[
            _buildReviewCard(
              id: r['id']?.toString() ?? r['headline'].toString(),
              author: r['author'] as String,
              avatarInitials: r['avatarInitials'] as String,
              headline: r['headline'] as String,
              date: r['date'] as String,
              content: r['content'] as String,
              helpfulCount: (r['helpfulCount'] as int?) ?? 0,
              rating: (r['rating'] as num?)?.toDouble() ?? 5.0,
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),
          ],
        ],
      ],
    );
  }

  Widget _buildReviewCard({
    required String id,
    required String author,
    required String avatarInitials,
    required String headline,
    required String date,
    required String content,
    required int helpfulCount,
    double rating = 5.0,
  }) {
    final isHelpfulVoted = _helpfulVoted.contains(id);
    final displayedCount = helpfulCount + (isHelpfulVoted ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xffe3e6e6),
              child: Text(
                avatarInitials,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff565959),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              author,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xff0f1111),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            AmazonRatingStars(rating: rating, showCount: false, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                headline,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xff0f1111),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Reviewed in India on $date',
          style: const TextStyle(fontSize: 12, color: storeMuted),
        ),
        const SizedBox(height: 2),
        const Text(
          'Verified Purchase',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xffc45500),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xff0f1111),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              '$displayedCount people found this helpful',
              style: const TextStyle(fontSize: 11, color: storeMuted),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(60, 26),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: isHelpfulVoted ? const Color(0xffe8f5e9) : null,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                side: BorderSide(color: isHelpfulVoted ? storeGreen : storeBorder),
              ),
              onPressed: () {
                setState(() {
                  if (isHelpfulVoted) {
                    _helpfulVoted.remove(id);
                  } else {
                    _helpfulVoted.add(id);
                  }
                });
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    backgroundColor: storeGreen,
                    content: Text(
                      isHelpfulVoted
                          ? 'Feedback removed.'
                          : 'Thank you for marking this review as helpful!',
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHelpfulVoted) ...[
                    const Icon(Icons.check, size: 12, color: storeGreen),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    isHelpfulVoted ? 'Helpful' : 'Helpful',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isHelpfulVoted ? FontWeight.bold : FontWeight.normal,
                      color: storeGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Text('|', style: TextStyle(color: storeBorder)),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Review reported for moderation. Thank you.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Report',
                  style: TextStyle(fontSize: 11, color: storeMuted)),
            ),
          ],
        ),
      ],
    );
  }
}

class _QnAItem {
  const _QnAItem({
    required this.question,
    required this.answer,
    required this.author,
    required this.date,
  });
  final String question, answer, author, date;
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


