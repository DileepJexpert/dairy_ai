import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dairy_ai/shared/widgets/cattle_list_tile.dart';
import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
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
          const FarmerAuthAction(nextRoute: '/herd'),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Status filter chips
              _StatusFilterBar(
                selected: activeFilter,
                onSelected: (status) {
                  ref.read(cattleStatusFilterProvider.notifier).state = status;
                },
              ),

              // Quick Shortcuts: 305-Day Lactation Curves & Tele-Vet Clinic
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => context.push('/herd/lifecycle/MIL-2024-0842'),
                        icon: const Icon(Icons.analytics_outlined, size: 16),
                        label: const Text('Lactation Analytics',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => context.push('/vet/booking'),
                        icon: const Icon(Icons.video_call_outlined, size: 16),
                        label: const Text('Tele-Vet Clinic',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
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
        ),
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

class _EmptyHerd extends ConsumerWidget {
  const _EmptyHerd();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    if (!isAuthenticated) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xff064e3b).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 56,
                  color: Color(0xff064e3b),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'लॉगिन आवश्यक है (Sign In Required)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff064e3b),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'अपने पंजीकृत पशु, दूध उत्पादन, टीकाकरण व स्वास्थ्य रिकॉर्ड देखने व प्रबंधित करने के लिए कृपया लॉगिन करें।',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xff475569),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff064e3b),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => context.push('/login?next=/herd'),
                icon: const Icon(Icons.login),
                label: const Text(
                  'लॉगिन करें / Sign In',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xff064e3b),
                  side: const BorderSide(color: Color(0xff064e3b)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => context.push('/register'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('नया किसान खाता बनाएं (Register)'),
              ),
            ],
          ),
        ),
      );
    }

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
    final isAuthError = message.toLowerCase().contains('authentication required') ||
        message.toLowerCase().contains('unauthorized') ||
        message.contains('401');

    if (isAuthError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56, color: Color(0xff047857)),
              const SizedBox(height: 16),
              const Text(
                'Sign In to View Your Herd',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Log in with your farm account to manage your cattle, vaccinations, and daily milk logs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/login?next=/herd'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Sign In (1-Click Demo Available)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

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
