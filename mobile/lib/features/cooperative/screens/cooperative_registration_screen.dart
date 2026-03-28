import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/cooperative/models/cooperative_models.dart';
import 'package:dairy_ai/features/cooperative/providers/cooperative_provider.dart';

class CooperativeRegistrationScreen extends ConsumerStatefulWidget {
  const CooperativeRegistrationScreen({super.key});

  @override
  ConsumerState<CooperativeRegistrationScreen> createState() =>
      _CooperativeRegistrationScreenState();
}

class _CooperativeRegistrationScreenState
    extends ConsumerState<CooperativeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _regNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();

  String _selectedType = 'milk_collection';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regNumberCtrl.dispose();
    _addressCtrl.dispose();
    _districtCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'registration_number': _regNumberCtrl.text.trim(),
      'cooperative_type': _selectedType,
      'address':
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'district':
          _districtCtrl.text.trim().isEmpty ? null : _districtCtrl.text.trim(),
      'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      'pincode':
          _pincodeCtrl.text.trim().isEmpty ? null : _pincodeCtrl.text.trim(),
    };

    await ref.read(cooperativeActionProvider.notifier).register(data);
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(cooperativeActionProvider);

    ref.listen<CooperativeActionState>(cooperativeActionProvider, (_, state) {
      if (state.isSuccess) {
        context.showSnackBar('Registration successful!');
        context.go('/coop-dashboard');
      } else if (state.errorMessage != null) {
        context.showSnackBar(state.errorMessage!, isError: true);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Cooperative Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Register Your Cooperative',
                style: context.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in your cooperative details to get started.',
                style: context.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Cooperative Name *'),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Registration Number
              TextFormField(
                controller: _regNumberCtrl,
                decoration:
                    const InputDecoration(labelText: 'Registration Number *'),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Cooperative Type
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration:
                    const InputDecoration(labelText: 'Cooperative Type *'),
                items: CooperativeTypes.options.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedType = v);
                },
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
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length != 6) {
                    return 'Pincode must be 6 digits';
                  }
                  return null;
                },
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
