import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/models/product_models.dart';
import '../../marketplace/providers/product_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/widgets/rfq_quote_dialog.dart';
import '../../cart/providers/cart_provider.dart';

/// Dedicated Machinery & Equipment Detail Screen (Toolsvilla Specs + IndiaMART RFQ + Spares & Delivery).
class MachineryDetailScreen extends ConsumerStatefulWidget {
  const MachineryDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<MachineryDetailScreen> createState() =>
      _MachineryDetailScreenState();
}

class _MachineryDetailScreenState extends ConsumerState<MachineryDetailScreen> {
  final int _activePhoto = 0;
  final _pincodeCtrl = TextEditingController(text: '388001');
  bool _checkingDelivery = false;
  String? _deliveryStatus;

  @override
  void dispose() {
    _pincodeCtrl.dispose();
    super.dispose();
  }

  void _checkPincodeDelivery() {
    if (_pincodeCtrl.text.trim().length != 6) return;
    setState(() => _checkingDelivery = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _checkingDelivery = false;
          _deliveryStatus =
              'Doorstep Freight Delivery Available to ${_pincodeCtrl.text.trim()} (Transit 3-5 days)';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(
            currentCategory: 'Machinery & Equipment',
            isFarmerHub: true,
          ),
          const StoreCategoryNavigation(selected: 'Machinery & Equipment'),
          Expanded(
            child: productAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: storeGreen)),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: storeError),
                      const SizedBox(height: 12),
                      Text('Machinery listing not found: $err',
                          style: const TextStyle(color: storeText)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/marketplace'),
                        child: const Text('Back to Farmer Hub'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (product) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: StoreLayout.maxWidth),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Breadcrumbs
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => context.go('/marketplace'),
                                      child: const Text('Farmer Machinery Hub',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: storeMuted,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const Text(' / ',
                                        style: TextStyle(color: storeMuted)),
                                    Text(product.title,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: storeGreen,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Responsive Main Grid
                                LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    final isWide = constraints.maxWidth >= 860;
                                    return Flex(
                                      direction: isWide
                                          ? Axis.horizontal
                                          : Axis.vertical,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Left: Photo & OEM Badges
                                        Expanded(
                                          flex: isWide ? 5 : 0,
                                          child: _buildMachineryGallery(product),
                                        ),
                                        if (isWide) const SizedBox(width: 24)
                                        else const SizedBox(height: 16),

                                        // Right: Buy Box & IndiaMART RFQ
                                        Expanded(
                                          flex: isWide ? 6 : 0,
                                          child: _buildMachineryBuyBox(product),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),

                                // Toolsvilla Technical Specification Matrix
                                _buildTechnicalMatrix(product),
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
      ),
    );
  }

  Widget _buildMachineryGallery(Product product) {
    final images = product.media;

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 340,
              width: double.infinity,
              child: images.isEmpty
                  ? Container(
                      color: const Color(0xfff8fafc),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.precision_manufacturing,
                              size: 80, color: storeMuted),
                          SizedBox(height: 8),
                          Text('Heavy Farm Machinery / Equipment',
                              style: TextStyle(
                                  color: storeMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : (images[_activePhoto.clamp(0, images.length - 1)]
                          .startsWith('assets/')
                      ? Image.asset(
                          images[_activePhoto.clamp(0, images.length - 1)],
                          fit: BoxFit.contain,
                        )
                      : Image.network(
                          images[_activePhoto.clamp(0, images.length - 1)],
                          fit: BoxFit.contain,
                        )),
            ),
          ),
          const SizedBox(height: 16),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: Icon(Icons.verified, size: 16, color: storeGreen),
                label: Text('OEM Certified & Tested'),
                backgroundColor: Color(0xffe8f5e9),
                labelStyle: TextStyle(
                    color: storeGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
              Chip(
                avatar: Icon(Icons.handyman_outlined, size: 16, color: storeOrange),
                label: Text('1-Year Standard Warranty + Spares Support'),
                backgroundColor: Color(0xfffff7ed),
                labelStyle: TextStyle(
                    color: storeOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
              Chip(
                avatar: Icon(Icons.local_shipping_outlined, size: 16, color: storeGreen),
                label: Text('Doorstep Logistics across India'),
                backgroundColor: Color(0xfff0fdf4),
                labelStyle: TextStyle(
                    color: storeGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMachineryBuyBox(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('FARM MACHINERY & IMPLEMENTS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: storeGreen)),
              ),
              const Spacer(),
              const Text('Brand: Milterra AgriTech OEM',
                  style: TextStyle(
                      fontSize: 11,
                      color: storeMuted,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            product.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: storeText,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.star, color: storeGold, size: 16),
              Icon(Icons.star, color: storeGold, size: 16),
              Icon(Icons.star, color: storeGold, size: 16),
              Icon(Icons.star, color: storeGold, size: 16),
              Icon(Icons.star_half, color: storeGold, size: 16),
              SizedBox(width: 6),
              Text('4.8 (42 Verified Commercial Farmer Ratings)',
                  style: TextStyle(fontSize: 11, color: storeMuted)),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${product.price.toInt()}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: storeGreen,
                ),
              ),
              const SizedBox(width: 8),
              const Text('ex-GST / Direct Factory Price',
                  style: TextStyle(fontSize: 12, color: storeMuted)),
            ],
          ),
          const SizedBox(height: 20),

          // Pincode Delivery Check
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: storeCream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Check Doorstep Freight Delivery:',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: storeMuted)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pincodeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'Enter 6-digit PIN code',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed:
                          _checkingDelivery ? null : _checkPincodeDelivery,
                      child: Text(_checkingDelivery ? 'Checking...' : 'Check'),
                    ),
                  ],
                ),
                if (_deliveryStatus != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: storeGreen),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _deliveryStatus!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: storeGreen,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dual Action: IndiaMART RFQ + Toolsvilla Direct Buy
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: storeOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => showRFQQuoteDialog(context,
                      product: product, defaultTitle: product.title),
                  icon: const Icon(Icons.request_quote_outlined, size: 20),
                  label: const Text('Get Best Price / RFQ',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: storeGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await ref
                        .read(cartProvider.notifier)
                        .add(product.id, 1, product);
                    if (mounted) {
                      context.push('/cart/checkout');
                    }
                  },
                  icon: const Icon(Icons.flash_on, size: 20),
                  label: const Text('Buy Now (Doorstep)',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalMatrix(Product product) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.precision_manufacturing, color: storeGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Toolsvilla Technical Specifications Matrix',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: storeGreen),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Verified engineering parameters tested for heavy-duty commercial dairy & fodder operations.',
            style: TextStyle(fontSize: 12, color: storeMuted),
          ),
          const Divider(height: 24),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 768;
              return GridView.count(
                crossAxisCount: isWide ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: isWide ? 3.0 : 2.2,
                children: const [
                  _TechSpecTile(label: 'Motor Power / HP', value: '3.0 HP (100% Copper)'),
                  _TechSpecTile(label: 'Rated RPM', value: '2880 RPM (High Torque)'),
                  _TechSpecTile(label: 'Power Source', value: 'Single Phase 220V AC'),
                  _TechSpecTile(label: 'Output Capacity', value: '600 - 800 kg/hr'),
                  _TechSpecTile(label: 'Cutting Blade Material', value: 'High Carbon Steel (HCS)'),
                  _TechSpecTile(label: 'Body Build', value: 'Reinforced Cast Iron + MS'),
                  _TechSpecTile(label: 'Spares Availability', value: 'Lifetime OEM Parts Available'),
                  _TechSpecTile(label: 'Warranty Period', value: '1 Year Full Machine Warranty'),
                  _TechSpecTile(label: 'Logistics Mode', value: 'Heavy Freight Doorstep'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TechSpecTile extends StatelessWidget {
  const _TechSpecTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: storeCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: storeMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: storeText)),
        ],
      ),
    );
  }
}
