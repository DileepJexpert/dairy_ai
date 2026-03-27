import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';
import 'package:dairy_ai/features/milk/models/milk_models.dart';
import 'package:dairy_ai/features/milk/providers/milk_provider.dart';

/// Screen to record daily milk production.
/// Supports single-cattle entry and a "quick entry" mode for batch recording
/// across multiple cattle.
class MilkRecordScreen extends ConsumerStatefulWidget {
  const MilkRecordScreen({super.key});

  @override
  ConsumerState<MilkRecordScreen> createState() => _MilkRecordScreenState();
}

class _MilkRecordScreenState extends ConsumerState<MilkRecordScreen> {
  bool _quickEntryMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Milk'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _quickEntryMode = !_quickEntryMode),
            icon: Icon(
              _quickEntryMode ? Icons.edit_note : Icons.speed,
              size: 20,
            ),
            label: Text(_quickEntryMode ? 'Standard' : 'Quick Entry'),
          ),
        ],
      ),
      body: _quickEntryMode
          ? _QuickEntryView()
          : const _SingleEntryForm(),
    );
  }
}

// ---------------------------------------------------------------------------
// Single cattle entry form
// ---------------------------------------------------------------------------
class _SingleEntryForm extends ConsumerStatefulWidget {
  const _SingleEntryForm();

  @override
  ConsumerState<_SingleEntryForm> createState() => _SingleEntryFormState();
}

