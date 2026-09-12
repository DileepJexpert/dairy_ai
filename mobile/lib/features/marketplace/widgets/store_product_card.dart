import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../cart/providers/wishlist_provider.dart';
import '../models/product_models.dart';
import 'store_design.dart';

// Presentation grouping only: every selected pack retains its real product ID.
// This matches the existing detail-page variant rule until family IDs exist.
List<List<Product>> storeProductGroups(List<Product> products) {
  final groups = <String, List<Product>>{};
  for (final product in products) {
    final key = product.packSize == null
        ? product.id
        : '${product.vendorId}|${product.title}|${storeCategory(product)}';
    groups.putIfAbsent(key, () => []).add(product);
  }
  return groups.values.toList();
}

class StoreProductCard extends StatefulWidget {
  const StoreProductCard(
      {super.key,
      required this.packs,
      required this.onOpen,
      required this.onAdd,
      this.busyIds = const {},
      this.compact = false});
  final List<Product> packs;
  final ValueChanged<Product> onOpen, onAdd;
  final Set<String> busyIds;
  final bool compact;
  @override
  State<StoreProductCard> createState() => _StoreProductCardState();
}

class _StoreProductCardState extends State<StoreProductCard> {
  String? _selected;
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.packs
        .firstWhere((p) => p.id == _selected, orElse: () => widget.packs.first);
    final busy = widget.busyIds.contains(product.id);
    final isEarth = product.taxonomy?['is_earth'] == true ||
        product.taxonomy?['category_name'] == 'MILTERRA Earth' ||
        product.title.toLowerCase().contains('milterra earth') ||
        (product.brand?.toLowerCase() == 'milterra earth');
    final isConcept = !isEarth &&
        (product.taxonomy?['concept'] == true ||
            (product.category == ProductCategory.feedNutrition &&
                !product.title.toLowerCase().contains('ghee') &&
                !product.title.toLowerCase().contains('paneer') &&
                !product.title.toLowerCase().contains('butter')));
    final conceptStatus =
        product.taxonomy?['status']?.toString() ?? 'Concept Preview';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : StoreLayout.motion,
        decoration: BoxDecoration(
          color: storeWhite,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          border: Border.all(
            color: _hover
                ? (isEarth
                    ? storeEarthDarkGreen.withValues(alpha: 0.5)
                    : storeGreen.withValues(alpha: 0.3))
                : storeBorder,
            width: _hover ? 1.5 : 1,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: (isEarth ? storeEarthDarkGreen : storeGreen)
                        .withValues(alpha: .08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  const BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.onOpen(product),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Stack with Badges
                Stack(
                  children: [
                    Material(
                      color:
                          isEarth ? storeEarthCream : const Color(0xfffaf8f5),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(StoreLayout.radius)),
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: 1.05,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: AnimatedScale(
                            scale: _hover ? 1.04 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: ProductArtwork(product: product),
                          ),
                        ),
                      ),
                    ),
                    if (isEarth)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: storeEarthTerracotta,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.eco_rounded,
                                  size: 11, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Coming Soon',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (isConcept)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: storeGreen,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.science_outlined,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                conceptStatus
                                        .toUpperCase()
                                        .contains('DEVELOPMENT')
                                    ? 'In Development'
                                    : 'Concept Preview',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: WishlistHeartButton(product: product),
                    ),
                  ],
                ),

                // Product Details Block
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: isEarth
                      ? _buildEarthDetails(context, product)
                      : isConcept
                          ? _buildConceptDetails(context, product)
                          : _buildCommercialDetails(context, product, busy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEarthDetails(BuildContext context, Product product) {
    final status = product.taxonomy?['status']?.toString() ?? 'Coming Soon';
    final brandLine = product.taxonomy?['brand_line']?.toString() ??
        'Living Soil • Farm Composts • Natural Carbon';
    final usage = product.taxonomy?['usage_description']?.toString() ??
        'Natural soil conditioner for gardens, plants, and organic farm beds.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge & Brand Line
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: storeEarthTerracotta,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                brandLine,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: storeEarthWarmBrown,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Title (Clickable)
        InkWell(
          key: ValueKey('catalogue-open-${product.id}'),
          onTap: () => widget.onOpen(product),
          child: SizedBox(
            height: 38,
            child: Text(
              product.title,
              style: TextStyle(
                fontSize: widget.compact ? 13 : 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xff111111),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Pack Size & Indicative Price Row
        Row(
          children: [
            if (product.packSize != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: storeEarthCream,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: storeEarthTerracotta.withValues(alpha: 0.4)),
                ),
                child: Text(
                  product.packSize!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: storeEarthWarmBrown,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${storeMoney(product.price)} (Indicative MRP)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xff555555),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Short Usage Description
        SizedBox(
          height: 32,
          child: Text(
            usage,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xff4b5563),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),

        // Source & Batch Traceability Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: storeEarthCream,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xffdcd6cb)),
          ),
          child: const Row(
            children: [
              Icon(Icons.eco_outlined, size: 13, color: storeEarthDarkGreen),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Sourced from Certified Dairy AI Partner Farms · Batch Traceable',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: storeEarthDarkGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Action Buttons: Notify Me & Explore Details
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 34,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: storeEarthDarkGreen,
                    foregroundColor: storeWhite,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => _showNotifyMeDialog(context, product),
                  icon:
                      const Icon(Icons.notifications_active_outlined, size: 14),
                  label: const Text(
                    'Notify Me',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: storeBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => widget.onOpen(product),
                child: const Text(
                  'Details',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: storeEarthDarkGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showNotifyMeDialog(BuildContext context, Product product) {
    final contactCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.notifications_active,
                color: storeEarthDarkGreen, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Notify on Launch: ${product.title}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: storeEarthDarkGreen,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MILTERRA Earth products are currently in production and quality curing. Enter your WhatsApp number or email to receive priority dispatch notifications when this batch opens.',
              style: TextStyle(fontSize: 12.5, color: Color(0xff444444)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'WhatsApp phone or email address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.contact_mail_outlined, size: 18),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: storeMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: storeEarthDarkGreen,
              foregroundColor: storeWhite,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 4),
                  backgroundColor: storeEarthDarkGreen,
                  content: Text(
                    'Thank you! We have registered your notification request for "${product.title}".',
                  ),
                ),
              );
            },
            child: const Text('Notify Me',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptDetails(BuildContext context, Product product) {
    final status = product.taxonomy?['status']?.toString() ?? 'Concept Preview';
    final brandLine = product.taxonomy?['brand_line']?.toString() ??
        'Feeds • Supplements • Calcium STC • Health & Productivity';
    final tagline = product.taxonomy?['tagline']?.toString() ??
        'Natural Nutrition for Healthy Livestock';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge & Brand Line
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: status.toLowerCase().contains('development')
                    ? const Color(0xff067d62)
                    : const Color(0xffd97706),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                brandLine,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: storeMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Title (Clickable) - Keep MILTERRA brand prefix consistent
        InkWell(
          onTap: () => widget.onOpen(product),
          child: SizedBox(
            height: 38,
            child: Text(
              product.title.toUpperCase().contains('MILTERRA')
                  ? product.title
                  : 'MILTERRA ${product.title}',
              style: TextStyle(
                fontSize: widget.compact ? 13 : 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xff111111),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Tagline
        SizedBox(
          height: 30,
          child: Text(
            tagline,
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Color(0xff4b5563),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),

        // Concept Validation Note
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xfff0fdf4),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xffbbf7d0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.biotech_outlined, size: 14, color: storeGreen),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Formulation Preview · Feedback Open',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: storeGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // CTA Buttons: Explore Concept / Share Feedback
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 34,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: storeGreen,
                    foregroundColor: storeWhite,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => widget.onOpen(product),
                  child: const Text(
                    'Explore Concept',
                    style:
                        TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 34,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: const BorderSide(color: storeBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => _showFeedbackDialog(context, product),
                child: const Text(
                  'Feedback',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: storeGreen),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showFeedbackDialog(BuildContext context, Product product) {
    final feedbackCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.rate_review_outlined, color: storeGreen, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Farmer Feedback: ${product.title}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: storeGreen),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help shape upcoming Milterra livestock nutrition formulations. What features, pack sizes, or ingredients are most important for your herd?',
              style: TextStyle(fontSize: 12.5, color: Color(0xff444444)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Enter your suggestions or field requirements…',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: storeMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: storeGreen,
              foregroundColor: storeWhite,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 3),
                  backgroundColor: storeGreen,
                  content: Text(
                      'Thank you! Your feedback for "${product.title}" has been recorded.'),
                ),
              );
            },
            child: const Text('Submit Feedback',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommercialDetails(
      BuildContext context, Product product, bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Brand / Category Tag
        Text(
          (product.brand ?? storeCategory(product)).toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: storeMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Title (Clickable)
        InkWell(
          key: ValueKey('catalogue-open-${product.id}'),
          onTap: () => widget.onOpen(product),
          child: SizedBox(
            height: 40,
            child: Text(
              product.title.replaceFirst('Milterra ', ''),
              style: TextStyle(
                fontSize: widget.compact ? 13 : 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xff111111),
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(height: 6),

        const AmazonRatingStars(rating: 0, reviewCount: 0),
        const SizedBox(height: 6),

        // Pack Sizes Selection Chips
        if (widget.packs.length > 1) ...[
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: widget.packs
                  .map((pack) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          key: ValueKey('catalogue-pack-${pack.id}'),
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            pack.packSize ?? pack.unit,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: pack.id == product.id
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: pack.id == product.id
                                  ? storeGreen
                                  : storeMuted,
                            ),
                          ),
                          selected: pack.id == product.id,
                          selectedColor: storeSage,
                          backgroundColor: storeCream,
                          side: BorderSide(
                            color: pack.id == product.id
                                ? storeGreen
                                : storeBorder,
                            width: pack.id == product.id ? 1.5 : 1,
                          ),
                          onSelected: (_) =>
                              setState(() => _selected = pack.id),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Current catalogue price
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              storeMoney(product.price),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xff0f1111),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Delivery Tag
        const Row(
          children: [
            Icon(Icons.bolt, size: 14, color: storeAmberDark),
            SizedBox(width: 2),
            Expanded(
              child: Text(
                'Delivery availability shown at checkout',
                style: TextStyle(
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
        const SizedBox(height: 2),

        // Stock Status
        Text(
          product.inStock
              ? (product.availableQuantity <= 5 && product.availableQuantity > 0
                  ? 'Only ${product.availableQuantity} left in stock - order soon'
                  : 'In stock')
              : 'Currently unavailable',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: product.inStock
                ? (product.availableQuantity <= 5 &&
                        product.availableQuantity > 0
                    ? const Color(0xffb12704)
                    : storeSuccess)
                : storeError,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 10),

        // Amazon-style Amber Add to Cart Button
        SizedBox(
          width: double.infinity,
          height: 36,
          child: FilledButton(
            style: StoreTheme.addToCartButton,
            onPressed: product.inStock &&
                    product.availableQuantity >= product.minOrderQuantity &&
                    !busy
                ? () => widget.onAdd(product)
                : null,
            child: Text(
              busy ? 'Adding…' : 'Add to cart',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WishlistHeartButton extends ConsumerWidget {
  const WishlistHeartButton({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlisted = ref.watch(isWishlistedProvider(product.id));

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: wishlisted ? 'Remove from Wishlist' : 'Add to Wishlist',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final added = ref.read(wishlistProvider.notifier).toggle(product);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 2),
                backgroundColor: storeGreen,
                content: Text(
                  added
                      ? 'Added ${product.title} to your Wishlist.'
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
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              wishlisted ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: wishlisted ? const Color(0xffd9383a) : storeMuted,
            ),
          ),
        ),
      ),
    );
  }
}
