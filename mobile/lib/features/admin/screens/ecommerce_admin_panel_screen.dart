import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../cart/providers/order_repository.dart';
import '../providers/admin_marketplace_provider.dart';
import '../models/analytics_models.dart';
import '../providers/admin_analytics_provider.dart';

class EcommerceAdminPanelScreen extends ConsumerStatefulWidget {
  const EcommerceAdminPanelScreen({super.key});

  @override
  ConsumerState<EcommerceAdminPanelScreen> createState() => _EcommerceAdminPanelScreenState();
}

class _EcommerceAdminPanelScreenState extends ConsumerState<EcommerceAdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 13, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminMarketplaceProvider);

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f8),
      appBar: AppBar(
        backgroundColor: const Color(0xff0d1b15),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: storeGreen,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('ADMIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            const Text('Milterra Enterprise Ecommerce Control Panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Customer Storefront',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/shop'),
          ),
          IconButton(
            tooltip: 'Seller Portal',
            icon: const Icon(Icons.business_outlined),
            onPressed: () => context.push('/seller/dashboard'),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/admin/login'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xffff9900),
          unselectedLabelColor: const Color(0xff94a3b8),
          indicatorColor: const Color(0xffff9900),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Products'),
            Tab(icon: Icon(Icons.science_outlined, size: 18), text: 'Animal Nutrition'),
            Tab(icon: Icon(Icons.shopping_cart_checkout_outlined, size: 18), text: 'Live Carts'),
            Tab(icon: Icon(Icons.public_outlined, size: 18), text: 'Traffic & Geo'),
            Tab(icon: Icon(Icons.ads_click_outlined, size: 18), text: 'User Clickstream'),
            Tab(icon: Icon(Icons.local_shipping_outlined, size: 18), text: 'Shipments & Logistics'),
            Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Batch Certificates'),
            Tab(icon: Icon(Icons.verified_user_outlined, size: 18), text: 'Sellers & KYC'),
            Tab(icon: Icon(Icons.local_offer_outlined, size: 18), text: 'Seller Offers'),
            Tab(icon: Icon(Icons.bolt_outlined, size: 18), text: 'Deals Engine'),
            Tab(icon: Icon(Icons.confirmation_number_outlined, size: 18), text: 'Coupons'),
            Tab(icon: Icon(Icons.warehouse_outlined, size: 18), text: 'Inventory'),
            Tab(icon: Icon(Icons.history_edu_outlined, size: 18), text: 'Audit Trail'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductsTab(),
          _buildAnimalNutritionTab(),
          _buildLiveCartsTab(),
          _buildTrafficGeoTab(),
          _buildClickstreamTab(),
          _buildShipmentsTab(),
          _buildCertificatesTab(adminState),
          _buildSellersTab(adminState),
          _buildSellerOffersTab(adminState),
          _buildDealsTab(adminState),
          _buildCouponsTab(adminState),
          _buildInventoryTab(adminState),
          _buildAuditLogsTab(adminState),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Products & Catalog
  // ---------------------------------------------------------------------------
  Widget _buildProductsTab() {
    final catalog = ref.watch(productsProvider(null)).valueOrNull ?? defaultMilterraProducts;
    final customProducts = ref.watch(adminMarketplaceProvider).customProducts;
    final allProducts = [...customProducts, ...catalog];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Canonical Product Catalog (${allProducts.length} Items)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create New Product'),
                onPressed: () => _showCreateProductDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = allProducts[i];
                final isConcept = p.taxonomy?['concept'] == true;
                final status = p.taxonomy?['status']?.toString() ?? (isConcept ? 'Concept Preview' : 'Active Commercial');

                return ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: ProductArtwork(product: p),
                  ),
                  title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    'Category: ${storeCategory(p)} · ${p.packSize ?? p.unit} · Base MRP: ${storeMoney(p.price)}',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConcept ? const Color(0xffe8f5e9) : const Color(0xffe3f2fd),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isConcept ? storeGreen : const Color(0xff90caf9)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isConcept ? storeGreen : const Color(0xff1565c0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: storeGreen),
                        tooltip: 'Edit Catalog Metadata',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Editing metadata for ${p.title}')),
                          );
                        },
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

  void _showCreateProductDialog() {
    final titleCtrl = TextEditingController(text: 'Milterra Single-Farm Cultured Cow Ghee');
    final brandCtrl = TextEditingController(text: 'MILTERRA Pure');
    final priceCtrl = TextEditingController(text: '899');
    final stockCtrl = TextEditingController(text: '40');
    final descCtrl = TextEditingController(
      text: 'Artisanal Vedic Bilona cultured cow ghee from our own Lucknow heritage pasture farm. Lab-certified 100% pure.',
    );
    String selectedSource = 'Single-Farm Lucknow Heritage';
    String selectedPackSize = '500 ml';
    String selectedCategory = 'Dairy Foods';
    bool isActiveCommercial = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xffdcfce7), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_business_outlined, color: storeGreen, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('Add New Product to Storefront', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Product Title',
                      hintText: 'e.g. Milterra Single-Farm Cultured Cow Ghee',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'Dairy Foods', child: Text('Dairy Foods')),
                            DropdownMenuItem(value: 'Animal Nutrition', child: Text('Animal Nutrition')),
                            DropdownMenuItem(value: 'Farm Machinery', child: Text('Farm Machinery')),
                            DropdownMenuItem(value: 'MILTERRA Earth', child: Text('MILTERRA Earth')),
                          ],
                          onChanged: (v) => setDialogState(() => selectedCategory = v ?? 'Dairy Foods'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedSource,
                          decoration: const InputDecoration(labelText: 'Milk / Batch Type', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'A2 Gir Cow Milk', child: Text('A2 Gir Cow (Cultured Ghee)')),
                            DropdownMenuItem(value: 'Murrah Buffalo Milk', child: Text('Murrah Buffalo Ghee')),
                            DropdownMenuItem(value: 'Single-Farm Lucknow Heritage', child: Text('Single-Farm Lucknow')),
                            DropdownMenuItem(value: 'Full Moon Purnima Batch', child: Text('Full Moon Batch')),
                            DropdownMenuItem(value: 'Herbal Infusion', child: Text('Herbal Infused Ghee')),
                          ],
                          onChanged: (v) => setDialogState(() => selectedSource = v ?? 'A2 Gir Cow Milk'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedPackSize,
                          decoration: const InputDecoration(labelText: 'Pack Size / Volume', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: '250 ml', child: Text('250 ml (Trial Glass Jar)')),
                            DropdownMenuItem(value: '500 ml', child: Text('500 ml (Family Glass Jar)')),
                            DropdownMenuItem(value: '1 litre', child: Text('1 Litre (Kitchen Jar)')),
                            DropdownMenuItem(value: '5 litre', child: Text('5 Litres (Heritage Tin)')),
                            DropdownMenuItem(value: '200 g', child: Text('200 g Block')),
                            DropdownMenuItem(value: '500 g', child: Text('500 g Block')),
                            DropdownMenuItem(value: '1 kg', child: Text('1 kg Pack')),
                          ],
                          onChanged: (v) => setDialogState(() => selectedPackSize = v ?? '500 ml'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Selling Price (₹)',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: stockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Warehouse Stock',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Product Story & Description',
                      hintText: 'Describe origin, bilona churn method, farm traceability...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isActiveCommercial,
                        activeColor: storeGreen,
                        onChanged: (v) => setDialogState(() => isActiveCommercial = v ?? true),
                      ),
                      const Expanded(
                        child: Text(
                          'Publish as Active Commercial Product (Immediately available for purchase)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff334155)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: storeGreen),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Publish Product to Website'),
              onPressed: () {
                final price = double.tryParse(priceCtrl.text.trim()) ?? 499.0;
                final stock = int.tryParse(stockCtrl.text.trim()) ?? 25;
                final newProd = Product(
                  id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
                  vendorId: 'vendor-milterra-direct',
                  title: titleCtrl.text.trim(),
                  category: ProductCategory.feedNutrition,
                  price: price,
                  unit: selectedPackSize.contains('g') ? 'pack' : 'jar',
                  brand: brandCtrl.text.trim(),
                  packSize: selectedPackSize,
                  description: descCtrl.text.trim(),
                  taxonomy: {
                    'department_name': selectedCategory,
                    'category_name': selectedSource,
                    'status': isActiveCommercial ? 'Active Commercial' : 'Concept Preview',
                    'concept': !isActiveCommercial,
                  },
                  inStock: stock > 0,
                  availableQuantity: stock,
                  minOrderQuantity: 1,
                  specifications: {
                    'Milk Source': selectedSource,
                    'Process': 'Vedic Bilona Churned',
                    'Pack Size': selectedPackSize,
                    'Purity Tested': '99.4% Verified',
                    'Diet Type': 'Vegetarian',
                  },
                );

                ref.read(adminMarketplaceProvider.notifier).addCustomProduct(newProd);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: storeGreen,
                    content: Text('Product "${newProd.title}" successfully added to website catalog!'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNutritionConceptDialog() {
    final titleCtrl = TextEditingController(text: 'MILTERRA RUMI-PRO High-Energy Rumen Bypass Fat');
    final subcatCtrl = TextEditingController(text: 'Bypass Nutrients');
    final taglineCtrl = TextEditingController(text: 'Increases Peak Lactation Yield by 1.8 Litres/Day');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Nutrition Concept Formulation'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Formulation Title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: subcatCtrl, decoration: const InputDecoration(labelText: 'Nutritional Subcategory', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Formulation Tagline & Bio-availability', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: storeGreen,
                  content: Text('Nutrition concept "${titleCtrl.text}" staged for farmer survey!'),
                ),
              );
            },
            child: const Text('Stage Concept'),
          ),
        ],
      ),
    );
  }
  // TAB 2: Animal Nutrition Hub
  // ---------------------------------------------------------------------------
  Widget _buildAnimalNutritionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MILTERRA CATTLE NUTRITION SOLUTIONS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: storeGreen),
                  ),
                  Text(
                    'Virtual catalogue, formulation lifecycle staging, farmer trial cohort validation.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.biotech_outlined, size: 18),
                label: const Text('Add Nutrition Concept SKU'),
                onPressed: () => _showAddNutritionConceptDialog(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Lifecycle Staging Guide
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: storeWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: storeBorder),
            ),
            child: Row(
              children: [
                _stagePill('1. Concept Preview', 'Virtual formulation showcase', const Color(0xffe8f5e9), storeGreen),
                const Icon(Icons.arrow_forward, size: 16, color: storeMuted),
                _stagePill('2. Farmer Feedback Open', 'Field survey collection', const Color(0xfffff8e1), storeAmberDark),
                const Icon(Icons.arrow_forward, size: 16, color: storeMuted),
                _stagePill('3. In Development', 'Pilot batch farmer trials', const Color(0xffe0f2f1), const Color(0xff00695c)),
                const Icon(Icons.arrow_forward, size: 16, color: storeMuted),
                _stagePill('4. Commercial Launch', 'Full cart & checkout unlock', const Color(0xffe3f2fd), const Color(0xff1565c0)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Nutrition Concepts Table
          const Text('Active Nutrition Formulations & Stages', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _nutritionConceptRow(
                  title: 'MILTERRA Mineral Supplement (Minera-360 Concentrate)',
                  subcategory: 'Supplements',
                  stage: 'Concept Preview',
                  tagline: 'Natural Nutrition for Healthy Livestock',
                  feedbackCount: 38,
                  trialSignups: 92,
                ),
                const Divider(height: 1),
                _nutritionConceptRow(
                  title: 'JANAM·42 Calving & Transition Course',
                  subcategory: 'Stage-Based Nutrition Courses',
                  stage: 'Farmer Feedback Open',
                  tagline: '42-Day Scientific Transition Nutrition Kit',
                  feedbackCount: 54,
                  trialSignups: 140,
                ),
                const Divider(height: 1),
                _nutritionConceptRow(
                  title: 'Bovine Gold Balanced Cattle Feed (50kg Pellets)',
                  subcategory: 'Pashu Aahar / Cattle Feed',
                  stage: 'In Development',
                  tagline: 'High Protein & Energy Balanced Ration',
                  feedbackCount: 88,
                  trialSignups: 210,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stagePill(String title, String desc, Color bg, Color text) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: text)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 10, color: storeMuted)),
            ],
          ),
        ),
      );

  Widget _nutritionConceptRow({
    required String title,
    required String subcategory,
    required String stage,
    required String tagline,
    required int feedbackCount,
    required int trialSignups,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: storeSage.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.science_outlined, color: storeGreen),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text('Subcategory: $subcategory · "$tagline"', style: const TextStyle(fontSize: 11, color: storeMuted)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xffe8f5e9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: storeGreen),
            ),
            child: Text(stage, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen)),
          ),
          const SizedBox(width: 12),
          Text('$feedbackCount Feedback\n$trialSignups Trials', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: storeDarkGreenNav)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Sellers & KYC Approvals
  // ---------------------------------------------------------------------------
  Widget _buildSellersTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seller Accounts & KYC Moderation (${state.sellers.length} Registered)',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.sellers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = state.sellers[i];
                final isPending = s.status == SellerStatus.pendingApproval;
                final isApproved = s.status == SellerStatus.approved;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: isApproved ? storeGreen : storeAmber,
                    child: Text(s.businessName.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    children: [
                      Text(s.businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isApproved ? const Color(0xffe8f5e9) : const Color(0xfffff8e1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(s.status.name.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isApproved ? storeGreen : storeAmberDark)),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'GSTIN: ${s.gstin ?? "N/A"} · FSSAI: ${s.fssaiLicense ?? "N/A"} · Warehouse: ${s.warehouseCity ?? "N/A"} · Comm: ${s.commissionRatePercent}%',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPending) ...[
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: storeGreen, minimumSize: const Size(80, 32)),
                          onPressed: () => ref.read(adminMarketplaceProvider.notifier).approveSeller(s.id),
                          child: const Text('Approve KYC', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (isApproved) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(80, 32), side: const BorderSide(color: storeError)),
                          onPressed: () => ref.read(adminMarketplaceProvider.notifier).suspendSeller(s.id, 'Quality standard violation'),
                          child: const Text('Suspend', style: TextStyle(fontSize: 11, color: storeError)),
                        ),
                      ],
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

  // ---------------------------------------------------------------------------
  // TAB 4: Seller Offers
  // ---------------------------------------------------------------------------
  Widget _buildSellerOffersTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Marketplace Seller SKU Offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen)),
          const SizedBox(height: 6),
          const Text('Compare prices and inventory across sellers for the same canonical catalog SKU.', style: TextStyle(fontSize: 12, color: storeMuted)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.offers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final o = state.offers[i];
                return ListTile(
                  leading: Icon(
                    o.isBuyBoxWinner ? Icons.star : Icons.store_outlined,
                    color: o.isBuyBoxWinner ? storeGold : storeGreen,
                  ),
                  title: Row(
                    children: [
                      Text('${o.sellerName} · SKU: ${o.sellerSku}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (o.isBuyBoxWinner) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xff232f3e), borderRadius: BorderRadius.circular(4)),
                          child: const Text('BUY BOX WINNER', style: TextStyle(fontSize: 9, color: Color(0xffff9900), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Price: ${storeMoney(o.sellingPrice)} (MRP ${storeMoney(o.mrp)}) · Available Stock: ${o.availableStock} units · ${o.deliveryPromise}',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.price_change_outlined, size: 18, color: storeGreen),
                        tooltip: 'Adjust Offer Price',
                        onPressed: () => _showEditOfferPriceDialog(o),
                      ),
                      IconButton(
                        icon: const Icon(Icons.inventory_outlined, size: 18, color: storeAmberDark),
                        tooltip: 'Adjust Stock Level',
                        onPressed: () => _showEditOfferStockDialog(o),
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

  // ---------------------------------------------------------------------------
  // TAB 5: Deals Engine
  // ---------------------------------------------------------------------------
  Widget _buildDealsTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Promotions & Lightning Deals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen)),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule New Deal'),
                onPressed: () => _showCreateDealDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final d in state.deals) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff3e0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt, color: storeOrange, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            'Deal Price: ${storeMoney(d.dealPrice)} (MRP ${storeMoney(d.mrp)} · -${d.discountPercent.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 12, color: storeMuted),
                          ),
                          Text('Runs until: ${d.endTime.toLocal()}', style: const TextStyle(fontSize: 11, color: storeGreen)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xffe8f5e9), borderRadius: BorderRadius.circular(12)),
                      child: const Text('ACTIVE LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 6: Coupons
  // ---------------------------------------------------------------------------
  Widget _buildCouponsTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Platform Coupons & Discount Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen)),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create Coupon'),
                onPressed: () => _showCreateCouponDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final c in state.coupons) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: storeSage, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.confirmation_number_outlined, color: storeGreen),
                ),
                title: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.0, color: storeGreen)),
                subtitle: Text('${c.description} · Min Order: ${storeMoney(c.minOrderValue)} · Redemptions: ${c.usageCount}', style: const TextStyle(fontSize: 12, color: storeMuted)),
                trailing: const Text('ACTIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 7: Inventory
  // ---------------------------------------------------------------------------
  Widget _buildInventoryTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Warehouse Stock & Reorder Levels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.offers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final o = state.offers[i];
                final isLow = o.availableStock <= o.lowStockThreshold;

                return ListTile(
                  leading: Icon(Icons.inventory, color: isLow ? storeError : storeGreen),
                  title: Text('${o.sellerSku} (${o.sellerName})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('Available: ${o.availableStock} units · Threshold: ${o.lowStockThreshold} units', style: const TextStyle(fontSize: 12, color: storeMuted)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLow ? const Color(0xffffebee) : const Color(0xffe8f5e9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isLow ? 'LOW STOCK ALERT' : 'HEALTHY STOCK',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isLow ? storeError : storeGreen),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 8: Audit Trail
  // ---------------------------------------------------------------------------
  Widget _buildAuditLogsTab(AdminMarketplaceState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Immutable Marketplace Audit Trail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen)),
          const SizedBox(height: 6),
          const Text('Tracks who modified prices, inventory, seller approvals, or promotions.', style: TextStyle(fontSize: 12, color: storeMuted)),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.auditLogs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final log = state.auditLogs[i];
                return ListTile(
                  leading: const Icon(Icons.shield_outlined, color: storeGreen),
                  title: Text('${log.action.name.toUpperCase()} on ${log.entityType}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${log.details}\nBy ${log.userIdentifier} (${log.userRole}) · ${log.timestamp}', style: const TextStyle(fontSize: 11, color: storeMuted, height: 1.3)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog Helpers
  // ---------------------------------------------------------------------------


  void _showEditOfferPriceDialog(SellerOffer o) {
    final priceCtrl = TextEditingController(text: o.sellingPrice.toStringAsFixed(0));
    final mrpCtrl = TextEditingController(text: o.mrp.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Price for ${o.sellerSku}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: mrpCtrl, decoration: const InputDecoration(labelText: 'MRP (₹)', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              final np = double.tryParse(priceCtrl.text) ?? o.sellingPrice;
              final nm = double.tryParse(mrpCtrl.text) ?? o.mrp;
              ref.read(adminMarketplaceProvider.notifier).updateOfferPrice(o.id, np, nm);
              Navigator.pop(ctx);
            },
            child: const Text('Update Price'),
          ),
        ],
      ),
    );
  }

  void _showEditOfferStockDialog(SellerOffer o) {
    final stockCtrl = TextEditingController(text: o.availableStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock for ${o.sellerSku}'),
        content: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Available Units', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              final ns = int.tryParse(stockCtrl.text) ?? o.availableStock;
              ref.read(adminMarketplaceProvider.notifier).updateOfferStock(o.id, ns);
              Navigator.pop(ctx);
            },
            child: const Text('Save Stock'),
          ),
        ],
      ),
    );
  }

  void _showCreateDealDialog() {
    final titleCtrl = TextEditingController(text: 'Flash Deal · Fresh Makhan');
    final dealPriceCtrl = TextEditingController(text: '199');
    final mrpCtrl = TextEditingController(text: '240');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Promotional Deal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Deal Title', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: dealPriceCtrl, decoration: const InputDecoration(labelText: 'Deal Price (₹)', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: mrpCtrl, decoration: const InputDecoration(labelText: 'MRP (₹)', border: OutlineInputBorder()))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              final dp = double.tryParse(dealPriceCtrl.text) ?? 199.0;
              final mrp = double.tryParse(mrpCtrl.text) ?? 240.0;
              final discount = mrp > dp ? ((mrp - dp) / mrp) * 100 : 15.0;
              final deal = DealPromotion(
                id: 'deal-${DateTime.now().millisecondsSinceEpoch}',
                title: titleCtrl.text.trim(),
                dealType: DealType.lightningDeal,
                productId: 'mil-buff-500',
                productTitle: 'Cultured Desi White Butter Makhan',
                productImage: 'assets/store/minera-360-jar.jpg',
                mrp: mrp,
                dealPrice: dp,
                discountPercent: discount,
                startTime: DateTime.now(),
                endTime: DateTime.now().add(const Duration(hours: 12)),
              );
              ref.read(adminMarketplaceProvider.notifier).addDeal(deal);
              Navigator.pop(ctx);
            },
            child: const Text('Launch Deal'),
          ),
        ],
      ),
    );
  }

  void _showCreateCouponDialog() {
    final codeCtrl = TextEditingController(text: 'SUMMER20');
    final discCtrl = TextEditingController(text: '20');
    final minCtrl = TextEditingController(text: '599');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Platform Coupon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Coupon Code (UPPERCASE)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: discCtrl, decoration: const InputDecoration(labelText: 'Discount %', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min Order (₹)', border: OutlineInputBorder()))),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              final coupon = PlatformCoupon(
                id: 'cpn-${DateTime.now().millisecondsSinceEpoch}',
                code: codeCtrl.text.trim().toUpperCase(),
                description: '${discCtrl.text}% instant savings on orders above ₹${minCtrl.text}',
                discountValue: double.tryParse(discCtrl.text) ?? 10.0,
                minOrderValue: double.tryParse(minCtrl.text) ?? 500.0,
                validUntil: DateTime.now().add(const Duration(days: 30)),
              );
              ref.read(adminMarketplaceProvider.notifier).addCoupon(coupon);
              Navigator.pop(ctx);
            },
            child: const Text('Save Coupon'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Shipments & Logistics
  // ---------------------------------------------------------------------------
  Widget _buildShipmentsTab() {
    final allOrders = ref.watch(ordersNotifierProvider);
    final pendingCount = allOrders.where((o) => !o.status.toUpperCase().contains('DELIVERED') && !o.status.toUpperCase().contains('CANCEL')).length;
    final deliveredCount = allOrders.where((o) => o.status.toUpperCase().contains('DELIVERED')).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Global Shipments & Logistics Fulfillment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen),
                  ),
                  Text(
                    'Total Orders: ${allOrders.length} | Active Shipments: $pendingCount | Completed: $deliveredCount',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh Tracking Hub'),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allOrders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final order = allOrders[i];
                final isDelivered = order.status.toUpperCase().contains('DELIVERED');

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDelivered ? const Color(0xffe8f5e9) : const Color(0xffe0f2fe),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDelivered ? Icons.check_circle : Icons.local_shipping,
                      color: isDelivered ? storeGreen : const Color(0xff0369a1),
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        '# ${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDelivered ? const Color(0xffdcfce7) : const Color(0xfffef3c7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          order.status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDelivered ? const Color(0xff15803d) : const Color(0xffb45309),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${order.carrier}',
                        style: const TextStyle(fontSize: 11, color: storeMuted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Buyer: ${order.address['recipient_name']} (${order.address['city']}) • Items: ${order.items.length} • Total: ${storeMoney(order.total)} • AWB: ${order.trackingNumber}',
                      style: const TextStyle(fontSize: 12, color: Color(0xff475569)),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          side: const BorderSide(color: storeBorder),
                        ),
                        onPressed: () {
                          ref.read(ordersNotifierProvider.notifier).simulateCourierStep(order.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: storeGreen,
                              content: Text('Simulated next fulfillment checkpoint for #${order.id}!'),
                            ),
                          );
                        },
                        child: const Text('Advance Milestone', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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

  // ---------------------------------------------------------------------------
  // TAB 4: Batch Certificates & Quality Assurance
  // ---------------------------------------------------------------------------
  Widget _buildCertificatesTab(AdminMarketplaceState adminState) {
    final certificates = adminState.batchCertificates;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Batch Quality & Lab Test Certificates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen),
                  ),
                  Text(
                    'FSSAI, Agmark & Soil Analysis verified batches (${certificates.length} Total)',
                    style: const TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Issue New Batch Certificate'),
                onPressed: () => _showCreateCertificateDialog(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: 260,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: certificates.length,
            itemBuilder: (context, i) {
              final cert = certificates[i];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x04000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, size: 13, color: Color(0xff166534)),
                              const SizedBox(width: 4),
                              Text(
                                cert.status,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xff166534)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Purity: ${cert.purityPercent}%',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: storeGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'BATCH #${cert.batchNumber}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: storeGreen),
                    ),
                    Text(
                      cert.productTitle,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xff1e293b)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Testing Lab: ${cert.laboratory}',
                      style: const TextStyle(fontSize: 11, color: storeMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'FSSAI / Standard: ${cert.fssaiLicense}',
                      style: const TextStyle(fontSize: 11, color: storeMuted),
                    ),
                    const Spacer(),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Signatory: ${cert.certifiedBy.split('(').first.trim()}',
                          style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xff64748b)),
                        ),
                        FilledButton.tonal(
                          onPressed: () => _showCertificateDetailsDialog(cert),
                          child: const Text('View Report', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreateCertificateDialog() {
    final batchCtrl = TextEditingController(text: 'MIL-GH-2026-10A');
    final productCtrl = TextEditingController(text: 'Milterra Pure A2 Gir Cow Bilona Ghee (1L)');
    final purityCtrl = TextEditingController(text: '99.6');
    final labCtrl = TextEditingController(text: 'National Dairy Research & Quality Laboratory, Karnal');
    final fssaiCtrl = TextEditingController(text: '10722001000456');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue New Batch Quality Certificate'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: batchCtrl, decoration: const InputDecoration(labelText: 'Batch Number', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: productCtrl, decoration: const InputDecoration(labelText: 'Product Title', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: purityCtrl, decoration: const InputDecoration(labelText: 'Purity %', border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: fssaiCtrl, decoration: const InputDecoration(labelText: 'FSSAI License', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: labCtrl, decoration: const InputDecoration(labelText: 'Testing Laboratory Name', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              final cert = BatchCertificate(
                id: 'cert-${DateTime.now().millisecondsSinceEpoch}',
                batchNumber: batchCtrl.text.trim().toUpperCase(),
                productId: 'custom-prod',
                productTitle: productCtrl.text.trim(),
                category: 'Dairy Foods',
                testDate: DateTime.now(),
                laboratory: labCtrl.text.trim(),
                fssaiLicense: fssaiCtrl.text.trim(),
                purityPercent: double.tryParse(purityCtrl.text) ?? 99.0,
                testParameters: {
                  'Purity Assessment': '${purityCtrl.text}% Verified',
                  'Foreign Fat Adulteration': 'Zero (Negative)',
                  'Microbiology Test': 'Pass / FSSAI Compliant',
                },
                certifiedBy: 'Chief Analytical Quality Officer',
                remarks: 'Certified for release to customer market.',
              );
              ref.read(adminMarketplaceProvider.notifier).addBatchCertificate(cert);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: storeGreen,
                  content: Text('Batch #${cert.batchNumber} certificate issued!'),
                ),
              );
            },
            child: const Text('Issue Certificate'),
          ),
        ],
      ),
    );
  }

  void _showCertificateDetailsDialog(BatchCertificate cert) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: storeGreen, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.verified, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('MILTERRA QUALITY ASSURANCE CERTIFICATE',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: storeGreen, letterSpacing: 0.8)),
                            Text('Batch #${cert.batchNumber}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('Product: ${cert.productTitle}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Laboratory: ${cert.laboratory}', style: const TextStyle(fontSize: 12, color: Color(0xff475569))),
                  Text('FSSAI / Agro License: ${cert.fssaiLicense}', style: const TextStyle(fontSize: 12, color: Color(0xff475569))),
                  Text('Purity Score: ${cert.purityPercent}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                  const SizedBox(height: 16),
                  const Text('LABORATORY TEST MATRIX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: storeMuted)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xffe2e8f0)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        for (final entry in cert.testParameters.entries)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xfff1f5f9))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key, style: const TextStyle(fontSize: 11.5, color: Color(0xff334155))),
                                Text(entry.value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: storeGreen)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Remarks: ${cert.remarks}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xff64748b))),
                  Text('Certified By: ${cert.certifiedBy}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff334155))),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: storeGreen),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: Live Carts & Abandoned Cart Recovery
  // ---------------------------------------------------------------------------
  Widget _buildLiveCartsTab() {
    final analyticsState = ref.watch(adminAnalyticsProvider);
    final analyticsNotifier = ref.read(adminAnalyticsProvider.notifier);

    final carts = analyticsState.carts;
    final activeCount = carts.where((c) => !c.isAbandoned && c.status == 'ACTIVE').length;
    final abandonedCount = carts.where((c) => c.isAbandoned).length;
    final totalAtRisk = carts.where((c) => c.isAbandoned).fold(0.0, (sum, c) => sum + c.subtotal);

    return RefreshIndicator(
      onRefresh: () => analyticsNotifier.fetchCarts(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Summary Cards
            Row(
              children: [
                _buildAnalyticsKpiCard(
                  title: 'Active Carts Right Now',
                  value: activeCount.toString(),
                  subtitle: 'Shoppers currently adding items',
                  icon: Icons.shopping_cart_outlined,
                  color: storeGreen,
                ),
                const SizedBox(width: 16),
                _buildAnalyticsKpiCard(
                  title: 'Abandoned Carts (>1hr)',
                  value: abandonedCount.toString(),
                  subtitle: 'Inactive carts needing recovery',
                  icon: Icons.remove_shopping_cart_outlined,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 16),
                _buildAnalyticsKpiCard(
                  title: 'Cart Value at Risk',
                  value: '₹${totalAtRisk.toStringAsFixed(0)}',
                  subtitle: 'Potential revenue recoverable',
                  icon: Icons.currency_rupee,
                  color: Colors.red.shade700,
                ),
                const SizedBox(width: 16),
                _buildAnalyticsKpiCard(
                  title: 'Recovery Rate',
                  value: '34.2%',
                  subtitle: 'Via automated WhatsApp nudges',
                  icon: Icons.trending_up,
                  color: Colors.teal.shade700,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Controls & Filters
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by customer phone (+91...) or product...',
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xff64748b)),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xfff8fafc),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                          ),
                        ),
                        onChanged: (val) => analyticsNotifier.setCartSearch(val),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('All Carts', 'all', analyticsState.cartFilter, (f) => analyticsNotifier.setCartFilter(f)),
                        _buildFilterChip('Active Only', 'active', analyticsState.cartFilter, (f) => analyticsNotifier.setCartFilter(f)),
                        _buildFilterChip('Abandoned', 'abandoned', analyticsState.cartFilter, (f) => analyticsNotifier.setCartFilter(f)),
                        _buildFilterChip('High Value (>₹1k)', 'high_value', analyticsState.cartFilter, (f) => analyticsNotifier.setCartFilter(f)),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xff64748b)),
                      tooltip: 'Refresh Carts',
                      onPressed: () => analyticsNotifier.fetchCarts(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Carts List
            if (analyticsState.isLoadingCarts)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (carts.isEmpty)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xff94a3b8)),
                        SizedBox(height: 12),
                        Text('No carts match the current filter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: carts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (ctx, idx) {
                  final cart = carts[idx];
                  return _buildAdminCartCard(cart, analyticsNotifier);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCartCard(AdminCartSummary cart, AdminAnalyticsNotifier notifier) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: cart.isAbandoned ? Colors.orange.shade300 : const Color(0xffe2e8f0),
          width: cart.isAbandoned ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: User phone, role, status badge, timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cart.isAbandoned ? Colors.orange.shade50 : const Color(0xfff0fdf4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    cart.isAbandoned ? Icons.remove_shopping_cart : Icons.shopping_bag,
                    color: cart.isAbandoned ? Colors.orange.shade800 : storeGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          cart.userPhone,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xff0f172a)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffe2e8f0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cart.userRole.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xff475569)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Last activity: ${cart.inactiveDurationMinutes < 60 ? "${cart.inactiveDurationMinutes}m ago" : "${cart.inactiveDurationMinutes ~/ 60}h ago"}',
                      style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cart.isAbandoned ? Colors.red.shade50 : const Color(0xffdcfce7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cart.isAbandoned ? Colors.red.shade200 : Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cart.isAbandoned ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        size: 14,
                        color: cart.isAbandoned ? Colors.red.shade700 : storeGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cart.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cart.isAbandoned ? Colors.red.shade800 : storeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xfff1f5f9)),

            // Cart Items List
            Column(
              children: cart.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xfff8fafc),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xffe2e8f0)),
                        ),
                        child: const Icon(Icons.inventory_2_outlined, size: 18, color: storeGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff1e293b))),
                            Text('SKU: ${it.productId}', style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8))),
                          ],
                        ),
                      ),
                      Text(
                        '${it.quantity} × ₹${it.unitPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, color: Color(0xff64748b)),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '₹${it.lineTotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            const Divider(height: 24, color: Color(0xfff1f5f9)),

            // Footer: Subtotal & Actions
            Row(
              children: [
                RichText(
                  text: TextSpan(
                    text: 'Total Cart Value: ',
                    style: const TextStyle(fontSize: 14, color: Color(0xff475569)),
                    children: [
                      TextSpan(
                        text: '₹${cart.subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w900, color: storeGreen, fontSize: 16),
                      ),
                      TextSpan(
                        text: ' (${cart.itemCount} items)',
                        style: const TextStyle(fontSize: 12, color: Color(0xff94a3b8)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff334155),
                    side: const BorderSide(color: Color(0xffcbd5e1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.ads_click, size: 16),
                  label: const Text('Inspect Journey', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    notifier.setClickstreamUserPhone(cart.userPhone);
                    _tabController.animateTo(4); // Jump to User Clickstream Tab (index 4)
                  },
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff25d366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('WhatsApp Recovery Nudge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showWhatsAppNudgeDialog(cart, notifier),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showWhatsAppNudgeDialog(AdminCartSummary cart, AdminAnalyticsNotifier notifier) async {
    final link = await notifier.getNudgeLink(cart.cartId);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xffdcfce7), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.chat_outlined, color: Color(0xff25d366), size: 22),
            ),
            const SizedBox(width: 10),
            const Text('Cart Recovery Nudge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Target Customer: ${cart.userPhone} (${cart.userRole.toUpperCase()})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Text('Cart Contents: ${cart.items.map((i) => i.title).join(", ")}',
                  style: const TextStyle(fontSize: 12, color: Color(0xff64748b))),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: const Text(
                  'Message Preview:\n"Namaste! We noticed you left items in your MILTERRA dairy cart. '
                  'Complete your order today with special coupon code *RECOVER10* for 10% OFF! '
                  'Tap to checkout: https://milterra.in/shop/cart"',
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xff334155)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Recovery Link:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              SelectableText(
                link ?? 'https://wa.me/91${cart.userPhone}',
                style: const TextStyle(fontSize: 11, color: storeGreen),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xff25d366)),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Send WhatsApp Message'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Recovery reminder triggered for ${cart.userPhone}')),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: Traffic & Geolocation Analytics
  // ---------------------------------------------------------------------------
  Widget _buildTrafficGeoTab() {
    final analyticsState = ref.watch(adminAnalyticsProvider);
    final traffic = analyticsState.traffic;

    if (analyticsState.isLoadingTraffic && traffic == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalVisits = traffic?.totalVisitors ?? 428;
    final todayVisits = traffic?.todayVisitors ?? 74;
    final liveVisits = traffic?.liveVisitors30m ?? 14;
    final totalPageViews = traffic?.totalPageViews ?? 1580;
    final bounceRate = traffic?.bounceRatePercent ?? 31.8;
    final avgDurationSecs = traffic?.avgSessionDurationSeconds ?? 184;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Cards
          Row(
            children: [
              _buildAnalyticsKpiCard(
                title: 'Total Site Visitors',
                value: totalVisits.toString(),
                subtitle: 'Unique customer sessions',
                icon: Icons.people_outline,
                color: storeGreen,
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Today\'s Visitors',
                value: todayVisits.toString(),
                subtitle: '+18% vs yesterday',
                icon: Icons.today_outlined,
                color: const Color(0xff2563eb),
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Live Visitors Now',
                value: liveVisits.toString(),
                subtitle: 'Active in last 30 minutes',
                icon: Icons.circle,
                color: const Color(0xff16a34a),
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Total Page Views',
                value: totalPageViews.toString(),
                subtitle: 'Avg ${(totalPageViews / totalVisits).toStringAsFixed(1)} pages/visit',
                icon: Icons.visibility_outlined,
                color: Colors.purple.shade700,
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Bounce Rate',
                value: '$bounceRate%',
                subtitle: 'Target < 40%',
                icon: Icons.exit_to_app_outlined,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 16),
              _buildAnalyticsKpiCard(
                title: 'Avg Session Duration',
                value: '${avgDurationSecs ~/ 60}m ${avgDurationSecs % 60}s',
                subtitle: 'High engagement in shop',
                icon: Icons.timer_outlined,
                color: Colors.teal.shade700,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Two-column layout: Geo distribution on left, Traffic Acquisition on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Where people are visiting from (Geo distribution)
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xffdbeafe), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.public, color: Color(0xff2563eb), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Visitor Geographic Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff0f172a))),
                                Text('Where customers are visiting your store from in India', style: TextStyle(fontSize: 12, color: Color(0xff64748b))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Top States & Dairy Belts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        ...((traffic?.topStates ?? []).map((s) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff1e293b))),
                                    Text('${s.visitorsCount} visits (${s.percent}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff2563eb))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: s.percent / 100.0,
                                  backgroundColor: const Color(0xfff1f5f9),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff2563eb)),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          );
                        })),

                        const Divider(height: 32, color: Color(0xfff1f5f9)),
                        const Text('Top Cities', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (traffic?.topCities ?? []).map((c) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xfff8fafc),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xffe2e8f0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: storeGreen),
                                  const SizedBox(width: 6),
                                  Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff0f172a))),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xffe2e8f0), borderRadius: BorderRadius.circular(4)),
                                    child: Text('${c.visitorsCount}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff475569))),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Column 2: How they arrived (Acquisition / Referrers)
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xffe2e8f0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: const Color(0xfffef3c7), borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.alt_route, color: Color(0xffd97706), size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Traffic Acquisition & Sources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff0f172a))),
                                Text('How visitors discovered and arrived at your storefront', style: TextStyle(fontSize: 12, color: Color(0xff64748b))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Traffic Sources', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        ...((traffic?.topReferrers ?? []).map((r) {
                          IconData refIcon = Icons.link;
                          Color refColor = const Color(0xff64748b);
                          if (r.type == 'whatsapp') {
                            refIcon = Icons.chat_outlined;
                            refColor = const Color(0xff25d366);
                          } else if (r.type == 'google') {
                            refIcon = Icons.search;
                            refColor = Colors.blue;
                          } else if (r.type == 'instagram') {
                            refIcon = Icons.camera_alt_outlined;
                            refColor = Colors.pink;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(refIcon, size: 16, color: refColor),
                                    const SizedBox(width: 8),
                                    Text(r.source, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xff1e293b))),
                                    const Spacer(),
                                    Text('${r.visitorsCount} visits (${r.percent}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: refColor)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                  value: r.percent / 100.0,
                                  backgroundColor: const Color(0xfff1f5f9),
                                  valueColor: AlwaysStoppedAnimation<Color>(refColor),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            ),
                          );
                        })),

                        const Divider(height: 32, color: Color(0xfff1f5f9)),
                        const Text('Device & Technology Breakdown', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff334155))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDeviceCard(
                                icon: Icons.phone_android,
                                label: 'Mobile App / Web',
                                count: traffic?.deviceBreakdown['mobile'] ?? 334,
                                percent: '78%',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDeviceCard(
                                icon: Icons.laptop_mac,
                                label: 'Desktop Browser',
                                count: traffic?.deviceBreakdown['desktop'] ?? 82,
                                percent: '19%',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDeviceCard(
                                icon: Icons.tablet_mac,
                                label: 'Tablet / iPad',
                                count: traffic?.deviceBreakdown['tablet'] ?? 12,
                                percent: '3%',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard({required IconData icon, required String label, required int count, required String percent}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xff64748b)),
          const SizedBox(height: 8),
          Text(percent, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff0f172a))),
          Text('$count visits', style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xff475569))),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 5: User Clickstream & Behavior Journey
  // ---------------------------------------------------------------------------
  Widget _buildClickstreamTab() {
    final analyticsState = ref.watch(adminAnalyticsProvider);
    final analyticsNotifier = ref.read(adminAnalyticsProvider.notifier);
    final events = analyticsState.clickstreamEvents;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xffe2e8f0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xfff3e8ff), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.ads_click, color: Color(0xff9333ea), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User Clickstream & Interaction Journey', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff0f172a))),
                          Text('Step-by-step click log: what a particular user or visitor clicked on your website', style: TextStyle(fontSize: 12, color: Color(0xff64748b))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Filter by customer phone (e.g. 9820112345) or session ID...',
                            prefixIcon: const Icon(Icons.person_search, size: 20, color: Color(0xff64748b)),
                            isDense: true,
                            filled: true,
                            fillColor: const Color(0xfff8fafc),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                            ),
                          ),
                          onSubmitted: (val) => analyticsNotifier.setClickstreamUserPhone(val.trim().isEmpty ? null : val.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (analyticsState.selectedUserPhone != null) ...[
                        Chip(
                          backgroundColor: const Color(0xffe0f2fe),
                          label: Text('Customer: ${analyticsState.selectedUserPhone}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xff0284c7))),
                          onDeleted: () => analyticsNotifier.setClickstreamUserPhone(null),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xff64748b)),
                        tooltip: 'Refresh Clickstream',
                        onPressed: () => analyticsNotifier.fetchClickstream(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All Actions', 'ALL', analyticsState.selectedEventType ?? 'ALL', (e) => analyticsNotifier.setClickstreamEventType(e == 'ALL' ? null : e)),
                      _buildFilterChip('Product Views', 'PRODUCT_VIEW', analyticsState.selectedEventType ?? 'ALL', (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip('Add to Cart', 'ADD_TO_CART', analyticsState.selectedEventType ?? 'ALL', (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip('Searches', 'SEARCH_QUERY', analyticsState.selectedEventType ?? 'ALL', (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip('Lab Certificates', 'CERTIFICATE_VIEW', analyticsState.selectedEventType ?? 'ALL', (e) => analyticsNotifier.setClickstreamEventType(e)),
                      _buildFilterChip('Checkouts', 'CHECKOUT_INITIATE', analyticsState.selectedEventType ?? 'ALL', (e) => analyticsNotifier.setClickstreamEventType(e)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Timeline Feed
          if (analyticsState.isLoadingClickstream)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (events.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.touch_app_outlined, size: 48, color: Color(0xff94a3b8)),
                      SizedBox(height: 12),
                      Text('No clickstream events recorded for this selection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xffe2e8f0)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final ev = events[idx];
                    return _buildTimelineEventRow(ev, idx == 0);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineEventRow(ClickstreamEventItem ev, bool isLatest) {
    Color badgeColor;
    IconData eventIcon;

    switch (ev.eventType) {
      case 'ADD_TO_CART':
        badgeColor = const Color(0xff16a34a);
        eventIcon = Icons.add_shopping_cart;
        break;
      case 'REMOVE_FROM_CART':
        badgeColor = Colors.red.shade700;
        eventIcon = Icons.remove_shopping_cart;
        break;
      case 'PRODUCT_VIEW':
        badgeColor = const Color(0xff2563eb);
        eventIcon = Icons.visibility_outlined;
        break;
      case 'SEARCH_QUERY':
        badgeColor = const Color(0xffd97706);
        eventIcon = Icons.search;
        break;
      case 'CERTIFICATE_VIEW':
        badgeColor = const Color(0xff0d9488);
        eventIcon = Icons.verified_outlined;
        break;
      case 'CHECKOUT_INITIATE':
        badgeColor = const Color(0xff9333ea);
        eventIcon = Icons.shopping_bag_outlined;
        break;
      default:
        badgeColor = const Color(0xff64748b);
        eventIcon = Icons.touch_app_outlined;
    }

    final timeFormatted = '${ev.createdAt.hour.toString().padLeft(2, '0')}:${ev.createdAt.minute.toString().padLeft(2, '0')}:${ev.createdAt.second.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time & relative label
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff1e293b))),
              const Text('UTC', style: TextStyle(fontSize: 10, color: Color(0xff94a3b8))),
            ],
          ),
        ),

        // Node circle icon
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: badgeColor, width: 1.5),
          ),
          child: Icon(eventIcon, size: 16, color: badgeColor),
        ),
        const SizedBox(width: 14),

        // Content
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLatest ? const Color(0xfff0fdf4) : const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isLatest ? Colors.green.shade300 : const Color(0xffe2e8f0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        ev.eventType,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ev.elementText ?? ev.pageUrl,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
                      ),
                    ),
                    if (ev.userPhone != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xffe2e8f0), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          ev.userPhone!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff334155)),
                        ),
                      )
                    else
                      Text(
                        'Session: ${ev.sessionId.substring(0, ev.sessionId.length > 12 ? 12 : ev.sessionId.length)}...',
                        style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.language, size: 12, color: Color(0xff94a3b8)),
                    const SizedBox(width: 4),
                    Text('Route: ${ev.pageUrl}', style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
                    if (ev.metadata != null && ev.metadata!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Payload: ${ev.metadata}',
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xff475569)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // KPI Card Helper
  // ---------------------------------------------------------------------------
  Widget _buildAnalyticsKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xffe2e8f0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff64748b))),
                  Icon(icon, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentVal, Function(String) onSelect) {
    final isSelected = currentVal == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelect(value),
      selectedColor: storeGreen,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : const Color(0xff334155),
      ),
      backgroundColor: const Color(0xfff1f5f9),
    );
  }
}
