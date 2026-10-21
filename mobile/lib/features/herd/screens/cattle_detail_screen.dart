import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/api_client.dart';

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
        appBar: AppBar(title: const Text('Cattle Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.pets, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Animal Profile Unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Unable to load cattle profile. Please try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back to Herd'),
                ),
              ],
            ),
          ),
        ),
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
                      context.push('/herd/${cattle.id}/edit', extra: cattle),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // Handle menu actions (share, remove)
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'share',
                      child: Text('Share'),
                    ),
                    PopupMenuItem(
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ActionChip(
                            icon: Icons.analytics_outlined,
                            label: 'Lactation & Lifecycle',
                            onTap: () =>
                                context.push('/herd/lifecycle/${cattle.id}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ActionChip(
                            icon: Icons.video_call_outlined,
                            label: 'Book Tele-Vet',
                            onTap: () =>
                                context.push('/vet/booking?cattleId=${cattle.id}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
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
                                context.push('/herd/${cattle.id}/edit', extra: cattle),
                          ),
                        ),
                      ],
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
              _HealthTab(cattleId: cattle.id, dateFormat: dateFormat),
              _MilkTab(cattleId: cattle.id, dateFormat: dateFormat),
              _BreedingTab(cattleId: cattle.id),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Hero section -- photo + key info
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
            CircleAvatar(
              radius: 50,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: cattle.photoUrl != null
                  ? NetworkImage(cattle.photoUrl!)
                  : null,
              child: cattle.photoUrl == null
                  ? Icon(Icons.pets,
                      size: 40,
                      color: theme.colorScheme.onSurfaceVariant)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(
              cattle.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
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
// Overview tab -- basic details
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
        if (cattle.dob != null)
          _DetailRow(
              label: 'Date of Birth', value: dateFormat.format(cattle.dob!)),
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
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.push(
              '/herd/${cattle.id}/sensors?name=${Uri.encodeComponent(cattle.name)}',
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Icon(Icons.sensors, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'View Live Sensor Data',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 16, color: theme.colorScheme.primary),
                ],
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

// =============================================================================
// Cattle Detail Tabs: Health, Milk & Breeding Providers and Views
// =============================================================================

final cattleBreedingProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, cattleId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get('/cattle/$cattleId/breeding');
    if (res.data is Map && res.data['success'] == true) {
      return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
    }
  } catch (_) {}
  return [];
});

final cattleHealthTabProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, cattleId) async {
  final dio = ref.watch(apiClientProvider);
  List<Map<String, dynamic>> vaccines = [];
  List<Map<String, dynamic>> health = [];
  try {
    final vRes = await dio.get('/cattle/$cattleId/vaccinations');
    if (vRes.data is Map && vRes.data['success'] == true) {
      vaccines = List<Map<String, dynamic>>.from(vRes.data['data'] ?? []);
    }
  } catch (_) {}
  try {
    final hRes = await dio.get('/cattle/$cattleId/health-records');
    if (hRes.data is Map && hRes.data['success'] == true) {
      health = List<Map<String, dynamic>>.from(hRes.data['data'] ?? []);
    }
  } catch (_) {}
  return {'vaccines': vaccines, 'health': health};
});

final cattleMilkTabProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, cattleId) async {
  final dio = ref.watch(apiClientProvider);
  try {
    final res = await dio.get('/milk-records', queryParameters: {'cattle_id': cattleId});
    if (res.data is Map && res.data['success'] == true) {
      return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
    }
  } catch (_) {}
  return [];
});

class _BreedingTab extends ConsumerWidget {
  const _BreedingTab({required this.cattleId});
  final String cattleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breedingAsync = ref.watch(cattleBreedingProvider(cattleId));
    final theme = Theme.of(context);

