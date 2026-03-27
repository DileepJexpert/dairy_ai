import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/admin/models/admin_models.dart';
import 'package:dairy_ai/features/admin/providers/admin_provider.dart';

/// Searchable, paginated list of all registered farmers.
class AdminFarmersScreen extends ConsumerStatefulWidget {
  const AdminFarmersScreen({super.key});

  @override
  ConsumerState<AdminFarmersScreen> createState() => _AdminFarmersScreenState();
}

class _AdminFarmersScreenState extends ConsumerState<AdminFarmersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(adminFarmersProvider);
    final filter = ref.watch(adminFarmersFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Farmers'),
      ),
      body: Column(
        children: [
          // ---------- Search bar ----------
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, phone, village...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(adminFarmersFilterProvider.notifier)
                              .setSearch('');
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                ref
                    .read(adminFarmersFilterProvider.notifier)
                    .setSearch(value);
              },
            ),
          ),

          // ---------- Farmer list ----------
          Expanded(
            child: farmersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load farmers',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(adminFarmersProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (paginated) {
                if (paginated.farmers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: DairyTheme.subtleGrey),
                        const SizedBox(height: 12),
                        Text(
                          filter.search.isNotEmpty
                              ? 'No farmers match your search'
                              : 'No farmers registered yet',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: DairyTheme.subtleGrey,
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(adminFarmersProvider),
                        child: ListView.separated(
                          itemCount: paginated.farmers.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            return _FarmerListTile(
                              farmer: paginated.farmers[index],
                            );
                          },
                        ),
                      ),
                    ),

                    // ---------- Pagination controls ----------
                    if (paginated.totalPages > 1)
                      _PaginationBar(
                        currentPage: paginated.page,
                        totalPages: paginated.totalPages,
                        totalItems: paginated.total,
                        onPrevious: paginated.hasPrevious
                            ? () => ref
                                .read(adminFarmersFilterProvider.notifier)
                                .previousPage()
                            : null,
                        onNext: paginated.hasNext
                            ? () => ref
                                .read(adminFarmersFilterProvider.notifier)
                                .nextPage()
                            : null,
                      ),
                  ],
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
// Single farmer list tile.
// ---------------------------------------------------------------------------
class _FarmerListTile extends StatelessWidget {
  final AdminFarmer farmer;

  const _FarmerListTile({required this.farmer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: DairyTheme.primaryGreen.withOpacity(0.1),
        child: Text(
          farmer.name.isNotEmpty ? farmer.name[0].toUpperCase() : '?',
          style: TextStyle(
            color: DairyTheme.primaryGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        farmer.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (farmer.village != null || farmer.district != null)
            Text(
              [farmer.village, farmer.district]
                  .where((e) => e != null)
                  .join(', '),
              style: theme.textTheme.bodySmall,
            ),
          Text(
            '${farmer.cattleCount} cattle',
            style: theme.textTheme.bodySmall?.copyWith(
              color: DairyTheme.primaryGreen,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            farmer.isActive ? Icons.check_circle : Icons.cancel,
            color: farmer.isActive ? DairyTheme.primaryGreen : Colors.red,
            size: 20,
          ),
          const SizedBox(height: 2),
          Text(
            farmer.isActive ? 'Active' : 'Inactive',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
      onTap: () {
        // Navigate to farmer detail — can be wired to a detail route.
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _FarmerDetailSheet(farmer: farmer),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Farmer detail bottom sheet.
// ---------------------------------------------------------------------------
class _FarmerDetailSheet extends StatelessWidget {
  final AdminFarmer farmer;

  const _FarmerDetailSheet({required this.farmer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(farmer.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          _detailRow(Icons.phone, 'Phone', farmer.phone),
          if (farmer.village != null)
            _detailRow(Icons.location_on, 'Village', farmer.village!),
          if (farmer.district != null)
            _detailRow(Icons.map, 'District', farmer.district!),
          if (farmer.state != null)
            _detailRow(Icons.flag, 'State', farmer.state!),
          _detailRow(Icons.pets, 'Cattle Count', '${farmer.cattleCount}'),
          _detailRow(
            Icons.calendar_today,
            'Joined',
            '${farmer.createdAt.day}/${farmer.createdAt.month}/${farmer.createdAt.year}',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DairyTheme.subtleGrey),
          const SizedBox(width: 12),
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 14)),
          Expanded(
            child: Text(value,
                style: TextStyle(color: DairyTheme.subtleGrey, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination bar.
// ---------------------------------------------------------------------------
class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$totalItems farmers',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrevious,
              ),
              Text(
                'Page $currentPage of $totalPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
