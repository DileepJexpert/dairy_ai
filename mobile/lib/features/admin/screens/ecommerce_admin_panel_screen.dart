import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../cart/providers/order_repository.dart';
import '../providers/admin_marketplace_provider.dart';

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
    _tabController = TabController(length: 10, vsync: this);
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

  // ---------------------------------------------------------------------------
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
  void _showCreateProductDialog() {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final sizeCtrl = TextEditingController(text: '500 ml');
    String selectedCategory = 'Dairy Foods';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Catalog Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Product Title', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                items: ['Dairy Foods', 'Animal Nutrition', 'Farm Equipment'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => selectedCategory = v ?? selectedCategory,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Base MRP (₹)', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: sizeCtrl, decoration: const InputDecoration(labelText: 'Pack Size', border: OutlineInputBorder()))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                final p = Product(
                  id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
                  title: titleCtrl.text.trim(),
                  price: double.tryParse(priceCtrl.text) ?? 500.0,
                  packSize: sizeCtrl.text.trim(),
                  unit: sizeCtrl.text.trim().isNotEmpty ? sizeCtrl.text.trim() : '500 ml',
                  category: ProductCategory.feedNutrition,
                  availableQuantity: 50,
                  minOrderQuantity: 1,
                  inStock: true,
                  vendorId: 'vendor-milterra',
                  media: const ['assets/store/minera-360-jar.jpg'],
                );
                ref.read(adminMarketplaceProvider.notifier).addCustomProduct(p);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Publish SKU'),
          ),
        ],
      ),
    );
  }

  void _showAddNutritionConceptDialog() {
    final titleCtrl = TextEditingController(text: 'MILTERRA Calcium STC High-Absorption Gel');
    final taglineCtrl = TextEditingController(text: 'Ionic Calcium with Vitamin D3 for Milk Fever Prevention');
    String selectedStage = 'Concept Preview';
    String selectedSubcategory = 'Supplements';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Cattle Nutrition Formulation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Formulation Title', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: taglineCtrl, decoration: const InputDecoration(labelText: 'Scientific Tagline', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedSubcategory,
                decoration: const InputDecoration(labelText: 'Nutrition Subcategory', border: OutlineInputBorder()),
                items: ['Pashu Aahar / Cattle Feed', 'Stage-Based Nutrition Courses', 'Supplements'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => selectedSubcategory = v ?? selectedSubcategory,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedStage,
                decoration: const InputDecoration(labelText: 'Lifecycle Stage', border: OutlineInputBorder()),
                items: ['Concept Preview', 'Farmer Feedback Open', 'In Development', 'Coming Later'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => selectedStage = v ?? selectedStage,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              final p = Product(
                id: 'nutri-${DateTime.now().millisecondsSinceEpoch}',
                title: titleCtrl.text.trim(),
                price: 499.0,
                packSize: '1 Litre Gel',
                unit: '1 L',
                category: ProductCategory.feedNutrition,
                availableQuantity: 0,
                minOrderQuantity: 1,
                inStock: false,
                vendorId: 'vendor-milterra',
                media: const ['assets/store/calci-feed-combo.jpg'],
                taxonomy: {
                  'concept': true,
                  'status': selectedStage,
                  'tagline': taglineCtrl.text.trim(),
                  'subcategory': selectedSubcategory,
                },
              );
              ref.read(adminMarketplaceProvider.notifier).addCustomProduct(p);
              Navigator.pop(ctx);
            },
            child: const Text('Save & Stage Formulation'),
          ),
        ],
      ),
    );
  }

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
}
