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
