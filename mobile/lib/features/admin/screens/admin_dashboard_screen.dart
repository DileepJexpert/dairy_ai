import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/shared/widgets/stat_card.dart';
import 'package:dairy_ai/features/admin/models/admin_models.dart';
import 'package:dairy_ai/features/admin/providers/admin_provider.dart';

/// Main admin dashboard with stat cards, registration chart, quick actions,
/// and a recent activity feed.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(adminDashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load dashboard',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(error.toString(),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => ref.invalidate(adminDashboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (dashboard) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminDashboardProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------- Stat cards ----------
              _buildStatCards(context, dashboard),
              const SizedBox(height: 24),

              // ---------- Registration chart ----------
              Text('Registrations This Month',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _RegistrationBarChart(
                farmersCount: dashboard.newFarmersThisMonth,
                cattleCount: dashboard.totalCattle,
              ),
              const SizedBox(height: 24),

              // ---------- Quick actions ----------
              Text('Quick Actions',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),

              // ---------- Recent activity ----------
              Text('Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _buildRecentActivity(context, dashboard.recentActivity),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, AdminDashboard dashboard) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        StatCard(
          icon: Icons.people,
          label: 'Total Farmers',
          value: '${dashboard.totalFarmers}',
          color: DairyTheme.primaryGreen,
        ),
        StatCard(
          icon: Icons.pets,
          label: 'Total Cattle',
          value: '${dashboard.totalCattle}',
          color: DairyTheme.accentOrange,
        ),
        StatCard(
          icon: Icons.medical_services,
          label: 'Total Vets',
          value: '${dashboard.totalVets}',
          color: Colors.blue,
        ),
        StatCard(
          icon: Icons.video_call,
          label: 'Active Consultations',
          value: '${dashboard.activeConsultations}',
          color: Colors.purple,
        ),
        StatCard(
          icon: Icons.water_drop,
          label: 'Milk Today (L)',
          value: dashboard.milkTodayLitres.toStringAsFixed(1),
          color: Colors.teal,
        ),
        StatCard(
          icon: Icons.pending_actions,
          label: 'Pending Verifications',
          value: '${dashboard.pendingVerifications}',
          color: DairyTheme.errorRed,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.people,
            label: 'Manage\nFarmers',
            color: DairyTheme.primaryGreen,
            onTap: () => context.go('/admin/farmers'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.medical_services,
            label: 'Manage\nVets',
            color: Colors.blue,
            onTap: () => context.go('/admin/vets'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.assignment,
            label: 'View\nConsultations',
            color: Colors.purple,
            onTap: () => context.push('/admin/consultations'),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(
      BuildContext context, List<RecentActivity> activities) {
    if (activities.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No recent activity',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DairyTheme.subtleGrey,
                  ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  _activityColor(activity.type).withOpacity(0.1),
              child: Icon(
                _activityIcon(activity.type),
                color: _activityColor(activity.type),
                size: 20,
              ),
            ),
            title: Text(activity.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    )),
            subtitle: Text(activity.description),
            trailing: Text(
              _timeAgo(activity.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        },
      ),
    );
  }

  IconData _activityIcon(String type) {
    switch (type) {
      case 'registration':
        return Icons.person_add;
      case 'consultation':
        return Icons.medical_services;
      case 'verification':
        return Icons.verified;
      case 'milk':
        return Icons.water_drop;
      default:
        return Icons.info_outline;
    }
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'registration':
        return DairyTheme.primaryGreen;
      case 'consultation':
        return Colors.purple;
      case 'verification':
        return Colors.blue;
      case 'milk':
        return Colors.teal;
      default:
        return DairyTheme.subtleGrey;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

// ---------------------------------------------------------------------------
// Quick action card widget.
// ---------------------------------------------------------------------------
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder bar chart using CustomPaint.
// ---------------------------------------------------------------------------
class _RegistrationBarChart extends StatelessWidget {
  final int farmersCount;
  final int cattleCount;

  const _RegistrationBarChart({
    required this.farmersCount,
    required this.cattleCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 160,
          child: CustomPaint(
            size: const Size(double.infinity, 160),
            painter: _BarChartPainter(
              labels: ['Farmers', 'Cattle'],
              values: [farmersCount.toDouble(), cattleCount.toDouble()],
              colors: [DairyTheme.primaryGreen, DairyTheme.accentOrange],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final List<Color> colors;

  _BarChartPainter({
    required this.labels,
    required this.values,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return;

    final barCount = values.length;
    final barWidth = (size.width - 40) / (barCount * 2);
    final chartHeight = size.height - 30;

    // Draw axis line.
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );

    for (var i = 0; i < barCount; i++) {
      final barHeight = (values[i] / maxValue) * (chartHeight - 10);
      final x = (size.width / (barCount + 1)) * (i + 1) - barWidth / 2;
      final y = chartHeight - barHeight;

      // Bar.
      final barPaint = Paint()..color = colors[i % colors.length];
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, barPaint);

      // Value text above bar.
      final valueSpan = TextSpan(
        text: values[i].toInt().toString(),
        style: TextStyle(
          color: colors[i % colors.length],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      final valuePainter = TextPainter(
        text: valueSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      valuePainter.paint(
        canvas,
        Offset(x + barWidth / 2 - valuePainter.width / 2, y - 18),
      );

      // Label text below bar.
      final labelSpan = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(
            x + barWidth / 2 - labelPainter.width / 2, chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels;
  }
}
