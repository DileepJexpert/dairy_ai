import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vendor/models/vendor_models.dart';
import 'package:dairy_ai/features/vendor/providers/vendor_provider.dart';

class VendorProfileScreen extends ConsumerStatefulWidget {
  const VendorProfileScreen({super.key});

  @override
  ConsumerState<VendorProfileScreen> createState() =>
      _VendorProfileScreenState();
}

class _VendorProfileScreenState extends ConsumerState<VendorProfileScreen> {
  bool _isEditing = false;

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

  void _populateFields(VendorProfile profile) {
    _businessNameCtrl.text = profile.businessName;
    _gstNumberCtrl.text = profile.gstNumber ?? '';
    _licenseNumberCtrl.text = profile.licenseNumber ?? '';
    _bankNameCtrl.text = profile.bankName ?? '';
    _accountNumberCtrl.text = profile.accountNumber ?? '';
    _ifscCodeCtrl.text = profile.ifscCode ?? '';
    _accountHolderNameCtrl.text = profile.accountHolderName ?? '';
    _upiIdCtrl.text = profile.upiId ?? '';
    _addressCtrl.text = profile.address ?? '';
    _districtCtrl.text = profile.district ?? '';
    _stateCtrl.text = profile.state ?? '';
    _pincodeCtrl.text = profile.pincode ?? '';
    _selectedVendorType = profile.vendorType;
    _productsCtrl.text = profile.productsServices.join(', ');
  }

  Future<void> _saveProfile() async {
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
      'address':
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'district':
          _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
      'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      'pincode':
          _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
      'products_services': products,
    };

    await ref.read(vendorActionProvider.notifier).updateProfile(data);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(vendorProfileProvider);
    final actionState = ref.watch(vendorActionProvider);

    ref.listen<VendorActionState>(vendorActionProvider, (_, state) {
      if (state.isSuccess) {
        context.showSnackBar('Profile updated successfully!');
        setState(() => _isEditing = false);
        ref.invalidate(vendorProfileProvider);
      } else if (state.errorMessage != null) {
        context.showSnackBar(state.errorMessage!, isError: true);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Profile'),
        actions: [
          if (profileAsync.hasValue && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _populateFields(profileAsync.value!);
                setState(() => _isEditing = true);
              },
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isEditing = false),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: context.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  error.toString(),
                  style: context.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(vendorProfileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) =>
            _isEditing ? _buildEditForm(actionState) : _buildProfileView(profile),
      ),
    );
  }

  Widget _buildProfileView(VendorProfile profile) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar / business header
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: DairyTheme.primaryGreen,
            child: Text(
              profile.businessName.isNotEmpty
                  ? profile.businessName[0].toUpperCase()
                  : 'V',
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            profile.businessName,
            style: context.textTheme.headlineMedium,
          ),
        ),
        Center(
          child: Text(
            VendorTypes.label(profile.vendorType),
            style: context.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),

        // Rating card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat(
                  label: 'Rating',
                  value: profile.rating.toStringAsFixed(1),
                  icon: Icons.star,
                ),
                _ProfileStat(
                  label: 'Orders',
                  value: profile.totalOrders.toString(),
                  icon: Icons.receipt_long,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Details
        _DetailTile(label: 'Phone', value: profile.phone ?? 'Not set'),
        _DetailTile(label: 'GST Number', value: profile.gstNumber ?? 'Not set'),
        _DetailTile(
            label: 'FSSAI License', value: profile.licenseNumber ?? 'Not set'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance,
                        size: 20, color: DairyTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Text('Bank & Settlement Account',
                        style: context.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 24),
                _DetailTile(
                    label: 'Bank Name', value: profile.bankName ?? 'Not set'),
                _DetailTile(
                  label: 'Account Number',
                  value: profile.accountNumber != null &&
                          profile.accountNumber!.isNotEmpty
                      ? '•••• •••• •••• ${profile.accountNumber!.length > 4 ? profile.accountNumber!.substring(profile.accountNumber!.length - 4) : profile.accountNumber!}'
                      : 'Not set',
                ),
                _DetailTile(
                    label: 'IFSC Code', value: profile.ifscCode ?? 'Not set'),
                _DetailTile(
                    label: 'Beneficiary Name',
                    value: profile.accountHolderName ?? 'Not set'),
                _DetailTile(
                    label: 'UPI ID', value: profile.upiId ?? 'Not set'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _DetailTile(label: 'Address', value: profile.address ?? 'Not set'),
        _DetailTile(
          label: 'Location',
          value: [profile.district, profile.state, profile.pincode]
              .where((e) => e != null && e.isNotEmpty)
              .join(', '),
        ),
        _DetailTile(
          label: 'Products / Services',
          value: profile.productsServices.isNotEmpty
              ? profile.productsServices.join(', ')
              : 'None',
        ),
      ],
    );
  }

  Widget _buildEditForm(VendorActionState actionState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _businessNameCtrl,
              decoration: const InputDecoration(labelText: 'Business Name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedVendorType,
              decoration: const InputDecoration(labelText: 'Vendor Type *'),
              items: VendorTypes.options.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedVendorType = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _gstNumberCtrl,
              decoration: const InputDecoration(labelText: 'GST Number'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseNumberCtrl,
              decoration:
                  const InputDecoration(labelText: 'FSSAI License Number'),
            ),
            const SizedBox(height: 24),
            Text('Bank & Settlement Details',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Bank Name (e.g. State Bank of India)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberCtrl,
              decoration:
                  const InputDecoration(labelText: 'Bank Account Number'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ifscCodeCtrl,
              decoration: const InputDecoration(
                  labelText: 'IFSC Code (e.g. SBIN0001234)'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountHolderNameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Account Holder / Beneficiary Name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _upiIdCtrl,
              decoration: const InputDecoration(
                  labelText: 'UPI ID (optional, e.g. business@upi)'),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Address'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _districtCtrl,
                    decoration: const InputDecoration(labelText: 'District'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stateCtrl,
                    decoration: const InputDecoration(labelText: 'State'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pincodeCtrl,
              decoration: const InputDecoration(labelText: 'Pincode'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v != null && v.isNotEmpty && v.length != 6) {
                  return 'Pincode must be 6 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productsCtrl,
              decoration: const InputDecoration(
                labelText: 'Products / Services',
                hintText: 'Comma-separated',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: actionState.isLoading ? null : _saveProfile,
              child: actionState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: DairyTheme.accentOrange),
        const SizedBox(height: 4),
        Text(value, style: context.textTheme.titleLarge),
        Text(label, style: context.textTheme.bodySmall),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not set' : value,
              style: context.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