class _SingleEntryFormState extends ConsumerState<_SingleEntryForm> {
  final _formKey = GlobalKey<FormState>();
  int? _cattleId;
  MilkSession _session = MilkSession.morning;
  final _quantityController = TextEditingController();
  final _fatController = TextEditingController();
  final _snfController = TextEditingController();
  BuyerType _buyerType = BuyerType.cooperative;
  final _priceController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cattleId == null) {
      context.showSnackBar('Please select a cattle', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await recordMilk(
        ref,
        cattleId: _cattleId!,
        date: _date,
        session: _session,
        quantityLitres: double.parse(_quantityController.text.trim()),
        fatPct: _fatController.text.trim().isNotEmpty
            ? double.parse(_fatController.text.trim())
            : null,
        snfPct: _snfController.text.trim().isNotEmpty
            ? double.parse(_snfController.text.trim())
            : null,
        buyerType: _buyerType,
        pricePerLitre: _priceController.text.trim().isNotEmpty
            ? double.parse(_priceController.text.trim())
            : null,
      );
      if (mounted) {
        context.showSnackBar('Milk record saved');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date picker
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Date'),
            subtitle: Text(DateFormat('dd MMM yyyy').format(_date)),
            onTap: _pickDate,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(height: 16),

          // Cattle selector
          cattleAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Failed to load cattle: $e'),
            data: (cattleList) => DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: 'Select Cattle',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.pets),
              ),
              value: _cattleId,
              items: cattleList
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.displayLabel),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _cattleId = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
          ),
          const SizedBox(height: 16),

          // Session selector
          Text(
            'Session',
            style: context.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<MilkSession>(
            segments: const [
              ButtonSegment(
                value: MilkSession.morning,
                label: Text('Morning'),
                icon: Icon(Icons.wb_sunny, size: 18),
              ),
              ButtonSegment(
                value: MilkSession.evening,
                label: Text('Evening'),
                icon: Icon(Icons.wb_twilight, size: 18),
              ),
              ButtonSegment(
                value: MilkSession.night,
                label: Text('Night'),
                icon: Icon(Icons.nightlight, size: 18),
              ),
            ],
            selected: {_session},
            onSelectionChanged: (s) => setState(() => _session = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 20),

          // Quantity
          TextFormField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: 'Quantity (litres)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.water_drop),
              suffixText: 'L',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final val = double.tryParse(v.trim());
              if (val == null || val <= 0) return 'Enter a valid quantity';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Fat % and SNF % in a row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _fatController,
                  decoration: InputDecoration(
                    labelText: 'Fat % (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: '%',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _snfController,
                  decoration: InputDecoration(
                    labelText: 'SNF % (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixText: '%',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Buyer type
          Text(
            'Buyer Type',
            style: context.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<BuyerType>(
            segments: const [
              ButtonSegment(
                value: BuyerType.cooperative,
                label: Text('Co-op'),
              ),
              ButtonSegment(
                value: BuyerType.private_buyer,
                label: Text('Private'),
              ),
              ButtonSegment(
                value: BuyerType.self_use,
                label: Text('Self'),
              ),
            ],
            selected: {_buyerType},
            onSelectionChanged: (s) => setState(() => _buyerType = s.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),

          // Price per litre
          TextFormField(
            controller: _priceController,
            decoration: InputDecoration(
              labelText: 'Price per litre (optional)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.currency_rupee),
              prefixText: 'Rs ',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
          const SizedBox(height: 28),

          // Submit
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('Save Milk Record'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick entry mode — record milk for multiple cattle at once
// ---------------------------------------------------------------------------
class _QuickEntryView extends ConsumerStatefulWidget {
  @override
  ConsumerState<_QuickEntryView> createState() => _QuickEntryViewState();
}

class _QuickEntryViewState extends ConsumerState<_QuickEntryView> {
  MilkSession _session = MilkSession.morning;
  DateTime _date = DateTime.now();
  BuyerType _buyerType = BuyerType.cooperative;
  double? _defaultPrice;
  final Map<int, TextEditingController> _quantityControllers = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitBatch() async {
    final entries = <MilkRecord>[];
    for (final entry in _quantityControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final qty = double.tryParse(text);
      if (qty == null || qty <= 0) continue;
      entries.add(MilkRecord(
        cattleId: entry.key,
        date: _date,
        session: _session,
        quantityLitres: qty,
        buyerType: _buyerType,
        pricePerLitre: _defaultPrice,
      ));
    }

    if (entries.isEmpty) {
      context.showSnackBar('Enter quantity for at least one cattle',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await recordMilkBatch(ref, records: entries);
      if (mounted) {
        context.showSnackBar(
            '${entries.length} milk records saved successfully');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) context.showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);

    return Column(
      children: [
        // Header controls
        Card(
          margin: const EdgeInsets.all(12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(2024),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setState(() => _date = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            isDense: true,
                            prefixIcon: const Icon(Icons.calendar_today,
                                size: 18),
                          ),
                          child: Text(
                            DateFormat('dd MMM').format(_date),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SegmentedButton<MilkSession>(
                        segments: const [
                          ButtonSegment(
                              value: MilkSession.morning,
                              label: Text('AM')),
                          ButtonSegment(
                              value: MilkSession.evening,
                              label: Text('PM')),
                          ButtonSegment(
                              value: MilkSession.night,
                              label: Text('Night')),
                        ],
                        selected: {_session},
                        onSelectionChanged: (s) =>
                            setState(() => _session = s.first),
                        showSelectedIcon: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Cattle list with quantity inputs
        Expanded(
          child: cattleAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (cattleList) {
              // Ensure controllers exist for all cattle.
              for (final c in cattleList) {
                _quantityControllers.putIfAbsent(
                  c.id,
                  () => TextEditingController(),
                );
              }
              return ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: cattleList.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cattle = cattleList[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor:
                          context.colorScheme.primaryContainer,
                      child: Text(
                        cattle.name.isNotEmpty
                            ? cattle.name[0].toUpperCase()
                            : '#',
                        style: TextStyle(
                          color: context.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      cattle.displayLabel,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: cattle.breed != null
                        ? Text(cattle.breed!,
                            style: context.textTheme.bodySmall)
                        : null,
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _quantityControllers[cattle.id],
                        decoration: InputDecoration(
                          hintText: '0.0',
                          suffixText: 'L',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Submit bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitBatch,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save All Records'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
