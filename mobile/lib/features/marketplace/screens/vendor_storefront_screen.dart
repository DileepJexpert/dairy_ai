import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/store_product_card.dart';

class VendorStorefrontScreen extends ConsumerStatefulWidget {
  const VendorStorefrontScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  ConsumerState<VendorStorefrontScreen> createState() =>
      _VendorStorefrontScreenState();
}

class _VendorStorefrontScreenState
    extends ConsumerState<VendorStorefrontScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'ALL';
  bool _inStockOnly = false;
  final Set<String> _addingIds = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addToCart(Product p) async {
    if (p.isConcept) return;
    if (ref.read(currentUserProvider) == null) {
      context.go('/login?next=/store/vendor/${widget.vendorId}');
      return;
    }
    setState(() => _addingIds.add(p.id));
    try {
      await ref.read(cartProvider.notifier).add(p.id, p.minOrderQuantity, p);
      if (mounted) {
        await showStoreCart(context);
      }
    } finally {
      if (mounted) {
        setState(() => _addingIds.remove(p.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storefrontAsync = ref.watch(vendorStorefrontProvider(widget.vendorId));

    return Scaffold(
      backgroundColor: storeCream,
      body: SafeArea(
        child: Column(
          children: [
            const StoreHeader(currentCategory: 'All'),
            Expanded(
              child: storefrontAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: storeGreen),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 64, color: storeMuted),
                        const SizedBox(height: 16),
                        const Text(
                          'Seller Storefront Not Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: storeGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This vendor profile is currently unavailable or inactive.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => context.go('/shop'),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Marketplace'),
                          style: FilledButton.styleFrom(
                            backgroundColor: storeGreen,
                            foregroundColor: storeWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (data) => _buildStorefrontContent(context, data),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorefrontContent(
      BuildContext context, VendorStorefrontData data) {
    final vendor = data.vendor;
    final allProducts = data.products;

    // Extract dynamic categories from the vendor's products
    final categories = <String>{'ALL'};
    for (final p in allProducts) {
      categories.add(storeCategory(p));
    }

    // Filter products
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = allProducts.where((p) {
      if (_inStockOnly && !p.inStock) return false;
      if (_selectedCategory != 'ALL') {
        if (storeCategory(p).toLowerCase() != _selectedCategory.toLowerCase()) {
          return false;
        }
      }
      if (query.isNotEmpty) {
        final matchesTitle = p.title.toLowerCase().contains(query);
        final matchesBrand = (p.brand ?? '').toLowerCase().contains(query);
        final matchesDesc =
            (p.description ?? '').toLowerCase().contains(query);
        final matchesPack = (p.packSize ?? '').toLowerCase().contains(query);
        if (!matchesTitle && !matchesBrand && !matchesDesc && !matchesPack) {
          return false;
        }
      }
      return true;
    }).toList();

    final isWide = MediaQuery.of(context).size.width >= 768;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 12,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Breadcrumbs
                _buildBreadcrumbs(vendor['business_name']?.toString() ?? 'Store'),
                const SizedBox(height: 16),

                // 2. Seller Hero Profile Banner
                _buildSellerHeroBanner(vendor, allProducts.length, isWide),
                const SizedBox(height: 18),

                // 3. About the Seller & Credentials
                _buildAboutSellerPanel(vendor),
                const SizedBox(height: 24),

                // 4. Products Search, Filter Chips & Count
                _buildCatalogControls(categories, filtered.length),
                const SizedBox(height: 16),

                // 5. Product Grid or Empty State
                if (filtered.isEmpty)
                  _buildEmptyState()
                else
                  _buildProductGrid(filtered),

                const SizedBox(height: 40),
                const StoreFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(String storeName) {
    return Row(
      children: [
        InkWell(
          onTap: () => context.go('/shop'),
          child: const Text(
            'Marketplace',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: storeMuted,
            ),
          ),
        ),
        const Text(
          '  ›  ',
          style: TextStyle(fontSize: 12, color: storeMuted),
        ),
        const Text(
          'Verified Producers',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: storeMuted,
          ),
        ),
        const Text(
          '  ›  ',
          style: TextStyle(fontSize: 12, color: storeMuted),
        ),
        Expanded(
          child: Text(
            storeName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: storeGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSellerHeroBanner(
      Map<String, dynamic> vendor, int totalProducts, bool isWide) {
    final businessName = vendor['business_name']?.toString() ?? 'Vendor';
    final vendorType = (vendor['vendor_type']?.toString() ?? 'PRODUCER')
        .replaceAll('_', ' ')
        .toUpperCase();
    final district = vendor['district']?.toString() ?? '';
    final state = vendor['state']?.toString() ?? '';
    final location = [district, state].where((s) => s.isNotEmpty).join(', ');
    final rating = double.tryParse(vendor['rating_avg']?.toString() ?? '4.8') ?? 4.8;
    final totalOrders = vendor['total_orders'] ?? 0;
    final isVerified = vendor['is_verified'] == true;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Top Color Bar with subtle farm branding
          Container(
            height: 90,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xff1e3a2b), Color(0xff2d5a3f), Color(0xff437c56)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco_outlined, color: storeAmber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'MILTERRA VERIFIED DIRECT PRODUCER',
                      style: TextStyle(
                        color: storeAmber.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    vendorType,
                    style: const TextStyle(
                      color: storeWhite,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Seller Info Block
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller Avatar Emblem
                Container(
                  width: isWide ? 84 : 64,
                  height: isWide ? 84 : 64,
                  decoration: BoxDecoration(
                    color: storeCream,
                    shape: BoxShape.circle,
                    border: Border.all(color: storeBorder, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      businessName.isNotEmpty
                          ? businessName.substring(0, 1).toUpperCase()
                          : 'V',
                      style: TextStyle(
                        fontSize: isWide ? 36 : 28,
                        fontWeight: FontWeight.w900,
                        color: storeGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            businessName,
                            style: TextStyle(
                              fontSize: isWide ? 22 : 18,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xff111827),
                            ),
                          ),
                          if (isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xffecfdf5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xff10b981), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      size: 13, color: Color(0xff059669)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified Seller',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff059669),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 14, color: storeMuted),
                            const SizedBox(width: 4),
                            Text(
                              location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xff4b5563),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Metrics Pill Badges
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _buildMetricBadge(
                            icon: Icons.star_rounded,
                            iconColor: const Color(0xfff59e0b),
                            label: '${rating.toStringAsFixed(1)} Rating',
                            bgColor: const Color(0xfffffbeb),
                          ),
                          _buildMetricBadge(
                            icon: Icons.local_shipping_outlined,
                            iconColor: storeGreen,
                            label: '$totalOrders Orders Fulfilled',
                            bgColor: storeGreen.withValues(alpha: 0.08),
                          ),
                          _buildMetricBadge(
                            icon: Icons.inventory_2_outlined,
                            iconColor: const Color(0xff4338ca),
                            label: '$totalProducts Live Products',
                            bgColor: const Color(0xffeef2ff),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Trust & Compliance Row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: storeCream.withValues(alpha: 0.6),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(15)),
              border: const Border(top: BorderSide(color: storeBorder)),
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (vendor['fssai_license_number'] != null &&
                    vendor['fssai_license_number'].toString().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 15, color: storeGreen),
                      const SizedBox(width: 5),
                      Text(
                        'FSSAI: ${vendor['fssai_license_number']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: storeGreen,
                        ),
                      ),
                    ],
                  ),
                if (vendor['gst_number'] != null &&
                    vendor['gst_number'].toString().isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined,
                          size: 15, color: Color(0xff4b5563)),
                      const SizedBox(width: 5),
                      Text(
                        'GSTIN: ${vendor['gst_number']}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff4b5563),
                        ),
                      ),
                    ],
                  ),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.thumb_up_alt_outlined,
                        size: 14, color: Color(0xff059669)),
                    SizedBox(width: 5),
                    Text(
                      '100% Quality & Traceability Guaranteed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSellerPanel(Map<String, dynamic> vendor) {
    final description = vendor['description']?.toString() ??
        'A dedicated verified producer providing direct agricultural and dairy goods on the Milterra platform.';
    final serviceAreas = (vendor['service_areas'] as List? ?? [])
        .map((e) => e.toString())
        .toList();
    final specialties = (vendor['products_services'] as List? ?? [])
        .map((e) => e.toString())
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About This Producer',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xff1f2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xff4b5563),
            ),
          ),
          if (specialties.isNotEmpty || serviceAreas.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final spec in specialties)
                  Chip(
                    label: Text(spec),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: storeGreen,
                    ),
                    backgroundColor: storeCream,
                    side: const BorderSide(color: storeBorder),
                    visualDensity: VisualDensity.compact,
                  ),
                for (final area in serviceAreas)
                  Chip(
                    avatar: const Icon(Icons.pin_drop_outlined,
                        size: 13, color: Color(0xff6b7280)),
                    label: Text(area),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff374151),
                    ),
                    backgroundColor: const Color(0xfff3f4f6),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCatalogControls(Set<String> categories, int resultCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: storeBorder),
          ),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: "Search within this seller's catalogue…",
              hintStyle: const TextStyle(fontSize: 13, color: storeMuted),
              prefixIcon: const Icon(Icons.search, color: storeGreen, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Filter chips row
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final cat in categories)
              ChoiceChip(
                label: Text(cat == 'ALL' ? 'All Products' : cat),
                selected: _selectedCategory.toUpperCase() == cat.toUpperCase(),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCategory = cat);
                  }
                },
                selectedColor: storeGreen,
                backgroundColor: storeWhite,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _selectedCategory.toUpperCase() == cat.toUpperCase()
                      ? storeWhite
                      : const Color(0xff374151),
                ),
                side: BorderSide(
                  color: _selectedCategory.toUpperCase() == cat.toUpperCase()
                      ? storeGreen
                      : storeBorder,
                ),
              ),
            FilterChip(
              label: const Text('In-Stock Only'),
              selected: _inStockOnly,
              onSelected: (val) => setState(() => _inStockOnly = val),
              selectedColor: const Color(0xffd1fae5),
              checkmarkColor: const Color(0xff059669),
              backgroundColor: storeWhite,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _inStockOnly ? const Color(0xff059669) : const Color(0xff374151),
              ),
              side: BorderSide(
                color: _inStockOnly ? const Color(0xff10b981) : storeBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Count Banner
        Text(
          '$resultCount ${resultCount == 1 ? 'product' : 'products'} available',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xff4b5563),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 54, color: storeMuted),
          const SizedBox(height: 12),
          const Text(
            'No matching products found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff1f2937),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Try clearing your search query or filters.',
            style: TextStyle(fontSize: 13, color: storeMuted),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _searchCtrl.clear();
                _selectedCategory = 'ALL';
                _inStockOnly = false;
              });
            },
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    // Group packs by familyKey for multi-pack variant selection cards
    final groups = storeProductGroups(products);

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      int columns = 1;
      if (width >= 1024) {
        columns = 4;
      } else if (width >= 680) {
        columns = 3;
      } else if (width >= 440) {
        columns = 2;
      }

      const gap = 16.0;
      final cardWidth = ((width - (gap * (columns - 1))) / columns)
          .clamp(140.0, 320.0);

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: groups.map((packs) {
          return SizedBox(
            width: cardWidth,
            child: StoreProductCard(
              key: ValueKey(packs.first.id),
              packs: packs,
              compact: columns > 2,
              busyIds: _addingIds,
              onAdd: _addToCart,
              onOpen: (p) => context.push('/shop/product/${p.id}'),
            ),
          );
        }).toList(),
      );
    });
  }
}
