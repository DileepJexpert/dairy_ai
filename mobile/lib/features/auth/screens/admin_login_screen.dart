import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../../marketplace/widgets/store_design.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _emailCtrl = TextEditingController(text: 'admin@milterra.com');
  final _passwordCtrl = TextEditingController(text: 'milterra#admin2026');
  String _selectedRole = 'SUPER_ADMIN';
  bool _busy = false;

  final _rolePresets = [
    {'role': 'SUPER_ADMIN', 'label': 'Super Admin (Full Access)', 'desc': 'All catalog, KYC, pricing, orders, and audit logs'},
    {'role': 'CATALOG_ADMIN', 'label': 'Catalog & Nutrition Admin', 'desc': 'Product creation, stage lifecycle, imagery'},
    {'role': 'DEAL_ADMIN', 'label': 'Deals & Pricing Admin', 'desc': 'Price revisions, promotions, lightning deals'},
    {'role': 'ORDER_ADMIN', 'label': 'Order & Fulfillment Operations', 'desc': 'Shipments, customer reviews, dispatch'},
  ];

  Future<void> _handleLogin() async {
    final username = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: storeError,
          content: Text('Please enter admin credentials.'),
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
        if (role == 'admin' || role == 'super_admin') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: storeGreen,
              content: Text('Welcome! Authenticated as ${currentUser?.role}.'),
            ),
          );
          context.go('/admin/ecommerce');
          return;
        } else {
          await ref.read(authProvider.notifier).logout();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: storeError,
              content: Text('Access Denied: Account lacks administrative privileges.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: storeError,
            content: Text('Authentication failed. Invalid admin credentials.'),
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
      backgroundColor: const Color(0xff0d1b15),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: storeWhite,
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Logo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: storeGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MILTERRA',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: storeGreen,
                              ),
                            ),
                            Text(
                              'Enterprise Admin Control Panel',
                              style: TextStyle(fontSize: 12, color: storeMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    const Text(
                      'Admin Authentication',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xff0f1111)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage platform catalog, multi-seller offers, deals, and audit trails.',
                      style: TextStyle(fontSize: 13, color: storeMuted),
                    ),
                    const SizedBox(height: 20),

                    // Role Selector Dropdown
                    const Text('Select Admin Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRole,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _rolePresets.map((r) {
                        return DropdownMenuItem<String>(
                          value: r['role'],
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(r['label']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    const Text('Admin Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
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

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: storeGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _busy ? null : _handleLogin,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Access Admin Control Panel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Secondary Nav Links
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => context.go('/seller/login'),
                            child: const Text('Seller Portal →', style: TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text('•', style: TextStyle(color: storeBorder)),
                          TextButton(
                            onPressed: () => context.go('/shop'),
                            child: const Text('Customer Storefront →', style: TextStyle(fontSize: 12, color: storeMuted)),
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
