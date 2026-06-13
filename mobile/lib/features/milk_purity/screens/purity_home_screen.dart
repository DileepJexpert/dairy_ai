import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/milk_purity_provider.dart';
import '../models/milk_purity_models.dart';
import '../widgets/brand_list_tile.dart';

class PurityHomeScreen extends ConsumerStatefulWidget {
  const PurityHomeScreen({super.key});

  @override
  ConsumerState<PurityHomeScreen> createState() => _PurityHomeScreenState();
}

class _PurityHomeScreenState extends ConsumerState<PurityHomeScreen> {
  final _searchController = TextEditingController();
  String? _searchQuery;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query.trim().isEmpty ? null : query.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Purity Checker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare brands',
            onPressed: () => context.push('/purity/compare'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: theme.colorScheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search milk brand (e.g. Amul, Mother Dairy)...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon:
                    Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                suffixIcon: _searchQuery != null
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: Colors.white.withOpacity(0.8)),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _searchQuery != null
                ? _SearchResults(query: _searchQuery!)
                : const _TopBrandsList(),
          ),
        ],
      ),
    );
  }
}

class _TopBrandsList extends ConsumerWidget {
  const _TopBrandsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(topBrandsProvider);
    final theme = Theme.of(context);

    return brandsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('Could not load brands',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => ref.invalidate(topBrandsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (brands) {
        if (brands.isEmpty) {
          return Center(
            child: Text('No brands available yet',
                style: theme.textTheme.bodyMedium),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(topBrandsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: brands.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events,
                          color: Colors.amber.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Top Brands by Purity Score',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final brand = brands[index - 1];
              return BrandListTile(
                brand: brand,
                rank: index,
                onTap: () => context.push('/purity/brand/${brand.slug}'),
              );
            },
          ),
        );
      },
    );
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;

  const _SearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchBrandsProvider(query));
    final theme = Theme.of(context);

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Search failed', style: theme.textTheme.bodyMedium),
      ),
      data: (brands) {
        if (brands.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No brands found for "$query"',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: brands.length,
          itemBuilder: (context, index) {
            final brand = brands[index];
            return BrandListTile(
              brand: brand,
              onTap: () => context.push('/purity/brand/${brand.slug}'),
            );
          },
        );
      },
    );
  }
}
