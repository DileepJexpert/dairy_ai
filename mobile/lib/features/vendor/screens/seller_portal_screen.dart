import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../admin/providers/admin_marketplace_provider.dart';
import '../providers/seller_portal_provider.dart';

class SellerPortalScreen extends ConsumerStatefulWidget {
  const SellerPortalScreen({super.key});

  @override
  ConsumerState<SellerPortalScreen> createState() => _SellerPortalScreenState();
}

class _SellerPortalScreenState extends ConsumerState<SellerPortalScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sellerPortalProvider);
    final adminState = ref.watch(adminMarketplaceProvider);

    // Fallback if not logged in
    final currentSeller = session.sellerAccount ?? adminState.sellers.first;
    final myOffers = adminState.offers.where((o) => o.sellerId == currentSeller.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        backgroundColor: storeDarkGreenNav,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.storefront, color: storeAmber, size: 22),
            const SizedBox(width: 8),
            Text('${currentSeller.businessName} · Seller Central', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Marketplace Store',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.push('/shop'),
          ),
          IconButton(
            tooltip: 'Switch Seller / Logout',
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sellerPortalProvider.notifier).logout();
              context.go('/seller/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: storeWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: storeBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: storeGreen,
                    child: Text(currentSeller.businessName.substring(0, 1), style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(currentSeller.businessName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: currentSeller.status == SellerStatus.approved ? const Color(0xffe8f5e9) : const Color(0xfffff8e1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentSeller.status.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: currentSeller.status == SellerStatus.approved ? storeGreen : storeAmberDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GSTIN: ${currentSeller.gstin ?? "Verified"} · Warehouse: ${currentSeller.warehouseCity ?? "Anand"} · Rating: ${currentSeller.ratingScore} ★ (${currentSeller.totalRatingsCount} ratings)',
                          style: const TextStyle(fontSize: 12, color: storeMuted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: storeGreen),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text('Add Offer to Catalog'),
                    onPressed: () => _showAddOfferModal(currentSeller),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Performance Metric KPI Cards
            Row(
              children: [
                _kpiCard('Active Offers', myOffers.length.toString(), Icons.sell_outlined, storeGreen),
                const SizedBox(width: 16),
                _kpiCard('Total Stock', myOffers.fold<int>(0, (sum, o) => sum + o.availableStock).toString(), Icons.inventory_2_outlined, storeAmberDark),
                const SizedBox(width: 16),
                _kpiCard('Commission Tier', '${currentSeller.commissionRatePercent}%', Icons.percent, const Color(0xff0284c7)),
                const SizedBox(width: 16),
                _kpiCard('Payout Method', currentSeller.upiId ?? 'Bank Direct', Icons.account_balance_wallet_outlined, const Color(0xff7c3aed)),
              ],
            ),
            const SizedBox(height: 28),

            // Active Offers Table
            const Text('Your Active Product Offers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: storeGreen)),
            const SizedBox(height: 12),
            if (myOffers.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: storeWhite, borderRadius: BorderRadius.circular(12), border: Border.all(color: storeBorder)),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 48, color: storeMuted),
                      const SizedBox(height: 12),
                      const Text('You have no active SKU offers listed yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      const Text('Map your stock to any canonical Milterra catalog product to start selling.', style: TextStyle(fontSize: 12, color: storeMuted)),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: storeGreen),
                        onPressed: () => _showAddOfferModal(currentSeller),
                        child: const Text('Add Your First Offer'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: myOffers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final o = myOffers[i];
                    return ListTile(
                      leading: Icon(
                        o.isBuyBoxWinner ? Icons.emoji_events : Icons.local_offer_outlined,
                        color: o.isBuyBoxWinner ? storeGold : storeGreen,
                      ),
                      title: Row(
                        children: [
                          Text('SKU: ${o.sellerSku}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (o.isBuyBoxWinner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xff232f3e), borderRadius: BorderRadius.circular(4)),
                              child: const Text('WINNING BUY BOX', style: TextStyle(fontSize: 9, color: Color(0xffff9900), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        'Your Selling Price: ${storeMoney(o.sellingPrice)} (MRP ${storeMoney(o.mrp)}) · Available Units: ${o.availableStock} · Fulfilled via ${o.fulfillmentType.name}',
                        style: const TextStyle(fontSize: 12, color: storeMuted),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: storeGreen),
                            tooltip: 'Edit Offer Price',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Offer ${o.sellerSku} price editing modal opened.')),
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
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String label, String value, IconData icon, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: storeWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: storeBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: storeMuted)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  void _showAddOfferModal(SellerAccount seller) {
    final catalog = ref.read(productsProvider(null)).valueOrNull ?? defaultMilterraProducts;
    String selectedProductId = catalog.first.id;
    final skuCtrl = TextEditingController(text: 'SELLER-${seller.businessName.substring(0, 3).toUpperCase()}-500');
    final priceCtrl = TextEditingController(text: '685');
    final mrpCtrl = TextEditingController(text: '750');
    final stockCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          return AlertDialog(
            title: const Text('Add Seller Offer to Milterra Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedProductId,
                      decoration: const InputDecoration(labelText: 'Select Canonical Product', border: OutlineInputBorder()),
                      items: catalog.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(p.title, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedProductId = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'Your Seller SKU Identifier', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Your Price (₹)', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: mrpCtrl, decoration: const InputDecoration(labelText: 'MRP (₹)', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Available Units for Dispatch', border: OutlineInputBorder())),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: storeGreen),
                onPressed: () {
                  final sp = double.tryParse(priceCtrl.text) ?? 685.0;
                  final mrp = double.tryParse(mrpCtrl.text) ?? 750.0;
                  final stock = int.tryParse(stockCtrl.text) ?? 30;

                  ref.read(sellerPortalProvider.notifier).createOfferForSeller(
                    productId: selectedProductId,
                    sellerSku: skuCtrl.text.trim(),
                    mrp: mrp,
                    sellingPrice: sp,
                    availableStock: stock,
                    fulfillmentType: FulfillmentType.sellerDirect,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Your offer has been submitted and is active!'), backgroundColor: storeGreen),
                  );
                },
                child: const Text('Publish Offer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
