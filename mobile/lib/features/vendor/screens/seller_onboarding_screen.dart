import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../marketplace/models/marketplace_models.dart';
import '../providers/seller_portal_provider.dart';

class SellerOnboardingScreen extends ConsumerStatefulWidget {
  const SellerOnboardingScreen({super.key});

  @override
  ConsumerState<SellerOnboardingScreen> createState() => _SellerOnboardingScreenState();
}

class _SellerOnboardingScreenState extends ConsumerState<SellerOnboardingScreen> {
  int _currentStep = 0;
  final _businessNameCtrl = TextEditingController(text: 'Panchamrit Dairy Farmer Producer Co.');
  final _tradeNameCtrl = TextEditingController(text: 'Panchamrit Organics');
  final _gstinCtrl = TextEditingController(text: '24AAPCD1234E1Z9');
  final _fssaiCtrl = TextEditingController(text: '10725001000987');
  final _emailCtrl = TextEditingController(text: 'contact@panchamritdairy.in');
  final _phoneCtrl = TextEditingController(text: '+91 98250 88990');
  final _cityCtrl = TextEditingController(text: 'Mehsana');
  final _bankAccCtrl = TextEditingController(text: '50200012345678');
  final _ifscCtrl = TextEditingController(text: 'HDFC0001234');
  final _upiCtrl = TextEditingController(text: 'panchamrit@hdfcbank');
  bool _uploadedGst = true;
  bool _uploadedFssai = true;

  void _submitApplication() {
    final newSeller = SellerAccount(
      id: 'seller-${DateTime.now().millisecondsSinceEpoch}',
      businessName: _businessNameCtrl.text.trim(),
      tradeName: _tradeNameCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim(),
      fssaiLicense: _fssaiCtrl.text.trim(),
      contactEmail: _emailCtrl.text.trim(),
      contactPhone: _phoneCtrl.text.trim(),
      warehouseCity: _cityCtrl.text.trim(),
      warehouseState: 'Gujarat',
      bankAccountNumber: _bankAccCtrl.text.trim(),
      ifscCode: _ifscCtrl.text.trim(),
      upiId: _upiCtrl.text.trim(),
      status: SellerStatus.pendingApproval,
      createdAt: DateTime.now(),
    );

    ref.read(sellerPortalProvider.notifier).registerNewSeller(newSeller);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: storeGreen, size: 28),
            SizedBox(width: 10),
            Text('Application Submitted!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thank you, ${_businessNameCtrl.text.trim()}! Your KYC documents have been submitted to Milterra Admin moderation.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Status: PENDING_APPROVAL\nApproval Window: 24 - 48 Hours',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeAmberDark),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: storeGreen),
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/seller/dashboard');
            },
            child: const Text('Go to Seller Dashboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        backgroundColor: storeDarkGreenNav,
        foregroundColor: Colors.white,
        title: const Text('Milterra Seller Onboarding & KYC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 3) {
                  setState(() => _currentStep++);
                } else {
                  _submitApplication();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              steps: [
                Step(
                  title: const Text('Business Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 0,
                  content: Column(
                    children: [
                      TextField(controller: _businessNameCtrl, decoration: const InputDecoration(labelText: 'Registered Entity Name', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _tradeNameCtrl, decoration: const InputDecoration(labelText: 'Brand / Trade Name', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Primary Warehouse City', border: OutlineInputBorder())),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Statutory Compliance (GST & FSSAI)', style: TextStyle(fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 1,
                  content: Column(
                    children: [
                      TextField(controller: _gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN Number (15 Digits)', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _fssaiCtrl, decoration: const InputDecoration(labelText: 'FSSAI License Number (14 Digits)', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _uploadedGst,
                        title: const Text('GST Registration Certificate Attached (PDF/JPG)', style: TextStyle(fontSize: 13)),
                        onChanged: (v) => setState(() => _uploadedGst = v ?? true),
                      ),
                      CheckboxListTile(
                        value: _uploadedFssai,
                        title: const Text('FSSAI Food/Feed Safety License Attached (PDF/JPG)', style: TextStyle(fontSize: 13)),
                        onChanged: (v) => setState(() => _uploadedFssai = v ?? true),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Settlement Bank & UPI', style: TextStyle(fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 2,
                  content: Column(
                    children: [
                      TextField(controller: _bankAccCtrl, decoration: const InputDecoration(labelText: 'Bank Account Number', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _ifscCtrl, decoration: const InputDecoration(labelText: 'IFSC Code', border: OutlineInputBorder())),
                      const SizedBox(height: 12),
                      TextField(controller: _upiCtrl, decoration: const InputDecoration(labelText: 'Settlement UPI VPA ID', border: OutlineInputBorder())),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Review & Agree to Platform Terms', style: TextStyle(fontWeight: FontWeight.bold)),
                  isActive: _currentStep >= 3,
                  content: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: storeSage.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Milterra Marketplace Service Level Agreement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: storeGreen)),
                        SizedBox(height: 6),
                        Text(
                          '• Standard commission: 7.5% - 8.0% on realized sales.\n• 24-hour dispatch commitment for Fulfilled-by-Seller orders.\n• 100% genuine lab-tested quality guarantee with zero tolerance for adulteration.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
