import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/finance/models/finance_models.dart';
import 'package:dairy_ai/features/finance/providers/finance_provider.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.feedCost;
  DateTime _selectedDate = DateTime.now();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Categories available per transaction type.
  List<TransactionCategory> get _availableCategories {
    if (_type == TransactionType.income) {
      return [
        TransactionCategory.milkSales,
        TransactionCategory.cattleSale,
        TransactionCategory.other,
      ];
    }
    return [
      TransactionCategory.feedCost,
      TransactionCategory.vetFees,
      TransactionCategory.medicine,
      TransactionCategory.cattlePurchase,
      TransactionCategory.equipment,
      TransactionCategory.labour,
      TransactionCategory.other,
    ];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(financeActionProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -- Type toggle --
            Text('Transaction Type',
                style: context.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (Set<TransactionType> selected) {
                setState(() {
                  _type = selected.first;
                  // Reset category when type changes.
                  _category = _availableCategories.first;
                });
              },
            ),

            const SizedBox(height: 20),

            // -- Category dropdown --
            DropdownButtonFormField<TransactionCategory>(
              value: _availableCategories.contains(_category)
                  ? _category
                  : _availableCategories.first,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: _availableCategories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(_categoryLabel(cat)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
              validator: (value) =>
                  value == null ? 'Please select a category' : null,
            ),

            const SizedBox(height: 16),

            // -- Amount --
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (INR) *',
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
                  return 'Please enter an amount';
                }
                final parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid positive amount';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // -- Description --
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
                hintText: 'Optional details...',
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 16),

            // -- Date picker --
            InkWell(
              onTap: () => _pickDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(dateFormat.format(_selectedDate)),
              ),
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
                  : const Icon(Icons.save),
              label: Text(
                  actionState.isSubmitting ? 'Saving...' : 'Save Transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final request = AddTransactionRequest(
      type: _type == TransactionType.income ? 'income' : 'expense',
      category: _categoryToString(_category),
      amount: double.parse(_amountController.text.trim()),
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
    );

    final success =
        await ref.read(financeActionProvider.notifier).addTransaction(request);

    if (success && mounted) {
      context.showSnackBar('Transaction added successfully!');
      Navigator.of(context).pop();
    }
  }

  String _categoryLabel(TransactionCategory cat) {
    switch (cat) {
      case TransactionCategory.milkSales:
        return 'Milk Sales';
      case TransactionCategory.feedCost:
        return 'Feed Cost';
      case TransactionCategory.vetFees:
        return 'Vet Fees';
      case TransactionCategory.medicine:
        return 'Medicine';
      case TransactionCategory.cattlePurchase:
        return 'Cattle Purchase';
      case TransactionCategory.cattleSale:
        return 'Cattle Sale';
      case TransactionCategory.equipment:
        return 'Equipment';
      case TransactionCategory.labour:
        return 'Labour';
      case TransactionCategory.other:
        return 'Other';
    }
  }

  String _categoryToString(TransactionCategory cat) {
    switch (cat) {
      case TransactionCategory.milkSales:
        return 'milk_sales';
      case TransactionCategory.feedCost:
        return 'feed_cost';
      case TransactionCategory.vetFees:
        return 'vet_fees';
      case TransactionCategory.medicine:
        return 'medicine';
      case TransactionCategory.cattlePurchase:
        return 'cattle_purchase';
      case TransactionCategory.cattleSale:
        return 'cattle_sale';
      case TransactionCategory.equipment:
        return 'equipment';
      case TransactionCategory.labour:
        return 'labour';
      case TransactionCategory.other:
        return 'other';
    }
  }
}
