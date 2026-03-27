import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/breeding/models/breeding_models.dart';
import 'package:dairy_ai/features/breeding/providers/breeding_provider.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart'
    show cattleListProvider;

class AddBreedingEventScreen extends ConsumerStatefulWidget {
  final String? preselectedCattleId;

  const AddBreedingEventScreen({super.key, this.preselectedCattleId});

  @override
  ConsumerState<AddBreedingEventScreen> createState() =>
      _AddBreedingEventScreenState();
}

class _AddBreedingEventScreenState
    extends ConsumerState<AddBreedingEventScreen> {
  final _formKey = GlobalKey<FormState>();

  late String? _selectedCattleId;
  BreedingEventType _selectedEventType = BreedingEventType.heatDetected;
  DateTime _selectedDate = DateTime.now();
  final _bullIdController = TextEditingController();
  final _aiTechIdController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCattleId = widget.preselectedCattleId;
  }

  @override
  void dispose() {
    _bullIdController.dispose();
    _aiTechIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);
    final actionState = ref.watch(breedingActionProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Breeding Event'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -- Select cattle --
            cattleAsync.when(
              data: (cattleList) => DropdownButtonFormField<String>(
                value: _selectedCattleId,
                decoration: const InputDecoration(
                  labelText: 'Select Cattle *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pets),
                ),
                items: cattleList
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.name} (${c.tagId})'),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCattleId = value),
                validator: (value) =>
                    value == null ? 'Please select cattle' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading cattle: $e'),
            ),

            const SizedBox(height: 16),

            // -- Event type --
            DropdownButtonFormField<BreedingEventType>(
              value: _selectedEventType,
              decoration: const InputDecoration(
                labelText: 'Event Type *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
              items: BreedingEventType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(_eventTypeLabel(type)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedEventType = value);
                }
              },
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

            // -- Expected calving info --
            if (_selectedEventType == BreedingEventType.aiDone) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Expected calving: ${dateFormat.format(_selectedDate.add(const Duration(days: 283)))}',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // -- Bull ID (optional) --
            if (_selectedEventType == BreedingEventType.aiDone ||
                _selectedEventType == BreedingEventType.heatDetected)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: _bullIdController,
                  decoration: const InputDecoration(
                    labelText: 'Bull / Semen ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge),
                    hintText: 'Optional',
                  ),
                ),
              ),

            // -- AI Tech ID (optional) --
            if (_selectedEventType == BreedingEventType.aiDone)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: _aiTechIdController,
                  decoration: const InputDecoration(
                    labelText: 'AI Technician ID',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Optional',
                  ),
                ),
              ),

            // -- Notes --
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
                hintText: 'Any additional observations...',
              ),
              maxLines: 3,
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

            // -- Submit button --
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
                  actionState.isSubmitting ? 'Saving...' : 'Save Event'),
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
    if (_selectedCattleId == null) return;

    final request = AddBreedingEventRequest(
      cattleId: _selectedCattleId!,
      eventType: _eventTypeToString(_selectedEventType),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      bullId:
          _bullIdController.text.isEmpty ? null : _bullIdController.text.trim(),
      aiTechId: _aiTechIdController.text.isEmpty
          ? null
          : _aiTechIdController.text.trim(),
      notes:
          _notesController.text.isEmpty ? null : _notesController.text.trim(),
    );

    final success =
        await ref.read(breedingActionProvider.notifier).addBreedingEvent(request);

    if (success && mounted) {
      context.showSnackBar('Breeding event added successfully!');
      Navigator.of(context).pop();
    }
  }

  String _eventTypeLabel(BreedingEventType type) {
    switch (type) {
      case BreedingEventType.heatDetected:
        return 'Heat Detected';
      case BreedingEventType.aiDone:
        return 'AI Done';
      case BreedingEventType.pregnancyConfirmed:
        return 'Pregnancy Confirmed';
      case BreedingEventType.calved:
        return 'Calved';
    }
  }

  String _eventTypeToString(BreedingEventType type) {
    switch (type) {
      case BreedingEventType.heatDetected:
        return 'heat_detected';
      case BreedingEventType.aiDone:
        return 'ai_done';
      case BreedingEventType.pregnancyConfirmed:
        return 'pregnancy_confirmed';
      case BreedingEventType.calved:
        return 'calved';
    }
  }
}
