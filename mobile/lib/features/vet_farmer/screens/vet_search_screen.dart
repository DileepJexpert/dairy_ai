import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _minFeeController = TextEditingController();
  final _maxFeeController = TextEditingController();

  bool _showLocationSection = false;
  bool _showFeeSection = false;
  bool _showFilterSection = true;

  @override
  void dispose() {
    _searchController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _minFeeController.dispose();
    _maxFeeController.dispose();
    super.dispose();
  }

  void _applyLocation() {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat != null && lng != null) {
      ref.read(vetSearchFiltersProvider.notifier).setLocation(lat, lng);
    } else {
      context.showSnackBar(
        'Enter valid latitude and longitude values',
        isError: true,
      );
    }
  }

  void _clearLocation() {
    _latController.clear();
    _lngController.clear();
    ref.read(vetSearchFiltersProvider.notifier).clearLocation();
  }

  void _applyFeeRange() {
    final min = double.tryParse(_minFeeController.text.trim());
    final max = double.tryParse(_maxFeeController.text.trim());
    ref.read(vetSearchFiltersProvider.notifier).setFeeRange(min, max);
  }

  void _clearFeeRange() {
    _minFeeController.clear();
    _maxFeeController.clear();
    ref.read(vetSearchFiltersProvider.notifier).setFeeRange(null, null);
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

          // --- Sort chips ---
          _SortChipRow(
            currentSort: filters.sortBy,
            onSortChanged: (sort) =>
                ref.read(vetSearchFiltersProvider.notifier).setSortBy(sort),
          ),

          // --- Collapsible filter sections ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Location section header
                _CollapsibleHeader(
                  title: 'Location',
                  icon: Icons.location_on_outlined,
                  isExpanded: _showLocationSection,
                  trailing: filters.hasLocation
                      ? Text(
                          'Within ${filters.maxDistanceKm.round()} km',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.primary,
                          ),
                        )
                      : null,
                  onToggle: () => setState(
                      () => _showLocationSection = !_showLocationSection),
                ),
                if (_showLocationSection) _buildLocationSection(filters),

                // Fee range section header
                _CollapsibleHeader(
                  title: 'Fee Range',
                  icon: Icons.currency_rupee,
                  isExpanded: _showFeeSection,
                  trailing: (filters.minFee != null || filters.maxFee != null)
                      ? Text(
                          _feeRangeLabel(filters.minFee, filters.maxFee),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.primary,
                          ),
                        )
                      : null,
                  onToggle: () =>
                      setState(() => _showFeeSection = !_showFeeSection),
                ),
                if (_showFeeSection) _buildFeeSection(),

                // Specialization & Language section header
                _CollapsibleHeader(
                  title: 'Specialization & Language',
                  icon: Icons.filter_list,
                  isExpanded: _showFilterSection,
                  trailing: (filters.specialization != null ||
                          filters.language != null)
                      ? Text(
                          'Active',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colorScheme.primary,
                          ),
                        )
                      : null,
                  onToggle: () => setState(
                      () => _showFilterSection = !_showFilterSection),
                ),
                if (_showFilterSection) _buildSpecLanguageSection(filters),
              ],
            ),
          ),

          // Clear all filters button
          if (_hasAnyActiveFilter(filters))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton.icon(
                onPressed: () {
                  ref.read(vetSearchFiltersProvider.notifier).clear();
                  _searchController.clear();
                  _latController.clear();
                  _lngController.clear();
                  _minFeeController.clear();
                  _maxFeeController.clear();
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear All Filters'),
              ),
            ),

          const SizedBox(height: 4),

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
                        sortBy: filters.sortBy,
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

  // --- Location filter section ---
  Widget _buildLocationSection(VetSearchFilters filters) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // Lat/Lng input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    hintText: 'e.g. 26.9124',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    hintText: 'e.g. 75.7873',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _applyLocation,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text('Use Location'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (filters.hasLocation) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearLocation,
                  icon: const Icon(Icons.location_off, size: 20),
                  tooltip: 'Clear location',
                  style: IconButton.styleFrom(
                    foregroundColor: context.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          // GPS note
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Automatic GPS requires the geolocator package. '
              'Enter your coordinates manually above.',
              style: context.textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (filters.hasLocation) ...[
            const SizedBox(height: 10),
            // Location active indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: context.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Searching within ${filters.maxDistanceKm.round()} km',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Distance slider
            Row(
              children: [
                Text('5 km', style: context.textTheme.labelSmall),
                Expanded(
                  child: Slider(
                    value: filters.maxDistanceKm,
                    min: 5,
                    max: 100,
                    divisions: 19,
                    label: '${filters.maxDistanceKm.round()} km',
                    onChanged: (value) => ref
                        .read(vetSearchFiltersProvider.notifier)
                        .setMaxDistance(value),
                  ),
                ),
                Text('100 km', style: context.textTheme.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- Fee range filter section ---
  Widget _buildFeeSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minFeeController,
                  decoration: const InputDecoration(
                    labelText: 'Min Fee',
                    prefixText: 'Rs ',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => _applyFeeRange(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxFeeController,
                  decoration: const InputDecoration(
                    labelText: 'Max Fee',
                    prefixText: 'Rs ',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => _applyFeeRange(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _clearFeeRange,
                icon: const Icon(Icons.clear, size: 20),
                tooltip: 'Clear fee range',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Specialization & Language section ---
  Widget _buildSpecLanguageSection(VetSearchFilters filters) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
    );
  }

  bool _hasAnyActiveFilter(VetSearchFilters filters) {
    return filters.specialization != null ||
        filters.language != null ||
        filters.hasLocation ||
        filters.minFee != null ||
        filters.maxFee != null ||
        (filters.query != null && filters.query!.isNotEmpty);
  }

  String _feeRangeLabel(double? min, double? max) {
    if (min != null && max != null) return 'Rs ${min.round()}-${max.round()}';
    if (min != null) return 'Rs ${min.round()}+';
    if (max != null) return 'Up to Rs ${max.round()}';
    return '';
  }
}

// ---------------------------------------------------------------------------
// Sort chip row.
// ---------------------------------------------------------------------------
class _SortChipRow extends StatelessWidget {
  final String currentSort;
  final ValueChanged<String> onSortChanged;

  const _SortChipRow({
    required this.currentSort,
    required this.onSortChanged,
  });

  static const _sortOptions = [
    ('distance', 'Distance', Icons.near_me),
    ('fee_low', 'Fee: Low to High', Icons.arrow_upward),
    ('fee_high', 'Fee: High to Low', Icons.arrow_downward),
    ('rating', 'Rating', Icons.star),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _sortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label, icon) = _sortOptions[index];
          final isSelected = currentSort == value;
          return ChoiceChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14),
                const SizedBox(width: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
            selected: isSelected,
            onSelected: (_) => onSortChanged(value),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Collapsible section header.
// ---------------------------------------------------------------------------
class _CollapsibleHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final Widget? trailing;
  final VoidCallback onToggle;

  const _CollapsibleHeader({
    required this.title,
    required this.icon,
    required this.isExpanded,
    this.trailing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            const Spacer(),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
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
// Distance badge widget.
// ---------------------------------------------------------------------------
class _DistanceBadge extends StatelessWidget {
  final double distanceKm;

  const _DistanceBadge({required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;

    if (distanceKm < 10) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade800;
    } else if (distanceKm < 25) {
      bgColor = Colors.orange.shade50;
      textColor = Colors.orange.shade800;
    } else {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            '${distanceKm.toStringAsFixed(1)} km away',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vet card in search results.
// ---------------------------------------------------------------------------
class _VetCard extends StatelessWidget {
  final VetProfile vet;
  final String sortBy;
  final VoidCallback onRequestConsultation;

  const _VetCard({
    required this.vet,
    required this.sortBy,
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
                      // Location label
                      if (vet.locationLabel != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 12,
                                color: Colors.grey.shade600),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                vet.locationLabel!,
                                style: context.textTheme.labelSmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Rating badge — shown prominently when sortBy is rating
                _buildRatingBadge(context),
              ],
            ),
            const SizedBox(height: 10),

            // Distance and service radius row
            if (vet.distanceKm != null || vet.serviceRadiusKm != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (vet.distanceKm != null)
                      _DistanceBadge(distanceKm: vet.distanceKm!),
                    if (vet.serviceRadiusKm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radar,
                                size: 12, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Serves within ${vet.serviceRadiusKm!.round()} km',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

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
                // Fee — highlighted when sorting by fee
                _buildFeeLabel(context),
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

  Widget _buildRatingBadge(BuildContext context) {
    final isRatingSort = sortBy == 'rating';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isRatingSort
            ? Colors.amber.shade100
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isRatingSort
              ? Colors.amber.shade400
              : Colors.amber.shade200,
          width: isRatingSort ? 1.5 : 1.0,
        ),
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
              fontSize: isRatingSort ? 15 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeLabel(BuildContext context) {
    final isFeeSort = sortBy == 'fee_low' || sortBy == 'fee_high';
    return Row(
      children: [
        Icon(Icons.currency_rupee,
            size: isFeeSort ? 18 : 16,
            color: context.colorScheme.primary),
        Text(
          '${vet.fee.toStringAsFixed(0)}/consultation',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: isFeeSort ? FontWeight.w800 : FontWeight.w600,
            color: context.colorScheme.primary,
            fontSize: isFeeSort ? 15 : null,
          ),
        ),
      ],
    );
  }
}
