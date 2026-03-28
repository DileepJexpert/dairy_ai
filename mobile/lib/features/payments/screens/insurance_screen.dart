import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/payments/models/payment_models.dart';
import 'package:dairy_ai/features/payments/providers/payment_provider.dart';

class InsuranceScreen extends ConsumerStatefulWidget {
  final String farmerId;

  const InsuranceScreen({super.key, required this.farmerId});

  @override
  ConsumerState<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends ConsumerState<InsuranceScreen> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

  @override
  Widget build(BuildContext context) {
    final insuranceAsync = ref.watch(insuranceProvider(widget.farmerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Policy',
            onPressed: () => _showNewPolicyForm(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(insuranceProvider(widget.farmerId));
        },
        child: insuranceAsync.when(
          data: (policies) {
            if (policies.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('No insurance policies yet'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showNewPolicyForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New Policy'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: policies.length,
              itemBuilder: (context, index) {
                final policy = policies[index];
                return _InsuranceCard(
                  policy: policy,
                  currencyFormat: _currencyFormat,
                  onFileClaim: policy.status?.toLowerCase() == 'active'
                      ? () => _showClaimDialog(context, policy)
                      : null,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // New Policy Form — bottom sheet
  // ---------------------------------------------------------------------------
  Future<void> _showNewPolicyForm(BuildContext context) async {
    final cattleIdController = TextEditingController();
    final insurerController = TextEditingController();
    final sumInsuredController = TextEditingController();
    final premiumController = TextEditingController();
    final subsidyPctController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 365));
    final dateFormat = DateFormat('yyyy-MM-dd');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                24,
                16,
                MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'New Insurance Policy',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: cattleIdController,
                        decoration: const InputDecoration(
                          labelText: 'Cattle ID *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pets),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: insurerController,
                        decoration: const InputDecoration(
                          labelText: 'Insurer Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.business),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: sumInsuredController,
                        decoration: const InputDecoration(
                          labelText: 'Sum Insured (INR) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: premiumController,
                        decoration: const InputDecoration(
                          labelText: 'Premium Amount (INR) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (double.tryParse(v) == null) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: subsidyPctController,
                        decoration: const InputDecoration(
                          labelText: 'Govt Subsidy % (optional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.percent),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Start date
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setSheetState(() => startDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(dateFormat.format(startDate)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // End date
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setSheetState(() => endDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month),
                          ),
                          child: Text(dateFormat.format(endDate)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      FilledButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          final data = <String, dynamic>{
                            'farmer_id': widget.farmerId,
                            'cattle_id': cattleIdController.text.trim(),
                            'insurer_name': insurerController.text.trim(),
                            'sum_insured':
                                double.parse(sumInsuredController.text.trim()),
                            'premium_amount':
                                double.parse(premiumController.text.trim()),
                            'start_date': dateFormat.format(startDate),
                            'end_date': dateFormat.format(endDate),
                          };

                          if (subsidyPctController.text.trim().isNotEmpty) {
                            data['govt_subsidy_pct'] = double.parse(
                                subsidyPctController.text.trim());
                          }

                          final success = await ref
                              .read(paymentActionProvider.notifier)
                              .createInsurance(data);

                          if (success && ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ref.invalidate(
                                insuranceProvider(widget.farmerId));
                            if (context.mounted) {
                              context.showSnackBar(
                                  'Insurance policy created!');
                            }
                          }
                        },
                        icon: const Icon(Icons.shield),
                        label: const Text('Create Policy'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // File Claim Dialog
  // ---------------------------------------------------------------------------
  Future<void> _showClaimDialog(
      BuildContext context, CattleInsurance policy) async {
    final claimAmountController = TextEditingController();
    final claimReasonController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File Insurance Claim'),
        content: Form(
          key: dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Policy: ${policy.policyNumber ?? policy.id}',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: claimAmountController,
                decoration: const InputDecoration(
                  labelText: 'Claim Amount (INR) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final parsed = double.tryParse(v);
                  if (parsed == null || parsed <= 0) return 'Invalid amount';
                  if (parsed > policy.sumInsured) {
                    return 'Cannot exceed sum insured (${_currencyFormat.format(policy.sumInsured)})';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: claimReasonController,
                decoration: const InputDecoration(
                  labelText: 'Claim Reason *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!dialogFormKey.currentState!.validate()) return;

              final data = {
                'claim_amount':
                    double.parse(claimAmountController.text.trim()),
                'claim_reason': claimReasonController.text.trim(),
              };

              final success = await ref
                  .read(paymentActionProvider.notifier)
                  .fileClaim(policy.id, data);

              if (ctx.mounted) Navigator.of(ctx).pop();

              if (success) {
                ref.invalidate(insuranceProvider(widget.farmerId));
                if (context.mounted) {
                  context.showSnackBar('Claim filed successfully!');
                }
              } else {
                if (context.mounted) {
                  final error = ref.read(paymentActionProvider).error;
                  context.showSnackBar(error ?? 'Failed to file claim',
                      isError: true);
                }
              }
            },
            child: const Text('Submit Claim'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Insurance Card
// ---------------------------------------------------------------------------
class _InsuranceCard extends StatelessWidget {
  final CattleInsurance policy;
  final NumberFormat currencyFormat;
  final VoidCallback? onFileClaim;

  const _InsuranceCard({
    required this.policy,
    required this.currencyFormat,
    this.onFileClaim,
  });

  Color get _cardColor {
    switch (policy.status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.grey;
      case 'claim_processing':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _cardColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      color: color.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    policy.policyNumber ?? 'Policy #${policy.id}',
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: policy.status ?? 'unknown', color: color),
              ],
            ),
            if (policy.insurerName != null) ...[
              const SizedBox(height: 4),
              Text(
                policy.insurerName!,
                style: context.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoColumn(
                    label: 'Sum Insured',
                    value: currencyFormat.format(policy.sumInsured),
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    label: 'Premium',
                    value: currencyFormat.format(policy.premiumAmount),
                  ),
                ),
                Expanded(
                  child: _InfoColumn(
                    label: 'Your Share',
                    value: currencyFormat.format(policy.farmerPremium),
                  ),
                ),
              ],
            ),
            if (policy.startDate != null || policy.endDate != null) ...[
              const SizedBox(height: 8),
              Text(
                '${policy.startDate ?? '?'}  to  ${policy.endDate ?? '?'}',
                style: context.textTheme.bodySmall
                    ?.copyWith(color: Colors.grey.shade500),
              ),
            ],
            if (policy.claimAmount != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Claim: ${currencyFormat.format(policy.claimAmount)} - ${policy.claimReason ?? ''}',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: Colors.red.shade800),
                ),
              ),
            ],
            if (onFileClaim != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onFileClaim,
                  icon: const Icon(Icons.description, size: 18),
                  label: const Text('File Claim'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info Column helper
// ---------------------------------------------------------------------------
class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;

  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.textTheme.labelSmall
                ?.copyWith(color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: context.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status Badge
// ---------------------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: context.textTheme.labelSmall?.copyWith(
          color: color.shade800,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

extension on Color {
  Color get shade800 {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0))
        .toColor();
  }
}
