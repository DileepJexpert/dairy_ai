import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/payments/providers/payment_provider.dart';

class LoanApplyScreen extends ConsumerStatefulWidget {
  final String farmerId;

  const LoanApplyScreen({super.key, required this.farmerId});

  @override
  ConsumerState<LoanApplyScreen> createState() => _LoanApplyScreenState();
}

class _LoanApplyScreenState extends ConsumerState<LoanApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _tenureController = TextEditingController();
  final _interestController = TextEditingController();

  String _loanType = 'cattle_purchase';

  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

  static const _loanTypes = <String, _LoanTypeInfo>{
    'cattle_purchase': _LoanTypeInfo('Cattle Purchase', Icons.pets),
    'feed_advance': _LoanTypeInfo('Feed Advance', Icons.grass),
    'equipment': _LoanTypeInfo('Equipment', Icons.build),
    'emergency': _LoanTypeInfo('Emergency', Icons.warning_amber),
    'dairy_infra': _LoanTypeInfo('Dairy Infrastructure', Icons.factory),
  };

  @override
  void dispose() {
    _principalController.dispose();
    _tenureController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(paymentActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Loan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -- Loan type dropdown --
            DropdownButtonFormField<String>(
              value: _loanType,
              decoration: InputDecoration(
                labelText: 'Loan Type *',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_loanTypes[_loanType]?.icon ?? Icons.money),
              ),
              items: _loanTypes.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(entry.value.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(entry.value.label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _loanType = value);
              },
              validator: (value) =>
                  value == null ? 'Please select a loan type' : null,
            ),

            const SizedBox(height: 16),

            // -- Principal amount --
            TextFormField(
              controller: _principalController,
              decoration: const InputDecoration(
                labelText: 'Principal Amount (INR) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the principal amount';
                }
                final parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid positive amount';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // -- Tenure months --
            TextFormField(
              controller: _tenureController,
              decoration: const InputDecoration(
                labelText: 'Tenure (months) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter tenure in months';
                }
                final parsed = int.tryParse(value);
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid number of months';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // -- Interest rate (optional) --
            TextFormField(
              controller: _interestController,
              decoration: const InputDecoration(
                labelText: 'Interest Rate % (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.percent),
                hintText: 'Leave blank for default rate',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),

            const SizedBox(height: 24),

            // -- Error message --
            if (actionState.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  actionState.error!,
                  style: TextStyle(color: context.colorScheme.error),
                ),
              ),

            // -- Submit --
            FilledButton.icon(
              onPressed: actionState.isSubmitting ? null : _submit,
              icon: actionState.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(
                  actionState.isSubmitting ? 'Submitting...' : 'Apply for Loan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final principal = double.parse(_principalController.text.trim());
    final tenure = int.parse(_tenureController.text.trim());

    final data = <String, dynamic>{
      'farmer_id': widget.farmerId,
      'loan_type': _loanType,
      'principal_amount': principal,
      'tenure_months': tenure,
    };

    if (_interestController.text.trim().isNotEmpty) {
      data['interest_rate_pct'] =
          double.parse(_interestController.text.trim());
    }

    final success =
        await ref.read(paymentActionProvider.notifier).applyLoan(data);

    if (success && mounted) {
      final resultData = ref.read(paymentActionProvider).resultData;
      final emiAmount = (resultData?['emi_amount'] as num?)?.toDouble();

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Loan Application Submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 48),
              const SizedBox(height: 16),
              const Text('Your loan application has been submitted.'),
              if (emiAmount != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8F00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFFF8F00).withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Estimated Monthly EMI',
                        style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: const Color(0xFFFF8F00),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currencyFormat.format(emiAmount),
                        style:
                            Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF8F00),
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Helper for loan type metadata
// ---------------------------------------------------------------------------
class _LoanTypeInfo {
  final String label;
  final IconData icon;

  const _LoanTypeInfo(this.label, this.icon);
}