    return breedingAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return const _PlaceholderTab(
            icon: Icons.favorite_border,
            label: 'No breeding records recorded yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final r = records[index];
            final eventType = r['event_type'] as String? ?? '';
            final date = r['date'] as String? ?? '';
            final bullId = r['bull_id'] as String?;
            final technician = r['ai_technician'] as String?;
            final expCalving = r['expected_calving_date'] as String?;
            final notes = r['notes'] as String?;

            IconData icon = Icons.event;
            Color iconColor = theme.colorScheme.primary;
            String title = 'Breeding Event';

            if (eventType == 'pregnancy_confirmed') {
              icon = Icons.pregnant_woman;
              iconColor = Colors.purple;
              title = 'Pregnancy Confirmed';
            } else if (eventType == 'ai_done') {
              icon = Icons.biotech;
              iconColor = Colors.teal;
              title = 'Artificial Insemination (AI)';
            } else if (eventType == 'heat_detected') {
              icon = Icons.local_fire_department;
              iconColor = Colors.orange;
              title = 'Heat Detected';
            } else if (eventType == 'calving') {
              icon = Icons.child_care;
              iconColor = Colors.green;
              title = 'Calving Record';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: iconColor.withOpacity(0.12),
                          child: Icon(icon, size: 20, color: iconColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              Text(date, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (bullId != null && bullId.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Bull: $bullId', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                    if (technician != null && technician.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Technician: $technician', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                    if (expCalving != null && expCalving.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Text('Expected Calving: $expCalving', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(notes, style: TextStyle(color: Colors.grey.shade800, fontStyle: FontStyle.italic, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No breeding records available.'),
        ),
      ),
    );
  }
}

class _HealthTab extends ConsumerWidget {
  const _HealthTab({required this.cattleId, required this.dateFormat});
  final String cattleId;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthAsync = ref.watch(cattleHealthTabProvider(cattleId));
    final theme = Theme.of(context);

    return healthAsync.when(
      data: (data) {
        final vaccines = data['vaccines'] as List<Map<String, dynamic>>;
        final records = data['health'] as List<Map<String, dynamic>>;

        if (vaccines.isEmpty && records.isEmpty) {
          return const _PlaceholderTab(
            icon: Icons.medical_services_outlined,
            label: 'No health or vaccination records found.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (vaccines.isNotEmpty) ...[
              Text('Vaccination History', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...vaccines.map((v) {
                final vName = v['vaccine_name'] as String? ?? 'Vaccine';
                final dateGiven = v['date_given'] as String? ?? '';
                final nextDue = v['next_due_date'] as String?;
                final admin = v['administered_by'] as String?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.shield_outlined, color: Colors.green),
                    ),
                    title: Text(vName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Given: $dateGiven ${admin != null ? '• $admin' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        if (nextDue != null && nextDue.isNotEmpty)
                          Text('Next Due: $nextDue', style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (records.isNotEmpty) ...[
              Text('Medical & Routine Checkups', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...records.map((h) {
                final rType = h['record_type'] as String? ?? 'Checkup';
                final date = h['date'] as String? ?? '';
                final diagnosis = h['diagnosis'] as String? ?? '';
                final treatment = h['treatment'] as String? ?? '';
                final notes = h['notes'] as String? ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(rType.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        if (diagnosis.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Diagnosis: $diagnosis', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                        if (treatment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('Treatment: $treatment', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        ],
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(notes, style: TextStyle(color: Colors.grey.shade800, fontStyle: FontStyle.italic, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No health records available.'),
        ),
      ),
    );
  }
}

class _MilkTab extends ConsumerWidget {
  const _MilkTab({required this.cattleId, required this.dateFormat});
  final String cattleId;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milkAsync = ref.watch(cattleMilkTabProvider(cattleId));
    final theme = Theme.of(context);

    return milkAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return const _PlaceholderTab(
            icon: Icons.water_drop_outlined,
            label: 'No milk records found for this animal.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final m = records[index];
            final date = m['date'] as String? ?? '';
            final session = m['session'] as String? ?? 'morning';
            final qty = (m['quantity_litres'] as num?)?.toDouble() ?? 0.0;
            final fat = (m['fat_pct'] as num?)?.toDouble() ?? 0.0;
            final snf = (m['snf_pct'] as num?)?.toDouble() ?? 0.0;
            final rate = (m['price_per_litre'] as num?)?.toDouble() ?? 0.0;
            final total = (m['total_amount'] as num?)?.toDouble() ?? 0.0;
            final buyer = m['buyer_name'] as String? ?? 'Dairy Center';

            final isMorning = session.toLowerCase() == 'morning';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isMorning ? Colors.orange.shade50 : Colors.indigo.shade50,
                      child: Icon(
                        isMorning ? Icons.wb_sunny : Icons.nightlight_round,
                        color: isMorning ? Colors.orange : Colors.indigo,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${isMorning ? 'Morning' : 'Evening'} • $date', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('₹$total', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('$qty Litres • Fat: $fat% • SNF: $snf%', style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                          Text('$buyer • ₹$rate/L', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No milk records available.'),
        ),
      ),
    );
  }
}
