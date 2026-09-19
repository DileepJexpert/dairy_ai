import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vendor/models/vendor_models.dart';
import 'package:dairy_ai/features/vendor/providers/vendor_provider.dart';

class VendorRegistrationScreen extends ConsumerStatefulWidget {
  const VendorRegistrationScreen({super.key});

  @override
  ConsumerState<VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState
    extends ConsumerState<VendorRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameCtrl = TextEditingController();
  final _gstNumberCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ifscCodeCtrl = TextEditingController();
  final _accountHolderNameCtrl = TextEditingController();
  final _upiIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _productsCtrl = TextEditingController();

  String _selectedVendorType = 'milk_buyer';

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _gstNumberCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ifscCodeCtrl.dispose();
    _accountHolderNameCtrl.dispose();
    _upiIdCtrl.dispose();
    _addressCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _productsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final products = _productsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final data = <String, dynamic>{
      'business_name': _businessNameCtrl.text.trim(),
      'vendor_type': _selectedVendorType,
      'gst_number': _gstNumberCtrl.text.trim().isEmpty
          ? null
          : _gstNumberCtrl.text.trim(),
      'license_number': _licenseNumberCtrl.text.trim().isEmpty
          ? null
          : _licenseNumberCtrl.text.trim(),
      'bank_name': _bankNameCtrl.text.trim().isEmpty
          ? null
          : _bankNameCtrl.text.trim(),
      'account_number': _accountNumberCtrl.text.trim().isEmpty
          ? null
          : _accountNumberCtrl.text.trim(),
      'ifsc_code': _ifscCodeCtrl.text.trim().isEmpty
          ? null
          : _ifscCodeCtrl.text.trim(),
      'account_holder_name': _accountHolderNameCtrl.text.trim().isEmpty
          ? null
          : _accountHolderNameCtrl.text.trim(),
      'upi_id': _upiIdCtrl.text.trim().isEmpty
          ? null
          : _upiIdCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      'district': _districtCtrl.text.trim().isEmpty
          ? null
          : _districtCtrl.text.trim(),
      'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      'pincode':
          _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
      'products_services': products,
    };

    await ref.read(vendorActionProvider.notifier).register(data);
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(vendorActionProvider);

    ref.listen<VendorActionState>(vendorActionProvider, (_, state) {
      if (state.isSuccess) {
        context.showSnackBar('Registration successful!');
        context.go('/vendor-dashboard');
      } else if (state.errorMessage != null) {
        context.showSnackBar(state.errorMessage!, isError: true);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register as a Vendor',
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in your business details to get started.',
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),

              // Business Name
              TextFormField(
                controller: _businessNameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Business Name *'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Vendor Type
              DropdownButtonFormField<String>(
                value: _selectedVendorType,
                decoration: const InputDecoration(labelText: 'Vendor Type *'),
                items: VendorTypes.options.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedVendorType = v);
                },
              ),
              const SizedBox(height: 16),

              // GST Number
              TextFormField(
                controller: _gstNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'GST Number',
                  hintText: 'Optional',
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // FSSAI License Number
              TextFormField(
                controller: _licenseNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'FSSAI License Number',
                  hintText: 'Optional for dairy/food vendors',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              Text('Bank & Settlement Account',
                  style: context.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              TextFormField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  hintText: 'e.g. State Bank of India, HDFC Bank',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _accountNumberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank Account Number',
                  hintText: 'For automated order settlements',
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _ifscCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'IFSC Code',
                  hintText: 'e.g. SBIN0001234',
                ),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _accountHolderNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Account Holder / Beneficiary Name',
                  hintText: 'Name as registered with bank',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _upiIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'UPI ID (optional)',
                  hintText: 'e.g. business@upi',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 24),

              // Address
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address'),
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // District + State row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _districtCtrl,
                      decoration:
                          const InputDecoration(labelText: 'District'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateCtrl,
                      decoration: const InputDecoration(labelText: 'State'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pincode
              TextFormField(
                controller: _pincodeCtrl,
                decoration: const InputDecoration(labelText: 'Pincode'),
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length != 6) {
                    return 'Pincode must be 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Products / Services
              TextFormField(
                controller: _productsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Products / Services',
                  hintText: 'Comma-separated, e.g. Milk, Ghee, Paneer',
                ),
                textInputAction: TextInputAction.done,
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Submit
              ElevatedButton(
                onPressed: actionState.isLoading ? null : _submit,
                child: actionState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
