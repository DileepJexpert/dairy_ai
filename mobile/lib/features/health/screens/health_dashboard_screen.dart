import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';

/// Health overview dashboard showing active issues, upcoming vaccinations,
/// sensor alerts, and a quick-access button for AI triage.
class HealthDashboardScreen extends ConsumerWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(activeHealthIssuesProvider);
              ref.invalidate(upcomingVaccinationsProvider);
              ref.invalidate(sensorAlertsProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeHealthIssuesProvider);
          ref.invalidate(upcomingVaccinationsProvider);
          ref.invalidate(sensorAlertsProvider);
          // Allow the providers to refetch.
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- AI Triage Quick Access ---
            _TriageQuickAccessCard(),
            const SizedBox(height: 20),

            // --- Sensor Alerts ---
            const _SectionHeader(
              title: 'Sensor Alerts',
              icon: Icons.sensors,
              iconColor: Colors.orange,
            ),
            const SizedBox(height: 8),
            _SensorAlertsSection(),
            const SizedBox(height: 20),

            // --- Active Health Issues ---
            const _SectionHeader(
              title: 'Active Health Issues',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.red,
            ),
            const SizedBox(height: 8),
            _ActiveIssuesSection(),
            const SizedBox(height: 16),

            // --- Agri-Hub Herd Care Supplies ---
            const _AgriHubHerdCareBanner(),
            const SizedBox(height: 20),

            // --- Upcoming Vaccinations ---
            const _SectionHeader(
              title: 'Upcoming Vaccinations',
              icon: Icons.vaccines,
              iconColor: Colors.blue,
            ),
            const SizedBox(height: 8),
            _UpcomingVaccinationsSection(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).pushNamed('/health/add-record');
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Record'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AI Triage quick-access card
// ---------------------------------------------------------------------------
class _TriageQuickAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).pushNamed('/health/add-record');
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.medical_services,
                  color: context.colorScheme.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Health Triage',
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Report symptoms and get instant AI diagnosis',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: context.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sensor alerts section
// ---------------------------------------------------------------------------
class _SensorAlertsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(sensorAlertsProvider);

    return alertsAsync.when(
      loading: () => const _ShimmerPlaceholder(height: 80),
      error: (err, _) => const _ErrorTile(message: 'Could not load sensor alerts'),
      data: (alerts) {
        if (alerts.isEmpty) {
          return const _EmptyTile(
            icon: Icons.check_circle_outline,
            message: 'No sensor alerts. All cattle vitals are normal.',
          );
        }
        return Column(
          children: alerts.map((alert) => _SensorAlertTile(alert: alert)).toList(),
        );
      },
    );
  }
}

class _SensorAlertTile extends StatelessWidget {
  final SensorAlert alert;
  const _SensorAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isTemp = alert.alertType == 'high_temp';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isTemp ? Colors.red : Colors.orange).withValues(alpha: 0.15),
          child: Icon(
            isTemp ? Icons.thermostat : Icons.monitor_heart,
            color: isTemp ? Colors.red : Colors.orange,
          ),
        ),
        title: Text(
          alert.cattleName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${alert.alertLabel}: ${alert.value.toStringAsFixed(1)} ${alert.unit}',
        ),
        trailing: Text(
          _timeAgo(alert.timestamp),
          style: context.textTheme.bodySmall,
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Active health issues section
// ---------------------------------------------------------------------------
class _ActiveIssuesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(activeHealthIssuesProvider);

    return issuesAsync.when(
      loading: () => const _ShimmerPlaceholder(height: 80),
      error: (err, _) => const _ErrorTile(message: 'Could not load health issues'),
      data: (issues) {
        if (issues.isEmpty) {
          return const _EmptyTile(
            icon: Icons.favorite,
            message: 'No active health issues. Great job!',
          );
        }
        return Column(
          children: issues.map((record) => _HealthIssueTile(record: record)).toList(),
        );
      },
    );
  }
}

class _HealthIssueTile extends StatelessWidget {
  final HealthRecord record;
  const _HealthIssueTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withValues(alpha: 0.15),
          child: const Icon(Icons.sick, color: Colors.red),
        ),
        title: Text(
          record.cattleName ?? 'Cattle #${record.cattleId}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          record.symptoms.isNotEmpty
              ? record.symptoms.join(', ')
              : record.type.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _TypeChip(type: record.type),
        onTap: () {
          // Navigate to health record detail if needed.
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final HealthRecordType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (type) {
      case HealthRecordType.illness:
        bg = Colors.red;
        break;
      case HealthRecordType.surgery:
        bg = Colors.purple;
        break;
      case HealthRecordType.treatment:
        bg = Colors.orange;
        break;
      case HealthRecordType.checkup:
        bg = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.name[0].toUpperCase() + type.name.substring(1),
        style: TextStyle(fontSize: 11, color: bg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming vaccinations section
// ---------------------------------------------------------------------------
class _UpcomingVaccinationsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacAsync = ref.watch(upcomingVaccinationsProvider);

    return vacAsync.when(
      loading: () => const _ShimmerPlaceholder(height: 80),
      error: (err, _) =>
          const _ErrorTile(message: 'Could not load vaccination schedule'),
      data: (vaccinations) {
        if (vaccinations.isEmpty) {
          return const _EmptyTile(
            icon: Icons.vaccines,
            message: 'No upcoming vaccinations.',
          );
        }
        return Column(
          children: vaccinations
              .map((v) => _VaccinationTile(vaccination: v))
              .toList(),
        );
      },
    );
  }
}

class _VaccinationTile extends StatelessWidget {
  final Vaccination vaccination;
  const _VaccinationTile({required this.vaccination});

  @override
  Widget build(BuildContext context) {
    final isOverdue = vaccination.isOverdue;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.15),
          child: Icon(
            Icons.vaccines,
            color: isOverdue ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          vaccination.cattleName ?? 'Cattle #${vaccination.cattleId}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(vaccination.vaccineName),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isOverdue ? 'OVERDUE' : 'Upcoming',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOverdue ? Colors.red : Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------
class _EmptyTile extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTile({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: context.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  const _ErrorTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: context.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: context.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  final double height;
  const _ShimmerPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class _AgriHubHerdCareBanner extends StatelessWidget {
  const _AgriHubHerdCareBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff5f8f5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xff1b4332).withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff1b4332).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Color(0xff1b4332),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milterra Agri-Hub Veterinary & Care Supplies',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1b4332),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Emergency drench, mineral nutrition & hygiene supplies',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep your herd protected. Rapid delivery of high-potency oral calcium, chelated trace minerals with live yeast, and herbal udder hygiene solutions.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xff333333),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(
                  Icons.local_pharmacy,
                  size: 16,
                  color: Color(0xff1b4332),
                ),
                label: const Text('Cal-Gold Drench (₹1,150)'),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b4332),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: const Color(0xff1b4332).withValues(alpha: 0.3),
                  ),
                ),
                onPressed: () => context.push('/shop/product/feed-calcium-5l'),
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Color(0xff1b4332),
                ),
                label: const Text('Chelated Minerals (₹890)'),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b4332),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: const Color(0xff1b4332).withValues(alpha: 0.3),
                  ),
                ),
                onPressed: () => context.push('/shop/product/feed-mineral-5'),
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.storefront,
                  size: 16,
                  color: Color(0xff1b4332),
                ),
                label: const Text('All Farm Essentials →'),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b4332),
                ),
                backgroundColor: const Color(0xff1b4332).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: const Color(0xff1b4332).withValues(alpha: 0.4),
                  ),
                ),
                onPressed: () => context.push('/shop?category=Animal nutrition'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
