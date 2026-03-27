import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';

/// Screen to add a new health record for a cattle.
/// Supports selecting cattle, record type, symptoms (multi-select chips),
/// diagnosis/treatment notes, and optional photo attachment.
/// On submit it also triggers AI triage when symptoms are present.
class HealthRecordScreen extends ConsumerStatefulWidget {
  const HealthRecordScreen({super.key});

  @override
  ConsumerState<HealthRecordScreen> createState() => _HealthRecordScreenState();
}

class _HealthRecordScreenState extends ConsumerState<HealthRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedCattleId;
  HealthRecordType _recordType = HealthRecordType.checkup;
  final Set<String> _selectedSymptoms = {};
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  String? _photoUrl; // would be set after image picker flow
  bool _isSubmitting = false;

  @override
  void dispose() {
    _diagnosisController.dispose();
    _treatmentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCattleId == null) {
      context.showSnackBar('Please select a cattle', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await addHealthRecord(
        ref,
        cattleId: _selectedCattleId!,
        type: _recordType,
        symptoms: _selectedSymptoms.toList(),
        diagnosis: _diagnosisController.text.trim().isNotEmpty
            ? _diagnosisController.text.trim()
            : null,
        treatment: _treatmentController.text.trim().isNotEmpty
            ? _treatmentController.text.trim()
            : null,
        photoUrl: _photoUrl,
        triggerTriage: _selectedSymptoms.isNotEmpty,
      );

      if (!mounted) return;

      // If triage was triggered, navigate to triage result screen.
      if (_selectedSymptoms.isNotEmpty) {
        Navigator.of(context).pushReplacementNamed('/health/triage-result');
      } else {
        context.showSnackBar('Health record added successfully');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Health Record'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Cattle selector ---
            Text(
              'Select Cattle',
              style: context.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            cattleAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                'Failed to load cattle: $e',
                style: TextStyle(color: context.colorScheme.error),
              ),
              data: (cattleList) {
                return DropdownButtonFormField<int>(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    hintText: 'Choose cattle',
                    prefixIcon: const Icon(Icons.pets),
                  ),
                  value: _selectedCattleId,
                  items: cattleList
                      .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.displayLabel),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCattleId = v),
                  validator: (v) => v == null ? 'Required' : null,
                );
              },
            ),
            const SizedBox(height: 20),

            // --- Record type ---
            Text(
              'Record Type',
              style: context.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<HealthRecordType>(
              segments: HealthRecordType.values
                  .map((t) => ButtonSegment(
                        value: t,
                        label: Text(
                          t.name[0].toUpperCase() + t.name.substring(1),
                        ),
                      ))
                  .toList(),
              selected: {_recordType},
              onSelectionChanged: (s) =>
                  setState(() => _recordType = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 20),

            // --- Symptoms multi-select chips ---
            Text(
              'Symptoms',
              style: context.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Select all that apply',
              style: context.textTheme.bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: HealthSymptom.all.map((symptom) {
                final selected = _selectedSymptoms.contains(symptom.id);
                return FilterChip(
                  label: Text(symptom.label),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedSymptoms.add(symptom.id);
                      } else {
                        _selectedSymptoms.remove(symptom.id);
                      }
                    });
                  },
                  selectedColor:
                      context.colorScheme.primaryContainer,
                  checkmarkColor: context.colorScheme.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- Diagnosis ---
            TextFormField(
              controller: _diagnosisController,
              decoration: InputDecoration(
                labelText: 'Diagnosis (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.medical_information),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // --- Treatment notes ---
            TextFormField(
              controller: _treatmentController,
              decoration: InputDecoration(
                labelText: 'Treatment Notes (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.note_alt),
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),

            // --- Attach photo ---
            OutlinedButton.icon(
              onPressed: () {
                // In production, launch image picker and upload to S3.
                // For now show a placeholder action.
                context.showSnackBar(
                    'Photo picker would open here (not available in preview)');
              },
              icon: const Icon(Icons.camera_alt),
              label: Text(_photoUrl != null
                  ? 'Photo attached'
                  : 'Attach Photo (optional)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Submit ---
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
              label: Text(
                _selectedSymptoms.isNotEmpty
                    ? 'Save & Run AI Triage'
                    : 'Save Record',
              ),
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
      ),
    );
  }
}
