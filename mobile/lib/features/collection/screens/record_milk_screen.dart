import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import '../models/collection_models.dart';
import '../providers/collection_provider.dart';

/// Form to record milk collection at a center.
///
/// After successful submission the resulting [MilkCollectionRecord] is shown
/// with a grade badge, rate, and net amount breakdown.
class RecordMilkScreen extends ConsumerStatefulWidget {
  const RecordMilkScreen({super.key, required this.centerId});

  final String centerId;

  @override
  ConsumerState<RecordMilkScreen> createState() => _RecordMilkScreenState();
}

class _RecordMilkScreenState extends ConsumerState<RecordMilkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmerIdController = TextEditingController();
  final _quantityController = TextEditingController();
  final _fatController = TextEditingController();
  final _snfController = TextEditingController();
  final _tempController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'morning';
  bool _isSubmitting = false;

  /// Holds the result after successful submission.
  MilkCollectionRecord? _result;

  final _currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

  @override
  void dispose() {
    _farmerIdController.dispose();
    _quantityController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      helpText: 'Select collection date',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final data = <String, dynamic>{
        'center_id': widget.centerId,
        'farmer_id': _farmerIdController.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'shift': _selectedShift,
        'quantity_litres': double.parse(_quantityController.text.trim()),
      };
      if (_fatController.text.trim().isNotEmpty) {
        data['fat_pct'] = double.parse(_fatController.text.trim());
      }
      if (_snfController.text.trim().isNotEmpty) {
        data['snf_pct'] = double.parse(_snfController.text.trim());
      }
      if (_tempController.text.trim().isNotEmpty) {
        data['temperature_celsius'] =
            double.parse(_tempController.text.trim());
      }

      final notifier = ref.read(collectionActionProvider.notifier);
      final record = await notifier.recordMilk(data);

      if (mounted) {
        setState(() => _result = record);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _farmerIdController.clear();
    _quantityController.clear();
    _fatController.clear();
    _snfController.clear();
    _tempController.clear();
    setState(() {
      _selectedDate = DateTime.now();
      _selectedShift = 'morning';
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Milk'),
      ),
      body: _result != null
          ? _ResultView(
              record: _result!,
              currencyFormat: _currencyFormat,
              onNewEntry: _resetForm,
              onDone: () => context.pop(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Center ID (read-only)
                    TextFormField(
                      initialValue: widget.centerId,
                      decoration: const InputDecoration(
                        labelText: 'Center ID',
                        prefixIcon: Icon(Icons.store),
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Farmer ID
                    TextFormField(
                      controller: _farmerIdController,
                      decoration: const InputDecoration(
                        labelText: 'Farmer ID',
                        hintText: 'Enter farmer ID',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter farmer ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Date picker
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          dateFormat.format(_selectedDate),
                          style: context.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Shift dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedShift,
                      decoration: const InputDecoration(
                        labelText: 'Shift',
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'morning', child: Text('Morning')),
                        DropdownMenuItem(
                            value: 'evening', child: Text('Evening')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedShift = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Quantity
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity (Litres)',
                        hintText: 'e.g., 12.5',
                        prefixIcon: Icon(Icons.water_drop),
                        suffixText: 'L',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter quantity';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Please enter a valid quantity';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Fat %
                    TextFormField(
                      controller: _fatController,
                      decoration: const InputDecoration(
                        labelText: 'Fat %',
                        hintText: 'e.g., 4.5',
                        prefixIcon: Icon(Icons.science),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed < 0 || parsed > 15) {
                            return 'Enter a valid fat % (0-15)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // SNF %
                    TextFormField(
                      controller: _snfController,
                      decoration: const InputDecoration(
                        labelText: 'SNF %',
                        hintText: 'e.g., 8.5',
                        prefixIcon: Icon(Icons.science_outlined),
                        suffixText: '%',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed < 0 || parsed > 15) {
                            return 'Enter a valid SNF % (0-15)';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Temperature
                    TextFormField(
                      controller: _tempController,
                      decoration: const InputDecoration(
                        labelText: 'Temperature (\u00B0C)',
                        hintText: 'e.g., 4.0',
                        prefixIcon: Icon(Icons.thermostat),
                        suffixText: '\u00B0C',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Enter a valid temperature';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Submit Collection'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// =============================================================================
// Result view — shown after successful milk recording
// =============================================================================

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.record,
    required this.currencyFormat,
    required this.onNewEntry,
    required this.onDone,
  });

  final MilkCollectionRecord record;
  final NumberFormat currencyFormat;
  final VoidCallback onNewEntry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rejection banner
          if (record.isRejected) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: DairyTheme.errorRed.withOpacity(0.08),
                border: Border.all(color: DairyTheme.errorRed, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cancel, color: DairyTheme.errorRed, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'REJECTED',
                    style: context.textTheme.headlineMedium?.copyWith(
                      color: DairyTheme.errorRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (record.rejectionReason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      record.rejectionReason!,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: DairyTheme.errorRed,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Success header (non-rejection)
          if (!record.isRejected) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle,
                        color: DairyTheme.primaryGreen, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'Collection Recorded',
                      style: context.textTheme.titleLarge?.copyWith(
                        color: DairyTheme.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Grade badge
          Center(child: _GradeBadge(grade: record.milkGrade)),
          const SizedBox(height: 16),

          // Details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(
                      label: 'Quantity', value: '${record.quantityLitres} L'),
                  if (record.fatPct != null)
                    _DetailRow(
                        label: 'Fat %', value: '${record.fatPct}%'),
                  if (record.snfPct != null)
                    _DetailRow(
                        label: 'SNF %', value: '${record.snfPct}%'),
                  if (record.temperatureCelsius != null)
                    _DetailRow(
                        label: 'Temperature',
                        value: '${record.temperatureCelsius}\u00B0C'),
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Rate',
                    value: '${currencyFormat.format(record.ratePerLitre)}/L',
                  ),
                  _DetailRow(
                    label: 'Total',
                    value: currencyFormat.format(record.totalAmount),
                  ),
                  if (record.qualityBonus > 0)
                    _DetailRow(
                      label: 'Quality Bonus',
                      value: '+ ${currencyFormat.format(record.qualityBonus)}',
                      valueColor: DairyTheme.primaryGreen,
                    ),
                  if (record.deductions > 0)
                    _DetailRow(
                      label: 'Deductions',
                      value: '- ${currencyFormat.format(record.deductions)}',
                      valueColor: DairyTheme.errorRed,
                    ),
                  const Divider(height: 24),
                  _DetailRow(
                    label: 'Net Amount',
                    value: currencyFormat.format(record.netAmount),
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          FilledButton.icon(
            onPressed: onNewEntry,
            icon: const Icon(Icons.add),
            label: const Text('New Entry'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Grade badge
// =============================================================================

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.grade});

  final String? grade;

  @override
  Widget build(BuildContext context) {
    if (grade == null) return const SizedBox.shrink();

    Color bg;
    Color fg;
    switch (grade!.toUpperCase()) {
      case 'A':
        bg = DairyTheme.primaryGreen;
        fg = Colors.white;
        break;
      case 'B':
        bg = Colors.blue;
        fg = Colors.white;
        break;
      case 'C':
        bg = DairyTheme.accentOrange;
        fg = Colors.white;
        break;
      case 'REJECTED':
        bg = DairyTheme.errorRed;
        fg = Colors.white;
        break;
      default:
        bg = Colors.grey;
        fg = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Grade ${grade!.toUpperCase()}',
        style: context.textTheme.titleMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// =============================================================================
// Detail row
// =============================================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? context.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600)
                : context.textTheme.bodyMedium,
          ),
          Text(
            value,
            style: isBold
                ? context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  )
                : context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
          ),
        ],
      ),
    );
  }
}
