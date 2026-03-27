import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_farmer/providers/vet_farmer_provider.dart';
import 'package:dairy_ai/features/vet_farmer/screens/consultation_request_screen.dart';

/// Farmer-side screen to search for available verified vets.
class VetSearchScreen extends ConsumerStatefulWidget {
  const VetSearchScreen({super.key});

  @override
  ConsumerState<VetSearchScreen> createState() => _VetSearchScreenState();
}

class _VetSearchScreenState extends ConsumerState<VetSearchScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(vetSearchFiltersProvider);
    final vetsAsync = ref.watch(vetSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a Vet')),
      body: Column(
        children: [
          // --- Search bar ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(vetSearchFiltersProvider.notifier)
                              .setQuery(null);
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref.read(vetSearchFiltersProvider.notifier).setQuery(value);
              },
            ),
          ),

          // --- Filter chips ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _FilterDropdown(
                    label: 'Specialization',
                    value: filters.specialization,
                    items: VetSpecialization.all,
                    onChanged: (val) => ref
                        .read(vetSearchFiltersProvider.notifier)
                        .setSpecialization(val),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FilterDropdown(
                    label: 'Language',
                    value: filters.language,
                    items: VetLanguage.all,
                    onChanged: (val) => ref
                        .read(vetSearchFiltersProvider.notifier)
                        .setLanguage(val),
                  ),
                ),
              ],
            ),
          ),

          if (filters.specialization != null || filters.language != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: () {
                  ref.read(vetSearchFiltersProvider.notifier).clear();
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear Filters'),
              ),
            ),

          const SizedBox(height: 8),

          // --- Results ---
          Expanded(
            child: vetsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: context.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Failed to load vets',
                        style: context.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(error.toString(),
                        style: context.textTheme.bodySmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => ref.invalidate(vetSearchProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (vets) {
                if (vets.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_services_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No vets found',
                            style: context.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Try adjusting your search or filters',
                            style: context.textTheme.bodySmall),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(vetSearchProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: vets.length,
                    itemBuilder: (context, index) {
                      return _VetCard(
                        vet: vets[index],
                        onRequestConsultation: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ConsultationRequestScreen(vet: vets[index]),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter dropdown widget.
// ---------------------------------------------------------------------------
class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        DropdownMenuItem<String>(value: null, child: Text('All $label')),
        ...items.map(
          (item) => DropdownMenuItem(value: item, child: Text(item)),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Vet card in search results.
// ---------------------------------------------------------------------------
class _VetCard extends StatelessWidget {
  final VetProfile vet;
  final VoidCallback onRequestConsultation;

  const _VetCard({
    required this.vet,
    required this.onRequestConsultation,
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
              children: [
                // Vet photo
                CircleAvatar(
                  radius: 28,
                  backgroundColor: context.colorScheme.primaryContainer,
                  backgroundImage:
                      vet.photoUrl != null ? NetworkImage(vet.photoUrl!) : null,
                  child: vet.photoUrl == null
                      ? Icon(Icons.person,
                          size: 28, color: context.colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${vet.name}',
                        style: context.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vet.qualification,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Rating badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        vet.rating.toStringAsFixed(1),
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Specializations
            if (vet.specializations.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: vet.specializations
                    .map(
                      (s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                      ),
                    )
                    .toList(),
              ),

            const SizedBox(height: 12),

            // Fee and action
            Row(
              children: [
                Icon(Icons.currency_rupee,
                    size: 16, color: context.colorScheme.primary),
                Text(
                  '${vet.fee.toStringAsFixed(0)}/consultation',
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onRequestConsultation,
                  icon: const Icon(Icons.video_call, size: 18),
                  label: const Text('Request Consultation'),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.zero,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
