import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../admin/providers/admin_marketplace_provider.dart';
import '../../vendor/providers/seller_portal_provider.dart';

class SellerLoginScreen extends ConsumerStatefulWidget {
  const SellerLoginScreen({super.key});

  @override
  ConsumerState<SellerLoginScreen> createState() => _SellerLoginScreenState();
}

class _SellerLoginScreenState extends ConsumerState<SellerLoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+91 98765 43210');
  String? _selectedSellerId = 'seller-milterra-direct';
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final sellers = ref.watch(adminMarketplaceProvider).sellers;

    return Scaffold(
      backgroundColor: storeCream,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: storeWhite,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: storeAmber,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storefront, color: storeGreen, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MILTERRA SELLER CENTRAL',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: storeGreen,
                              ),
                            ),
                            Text(
                              'Multi-Tenant Partner Portal',
                              style: TextStyle(fontSize: 12, color: storeMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    const Text(
                      'Seller Sign In',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xff0f1111)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage your product offers, pricing, fulfillment, and daily settlements.',
                      style: TextStyle(fontSize: 13, color: storeMuted),
                    ),
                    const SizedBox(height: 20),

                    // Fast Demo Switcher between approved sellers
                    const Text('Select Verified Seller Account', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedSellerId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: sellers.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(
                            '${s.businessName} (${s.status.name.toUpperCase()})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedSellerId = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    const Text('Registered Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                await Future.delayed(const Duration(milliseconds: 500));
                                if (!mounted) return;
                                final match = sellers.firstWhere((s) => s.id == _selectedSellerId);
                                ref.read(sellerPortalProvider.notifier).loginAsSeller(match);
                                setState(() => _busy = false);
                                if (mounted) {
                                  context.go('/seller/dashboard');
                                }
                              },
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Sign In to Seller Dashboard', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Onboarding CTA Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: storeSage.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: storeGreen.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'New to Milterra?',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: storeGreen),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Register as a verified dairy producer or nutrition supplier.',
                            style: TextStyle(fontSize: 12, color: storeMuted),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: storeGreen),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              icon: const Icon(Icons.assignment_ind_outlined, size: 16, color: storeGreen),
                              label: const Text('Start Seller Registration →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                              onPressed: () => context.push('/seller/onboarding'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
