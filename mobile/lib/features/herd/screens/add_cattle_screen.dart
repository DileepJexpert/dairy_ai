import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/cattle_provider.dart';
import '../models/cattle_model.dart';

/// Indian dairy cattle breeds for the breed dropdown.
const List<String> _indianBreeds = [
  'Gir',
  'Sahiwal',
  'Red Sindhi',
  'Tharparkar',
  'Rathi',
  'Kankrej',
  'Murrah',
  'Mehsana',
  'Jaffarabadi',
  'Nili-Ravi',
  'Surti',
  'Banni',
  'HF (Holstein Friesian)',
  'Jersey',
  'HF Cross',
  'Jersey Cross',
  'Other',
];

/// Screen for adding or editing a cattle entry.
///
/// When [cattle] is provided the screen operates in edit mode.
class AddCattleScreen extends ConsumerStatefulWidget {
  const AddCattleScreen({
    super.key,
    required this.farmerId,
    this.cattle,
  });

  final String farmerId;
  final Cattle? cattle;

  bool get isEditing => cattle != null;

  @override
  ConsumerState<AddCattleScreen> createState() => _AddCattleScreenState();
}

class _AddCattleScreenState extends ConsumerState<AddCattleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _tagController;
  late String _selectedBreed;
  late CattleSex _selectedSex;
  DateTime? _selectedDob;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cattle;
    _nameController = TextEditingController(text: c?.name ?? '');
    _tagController = TextEditingController(text: c?.tagId ?? '');
    _selectedBreed = c?.breed ?? _indianBreeds.first;
    _selectedSex = c?.sex ?? CattleSex.female;
    _selectedDob = c?.dob;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final notifier =
          ref.read(cattleListProvider(widget.farmerId).notifier);

      if (widget.isEditing) {
        await notifier.updateCattle(
          widget.cattle!.id,
          UpdateCattleRequest(
            name: _nameController.text.trim(),
            tagId: _tagController.text.trim(),
            breed: _selectedBreed,
            sex: _selectedSex,
            dob: _selectedDob,
          ),
        );
      } else {
        await notifier.addCattle(
          CreateCattleRequest(
            name: _nameController.text.trim(),
            tagId: _tagController.text.trim(),
            breed: _selectedBreed,
            sex: _selectedSex,
            dob: _selectedDob!,
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing
                ? 'Cattle updated successfully'
                : 'Cattle added successfully'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Date picker
  // ---------------------------------------------------------------------------

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ??
          DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Select date of birth',
    );
    if (picked != null) {
      setState(() => _selectedDob = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Cattle' : 'Add Cattle'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo placeholder
              Center(
                child: GestureDetector(
                  onTap: () {
                    // TODO: Implement photo picker
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_outlined,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 4),
                        Text(
                          'Add Photo',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g., Lakshmi',
                  prefixIcon: Icon(Icons.pets),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Tag ID
              TextFormField(
                controller: _tagController,
                decoration: const InputDecoration(
                  labelText: 'Tag ID',
                  hintText: 'e.g., IN-GJ-001',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a tag ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Breed dropdown
              DropdownButtonFormField<String>(
                value: _selectedBreed,
                decoration: const InputDecoration(
                  labelText: 'Breed',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: _indianBreeds
                    .map((breed) =>
                        DropdownMenuItem(value: breed, child: Text(breed)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedBreed = value);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a breed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Sex toggle
              Text('Sex', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              SegmentedButton<CattleSex>(
                segments: const [
                  ButtonSegment(
                    value: CattleSex.female,
                    label: Text('Female'),
                    icon: Icon(Icons.female),
                  ),
                  ButtonSegment(
                    value: CattleSex.male,
                    label: Text('Male'),
                    icon: Icon(Icons.male),
                  ),
                ],
                selected: {_selectedSex},
                onSelectionChanged: (selection) {
                  setState(() => _selectedSex = selection.first);
                },
              ),
              const SizedBox(height: 16),

              // DOB picker
              InkWell(
                onTap: _pickDob,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: const OutlineInputBorder(),
                    suffixIcon: _selectedDob != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () =>
                                setState(() => _selectedDob = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _selectedDob != null
                        ? dateFormat.format(_selectedDob!)
                        : 'Tap to select',
                    style: _selectedDob != null
                        ? theme.textTheme.bodyLarge
                        : theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
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
                    : Icon(widget.isEditing ? Icons.save : Icons.add),
                label: Text(widget.isEditing ? 'Save Changes' : 'Add Cattle'),
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
