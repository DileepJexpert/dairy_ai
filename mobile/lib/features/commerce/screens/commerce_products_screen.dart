import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/widgets/store_design.dart';

class CommerceProductsScreen extends ConsumerStatefulWidget {
  const CommerceProductsScreen({super.key});

  @override
  ConsumerState<CommerceProductsScreen> createState() => _CommerceProductsScreenState();
}

class _CommerceProductsScreenState extends ConsumerState<CommerceProductsScreen> {
  String _selectedDepartment = 'All';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // 0: Product Families & Pack Variants, 1: Flat SKU Inventory Table
  int _viewMode = 0;

  // Local stateful lists for admin catalog mutations
  late List<Product> _products;
  late List<ProductFamily> _families;

  @override
  void initState() {
    super.initState();
    _products = List<Product>.from(defaultMilterraProducts);
    _families = List<ProductFamily>.from(defaultMilterraProductFamilies);
  }

  // ---------------------------------------------------------------------------
  // Variant Mutations
  // ---------------------------------------------------------------------------

  void _toggleVariantStock(ProductFamily family, ProductVariant variant) {
    setState(() {
      final famIdx = _families.indexWhere((f) => f.id == family.id);
      if (famIdx != -1) {
        final currentFam = _families[famIdx];
        final updatedVariants = currentFam.variants.map((v) {
          if (v.id == variant.id) {
            final newInStock = !v.inStock;
            return ProductVariant(
              id: v.id,
              sku: v.sku,
              packSize: v.packSize,
              price: v.price,
              compareAtPrice: v.compareAtPrice,
              stockQuantity: newInStock ? (v.stockQuantity > 0 ? v.stockQuantity : 50) : 0,
              inStock: newInStock,
              weightGrams: v.weightGrams,
            );
          }
          return v;
        }).toList();

        _families[famIdx] = currentFam.copyWith(variants: updatedVariants);
      }

      // Also sync matching product in _products if present
      final prodIdx = _products.indexWhere((p) => p.id == variant.id);
      if (prodIdx != -1) {
        final cur = _products[prodIdx];
        _products[prodIdx] = cur.copyWith(
          inStock: !cur.inStock,
          availableQuantity: cur.inStock ? 0 : 50,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${variant.packSize} (${variant.sku}) stock toggled'),
        backgroundColor: storeGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editVariantPriceAndStock(ProductFamily family, ProductVariant variant) {
    final priceCtrl = TextEditingController(text: variant.price.toStringAsFixed(0));
    final compareCtrl = TextEditingController(text: variant.compareAtPrice?.toStringAsFixed(0) ?? '');
    final stockCtrl = TextEditingController(text: variant.stockQuantity.toString());

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Pack: ${variant.packSize} (${variant.sku})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Selling Price (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: compareCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'MRP / Compare-at Price (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
                hintText: 'Optional strikethrough price',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Available Stock Quantity',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeAmber, foregroundColor: storeGreen),
            onPressed: () {
              final newPrice = double.tryParse(priceCtrl.text.trim());
              final newCompare = double.tryParse(compareCtrl.text.trim());
              final newStock = int.tryParse(stockCtrl.text.trim()) ?? 0;

              if (newPrice != null && newPrice > 0) {
                setState(() {
                  final famIdx = _families.indexWhere((f) => f.id == family.id);
                  if (famIdx != -1) {
                    final currentFam = _families[famIdx];
                    final updatedVariants = currentFam.variants.map((v) {
                      if (v.id == variant.id) {
                        return ProductVariant(
                          id: v.id,
                          sku: v.sku,
                          packSize: v.packSize,
                          price: newPrice,
                          compareAtPrice: newCompare,
                          stockQuantity: newStock,
                          inStock: newStock > 0,
                          weightGrams: v.weightGrams,
                        );
                      }
                      return v;
                    }).toList();
                    _families[famIdx] = currentFam.copyWith(variants: updatedVariants);
                  }

                  final prodIdx = _products.indexWhere((p) => p.id == variant.id);
                  if (prodIdx != -1) {
                    _products[prodIdx] = _products[prodIdx].copyWith(
                      price: newPrice,
                      inStock: newStock > 0,
                      availableQuantity: newStock,
                    );
                  }
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated ${variant.packSize} to ${storeMoney(newPrice)}')),
                );
              }
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddVariantToFamilyDialog(ProductFamily family) {
    final packCtrl = TextEditingController();
    final skuCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final compareCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '50');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Variant to "${family.title}"'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: packCtrl,
                decoration: const InputDecoration(
                  labelText: 'Pack Size',
                  hintText: 'e.g. 250 ml, 2 L, 25 kg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skuCtrl,
                decoration: const InputDecoration(
                  labelText: 'SKU Code',
                  hintText: 'e.g. MIL-GHEE-250',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling Price (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: compareCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'MRP / Compare-At (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Initial Stock Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeAmber, foregroundColor: storeGreen),
            onPressed: () {
              final pack = packCtrl.text.trim();
              final sku = skuCtrl.text.trim().isNotEmpty
                  ? skuCtrl.text.trim()
                  : 'SKU-${DateTime.now().millisecondsSinceEpoch}';
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              final compare = double.tryParse(compareCtrl.text.trim());
              final stock = int.tryParse(stockCtrl.text.trim()) ?? 50;

              if (pack.isEmpty || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid pack size and price.')),
                );
                return;
              }

              final newVariant = ProductVariant(
                id: 'var-${DateTime.now().millisecondsSinceEpoch}',
                sku: sku,
                packSize: pack,
                price: price,
                compareAtPrice: compare,
                stockQuantity: stock,
                inStock: stock > 0,
              );

              setState(() {
                final famIdx = _families.indexWhere((f) => f.id == family.id);
                if (famIdx != -1) {
                  _families[famIdx] = _families[famIdx].copyWith(
                    variants: [..._families[famIdx].variants, newVariant],
                  );
                }

                // Also add to _products
                _products.insert(
                  0,
                  Product(
                    id: newVariant.id,
                    vendorId: 'vendor-milterra-direct',
                    title: '${family.title} ($pack)',
                    category: family.department.contains('Machinery')
                        ? ProductCategory.equipment
                        : ProductCategory.feedNutrition,
                    price: price,
                    unit: pack,
                    brand: family.brand,
                    packSize: pack,
                    description: family.description,
                    taxonomy: {
                      'department_name': family.department,
                      'category_name': family.taxonomyPath ?? family.department,
                    },
                    inStock: stock > 0,
                    availableQuantity: stock,
                    minOrderQuantity: 1,
                  ),
                );
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added $pack variant to "${family.title}"'),
                  backgroundColor: storeGreen,
                ),
              );
            },
            child: const Text('Add Variant', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Add Entire Product Family & Initial Variants
  // ---------------------------------------------------------------------------

  void _showAddProductFamilyDialog() {
    final titleCtrl = TextEditingController();
    final brandCtrl = TextEditingController(text: 'Milterra Pure');
    final descCtrl = TextEditingController();
    final purityCtrl = TextEditingController(text: 'Grade A+ (99.4% Purity Verified)');
    final fssaiCtrl = TextEditingController(text: '10019021004312');
    String department = 'Dairy Foods';
    bool isOrganic = true;

    // Temporary variants builder
    final variants = <Map<String, dynamic>>[
      {'pack': '500 ml', 'sku': 'MIL-NEW-500', 'price': '650', 'compare': '790', 'stock': '100'},
      {'pack': '1 L', 'sku': 'MIL-NEW-1000', 'price': '1250', 'compare': '1450', 'stock': '50'},
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add Product Family & Pack Variants',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: storeGreen),
                        ),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const Divider(height: 20),

                    // Department & Brand
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: department,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Dairy Foods', child: Text('🥛 Dairy Foods')),
                                  DropdownMenuItem(value: 'Animal Nutrition', child: Text('🌾 Animal Nutrition')),
                                  DropdownMenuItem(value: 'Farm Machinery', child: Text('⚙️ Farm Machinery')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => department = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Brand Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: brandCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Family Title
                    const Text('Product Family Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Milterra Cultured Sahiwal Bilona Ghee',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Heritage craft process, grass-fed origin, health benefits…',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Purity & FSSAI
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Purity / Quality Grade', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: purityCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('FSSAI License #', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: fssaiCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Organic Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: isOrganic,
                          activeColor: storeGreen,
                          onChanged: (val) => setModalState(() => isOrganic = val ?? true),
                        ),
                        const Text('Certified 100% Organic Farm Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pack Variants Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pack Variants (SKUs)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeGreen),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setModalState(() {
                              variants.add({
                                'pack': '5 L',
                                'sku': 'MIL-NEW-5000',
                                'price': '5900',
                                'compare': '6900',
                                'stock': '20',
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Pack Size', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Variant input rows
                    for (int i = 0; i < variants.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xfff8faf9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: storeBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: variants[i]['pack'],
                                decoration: const InputDecoration(labelText: 'Pack Size', isDense: true),
                                onChanged: (v) => variants[i]['pack'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: variants[i]['sku'],
                                decoration: const InputDecoration(labelText: 'SKU Code', isDense: true),
                                onChanged: (v) => variants[i]['sku'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: variants[i]['price'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Price (₹)', isDense: true),
                                onChanged: (v) => variants[i]['price'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: variants[i]['compare'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'MRP (₹)', isDense: true),
                                onChanged: (v) => variants[i]['compare'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: variants[i]['stock'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Stock', isDense: true),
                                onChanged: (v) => variants[i]['stock'] = v,
                              ),
                            ),
                            if (variants.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () {
                                  setModalState(() => variants.removeAt(i));
                                },
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeAmber,
                          foregroundColor: storeGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        ),
                        onPressed: () {
                          final title = titleCtrl.text.trim();
                          if (title.isEmpty || variants.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a product title and at least one variant.')),
                            );
                            return;
                          }

                          final familyId = 'fam-${DateTime.now().millisecondsSinceEpoch}';
                          final builtVariants = <ProductVariant>[];
                          final builtProducts = <Product>[];

                          for (final v in variants) {
                            final pack = v['pack']?.toString() ?? 'Pack';
                            final sku = v['sku']?.toString() ?? 'SKU-${DateTime.now().millisecondsSinceEpoch}';
                            final price = double.tryParse(v['price']?.toString() ?? '0') ?? 0.0;
                            final compare = double.tryParse(v['compare']?.toString() ?? '');
                            final stock = int.tryParse(v['stock']?.toString() ?? '50') ?? 50;

                            final varId = 'var-${sku.hashCode.abs()}';
                            final variantObj = ProductVariant(
                              id: varId,
                              sku: sku,
                              packSize: pack,
                              price: price,
                              compareAtPrice: compare,
                              stockQuantity: stock,
                              inStock: stock > 0,
                            );
                            builtVariants.add(variantObj);

                            builtProducts.add(
                              Product(
                                id: varId,
                                vendorId: 'vendor-milterra-direct',
                                title: '$title ($pack)',
                                category: department.contains('Machinery')
                                    ? ProductCategory.equipment
                                    : ProductCategory.feedNutrition,
                                price: price,
                                unit: pack,
                                brand: brandCtrl.text.trim(),
                                packSize: pack,
                                description: descCtrl.text.trim().isNotEmpty
                                    ? descCtrl.text.trim()
                                    : 'Certified Milterra Pure Dairy Product.',
                                taxonomy: {
                                  'department_name': department,
                                  'category_name': department,
                                },
                                inStock: stock > 0,
                                availableQuantity: stock,
                                minOrderQuantity: 1,
                              ),
                            );
                          }

                          final newFamily = ProductFamily(
                            id: familyId,
                            title: title,
                            brand: brandCtrl.text.trim(),
                            department: department,
                            taxonomyPath: '$department / ${title.split(' ').last}',
                            description: descCtrl.text.trim().isNotEmpty
                                ? descCtrl.text.trim()
                                : 'Authentic Milterra farm-fresh quality.',
                            variants: builtVariants,
                            isOrganic: isOrganic,
                            purityGrade: purityCtrl.text.trim(),
                            fssaiLicense: fssaiCtrl.text.trim(),
                          );

                          setState(() {
                            _families.insert(0, newFamily);
                            _products.insertAll(0, builtProducts);
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Created Product Family "$title" with ${builtVariants.length} variants!'),
                              backgroundColor: storeGreen,
                            ),
                          );
                        },
                        child: const Text('Save & Publish Product Family',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  // ---------------------------------------------------------------------------
  // Build Screen
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Filter families
    var filteredFamilies = _families;
    if (_selectedDepartment != 'All') {
      filteredFamilies = filteredFamilies.where((f) {
        if (_selectedDepartment == 'Dairy Foods') return f.department.contains('Dairy');
        if (_selectedDepartment == 'Cattle Feed') return f.department.contains('Nutrition') || f.department.contains('Feed');
        if (_selectedDepartment == 'Machinery') return f.department.contains('Machinery') || f.department.contains('Equipment');
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredFamilies = filteredFamilies.where((f) =>
          f.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          f.variants.any((v) => v.sku.toLowerCase().contains(_searchQuery.toLowerCase()))).toList();
    }

    // Filter flat products
    var filteredProducts = _products;
    if (_selectedDepartment == 'Dairy Foods') {
      filteredProducts = filteredProducts.where((p) {
        final dept = p.taxonomy?['department_name']?.toString() ?? '';
        return dept.contains('Dairy') || p.category == ProductCategory.feedNutrition && p.price < 1000;
      }).toList();
    } else if (_selectedDepartment == 'Cattle Feed') {
      filteredProducts = filteredProducts.where((p) {
        final dept = p.taxonomy?['department_name']?.toString() ?? '';
        return dept.contains('Cattle') || dept.contains('Feed') || p.title.contains('Feed') || p.title.contains('Mineral');
      }).toList();
    } else if (_selectedDepartment == 'Machinery') {
      filteredProducts = filteredProducts.where((p) => p.category == ProductCategory.equipment).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredProducts = filteredProducts.where((p) =>
          p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.id.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        title: const Text('Milterra · Commerce Admin'),
        backgroundColor: storeGreen,
        foregroundColor: storeWhite,
        leading: IconButton(
          tooltip: 'Back to shop',
          onPressed: () => context.go('/shop'),
          icon: const Icon(Icons.storefront_outlined),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/admin/commerce'),
            icon: const Icon(Icons.category_outlined, color: storeAmber, size: 18),
            label: const Text('Categories & Depts', style: TextStyle(color: storeWhite)),
          ),
          TextButton.icon(
            onPressed: () => context.go('/admin/commerce/orders'),
            icon: const Icon(Icons.local_shipping_outlined, color: storeAmber, size: 18),
            label: const Text('Orders & Shipments', style: TextStyle(color: storeWhite)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: storeAmber, foregroundColor: storeGreen),
            onPressed: _showAddProductFamilyDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Product Family', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < StoreLayout.tablet;

          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Row(
                        children: [
                          InkWell(
                            onTap: () => context.go('/shop'),
                            child: const Text('Milterra Storefront', style: TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                          const Text('Commerce Admin › Product & SKU Manager',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Header & Action Bar
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Product Families & SKU Management',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: storeGreen),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_families.length} product families · ${_products.length} sellable SKUs · Authoritative catalog contracts',
                                  style: const TextStyle(fontSize: 13, color: storeMuted),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: storeAmber, foregroundColor: storeGreen),
                            onPressed: _showAddProductFamilyDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product Family', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // View Mode Segmented Control
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: storeWhite,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: storeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildViewSegmentButton(
                              index: 0,
                              icon: Icons.layers_outlined,
                              label: 'Product Families & Variants (${_families.length})',
                            ),
                            _buildViewSegmentButton(
                              index: 1,
                              icon: Icons.table_chart_outlined,
                              label: 'All SKU Inventory Table (${_products.length})',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filter Chips & Search
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final d in ['All', 'Dairy Foods', 'Cattle Feed', 'Machinery'])
                            ChoiceChip(
                              label: Text(d),
                              selected: _selectedDepartment == d,
                              selectedColor: storeGreen,
                              labelStyle: TextStyle(
                                color: _selectedDepartment == d ? storeWhite : storeGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _selectedDepartment = d),
                            ),
                          Container(
                            width: 250,
                            height: 38,
                            decoration: BoxDecoration(
                              color: storeWhite,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: storeBorder),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: const InputDecoration(
                                hintText: 'Search SKU, pack, or title…',
                                hintStyle: TextStyle(fontSize: 12, color: storeMuted),
                                border: InputBorder.none,
                                icon: Icon(Icons.search, size: 18, color: storeMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Active View Mode Rendering
                      if (_viewMode == 0)
                        _buildProductFamiliesList(filteredFamilies)
                      else
                        _buildProductsFlatTable(filteredProducts),
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

  Widget _buildViewSegmentButton({required int index, required IconData icon, required String label}) {
    final isSelected = _viewMode == index;
    return InkWell(
      onTap: () => setState(() => _viewMode = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? storeGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? storeWhite : storeGreen),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? storeWhite : storeGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View 1: Product Families & Pack Variants List
  // ---------------------------------------------------------------------------

  Widget _buildProductFamiliesList(List<ProductFamily> families) {
    if (families.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: storeWhite,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          border: Border.all(color: storeBorder),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: storeMuted),
              SizedBox(height: 12),
              Text('No product families match your filter.', style: TextStyle(color: storeMuted, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: families.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final family = families[index];
        return _buildFamilyCard(family);
      },
    );
  }

  Widget _buildFamilyCard(ProductFamily family) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xfffafaf8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(StoreLayout.radius)),
              border: Border(bottom: BorderSide(color: storeBorder)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Family Icon / Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xfff5f0e6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xffe5d9c5)),
                  ),
                  child: family.primaryImage != null
                      ? Image.asset(
                          family.primaryImage!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.egg_outlined, color: storeGreen, size: 24),
                        )
                      : const Icon(Icons.auto_awesome, color: storeOrange, size: 24),
                ),
                const SizedBox(width: 14),

                // Family Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              family.title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: storeGreen),
                            ),
                          ),
                          if (family.isOrganic) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xffe6f4ea),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.eco, size: 12, color: Color(0xff1e8e3e)),
                                  SizedBox(width: 4),
                                  Text('100% Organic', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xff1e8e3e))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            '${family.variants.length} Pack Sizes',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          Text('Brand: ${family.brand}', style: const TextStyle(fontSize: 11.5, color: storeMuted)),
                          const Text('•', style: TextStyle(fontSize: 11.5, color: storeMuted)),
                          Text('Dept: ${family.department}', style: const TextStyle(fontSize: 11.5, color: storeMuted)),
                          if (family.taxonomyPath != null) ...[
                            const Text('•', style: TextStyle(fontSize: 11.5, color: storeMuted)),
                            Text('Taxonomy: ${family.taxonomyPath}', style: const TextStyle(fontSize: 11.5, color: Color(0xff1a73e8), fontWeight: FontWeight.w600)),
                          ],
                          if (family.purityGrade != null) ...[
                            const Text('•', style: TextStyle(fontSize: 11.5, color: storeMuted)),
                            Text(family.purityGrade!, style: const TextStyle(fontSize: 11.5, color: Color(0xffb7791f), fontWeight: FontWeight.bold)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Variants Table Header & Rows
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PACK VARIANTS · STARTING FROM ${storeMoney(family.startingPrice)} (TOTAL INVENTORY: ${family.totalStock} UNITS)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: storeMuted, letterSpacing: 0.5),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: () => _showAddVariantToFamilyDialog(family),
                      icon: const Icon(Icons.add, size: 14, color: storeGreen),
                      label: const Text('Add Variant Pack', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Variants list
                for (final variant in family.variants)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xfffbfaf7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: storeBorder),
                    ),
                    child: Row(
                      children: [
                        // Pack size badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: storeWhite,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: storeBorder),
                          ),
                          child: Text(
                            variant.packSize,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: storeGreen),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // SKU code
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                variant.sku,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff0f1111)),
                              ),
                              if (variant.weightGrams != null)
                                Text(
                                  'Weight: ${variant.weightGrams}g',
                                  style: const TextStyle(fontSize: 10.5, color: storeMuted),
                                ),
                            ],
                          ),
                        ),

                        // Price & Compare Price
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              storeMoney(variant.price),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeOrange),
                            ),
                            if (variant.compareAtPrice != null && variant.compareAtPrice! > variant.price)
                              Text(
                                storeMoney(variant.compareAtPrice!),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: storeMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // In Stock Toggle
                        Column(
                          children: [
                            Switch(
                              value: variant.inStock,
                              activeThumbColor: storeGreen,
                              onChanged: (_) => _toggleVariantStock(family, variant),
                            ),
                            Text(
                              variant.inStock ? 'Stock: ${variant.stockQuantity}' : 'Out of Stock',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: variant.inStock ? const Color(0xff067d62) : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),

                        // Edit Variant
                        IconButton(
                          tooltip: 'Edit Price & Stock',
                          icon: const Icon(Icons.edit_outlined, size: 18, color: storeMuted),
                          onPressed: () => _editVariantPriceAndStock(family, variant),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // View 2: Flat Products / SKU Table
  // ---------------------------------------------------------------------------

  Widget _buildProductsFlatTable(List<Product> filtered) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: storeBorder),
        itemBuilder: (context, index) {
          final p = filtered[index];
          final dept = p.taxonomy?['department_name']?.toString() ??
              (p.category == ProductCategory.equipment ? 'Machinery' : 'Dairy / Feed');

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: storeCream,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: storeBorder),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: storeGreen, size: 24),
                ),
                const SizedBox(width: 14),

                // Title & Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff0f1111),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SKU: ${p.id} · $dept · Pack: ${p.packSize ?? p.unit}',
                        style: const TextStyle(fontSize: 11, color: storeMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Price with quick edit
                InkWell(
                  onTap: () => _editFlatProductPrice(p),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xfff8faf9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: storeBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          storeMoney(p.price),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: storeOrange,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 14, color: storeMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Stock Toggle
                Column(
                  children: [
                    Switch(
                      value: p.inStock,
                      activeThumbColor: storeGreen,
                      onChanged: (_) {
                        setState(() {
                          final idx = _products.indexWhere((x) => x.id == p.id);
                          if (idx != -1) {
                            _products[idx] = _products[idx].copyWith(
                              inStock: !_products[idx].inStock,
                              availableQuantity: _products[idx].inStock ? 0 : 50,
                            );
                          }
                        });
                      },
                    ),
                    Text(
                      p.inStock ? 'In Stock (${p.availableQuantity})' : 'Out of Stock',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: p.inStock ? const Color(0xff067d62) : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // View on Storefront button
                IconButton(
                  tooltip: 'View on storefront',
                  icon: const Icon(Icons.open_in_new, size: 18, color: Color(0xff007185)),
                  onPressed: () => context.go('/shop/product/${p.id}'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _editFlatProductPrice(Product p) {
    final priceCtrl = TextEditingController(text: p.price.toStringAsFixed(0));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Price · ${p.title}'),
        content: TextField(
          controller: priceCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Base Price (₹)',
            border: OutlineInputBorder(),
            prefixText: '₹ ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeAmber, foregroundColor: storeGreen),
            onPressed: () {
              final newPrice = double.tryParse(priceCtrl.text.trim());
              if (newPrice != null && newPrice > 0) {
                setState(() {
                  final index = _products.indexWhere((x) => x.id == p.id);
                  if (index != -1) {
                    _products[index] = _products[index].copyWith(price: newPrice);
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated price to ${storeMoney(newPrice)}')),
                );
              }
            },
            child: const Text('Save Price', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
