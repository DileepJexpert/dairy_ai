import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/home_provider.dart';
import '../models/dashboard_model.dart';
import '../../../shared/widgets/stat_card.dart';

class FarmerHomeScreen extends ConsumerWidget {
  const FarmerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(dashboardStatsProvider.notifier).refresh(),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () =>
              ref.read(dashboardStatsProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, stats),
              SliverToBoxAdapter(child: _buildStatsGrid(context, stats)),
              SliverToBoxAdapter(child: _buildQuickActions(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              _buildActivityList(context, stats.recentActivities),
              // Bottom padding so FAB doesn't overlap
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // App bar with greeting
  // ---------------------------------------------------------------------------

  SliverAppBar _buildAppBar(BuildContext context, DashboardStats stats) {
    final greeting = _greeting();
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting,',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.8),
                  ),
            ),
            Text(
              stats.farmerName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
      actions: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: Icon(
            Icons.notifications_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        IconButton(
          onPressed: () => context.push('/profile'),
          icon: Icon(
            Icons.person_outline,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2x2 Stats grid
  // ---------------------------------------------------------------------------

  Widget _buildStatsGrid(BuildContext context, DashboardStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          StatCard(
            icon: Icons.pets,
            label: 'Total Cattle',
            value: '${stats.totalCattle}',
            color: Colors.teal,
            onTap: () => context.push('/herd'),
          ),
          StatCard(
            icon: Icons.water_drop,
            label: "Today's Milk",
            value: '${stats.todayMilkLitres.toStringAsFixed(1)} L',
            color: Colors.blue,
            onTap: () => context.push('/milk'),
          ),
          StatCard(
            icon: Icons.warning_amber_rounded,
            label: 'Health Alerts',
            value: '${stats.pendingHealthAlerts}',
            color: stats.pendingHealthAlerts > 0 ? Colors.red : Colors.green,
            onTap: () => context.push('/health'),
          ),
          StatCard(
            icon: Icons.vaccines,
            label: 'Vaccinations Due',
            value: '${stats.upcomingVaccinations}',
            color: Colors.orange,
            onTap: () => context.push('/vaccinations'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick action buttons
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickActionButton(
                icon: Icons.water_drop_outlined,
                label: 'Add Milk',
                color: Colors.blue,
                onTap: () => context.push('/milk/add'),
              ),
              _QuickActionButton(
                icon: Icons.medical_services_outlined,
                label: 'Health Check',
                color: Colors.red,
                onTap: () => context.push('/health/triage'),
              ),
              _QuickActionButton(
                icon: Icons.video_call_outlined,
                label: 'Call Vet',
                color: Colors.green,
                onTap: () => context.push('/vet'),
              ),
              _QuickActionButton(
                icon: Icons.smart_toy_outlined,
                label: 'AI Chat',
                color: Colors.purple,
                onTap: () => context.push('/chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recent activity list
  // ---------------------------------------------------------------------------

  SliverList _buildActivityList(
      BuildContext context, List<RecentActivity> activities) {
    if (activities.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No recent activity',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ]),
      );
    }

    return SliverList.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _ActivityTile(activity: activity);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// =============================================================================
// Private widgets
// =============================================================================

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final RecentActivity activity;

  IconData _iconForType(String type) {
    switch (type) {
      case 'milk':
        return Icons.water_drop;
      case 'health':
        return Icons.medical_services;
      case 'vaccination':
        return Icons.vaccines;
      case 'breeding':
        return Icons.favorite;
      case 'feed':
        return Icons.grass;
      case 'finance':
        return Icons.currency_rupee;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'milk':
        return Colors.blue;
      case 'health':
        return Colors.red;
      case 'vaccination':
        return Colors.orange;
      case 'breeding':
        return Colors.pink;
      case 'feed':
        return Colors.green;
      case 'finance':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorForType(activity.type);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(_iconForType(activity.type), color: color, size: 20),
      ),
      title: Text(
        activity.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        activity.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: activity.cattleTag != null
          ? Text(
              activity.cattleTag!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
