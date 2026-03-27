import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            _SectionHeader(
              title: 'Sensor Alerts',
              icon: Icons.sensors,
              iconColor: Colors.orange,
            ),
            const SizedBox(height: 8),
            _SensorAlertsSection(),
            const SizedBox(height: 20),

            // --- Active Health Issues ---
            _SectionHeader(
              title: 'Active Health Issues',
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.red,
            ),
            const SizedBox(height: 8),
            _ActiveIssuesSection(),
            const SizedBox(height: 20),

            // --- Upcoming Vaccinations ---
            _SectionHeader(
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
                            .withOpacity(0.8),
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
      error: (err, _) => _ErrorTile(message: 'Could not load sensor alerts'),
      data: (alerts) {
        if (alerts.isEmpty) {
          return _EmptyTile(
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
          backgroundColor: (isTemp ? Colors.red : Colors.orange).withOpacity(0.15),
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
      error: (err, _) => _ErrorTile(message: 'Could not load health issues'),
      data: (issues) {
        if (issues.isEmpty) {
          return _EmptyTile(
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
          backgroundColor: Colors.red.withOpacity(0.15),
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
        color: bg.withOpacity(0.15),
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
          _ErrorTile(message: 'Could not load vaccination schedule'),
      data: (vaccinations) {
        if (vaccinations.isEmpty) {
          return _EmptyTile(
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
              (isOverdue ? Colors.red : Colors.blue).withOpacity(0.15),
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
            color: (isOverdue ? Colors.red : Colors.blue).withOpacity(0.15),
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
