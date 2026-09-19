import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/widgets/product_media_manager.dart';
import '../../commerce/models/taxonomy.dart';
import '../../commerce/providers/commerce_provider.dart';

final vendorProductsProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(currentUserProvider);
  final res = await ref.read(dioProvider).get('/vendor/products');
  final body = res.data as Map<String, dynamic>;
  final list = (body['data'] as List? ?? [])
      .map((x) => Product.fromJson(Map<String, dynamic>.from(x as Map)))
      .toList();
  return list;
});

class VendorProductsScreen extends ConsumerStatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  ConsumerState<VendorProductsScreen> createState() =>
      _VendorProductsScreenState();
}

class _VendorProductsScreenState extends ConsumerState<VendorProductsScreen> {
  String _filter = 'all'; // 'all', 'in_stock', 'low_stock', 'out_of_stock'
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(vendorProductsProvider);

    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        title: const Text(
          'Seller Catalogue Manager',
          style: TextStyle(fontWeight: FontWeight.bold, color: storeGreen),
        ),
        backgroundColor: storeWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: storeGreen),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh listings',
            onPressed: () => ref.invalidate(vendorProductsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: storeAmber,
        foregroundColor: storeGreen,
        onPressed: () => _openAddProductModal(context),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text(
          'Add New Product',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: storeMuted),
              const SizedBox(height: 12),
              Text('Error loading catalogue: $e'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(vendorProductsProvider),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
        data: (allProducts) {
          final query = _searchCtrl.text.trim().toLowerCase();
          final filtered = allProducts.where((p) {
            final matchesQuery = query.isEmpty ||
                p.title.toLowerCase().contains(query) ||
                (p.brand?.toLowerCase().contains(query) ?? false);
            if (!matchesQuery) return false;

            return switch (_filter) {
              'in_stock' => p.availableQuantity > 5,
              'low_stock' =>
                p.availableQuantity > 0 && p.availableQuantity <= 5,
              'out_of_stock' => p.availableQuantity <= 0,
              _ => true,
            };
          }).toList();

          final inStockCount =
              allProducts.where((p) => p.availableQuantity > 5).length;
          final lowStockCount = allProducts
              .where((p) => p.availableQuantity > 0 && p.availableQuantity <= 5)
              .length;
          final outStockCount =
              allProducts.where((p) => p.availableQuantity <= 0).length;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(vendorProductsProvider),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Stats Overview
                      _buildCatalogueStatsRow(
                        total: allProducts.length,
                        inStock: inStockCount,
                        lowStock: lowStockCount,
                        outOfStock: outStockCount,
                      ),
                      const SizedBox(height: 18),

                      // Search and Filter Strip
                      _buildSearchAndFilterStrip(),
                      const SizedBox(height: 18),

                      // Product List or Empty State
                      if (filtered.isEmpty)
                        _buildEmptyCatalogueState()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            return _buildVendorProductCard(product);
                          },
                        ),
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Catalogue Summary Metric Cards
  // --------------------------------------------------------------------------
  Widget _buildCatalogueStatsRow({
    required int total,
    required int inStock,
    required int lowStock,
    required int outOfStock,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      final isCompact = constraints.maxWidth < 650;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _statTile('Active Listings', '$total', Icons.inventory_2_outlined,
              storeGreen, isCompact ? 140 : 200),
          _statTile('In Stock', '$inStock', Icons.check_circle_outline,
              const Color(0xff2e7d32), isCompact ? 140 : 200),
          _statTile('Low Stock (≤5)', '$lowStock', Icons.warning_amber_rounded,
              const Color(0xffb78103), isCompact ? 140 : 200),
          _statTile('Out of Stock', '$outOfStock', Icons.cancel_outlined,
              const Color(0xffc62828), isCompact ? 140 : 200),
        ],
      );
    });
  }

  Widget _statTile(
      String title, String val, IconData icon, Color color, double minWidth) {
    return Container(
      width: minWidth,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                val,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: storeMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Search Bar & Filter Chips Strip
  // --------------------------------------------------------------------------
  Widget _buildSearchAndFilterStrip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input field
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search products by title or brand...',
              prefixIcon: const Icon(Icons.search, color: storeMuted),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: storeBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('all', 'All Products'),
              _filterChip('in_stock', 'In Stock'),
              _filterChip('low_stock', 'Low Stock (≤5)'),
              _filterChip('out_of_stock', 'Out of Stock'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = key),
      selectedColor: storeAmber.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? storeGreen : storeMuted,
      ),
      backgroundColor: storeWhite,
      side: BorderSide(
        color: isSelected ? storeAmber : storeBorder,
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Product Card with Artwork, Stock Stepper, Active Toggle
  // --------------------------------------------------------------------------
  Widget _buildVendorProductCard(Product p) {
    final isLowStock = p.availableQuantity > 0 && p.availableQuantity <= 5;
    final isOut = p.availableQuantity <= 0;

    final stockColor = isOut
        ? const Color(0xffc62828)
        : (isLowStock ? const Color(0xffb78103) : const Color(0xff2e7d32));

    final stockLabel = isOut
        ? 'Out of Stock'
        : (isLowStock
            ? 'Low Stock (${p.availableQuantity} left)'
            : 'In Stock (${p.availableQuantity} available)');

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Product Artwork Thumbnail
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xfff9f9f9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: storeBorder),
            ),
            padding: const EdgeInsets.all(4),
            child: p.media.isNotEmpty
                ? Image.network(
                    p.media.first,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        ProductArtwork(product: p, showCaption: false),
                  )
                : ProductArtwork(product: p, showCaption: false),
          ),
          const SizedBox(width: 16),

          // Center Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Department/Category pill & Publication Status
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: storeWarm,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        storeCategory(p).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: storeGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.isPendingApproval
                            ? const Color(0xfffff8e1)
                            : p.isRejected
                                ? const Color(0xffffebee)
                                : const Color(0xffe8f5e9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: p.isPendingApproval
                                ? storeAmberDark
                                : p.isRejected
                                    ? storeError
                                    : storeGreen),
                      ),
                      child: Text(
                        p.isPendingApproval
                            ? 'PENDING REVIEW'
                            : p.isRejected
                                ? 'REJECTED'
                                : 'LIVE ON STORE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: p.isPendingApproval
                              ? storeAmberDark
                              : p.isRejected
                                  ? storeError
                                  : storeGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Title
                Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: storeGreen,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Brand & Pack Size
                Wrap(
                  spacing: 8,
                  children: [
                    if (p.brand != null && p.brand!.isNotEmpty)
                      Text(
                        'Brand: ${p.brand}',
                        style: const TextStyle(fontSize: 12, color: storeMuted),
                      ),
                    if (p.packSize != null && p.packSize!.isNotEmpty)
                      Text(
                        '• ${p.packSize}',
                        style: const TextStyle(fontSize: 12, color: storeMuted),
                      ),
                    Text(
                      '• Unit: ${p.unit}',
                      style: const TextStyle(fontSize: 12, color: storeMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Price & Stock status row
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      storeMoney(p.price),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: storeOrange,
                      ),
                    ),
                    if (p.compareAtPrice != null && p.compareAtPrice! > p.price)
                      Text(
                        storeMoney(p.compareAtPrice!),
                        style: const TextStyle(
                          fontSize: 13,
                          color: storeMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stockColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: stockColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        stockLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: stockColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right Quick Actions Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Stock Quick Update Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  side: const BorderSide(color: storeBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _openStockAdjustmentDialog(p),
                icon: const Icon(Icons.edit_note, size: 16, color: storeGreen),
                label: const Text(
                  'Set Stock',
                  style: TextStyle(fontSize: 12, color: storeGreen),
                ),
              ),
              const SizedBox(height: 8),

              // Active / Inactive switch
              TextButton.icon(
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Images'),
                onPressed: () async {
                  await showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          ProductMediaManager(productId: p.id, title: p.title));
                  ref.invalidate(vendorProductsProvider);
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.isActive ? 'Listed' : 'Paused',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: p.isActive ? storeGreen : storeMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: p.isActive,
                    activeThumbColor: storeGreen,
                    onChanged: (val) => _toggleProductStatus(p, val),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCatalogueState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: storeMuted),
          const SizedBox(height: 16),
          const Text(
            'No products matching this filter.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try clearing your search or add a new product listing.',
            style: TextStyle(fontSize: 13, color: storeMuted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: storeAmber,
              foregroundColor: storeGreen,
            ),
            onPressed: () => _openAddProductModal(context),
            icon: const Icon(Icons.add),
            label: const Text('Add Product Listing'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Quick Stock Adjustment Dialog
  // --------------------------------------------------------------------------
  Future<void> _openStockAdjustmentDialog(Product p) async {
    final stockCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Stock: ${p.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the total warehouse count, including reserved units. Existing reservations are protected:',
              style: TextStyle(fontSize: 13, color: storeMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Total warehouse quantity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warehouse_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: storeAmber,
              foregroundColor: storeGreen,
            ),
            onPressed: () async {
              final newStock = int.tryParse(stockCtrl.text.trim());
              if (newStock == null || newStock < 0) return;
              Navigator.pop(ctx);

              try {
                final dio = ref.read(dioProvider);
                await dio.patch(
                  '/vendor/commerce/offers/${p.id}',
                  data: {'available_stock': newStock},
                );
                ref.invalidate(vendorProductsProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: storeGreen,
                      content: Text(
                          'Updated inventory for ${p.title} to $newStock units.'),
                    ),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Stock was not saved. Check your connection and try again.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Update Inventory'),
          ),
        ],
      ),
    );
    stockCtrl.dispose();
  }

  // --------------------------------------------------------------------------
  // Toggle Active / Inactive Status
  // --------------------------------------------------------------------------
  Future<void> _toggleProductStatus(Product p, bool active) async {
    try {
      final dio = ref.read(dioProvider);
      if (!active) {
        await dio.delete('/vendor/products/${p.id}');
      } else {
        await dio.put(
          '/vendor/products/${p.id}',
          data: {'is_active': true},
        );
      }
      ref.invalidate(vendorProductsProvider);
    } catch (_) {
      ref.invalidate(vendorProductsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Listing status was not saved. Please try again.')));
      }
    }
  }

  // --------------------------------------------------------------------------
  // Modal Sheet: Add New Product Across Any Department
  // --------------------------------------------------------------------------
  Future<void> _openAddProductModal(BuildContext context) async {
    final sku = TextEditingController(
        text: 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}');
    final title = TextEditingController();
    final brand = TextEditingController(text: 'Milterra');
    final packSize = TextEditingController(text: '500 ml');
    final price = TextEditingController();
    final mrp = TextEditingController();
    final stock = TextEditingController(text: '25');
    final unit = TextEditingController(text: 'jar');
    final weight = TextEditingController(text: '500');
    final image = TextEditingController();
    final desc = TextEditingController();

    String? selectedDepartmentId;
    String? selectedCategoryId;
    String? selectedSubcategoryId;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: storeWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 20, 24, MediaQuery.viewInsetsOf(sheet).bottom + 24),
        child: StatefulBuilder(
          builder: (modalCtx, setModalState) => Consumer(
            builder: (ctx, ref, _) {
              final taxonomy = ref.watch(taxonomyProvider).valueOrNull ??
                  const TaxonomyCatalogue(enabled: false, nodes: []);
              final departments = taxonomy.departments;

              if (selectedDepartmentId == null && departments.isNotEmpty) {
                selectedDepartmentId = departments.first.id;
              }

              final categories = selectedDepartmentId != null
                  ? taxonomy.categoriesFor(selectedDepartmentId)
                  : <TaxonomyNode>[];

              if (selectedCategoryId != null &&
                  !categories.any((c) => c.id == selectedCategoryId)) {
                selectedCategoryId = null;
                selectedSubcategoryId = null;
              }

              final subcategories = selectedCategoryId != null
                  ? taxonomy.subcategoriesFor(selectedCategoryId)
                  : <TaxonomyNode>[];

              if (selectedSubcategoryId != null &&
                  !subcategories.any((s) => s.id == selectedSubcategoryId)) {
                selectedSubcategoryId = null;
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Product / SKU',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: storeGreen,
                              ),
                            ),
                            Text(
                              'Amazon/Flipkart-style Catalogue Onboarding',
                              style: TextStyle(fontSize: 12, color: storeMuted),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheet),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Section: Category Hierarchy
                    const Text(
                      'Marketplace Taxonomy Classification *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: storeGreen,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Department (L1) Dropdown
                    if (departments.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedDepartmentId,
                        decoration: const InputDecoration(
                          labelText: 'Department (Level 1)',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: departments
                            .map((d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text(d.name),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setModalState(() {
                            selectedDepartmentId = val;
                            selectedCategoryId = null;
                            selectedSubcategoryId = null;
                            final deptName = departments
                                .firstWhere((d) => d.id == val)
                                .name
                                .toLowerCase();
                            if (deptName.contains('equipment') ||
                                deptName.contains('machinery')) {
                              unit.text = 'unit';
                              packSize.text = '1 machine';
                            } else if (deptName.contains('feed') ||
                                deptName.contains('nutrition')) {
                              unit.text = 'bag';
                              packSize.text = '50 kg';
                            } else {
                              unit.text = 'jar';
                              packSize.text = '500 ml';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Category (L2) Dropdown
                    if (categories.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category (Level 2)',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Select Category —'),
                          ),
                          ...categories.map((c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name),
                              )),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedCategoryId = val;
                            selectedSubcategoryId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Subcategory (L3) Dropdown
                    if (subcategories.isNotEmpty) ...[
                      DropdownButtonFormField<String?>(
                        initialValue: selectedSubcategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Subcategory (Level 3 - Optional)',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('— Select Subcategory (Optional) —'),
                          ),
                          ...subcategories.map((s) => DropdownMenuItem<String?>(
                                value: s.id,
                                child: Text(s.name),
                              )),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedSubcategoryId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Section: SKU and Title
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: sku,
                            decoration: InputDecoration(
                              labelText: 'Seller SKU *',
                              hintText: 'e.g. MIL-GHEE-500',
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                tooltip: 'Auto-generate SKU',
                                onPressed: () => setModalState(() => sku.text =
                                    'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: brand,
                            decoration: const InputDecoration(
                              labelText: 'Brand',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Title
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'Product Title *',
                        hintText: 'e.g. Pure A2 Gir Cow Bilona Ghee (Glass Jar)',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Pack Size & Unit
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: packSize,
                            decoration: const InputDecoration(
                              labelText: 'Pack Size / Variant *',
                              hintText: 'e.g. 500 ml / 1 kg',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: unit,
                            decoration: const InputDecoration(
                              labelText: 'Unit of Measure',
                              hintText: 'jar / bottle / bag',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: weight,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Weight (g)',
                              hintText: 'e.g. 500',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Price, MRP & Stock Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Selling Price (₹) *',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: mrp,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'MRP / Compare (₹)',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: stock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Initial Stock *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Image URL with presets
                    TextField(
                      controller: image,
                      decoration: const InputDecoration(
                        labelText: 'Primary Image URL (optional)',
                        hintText:
                            'https://... or leave empty to upload via media manager',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description
                    TextField(
                      controller: desc,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Short Description & Key Highlights',
                        hintText:
                            'Key purity features, certifications, source farm...',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Publish Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(StoreLayout.radius),
                          ),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: storeGreen,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          isSubmitting
                              ? 'Publishing Listing...'
                              : 'Publish Product Listing',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final titleText = title.text.trim();
                                final priceVal =
                                    double.tryParse(price.text.trim());
                                if (titleText.length < 2 ||
                                    priceVal == null ||
                                    priceVal <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please enter a valid product title and price.'),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                try {
                                  final dio = ref.read(dioProvider);
                                  final chosenTaxonomyId =
                                      selectedSubcategoryId ??
                                          selectedCategoryId ??
                                          selectedDepartmentId;

                                  final payload = <String, dynamic>{
                                    'sku': sku.text.trim().isNotEmpty
                                        ? sku.text.trim()
                                        : 'SKU-${DateTime.now().millisecondsSinceEpoch}',
                                    'title': titleText,
                                    'brand': brand.text.trim().isNotEmpty
                                        ? brand.text.trim()
                                        : null,
                                    'pack_size': packSize.text.trim().isNotEmpty
                                        ? packSize.text.trim()
                                        : null,
                                    'description': desc.text.trim().isNotEmpty
                                        ? desc.text.trim()
                                        : null,
                                    'category': 'FEED_NUTRITION',
                                    'base_price': priceVal,
                                    'unit': unit.text.trim().isNotEmpty
                                        ? unit.text.trim()
                                        : 'unit',
                                    'initial_stock':
                                        int.tryParse(stock.text.trim()) ?? 0,
                                  };

                                  if (chosenTaxonomyId != null) {
                                    payload['category_id'] = chosenTaxonomyId;
                                  }
                                  final mrpVal =
                                      double.tryParse(mrp.text.trim());
                                  if (mrpVal != null && mrpVal > 0) {
                                    payload['compare_at_price'] = mrpVal;
                                  }
                                  final weightVal =
                                      int.tryParse(weight.text.trim());
                                  if (weightVal != null && weightVal > 0) {
                                    payload['weight_grams'] = weightVal;
                                  }

                                  final res = await dio.post(
                                    '/vendor/products',
                                    data: payload,
                                  );
                                  final createdData =
                                      res.data['data'] as Map<String, dynamic>?;
                                  final newProductId =
                                      createdData?['id']?.toString();

                                  if (newProductId != null &&
                                      image.text.trim().isNotEmpty) {
                                    await dio.post(
                                      '/vendor/products/$newProductId/media',
                                      data: {
                                        'url': image.text.trim(),
                                        'is_primary': true,
                                      },
                                    );
                                  }

                                  ref.invalidate(vendorProductsProvider);
                                  if (sheet.mounted) Navigator.pop(sheet);

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: storeGreen,
                                        content: Text(
                                          'Product "$titleText" published successfully!',
                                        ),
                                        action: newProductId != null
                                            ? SnackBarAction(
                                                label: 'Add Images',
                                                textColor: storeAmber,
                                                onPressed: () {
                                                  showDialog<void>(
                                                    context: context,
                                                    barrierDismissible: false,
                                                    builder: (_) =>
                                                        ProductMediaManager(
                                                      productId: newProductId,
                                                      title: titleText,
                                                    ),
                                                  );
                                                },
                                              )
                                            : null,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Failed to publish product: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    for (final c in [
      sku,
      title,
      brand,
      packSize,
      price,
      mrp,
      stock,
      unit,
      weight,
      image,
      desc
    ]) {
      c.dispose();
    }
  }
}
