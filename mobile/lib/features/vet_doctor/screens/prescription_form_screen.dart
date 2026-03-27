import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_doctor/models/vet_doctor_models.dart';
import 'package:dairy_ai/features/vet_doctor/providers/vet_doctor_provider.dart';

/// Prescription form where the vet can add medicines, instructions,
/// and a follow-up date.
class PrescriptionFormScreen extends ConsumerStatefulWidget {
  final int consultationId;

  const PrescriptionFormScreen({super.key, required this.consultationId});

  @override
  ConsumerState<PrescriptionFormScreen> createState() =>
      _PrescriptionFormScreenState();
}

class _PrescriptionFormScreenState
    extends ConsumerState<PrescriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instructionsController = TextEditingController();
  final List<_MedicineEntry> _medicines = [];
  DateTime? _followUpDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Start with one empty medicine row.
    _addMedicine();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    for (final m in _medicines) {
      m.dispose();
    }
    super.dispose();
  }

  void _addMedicine() {
    setState(() {
      _medicines.add(_MedicineEntry());
    });
  }

  void _removeMedicine(int index) {
    setState(() {
      _medicines[index].dispose();
      _medicines.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write Prescription')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- Medicines section ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medicines',
                  style: context.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addMedicine,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Medicine'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...List.generate(_medicines.length, (index) {
              return _MedicineCard(
                entry: _medicines[index],
                index: index,
                canRemove: _medicines.length > 1,
                onRemove: () => _removeMedicine(index),
              );
            }),

            const SizedBox(height: 24),

            // --- Instructions ---
            Text(
              'Instructions',
              style: context.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _instructionsController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Additional instructions for the farmer (diet, care, etc.)',
                alignLabelWithHint: true,
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Please add instructions'
                  : null,
            ),
            const SizedBox(height: 24),

            // --- Follow-up date ---
            Text(
              'Follow-up Date',
              style: context.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate:
                      DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _followUpDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _followUpDate != null
                    ? '${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year}'
                    : 'Select follow-up date (optional)',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 32),

            // --- Submit ---
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Prescription'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that at least one medicine has a name.
    final validMedicines = _medicines
        .where((m) => m.nameController.text.trim().isNotEmpty)
        .toList();
    if (validMedicines.isEmpty) {
      context.showSnackBar('Please add at least one medicine', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final medicines = validMedicines
          .map((m) => Medicine(
                name: m.nameController.text.trim(),
                dosage: m.dosageController.text.trim(),
                frequency: m.frequencyController.text.trim(),
                duration: m.durationController.text.trim(),
              ))
          .toList();

      final payload = PrescriptionPayload(
        consultationId: widget.consultationId,
        medicines: medicines,
        instructions: _instructionsController.text.trim(),
        followUpDate: _followUpDate,
      );

      await submitPrescription(ref, payload: payload);

      if (!mounted) return;
      context.showSnackBar('Prescription submitted successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Medicine entry state holder.
// ---------------------------------------------------------------------------
class _MedicineEntry {
  final nameController = TextEditingController();
  final dosageController = TextEditingController();
  final frequencyController = TextEditingController();
  final durationController = TextEditingController();

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
  }
}

// ---------------------------------------------------------------------------
// Medicine card widget.
// ---------------------------------------------------------------------------
class _MedicineCard extends StatelessWidget {
  final _MedicineEntry entry;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  const _MedicineCard({
    required this.entry,
    required this.index,
    required this.canRemove,
    required this.onRemove,
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
                Text(
                  'Medicine ${index + 1}',
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (canRemove)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    color: Colors.red,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name',
                hintText: 'e.g. Amoxicillin',
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Required'
                  : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: entry.dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage',
                      hintText: 'e.g. 500mg',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: entry.frequencyController,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      hintText: 'e.g. 2x/day',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: entry.durationController,
              decoration: const InputDecoration(
                labelText: 'Duration',
                hintText: 'e.g. 7 days',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
