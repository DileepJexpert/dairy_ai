import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../admin/providers/admin_marketplace_provider.dart';
import '../../vendor/providers/seller_portal_provider.dart';

class SellerLoginScreen extends ConsumerStatefulWidget {
  const SellerLoginScreen({super.key});

  @override
  ConsumerState<SellerLoginScreen> createState() => _SellerLoginScreenState();
}

class _SellerLoginScreenState extends ConsumerState<SellerLoginScreen> {
  final _emailCtrl = TextEditingController(text: 'seller@milterra.com');
  final _passwordCtrl = TextEditingController(text: 'seller#milterra2026');
  bool _busy = false;

  Future<void> _handleSellerLogin() async {
    final username = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeError,
          content: Text('Please enter seller credentials.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final success = await ref.read(authProvider.notifier).loginWithPassword(
            username: username,
            password: password,
          );
      if (!mounted) return;
      if (success) {
        final currentUser = ref.read(currentUserProvider);
        final role = currentUser?.role.toLowerCase();
        if (role == 'vendor' || role == 'seller' || role == 'admin' || role == 'super_admin') {
          final sellers = ref.read(adminMarketplaceProvider).sellers;
          final match = sellers.firstWhere(
            (s) => s.id == currentUser?.id || s.contactEmail == username,
            orElse: () => sellers.first,
          );
          ref.read(sellerPortalProvider.notifier).loginAsSeller(match);
          if (mounted) {
            context.go('/seller/dashboard');
          }
          return;
        } else {
          await ref.read(authProvider.notifier).logout();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: storeError,
              content: Text('Access Denied: Account is not registered as a seller or vendor.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: storeError,
            content: Text('Authentication failed. Invalid seller credentials.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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

                    const Text('Seller Username / Business Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.business_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
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
                        onPressed: _busy ? null : _handleSellerLogin,
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
