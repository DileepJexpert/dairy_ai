import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_farmer/providers/vet_farmer_provider.dart';
import 'package:dairy_ai/features/vet_farmer/screens/consultation_chat_screen.dart';

/// Screen where a farmer creates a consultation request:
/// select cattle, describe symptoms, optionally attach a photo,
/// choose consultation type, view AI triage, then submit.
class ConsultationRequestScreen extends ConsumerStatefulWidget {
  final VetProfile vet;

  const ConsultationRequestScreen({super.key, required this.vet});

  @override
  ConsumerState<ConsultationRequestScreen> createState() =>
      _ConsultationRequestScreenState();
}

class _ConsultationRequestScreenState
    extends ConsumerState<ConsultationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  int? _selectedCattleId;
  ConsultationType _consultationType = ConsultationType.chat;
  final Set<String> _selectedSymptoms = {};
  String? _photoUrl;
  bool _isSubmitting = false;
  bool _triageCompleted = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(farmerCattleListProvider);
    final triageState = ref.watch(consultationTriageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Consultation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // --- Vet info summary ---
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.colorScheme.primaryContainer,
                  backgroundImage: widget.vet.photoUrl != null
                      ? NetworkImage(widget.vet.photoUrl!)
                      : null,
                  child: widget.vet.photoUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text('Dr. ${widget.vet.name}'),
                subtitle: Text(widget.vet.qualification),
                trailing: Text(
                  'Rs ${widget.vet.fee.toStringAsFixed(0)}',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: context.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Select cattle ---
            Text('Select Cattle',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            cattleAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading cattle: $e',
                  style: TextStyle(color: context.colorScheme.error)),
              data: (cattleList) {
                if (cattleList.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No cattle registered yet.',
                          style: context.textTheme.bodyMedium),
                    ),
                  );
                }
                return DropdownButtonFormField<int>(
                  value: _selectedCattleId,
                  decoration:
                      const InputDecoration(labelText: 'Choose cattle'),
                  items: cattleList
                      .map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.displayLabel)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedCattleId = val),
                  validator: (val) =>
                      val == null ? 'Please select a cattle' : null,
                );
              },
            ),
            const SizedBox(height: 20),

            // --- Symptoms multi-select ---
            Text('Symptoms',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
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
                    // Reset triage when symptoms change.
                    _triageCompleted = false;
                    ref.read(consultationTriageProvider.notifier).clear();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // --- Description ---
            Text('Describe the Problem',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe what you have observed...',
                alignLabelWithHint: true,
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Please describe the problem'
                  : null,
            ),
            const SizedBox(height: 20),

            // --- Photo attachment (placeholder) ---
            Text('Attach Photo (Optional)',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // Placeholder — would open image picker.
                context.showSnackBar('Photo picker coming soon');
              },
              icon: const Icon(Icons.camera_alt),
              label: Text(_photoUrl != null ? 'Photo attached' : 'Take Photo'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            const SizedBox(height: 20),

            // --- Consultation type ---
            Text('Consultation Type',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<ConsultationType>(
              segments: const [
                ButtonSegment(
                  value: ConsultationType.chat,
                  label: Text('Chat'),
                  icon: Icon(Icons.chat),
                ),
                ButtonSegment(
                  value: ConsultationType.video,
                  label: Text('Video'),
                  icon: Icon(Icons.videocam),
                ),
                ButtonSegment(
                  value: ConsultationType.in_person,
                  label: Text('In Person'),
                  icon: Icon(Icons.location_on),
                ),
              ],
              selected: {_consultationType},
              onSelectionChanged: (val) =>
                  setState(() => _consultationType = val.first),
            ),
            const SizedBox(height: 24),

            // --- AI Triage section ---
            if (!_triageCompleted && _selectedSymptoms.isNotEmpty) ...[
              FilledButton.tonal(
                onPressed: triageState.isLoading
                    ? null
                    : () async {
                        if (_selectedCattleId == null) {
                          context.showSnackBar('Please select a cattle first',
                              isError: true);
                          return;
                        }
                        await ref
                            .read(consultationTriageProvider.notifier)
                            .runTriage(
                              cattleId: _selectedCattleId!,
                              symptoms: _selectedSymptoms.toList(),
                            );
                        setState(() => _triageCompleted = true);
                      },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: triageState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Run AI Triage'),
              ),
              const SizedBox(height: 16),
            ],

            // --- Triage result display ---
            if (_triageCompleted && triageState.result != null) ...[
              _TriageResultCard(result: triageState.result!),
              const SizedBox(height: 16),
            ],

            if (_triageCompleted && triageState.error != null)
              Card(
                color: context.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Triage error: ${triageState.error}',
                    style:
                        TextStyle(color: context.colorScheme.onErrorContainer),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // --- Submit button ---
            FilledButton(
              onPressed: _isSubmitting ? null : _submitRequest,
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
                  : const Text('Submit Request'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSymptoms.isEmpty) {
      context.showSnackBar('Please select at least one symptom', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final request = ConsultationRequest(
        cattleId: _selectedCattleId!,
        vetId: widget.vet.id,
        type: _consultationType,
        symptoms: _selectedSymptoms.toList(),
        description: _descriptionController.text.trim(),
        photoUrl: _photoUrl,
      );

      final consultation =
          await requestConsultation(ref, request: request);

      if (!mounted) return;
      context.showSnackBar('Consultation requested successfully');

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              ConsultationChatScreen(consultationId: consultation.id),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Compact triage result card for the request screen.
// ---------------------------------------------------------------------------
class _TriageResultCard extends StatelessWidget {
  final TriageResult result;

  const _TriageResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final Color severityColor;
    final String severityLabel;
    switch (result.severity) {
      case TriageSeverity.low:
        severityColor = Colors.green;
        severityLabel = 'Low';
        break;
      case TriageSeverity.medium:
        severityColor = Colors.orange;
        severityLabel = 'Medium';
        break;
      case TriageSeverity.high:
        severityColor = Colors.red;
        severityLabel = 'High';
        break;
    }

    return Card(
      color: severityColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: severityColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy, size: 20, color: severityColor),
                const SizedBox(width: 8),
                Text(
                  'AI Triage Result',
                  style: context.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Severity: $severityLabel',
                    style: TextStyle(
                      color: severityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.diagnosis, style: context.textTheme.bodyMedium),
            if (result.recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...result.recommendedActions.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('  \u2022  ',
                          style: TextStyle(color: severityColor)),
                      Expanded(
                          child: Text(a,
                              style: context.textTheme.bodySmall)),
                    ],
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
