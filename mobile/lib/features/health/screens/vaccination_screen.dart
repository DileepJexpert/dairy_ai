import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';

/// Vaccination tracker screen: list vaccinations per cattle with
/// upcoming/overdue badges and an add-vaccination form.
class VaccinationScreen extends ConsumerStatefulWidget {
  const VaccinationScreen({super.key});

  @override
  ConsumerState<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends ConsumerState<VaccinationScreen> {
  int? _filterCattleId;

  @override
  Widget build(BuildContext context) {
    final vaccinationsAsync = ref.watch(vaccinationsProvider(_filterCattleId));
    final cattleAsync = ref.watch(cattleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccinations'),
      ),
      body: Column(
        children: [
          // --- Cattle filter ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: cattleAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (cattleList) => DropdownButtonFormField<int?>(
                decoration: InputDecoration(
                  labelText: 'Filter by cattle',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.filter_alt),
                  isDense: true,
                ),
                value: _filterCattleId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Cattle'),
                  ),
                  ...cattleList.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.displayLabel),
                      )),
                ],
                onChanged: (v) => setState(() => _filterCattleId = v),
              ),
            ),
          ),

          // --- Vaccination list ---
          Expanded(
            child: vaccinationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: context.colorScheme.error),
                      const SizedBox(height: 12),
                      Text('Failed to load vaccinations',
                          style: context.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () => ref.invalidate(
                            vaccinationsProvider(_filterCattleId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (vaccinations) {
                if (vaccinations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.vaccines,
                            size: 64,
                            color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'No vaccinations recorded',
                          style: context.textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Sort: overdue first, then upcoming, then rest.
                final sorted = List<Vaccination>.from(vaccinations)
                  ..sort((a, b) {
                    if (a.isOverdue && !b.isOverdue) return -1;
                    if (!a.isOverdue && b.isOverdue) return 1;
                    if (a.isUpcoming && !b.isUpcoming) return -1;
                    if (!a.isUpcoming && b.isUpcoming) return 1;
                    return b.dateGiven.compareTo(a.dateGiven);
                  });

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(vaccinationsProvider(_filterCattleId));
                    await Future.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) =>
                        _VaccinationCard(vaccination: sorted[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddVaccinationSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Vaccination'),
      ),
    );
  }

  void _showAddVaccinationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _AddVaccinationForm(
          preSelectedCattleId: _filterCattleId,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vaccination card
// ---------------------------------------------------------------------------
class _VaccinationCard extends StatelessWidget {
  final Vaccination vaccination;
  const _VaccinationCard({required this.vaccination});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    vaccination.cattleName ??
                        'Cattle #${vaccination.cattleId}',
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (vaccination.isOverdue)
                  _BadgeChip(label: 'OVERDUE', color: Colors.red)
                else if (vaccination.isUpcoming)
                  _BadgeChip(label: 'UPCOMING', color: Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.vaccines, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(vaccination.vaccineName,
                    style: context.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Given: ${dateFormat.format(vaccination.dateGiven)}',
                  style: context.textTheme.bodySmall,
                ),
                if (vaccination.nextDue != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.event, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Next: ${dateFormat.format(vaccination.nextDue!)}',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: vaccination.isOverdue ? Colors.red : null,
                      fontWeight: vaccination.isOverdue
                          ? FontWeight.w600
                          : null,
                    ),
                  ),
                ],
              ],
            ),
            if (vaccination.administeredBy != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'By: ${vaccination.administeredBy}',
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add vaccination bottom sheet form
// ---------------------------------------------------------------------------
class _AddVaccinationForm extends ConsumerStatefulWidget {
  final int? preSelectedCattleId;

  const _AddVaccinationForm({this.preSelectedCattleId});

  @override
  ConsumerState<_AddVaccinationForm> createState() =>
      _AddVaccinationFormState();
}

class _AddVaccinationFormState extends ConsumerState<_AddVaccinationForm> {
  final _formKey = GlobalKey<FormState>();
  int? _cattleId;
  final _vaccineNameController = TextEditingController();
  DateTime _dateGiven = DateTime.now();
  DateTime? _nextDue;
  final _administeredByController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cattleId = widget.preSelectedCattleId;
  }

  @override
  void dispose() {
    _vaccineNameController.dispose();
    _administeredByController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isNextDue}) async {
    final initial = isNextDue
        ? (_nextDue ?? DateTime.now().add(const Duration(days: 90)))
        : _dateGiven;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isNextDue) {
          _nextDue = picked;
        } else {
          _dateGiven = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cattleId == null) {
      context.showSnackBar('Please select a cattle', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await addVaccination(
        ref,
        cattleId: _cattleId!,
        vaccineName: _vaccineNameController.text.trim(),
        dateGiven: _dateGiven,
        nextDue: _nextDue,
        administeredBy: _administeredByController.text.trim().isNotEmpty
            ? _administeredByController.text.trim()
            : null,
      );
      if (mounted) {
        context.showSnackBar('Vaccination added successfully');
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
    final dateFormat = DateFormat('dd MMM yyyy');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Vaccination',
              style: context.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Cattle selector
            cattleAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) =>
                  const Text('Could not load cattle list'),
              data: (cattleList) => DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Cattle',
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

            // Vaccine name
            TextFormField(
              controller: _vaccineNameController,
              decoration: InputDecoration(
                labelText: 'Vaccine Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.vaccines),
                hintText: 'e.g. FMD, HS-BQ, Brucella',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Date given
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date Given'),
              subtitle: Text(dateFormat.format(_dateGiven)),
              onTap: () => _pickDate(isNextDue: false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),

            // Next due date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Next Due Date (optional)'),
              subtitle: Text(
                _nextDue != null
                    ? dateFormat.format(_nextDue!)
                    : 'Tap to set',
              ),
              trailing: _nextDue != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _nextDue = null),
                    )
                  : null,
              onTap: () => _pickDate(isNextDue: true),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 16),

            // Administered by
            TextFormField(
              controller: _administeredByController,
              decoration: InputDecoration(
                labelText: 'Administered By (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
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
              label: const Text('Save Vaccination'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
