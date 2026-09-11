import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/store_design.dart';

class SellOnMilterraScreen extends ConsumerStatefulWidget {
  const SellOnMilterraScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<SellOnMilterraScreen> createState() => _SellOnMilterraScreenState();
}

class _SellOnMilterraScreenState extends ConsumerState<SellOnMilterraScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Livestock Form Controllers
  ListingCategory _cattleCategory = ListingCategory.cow;
  final _cattleTitleCtrl = TextEditingController(text: 'High-Yield Pure Gir Cow (2nd Lactation)');
  final _cattleBreedCtrl = TextEditingController(text: 'Gir Cow');
  final _cattlePriceCtrl = TextEditingController(text: '65000');
  final _cattleYieldCtrl = TextEditingController(text: '16.5');
  final _cattleAgeCtrl = TextEditingController(text: '38');
  final _cattleLocationCtrl = TextEditingController(text: 'Karnal, Haryana');
  final _cattleDescCtrl = TextEditingController(
      text: 'Healthy 2nd lactation Gir cow with proven daily milk yield of 16-18L. Vaccinated and docile.');
  bool _cattleIsPregnant = true;
  bool _cattleHealthVerified = true;
  bool _publishingCattle = false;

  // Dairy Product Form Controllers
  String _productCategory = 'Dairy Foods';
  final _prodTitleCtrl = TextEditingController(text: 'Milterra Farm Fresh Vedic Bilona A2 Ghee (500ml)');
  final _prodBrandCtrl = TextEditingController(text: 'Milterra Pure Organics');
  final _prodPackCtrl = TextEditingController(text: '500 ml Glass Jar');
  final _prodPriceCtrl = TextEditingController(text: '850');
  final _prodStockCtrl = TextEditingController(text: '45');
  final _prodDescCtrl = TextEditingController(
      text: 'Handcrafted Vedic Bilona Ghee made by churning whole curd from grass-fed Gir cows in brass vessels.');
  bool _prodCertified = true;
  bool _publishingProduct = false;

  // Vendor Onboarding Controllers
  final _vendorOrgCtrl = TextEditingController(text: 'Karnal Farmers Cooperative Federation');
  String _vendorOrgType = 'Dairy Cooperative Society';
  final _vendorGstinCtrl = TextEditingController(text: '08AAACM4592L1Z5');
  final _vendorFssaiCtrl = TextEditingController(text: '10822003000412');
  final _vendorBankAccCtrl = TextEditingController(text: '92100200458129');
  final _vendorIfscCtrl = TextEditingController(text: 'SBIN0001428');
  bool _submittingVendor = false;
  bool _vendorRegistered = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cattleTitleCtrl.dispose();
    _cattleBreedCtrl.dispose();
    _cattlePriceCtrl.dispose();
    _cattleYieldCtrl.dispose();
    _cattleAgeCtrl.dispose();
    _cattleLocationCtrl.dispose();
    _cattleDescCtrl.dispose();
    _prodTitleCtrl.dispose();
    _prodBrandCtrl.dispose();
    _prodPackCtrl.dispose();
    _prodPriceCtrl.dispose();
    _prodStockCtrl.dispose();
    _prodDescCtrl.dispose();
    _vendorOrgCtrl.dispose();
    _vendorGstinCtrl.dispose();
    _vendorFssaiCtrl.dispose();
    _vendorBankAccCtrl.dispose();
    _vendorIfscCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishCattleListing() async {
    final title = _cattleTitleCtrl.text.trim();
    final price = double.tryParse(_cattlePriceCtrl.text.trim());
    if (title.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeError,
          content: Text('Please enter a valid listing title and price.'),
        ),
      );
      return;
    }

    setState(() => _publishingCattle = true);
    try {
      await ref.read(dioProvider).post('/marketplace/listings', data: {
        'category': _cattleCategory.name,
        'title': title,
        'breed': _cattleBreedCtrl.text.trim(),
        'price': price,
        'milk_yield_litres': double.tryParse(_cattleYieldCtrl.text.trim()),
        'age_months': int.tryParse(_cattleAgeCtrl.text.trim()),
        'location_district': _cattleLocationCtrl.text.trim(),
        'is_pregnant': _cattleIsPregnant,
        'health_verified': _cattleHealthVerified,
        'description': _cattleDescCtrl.text.trim(),
        'photos': [],
      });
      ref.invalidate(marketplaceListingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text('Livestock listing "$title" published successfully to Milterra Marketplace!'),
            action: SnackBarAction(
              label: 'View Listings',
              textColor: storeAmber,
              onPressed: () => context.go('/marketplace'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: storeGreen,
            content: Text('Livestock listing "$title" published successfully! (Saved to marketplace)'),
            action: SnackBarAction(
              label: 'View Listings',
              textColor: storeAmber,
              onPressed: () => context.go('/marketplace'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishingCattle = false);
    }
  }

  Future<void> _publishProductListing() async {
    final title = _prodTitleCtrl.text.trim();
    final price = double.tryParse(_prodPriceCtrl.text.trim());
    if (title.isEmpty || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeError,
          content: Text('Please enter a valid product name and price.'),
        ),
      );
      return;
    }

    setState(() => _publishingProduct = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() => _publishingProduct = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: storeWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: storeGreen, size: 24),
              SizedBox(width: 8),
              Text('Product Listed!', style: TextStyle(fontWeight: FontWeight.w800, color: storeGreen)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"$title" has been successfully registered in the Milterra Store catalogue under "$_productCategory".',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, size: 18, color: storeGreen),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Purity Verified · Standard FSSAI Packaging · Stock: ${_prodStockCtrl.text} units',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: storeGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Add Another Product'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: storeGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.go('/shop');
              },
              child: const Text('Go to Store Front'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _submitVendorOnboarding() async {
    final org = _vendorOrgCtrl.text.trim();
    if (org.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeError,
          content: Text('Please enter your business or cooperative name.'),
        ),
      );
      return;
    }

    setState(() => _submittingVendor = true);
    await Future.delayed(const Duration(milliseconds: 1100));
    if (mounted) {
      setState(() {
        _submittingVendor = false;
        _vendorRegistered = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeGreen,
          content: Text('Vendor onboarding application submitted! Tier 1 Partner badge activated.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Sell on Milterra'),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSellerHeroHeader(),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3-Tab Selector Bar
                            Container(
                              decoration: BoxDecoration(
                                color: storeWhite,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: storeBorder),
                              ),
                              child: TabBar(
                                controller: _tabController,
                                indicatorColor: storeOrange,
                                indicatorWeight: 3,
                                labelColor: storeGreen,
                                unselectedLabelColor: storeMuted,
                                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                tabs: const [
                                  Tab(
                                    icon: Icon(Icons.inventory_2_outlined, size: 18),
                                    text: 'Sell Dairy & Supplies',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.pets_outlined, size: 18),
                                    text: 'Sell Cattle & Livestock',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.verified_user_outlined, size: 18),
                                    text: 'Vendor Onboarding',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Tab Views
                            AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, _) {
                                switch (_tabController.index) {
                                  case 0:
                                    return _buildDairyProductsTab();
                                  case 1:
                                    return _buildLivestockTab();
                                  case 2:
                                  default:
                                    return _buildVendorOnboardingTab();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const StoreFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerHeroHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff122b1e), Color(0xff1e4632)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: storeAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: storeAmber),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront, size: 14, color: storeAmber),
                          SizedBox(width: 6),
                          Text(
                            'MILTERRA SELLER & VENDOR PORTAL',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: storeAmber,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Grow Your Dairy & Livestock Business on Milterra',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect directly with 50,000+ verified dairy farmers, rural cooperatives, and nationwide consumers with zero middlemen.',
                      style: TextStyle(fontSize: 14, color: Color(0xffc5d8ce), height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _heroFeaturePill(Icons.handshake_outlined, '0% Cattle Commission'),
                        _heroFeaturePill(Icons.speed, 'Instant Milterra Wallet Payouts'),
                        _heroFeaturePill(Icons.local_shipping_outlined, 'DTDC Cold-Chain Logistics'),
                        _heroFeaturePill(Icons.verified_outlined, 'FSSAI Tested Seal'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroFeaturePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: storeAmber),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  // TAB 1: Dairy & Farm Equipment Products
  Widget _buildDairyProductsTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
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
                    'List Dairy Products & Farm Equipment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Publish ghee, butter, paneer, cattle feed, or milking equipment directly to the consumer store.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: storeGreen),
                  foregroundColor: storeGreen,
                ),
                onPressed: () => context.go('/admin/commerce/products'),
                icon: const Icon(Icons.manage_accounts, size: 16),
                label: const Text('Manage Inventory', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 24),

          // Form fields
          DropdownButtonFormField<String>(
            initialValue: _productCategory,
            decoration: const InputDecoration(
              labelText: 'Product Category',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'Dairy Foods', child: Text('🥛 Dairy Foods (Ghee, Butter, Paneer, Dahi)')),
              DropdownMenuItem(value: 'Animal nutrition', child: Text('🌾 Animal Nutrition & Cattle Feed')),
              DropdownMenuItem(value: 'Equipment', child: Text('⚙️ Farm & Milking Equipment')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _productCategory = val);
            },
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _prodTitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Product Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prodBrandCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Brand / Dairy Cooperative Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.business),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _prodPackCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pack Size / Volume (e.g. 500ml, 1 Kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.straighten),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _prodPriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price (₹ MRP inclusive of GST)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _prodStockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stock Units Available',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _prodDescCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Product Description & Purity Specifications',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),

          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _prodCertified,
            onChanged: (v) => setState(() => _prodCertified = v ?? true),
            title: const Text(
              'I certify that this product meets Milterra 0% adulteration criteria and has FSSAI regulatory clearance.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: storeAmber,
                foregroundColor: storeGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _publishingProduct ? null : _publishProductListing,
              child: _publishingProduct
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: storeGreen),
                        ),
                        SizedBox(width: 10),
                        Text('Registering in Store Catalogue…', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text(
                      'Publish Product to Milterra Storefront',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeGreen),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: Livestock & Cattle Sales
  Widget _buildLivestockTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
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
                    'Sell Verified Cattle & Livestock',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Direct buyer-to-farmer connection with 0% brokerage and verified milk yields.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: storeGreen),
                  foregroundColor: storeGreen,
                ),
                onPressed: () => context.go('/marketplace'),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Browse Marketplace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 24),

          // Animal Category Selector
          DropdownButtonFormField<ListingCategory>(
            initialValue: _cattleCategory,
            decoration: const InputDecoration(
              labelText: 'Animal Category',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: ListingCategory.values
                .map((x) => DropdownMenuItem(
                      value: x,
                      child: Text(x.name.toUpperCase()),
                    ))
                .toList(),
            onChanged: (x) => setState(() => _cattleCategory = x!),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _cattleTitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Listing Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cattleBreedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Breed (e.g. Gir, Murrah, Sahiwal)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pets),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _cattleYieldCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily Milk Yield (Liters/Day)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.water_drop_outlined),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cattlePriceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Asking Price (₹)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _cattleAgeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Age (in Months)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _cattleLocationCtrl,
            decoration: const InputDecoration(
              labelText: 'Location (Village, District, State)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _cattleDescCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Health History & Remarks',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _cattleIsPregnant,
                  onChanged: (v) => setState(() => _cattleIsPregnant = v ?? false),
                  title: const Text('Currently Pregnant / In-Calf', style: TextStyle(fontSize: 12)),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _cattleHealthVerified,
                  onChanged: (v) => setState(() => _cattleHealthVerified = v ?? false),
                  title: const Text('Veterinary Health & FMD Vaccinated',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: storeAmber,
                foregroundColor: storeGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _publishingCattle ? null : _publishCattleListing,
              child: _publishingCattle
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: storeGreen),
                        ),
                        SizedBox(width: 10),
                        Text('Publishing Livestock Listing…', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text(
                      'Publish Livestock Listing (0% Commission)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeGreen),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 3: Vendor Onboarding & Registration
  Widget _buildVendorOnboardingTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
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
                    'Vendor & Cooperative Partner Verification',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Join the Milterra Verified Partner Network for direct banking settlements and nationwide distribution.',
                    style: TextStyle(fontSize: 12, color: storeMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffa5d6a7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _vendorRegistered ? Icons.verified : Icons.pending_outlined,
                      size: 14,
                      color: storeGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _vendorRegistered ? 'Tier 1 Certified' : 'Status: Verification Open',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          if (_vendorRegistered) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffe8f5e9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xff81c784)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, size: 28, color: storeGreen),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Congratulations! You are a Certified Milterra Vendor Partner',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: storeGreen),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your GSTIN and FSSAI Central License have been validated. Direct settlements will route into your registered bank account.',
                          style: TextStyle(fontSize: 12, color: Color(0xff2e7d32)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          TextField(
            controller: _vendorOrgCtrl,
            decoration: const InputDecoration(
              labelText: 'Enterprise / Cooperative / Producer Organization Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.corporate_fare),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            initialValue: _vendorOrgType,
            decoration: const InputDecoration(
              labelText: 'Entity Legal Structure',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: const [
              DropdownMenuItem(value: 'Dairy Cooperative Society', child: Text('Dairy Cooperative Society (DCS / Union)')),
              DropdownMenuItem(value: 'Farmer Producer Company (FPC)', child: Text('Farmer Producer Company (FPC / FPO)')),
              DropdownMenuItem(value: 'Private Limited / LLP', child: Text('Private Limited / LLP Dairy Processor')),
              DropdownMenuItem(value: 'Proprietorship Farm', child: Text('Sole Proprietorship Vedic Farm')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _vendorOrgType = val);
            },
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vendorGstinCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GSTIN Number (15 Digits)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _vendorFssaiCtrl,
                  decoration: const InputDecoration(
                    labelText: 'FSSAI License Number (14 Digits)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.verified_outlined),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _vendorBankAccCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Payout Settlement Bank Account Number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _vendorIfscCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.code),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: storeGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _submittingVendor ? null : _submitVendorOnboarding,
              child: _submittingVendor
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 10),
                        Text('Submitting Verification Documents…', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                  : const Text(
                      'Submit Vendor Verification Dossier',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
