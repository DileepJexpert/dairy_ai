import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/payments/providers/payment_provider.dart';

class CreateCycleScreen extends ConsumerStatefulWidget {
  const CreateCycleScreen({super.key});

  @override
  ConsumerState<CreateCycleScreen> createState() => _CreateCycleScreenState();
}

class _CreateCycleScreenState extends ConsumerState<CreateCycleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _centerIdController = TextEditingController();

  String _cycleType = 'monthly';
  DateTime _periodStart = DateTime.now();
  DateTime _periodEnd = DateTime.now().add(const Duration(days: 30));

  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _centerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(paymentActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Payment Cycle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -- Cycle Type dropdown --
            DropdownButtonFormField<String>(
              value: _cycleType,
              decoration: const InputDecoration(
                labelText: 'Cycle Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(
                    value: 'fortnightly', child: Text('Fortnightly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _cycleType = value;
                    // Auto-adjust period end based on cycle type.
                    switch (value) {
                      case 'weekly':
                        _periodEnd =
                            _periodStart.add(const Duration(days: 7));
                        break;
                      case 'fortnightly':
                        _periodEnd =
                            _periodStart.add(const Duration(days: 14));
                        break;
                      case 'monthly':
                        _periodEnd =
                            _periodStart.add(const Duration(days: 30));
                        break;
                    }
                  });
                }
              },
              validator: (value) =>
                  value == null ? 'Please select a cycle type' : null,
            ),

            const SizedBox(height: 16),

            // -- Period Start --
            InkWell(
              onTap: () => _pickDate(context, isStart: true),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Period Start *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(_dateFormat.format(_periodStart)),
              ),
            ),

            const SizedBox(height: 16),

            // -- Period End --
            InkWell(
              onTap: () => _pickDate(context, isStart: false),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Period End *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(_dateFormat.format(_periodEnd)),
              ),
            ),

            const SizedBox(height: 16),

            // -- Center ID --
            TextFormField(
              controller: _centerIdController,
              decoration: const InputDecoration(
                labelText: 'Center ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
                hintText: 'Optional — leave blank for all centers',
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
                  : const Icon(Icons.check),
              label: Text(actionState.isSubmitting
                  ? 'Creating...'
                  : 'Create Cycle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, {required bool isStart}) async {
    final initial = isStart ? _periodStart : _periodEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
          // Ensure end is after start.
          if (_periodEnd.isBefore(_periodStart)) {
            _periodEnd = _periodStart.add(const Duration(days: 7));
          }
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_periodEnd.isBefore(_periodStart) ||
        _periodEnd.isAtSameMomentAs(_periodStart)) {
      context.showSnackBar('Period end must be after period start',
          isError: true);
      return;
    }

    final data = <String, dynamic>{
      'cycle_type': _cycleType,
      'period_start': _dateFormat.format(_periodStart),
      'period_end': _dateFormat.format(_periodEnd),
    };

    if (_centerIdController.text.trim().isNotEmpty) {
      data['center_id'] = _centerIdController.text.trim();
    }

    final success =
        await ref.read(paymentActionProvider.notifier).createCycle(data);

    if (success && mounted) {
      context.showSnackBar('Payment cycle created successfully!');
      Navigator.of(context).pop();
    }
  }
}
