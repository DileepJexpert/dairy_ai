import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/cattle_provider.dart';
import '../models/cattle_model.dart';

/// Detailed view of a single cattle with tabs for Overview, Health, Milk,
/// and Breeding records.
class CattleDetailScreen extends ConsumerWidget {
  const CattleDetailScreen({super.key, required this.cattleId});

  final String cattleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cattleAsync = ref.watch(cattleDetailProvider(cattleId));

    return cattleAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (cattle) => _CattleDetailBody(cattle: cattle),
    );
  }
}

class _CattleDetailBody extends StatelessWidget {
  const _CattleDetailBody({required this.cattle});

  final Cattle cattle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd MMM yyyy');

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      context.push('/herd/${cattle.id}/edit'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // Handle menu actions
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Text('Share'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove'),
                    ),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _HeroSection(cattle: cattle),
              ),
            ),
            // Quick action bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.water_drop_outlined,
                        label: 'Record Milk',
                        onTap: () =>
                            context.push('/milk/add?cattle_id=${cattle.id}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.medical_services_outlined,
                        label: 'Health Check',
                        onTap: () => context
                            .push('/health/triage?cattle_id=${cattle.id}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionChip(
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: () =>
                            context.push('/herd/${cattle.id}/edit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tab bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Health'),
                    Tab(text: 'Milk'),
                    Tab(text: 'Breeding'),
                  ],
                ),
                color: theme.colorScheme.surface,
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(cattle: cattle, dateFormat: dateFormat),
              _PlaceholderTab(
                icon: Icons.medical_services,
                label: 'Health records will appear here.',
              ),
              _PlaceholderTab(
                icon: Icons.water_drop,
                label: 'Milk records will appear here.',
              ),
              _PlaceholderTab(
                icon: Icons.favorite,
                label: 'Breeding records will appear here.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Hero section — photo + key info
// =============================================================================

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.cattle});

  final Cattle cattle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Photo
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: cattle.photoUrl != null
                  ? NetworkImage(cattle.photoUrl!)
                  : null,
              child: cattle.photoUrl == null
                  ? Icon(Icons.pets, size: 40,
                      color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(height: 12),
            // Name
            Text(
              cattle.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // Tag + breed
            Text(
              '${cattle.tagId}  ·  ${cattle.breed}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Overview tab — basic details
// =============================================================================

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.cattle, required this.dateFormat});

  final Cattle cattle;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailRow(label: 'Tag ID', value: cattle.tagId),
        _DetailRow(label: 'Breed', value: cattle.breed),
        _DetailRow(
            label: 'Sex',
            value: cattle.sex == CattleSex.female ? 'Female' : 'Male'),
        _DetailRow(
            label: 'Date of Birth', value: dateFormat.format(cattle.dob)),
        _DetailRow(label: 'Age', value: cattle.age),
        _DetailRow(label: 'Status', value: cattle.statusLabel),
        if (cattle.createdAt != null)
          _DetailRow(
            label: 'Added On',
            value: dateFormat.format(cattle.createdAt!),
          ),
        const SizedBox(height: 24),
        Text(
          'Sensor Data',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No sensor data available.\nConnect an IoT collar to start tracking.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Placeholder tab for future content
// =============================================================================

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Action chip button
// =============================================================================

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
    );
  }
}

// =============================================================================
// Sliver tab bar delegate
// =============================================================================

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar, {required this.color});

  final TabBar _tabBar;
  final Color color;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
