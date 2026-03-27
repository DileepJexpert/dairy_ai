import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dairy_ai/shared/widgets/cattle_list_tile.dart';
import '../providers/cattle_provider.dart';
import '../models/cattle_model.dart';

/// Displays the farmer's full cattle list with search and status filtering.
class HerdListScreen extends ConsumerStatefulWidget {
  const HerdListScreen({super.key, required this.farmerId});

  final String farmerId;

  @override
  ConsumerState<HerdListScreen> createState() => _HerdListScreenState();
}

class _HerdListScreenState extends ConsumerState<HerdListScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAsync =
        ref.watch(filteredCattleListProvider(widget.farmerId));
    final activeFilter = ref.watch(cattleStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? _SearchField(
                controller: _searchController,
                onChanged: (q) =>
                    ref.read(cattleSearchQueryProvider.notifier).state = q,
              )
            : const Text('My Herd'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(cattleSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          _StatusFilterBar(
            selected: activeFilter,
            onSelected: (status) {
              ref.read(cattleStatusFilterProvider.notifier).state = status;
            },
          ),
          // Cattle list
          Expanded(
            child: filteredAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, _) => _ErrorBody(
                message: err.toString(),
                onRetry: () => ref
                    .read(cattleListProvider(widget.farmerId).notifier)
                    .refresh(),
              ),
              data: (cattle) {
                if (cattle.isEmpty) {
                  return const _EmptyHerd();
                }
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(cattleListProvider(widget.farmerId).notifier)
                      .refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: cattle.length,
                    itemBuilder: (context, index) {
                      final animal = cattle[index];
                      return CattleListTile(
                        cattle: animal,
                        onTap: () =>
                            context.push('/herd/${animal.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/herd/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add Cattle'),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: true,
      decoration: const InputDecoration(
        hintText: 'Search by name or tag...',
        border: InputBorder.none,
      ),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});

  final CattleStatus? selected;
  final ValueChanged<CattleStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...CattleStatus.values.map((status) {
            final label = switch (status) {
              CattleStatus.active => 'Active',
              CattleStatus.dry => 'Dry',
              CattleStatus.sold => 'Sold',
              CattleStatus.deceased => 'Deceased',
            };
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: selected == status,
                onSelected: (_) =>
                    onSelected(selected == status ? null : status),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _EmptyHerd extends StatelessWidget {
  const _EmptyHerd();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pets, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No cattle found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first cattle.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
