import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/payments/models/payment_models.dart';
import 'package:dairy_ai/features/payments/providers/payment_provider.dart';

class SubsidyScreen extends ConsumerStatefulWidget {
  final String farmerId;

  const SubsidyScreen({super.key, required this.farmerId});

  @override
  ConsumerState<SubsidyScreen> createState() => _SubsidyScreenState();
}

class _SubsidyScreenState extends ConsumerState<SubsidyScreen> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

  @override
  Widget build(BuildContext context) {
    final subsidiesAsync = ref.watch(subsidiesProvider(widget.farmerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subsidies'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showApplyForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(subsidiesProvider(widget.farmerId));
        },
        child: subsidiesAsync.when(
          data: (subsidies) {
            if (subsidies.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volunteer_activism,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('No subsidy applications yet'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _showApplyForm(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Apply for Subsidy'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: subsidies.length + 1, // +1 for FAB spacer
              itemBuilder: (context, index) {
                if (index == subsidies.length) {
                  return const SizedBox(height: 80);
                }
                return _SubsidyCard(
                  subsidy: subsidies[index],
                  currencyFormat: _currencyFormat,
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
  // Apply for Subsidy — bottom sheet
  // ---------------------------------------------------------------------------
  Future<void> _showApplyForm(BuildContext context) async {
    String scheme = 'nabard_dairy';
    final schemeNameController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    const schemes = <String, String>{
      'nabard_dairy': 'NABARD Dairy',
      'ndp_ii': 'NDP-II',
      'didf': 'DIDF',
      'state_scheme': 'State Scheme',
    };

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
                        'Apply for Subsidy',
                        style: Theme.of(ctx)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),

                      // Scheme dropdown
                      DropdownButtonFormField<String>(
                        value: scheme,
                        decoration: const InputDecoration(
                          labelText: 'Scheme *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                        items: schemes.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => scheme = value);
                          }
                        },
                        validator: (v) =>
                            v == null ? 'Please select a scheme' : null,
                      ),
                      const SizedBox(height: 12),

                      // Scheme name
                      TextFormField(
                        controller: schemeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Scheme Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.label),
                          hintText: 'e.g., NABARD Dairy Entrepreneurship',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Applied amount
                      TextFormField(
                        controller: amountController,
                        decoration: const InputDecoration(
                          labelText: 'Applied Amount (INR) *',
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
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      FilledButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          final data = <String, dynamic>{
                            'farmer_id': widget.farmerId,
                            'scheme': scheme,
                            'scheme_name': schemeNameController.text.trim(),
                            'applied_amount':
                                double.parse(amountController.text.trim()),
                          };

                          final success = await ref
                              .read(paymentActionProvider.notifier)
                              .applySubsidy(data);

                          if (success && ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ref.invalidate(
                                subsidiesProvider(widget.farmerId));
                            if (context.mounted) {
                              context.showSnackBar(
                                  'Subsidy application submitted!');
                            }
                          } else if (ctx.mounted) {
                            final error =
                                ref.read(paymentActionProvider).error;
                            if (context.mounted) {
                              context.showSnackBar(
                                  error ?? 'Failed to apply',
                                  isError: true);
                            }
                          }
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Application'),
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
}

// ---------------------------------------------------------------------------
// Subsidy Card
// ---------------------------------------------------------------------------
class _SubsidyCard extends StatelessWidget {
  final SubsidyApplication subsidy;
  final NumberFormat currencyFormat;

  const _SubsidyCard({
    required this.subsidy,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    subsidy.schemeName,
                    style: context.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _SubsidyStatusBadge(status: subsidy.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subsidy.schemeLabel,
              style: context.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AmountColumn(
                    label: 'Applied',
                    amount: subsidy.appliedAmount,
                    currencyFormat: currencyFormat,
                    color: Colors.blue.shade700,
                  ),
                ),
                if (subsidy.approvedAmount != null)
                  Expanded(
                    child: _AmountColumn(
                      label: 'Approved',
                      amount: subsidy.approvedAmount!,
                      currencyFormat: currencyFormat,
                      color: Colors.green.shade700,
                    ),
                  ),
                if (subsidy.disbursedAmount != null)
                  Expanded(
                    child: _AmountColumn(
                      label: 'Disbursed',
                      amount: subsidy.disbursedAmount!,
                      currencyFormat: currencyFormat,
                      color: Colors.purple.shade700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Amount Column helper
// ---------------------------------------------------------------------------
class _AmountColumn extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat currencyFormat;
  final Color color;

  const _AmountColumn({
    required this.label,
    required this.amount,
    required this.currencyFormat,
    required this.color,
  });

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
            currencyFormat.format(amount),
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Subsidy Status Badge
// ---------------------------------------------------------------------------
class _SubsidyStatusBadge extends StatelessWidget {
  final String status;

  const _SubsidyStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'applied':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'approved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'rejected':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'disbursed':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: context.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
