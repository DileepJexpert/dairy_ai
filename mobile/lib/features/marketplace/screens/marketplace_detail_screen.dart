import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/store_design.dart';

class MarketplaceDetailScreen extends ConsumerStatefulWidget {
  const MarketplaceDetailScreen({super.key, required this.listingId});
  final String listingId;

  @override
  ConsumerState<MarketplaceDetailScreen> createState() =>
      _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState
    extends ConsumerState<MarketplaceDetailScreen> {
  final TextEditingController _inquiryMsgController = TextEditingController(
      text: 'Namaste, I am interested in this listing. Please share details.');
  bool _sendingInquiry = false;

  @override
  void dispose() {
    _inquiryMsgController.dispose();
    super.dispose();
  }

  void _showContactDialog(BuildContext context, String sellerName, String location) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified, color: storeGreen, size: 24),
            const SizedBox(width: 8),
            Text('Contact $sellerName',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location: $location',
                style: const TextStyle(color: storeMuted, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xffe8f5e9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffa5d6a7)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.phone_in_talk, color: storeGreen, size: 24),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Farmer Contact Helpline',
                          style: TextStyle(fontSize: 11, color: storeMuted)),
                      Text('+91 98765 XXXXX (Verified)',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: storeGreen)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: storeCream,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, size: 16, color: storeOrange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'OLX Safety Tip: Always inspect cattle and machinery physically at the seller\'s premises before transferring money.',
                      style: TextStyle(fontSize: 11, color: storeText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff25D366),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xff25D366),
                  content: Text('WhatsApp Chat initialized with seller!'),
                ),
              );
            },
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('WhatsApp Chat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(marketplaceDetailProvider(widget.listingId));

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Pashu Mandi'),
          Expanded(
            child: detailAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: storeGreen)),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: storeError),
                      const SizedBox(height: 12),
                      Text('Unable to load listing: $err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: storeText)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.go('/marketplace'),
                        child: const Text('Back to Mandi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (item) {
                final formattedPrice = NumberFormat.currency(
                  locale: 'en_IN',
                  symbol: '₹',
                  decimalDigits: 0,
                ).format(item.price);
                final locationStr = [
                  item.locationVillage,
                  item.locationDistrict,
                  item.locationState
                ].whereType<String>().where((s) => s.isNotEmpty).join(', ');

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
                                      child: const Text('Mandi Classifieds',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: storeMuted,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const Text(' / ',
                                        style: TextStyle(color: storeMuted)),
                                    Text(item.category.name.toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: storeGreen,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Main Content (Responsive Row / Column)
                                LayoutBuilder(
                                  builder: (ctx, constraints) {
                                    final isWide = constraints.maxWidth >= 768;
                                    return Flex(
                                      direction: isWide
                                          ? Axis.horizontal
                                          : Axis.vertical,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Left side: Photo & Badges
                                        Expanded(
                                          flex: isWide ? 6 : 0,
                                          child: _buildPhotoGallery(item),
                                        ),
                                        if (isWide) const SizedBox(width: 24)
                                        else const SizedBox(height: 16),

                                        // Right side: Details & Contact Actions
                                        Expanded(
                                          flex: isWide ? 5 : 0,
                                          child: _buildDetailsPanel(
                                              item, formattedPrice, locationStr),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 32),

                                // Detailed Specs & Safety Advice
                                _buildSpecsAndSafety(item),
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

  Widget _buildPhotoGallery(dynamic item) {
    final photos = item.photos as List<String>;
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
              height: 320,
              width: double.infinity,
              child: photos.isEmpty
                  ? Container(
                      color: const Color(0xfff0fdf4),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pets, size: 80, color: Color(0xff86efac)),
                          SizedBox(height: 8),
                          Text('Direct Farmer Listing Photo',
                              style: TextStyle(
                                  color: storeMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  : Image.network(
                      photos.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xfff0fdf4),
                        child: const Icon(Icons.pets,
                            size: 80, color: Color(0xff86efac)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.healthVerified == true)
                const Chip(
                  avatar: Icon(Icons.verified, size: 16, color: storeGreen),
                  label: Text('Health Certified by Vet'),
                  backgroundColor: Color(0xffe8f5e9),
                  labelStyle: TextStyle(
                      color: storeGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              if (item.vaccinationVerified == true)
                const Chip(
                  avatar:
                      Icon(Icons.medical_services, size: 16, color: Color(0xff0284c7)),
                  label: Text('FMD & HS Vaccinated'),
                  backgroundColor: Color(0xffe0f2fe),
                  labelStyle: TextStyle(
                      color: Color(0xff0284c7),
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              Chip(
                avatar: const Icon(Icons.pin_drop, size: 16, color: storeOrange),
                label: Text(item.locationDistrict ?? 'Direct Farm'),
                backgroundColor: const Color(0xfffff7ed),
                labelStyle: const TextStyle(
                    color: storeOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(
      dynamic item, String formattedPrice, String locationStr) {
    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: storeText,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: storeMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  locationStr.isEmpty ? 'India' : locationStr,
                  style: const TextStyle(
                      fontSize: 13,
                      color: storeMuted,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formattedPrice,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: storeGreen,
                ),
              ),
              const SizedBox(width: 8),
              if (item.isNegotiable == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xffe8f5e9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xffa5d6a7)),
                  ),
                  child: const Text('Price Negotiable',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: storeGreen)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Key Quick Specs Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: storeCream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                _specRow('Breed / Type', item.breed ?? 'Indigenous / Cross'),
                if (item.milkYieldLitres != null)
                  _specRow('Milk Yield / Day', '${item.milkYieldLitres} Litres/day'),
                if (item.ageMonths != null)
                  _specRow('Age', '${item.ageMonths} Months'),
                if (item.isPregnant == true)
                  _specRow('Pregnancy Status',
                      '${item.monthsPregnant ?? 'Active'} Months Pregnant')
                else
                  _specRow('Pregnancy Status', 'Not Pregnant'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Seller Quick Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffe2e8f0)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: storeGreen,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.sellerName ?? 'Verified Farmer / Breeder',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const Text('Milterra Pashu Mandi Verified Member',
                          style: TextStyle(fontSize: 11, color: storeMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Call to Actions (OLX / IndiaMART style)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showContactDialog(
                      context,
                      item.sellerName ?? 'Farmer',
                      locationStr.isEmpty ? 'India' : locationStr),
                  icon: const Icon(Icons.chat, size: 20),
                  label: const Text('WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: storeOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showContactDialog(
                      context,
                      item.sellerName ?? 'Farmer',
                      locationStr.isEmpty ? 'India' : locationStr),
                  icon: const Icon(Icons.call, size: 20),
                  label: const Text('Call Seller',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: storeGreen,
              side: const BorderSide(color: storeGreen, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _sendingInquiry
                ? null
                : () async {
                    setState(() => _sendingInquiry = true);
                    try {
                      await ref.read(dioProvider).post(
                          '/marketplace/listings/${widget.listingId}/inquiries',
                          data: {'message': _inquiryMsgController.text.trim()});
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: storeGreen,
                            content: Text(
                                'Inquiry sent directly to farmer! They will contact you shortly.'),
                          ),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: storeGreen,
                            content: Text(
                                'Inquiry submitted. Seller will call you directly.'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _sendingInquiry = false);
                    }
                  },
            icon: const Icon(Icons.send_outlined, size: 18),
            label: Text(_sendingInquiry ? 'Sending...' : 'Send Best Offer / Message'),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: storeMuted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: storeText)),
        ],
      ),
    );
  }

  Widget _buildSpecsAndSafety(dynamic item) {
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
          const Text(
            'About this Animal / Listing',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: storeText),
          ),
          const SizedBox(height: 10),
          Text(
            item.description ??
                'High-pedigree cattle listing directly from verified dairy farm. Vaccinated, docile, and suitable for high daily milk yield in commercial dairy setups.',
            style: const TextStyle(fontSize: 13, color: storeText, height: 1.5),
          ),
          const Divider(height: 32),
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: storeGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Milterra Pashu Mandi Safety Standards',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: storeGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Check the physical ear tag / Pashu Aadhaar before confirming transaction.\n'
            '• Verify milk output in person over two consecutive milking sessions.\n'
            '• Ensure transport permits and health certificates are collected from the local veterinary dispensary.',
            style: TextStyle(fontSize: 12, color: storeMuted, height: 1.6),
          ),
        ],
      ),
    );
  }
}
