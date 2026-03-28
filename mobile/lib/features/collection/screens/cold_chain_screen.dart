import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/core/extensions.dart';
import '../models/collection_models.dart';
import '../providers/collection_provider.dart';

/// Two-tab screen for cold chain management:
/// - Tab 1: Record a temperature reading.
/// - Tab 2: View alerts with severity colour coding.
class ColdChainScreen extends ConsumerStatefulWidget {
  const ColdChainScreen({super.key, required this.centerId});

  final String centerId;

  @override
  ConsumerState<ColdChainScreen> createState() => _ColdChainScreenState();
}

class _ColdChainScreenState extends ConsumerState<ColdChainScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cold Chain'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.thermostat), text: 'Record'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Alerts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RecordReadingTab(centerId: widget.centerId),
          _AlertsTab(centerId: widget.centerId),
        ],
      ),
    );
  }
}

// =============================================================================
// Tab 1: Record reading
// =============================================================================

class _RecordReadingTab extends ConsumerStatefulWidget {
  const _RecordReadingTab({required this.centerId});

  final String centerId;

  @override
  ConsumerState<_RecordReadingTab> createState() => _RecordReadingTabState();
}

class _RecordReadingTabState extends ConsumerState<_RecordReadingTab> {
  final _formKey = GlobalKey<FormState>();
  final _tempController = TextEditingController();
  bool _isSubmitting = false;
  ColdChainReading? _result;

  @override
  void dispose() {
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(collectionActionProvider.notifier);
      final reading = await notifier.recordColdChain({
        'center_id': widget.centerId,
        'temperature_celsius': double.parse(_tempController.text.trim()),
      });

      if (mounted) {
        setState(() => _result = reading);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _reset() {
    _tempController.clear();
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ReadingResult(
        reading: _result!,
        onRecordAnother: _reset,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Illustration area
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: DairyTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.thermostat,
                  size: 48,
                  color: DairyTheme.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Record Temperature',
              style: context.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter the current chilling unit temperature reading.',
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Temperature input
            TextFormField(
              controller: _tempController,
              decoration: const InputDecoration(
                labelText: 'Temperature (\u00B0C)',
                hintText: 'e.g., 4.0',
                prefixIcon: Icon(Icons.thermostat),
                suffixText: '\u00B0C',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter temperature';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Submit Reading'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Reading result
// =============================================================================

class _ReadingResult extends StatelessWidget {
  const _ReadingResult({
    required this.reading,
    required this.onRecordAnother,
  });

  final ColdChainReading reading;
  final VoidCallback onRecordAnother;

  @override
  Widget build(BuildContext context) {
    final isAlert = reading.isAlert;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAlert ? Icons.warning_amber : Icons.check_circle,
              size: 64,
              color: isAlert ? DairyTheme.errorRed : DairyTheme.primaryGreen,
            ),
            const SizedBox(height: 16),
            Text(
              '${reading.temperatureCelsius.toStringAsFixed(1)}\u00B0C',
              style: context.textTheme.headlineLarge?.copyWith(
                color:
                    isAlert ? DairyTheme.errorRed : DairyTheme.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAlert ? 'Temperature alert triggered!' : 'Temperature normal',
              style: context.textTheme.titleMedium?.copyWith(
                color:
                    isAlert ? DairyTheme.errorRed : DairyTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRecordAnother,
              icon: const Icon(Icons.refresh),
              label: const Text('Record Another'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 2: Alerts list
// =============================================================================

class _AlertsTab extends ConsumerWidget {
  const _AlertsTab({required this.centerId});

  final String centerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(coldChainAlertsProvider(centerId));

    return alertsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: context.colorScheme.error),
              const SizedBox(height: 16),
              Text(err.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    ref.invalidate(coldChainAlertsProvider(centerId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (alerts) {
        if (alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    size: 64, color: DairyTheme.primaryGreen.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'No alerts',
                  style: context.textTheme.titleMedium
                      ?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Text(
                  'All cold chain readings are within safe limits.',
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(coldChainAlertsProvider(centerId)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              return _AlertCard(alert: alerts[index]);
            },
          ),
        );
      },
    );
  }
}

// =============================================================================
// Alert card
// =============================================================================

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final ColdChainAlert alert;

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color iconColor;
    IconData iconData;

    switch (alert.severity) {
      case 'critical':
        borderColor = DairyTheme.errorRed;
        iconColor = DairyTheme.errorRed;
        iconData = Icons.error;
        break;
      case 'warning':
        borderColor = Colors.amber.shade700;
        iconColor = Colors.amber.shade700;
        iconData = Icons.warning_amber;
        break;
      default: // info
        borderColor = Colors.blue;
        iconColor = Colors.blue;
        iconData = Icons.info_outline;
    }

    // Format the timestamp.
    String formattedTime;
    try {
      final dt = DateTime.parse(alert.createdAt);
      formattedTime = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      formattedTime = alert.createdAt;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconData, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Severity + status row
                  Row(
                    children: [
                      _SeverityChip(severity: alert.severity),
                      const SizedBox(width: 8),
                      _StatusChip(status: alert.status),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Temperature
                  Text(
                    '${alert.temperatureCelsius.toStringAsFixed(1)}\u00B0C',
                    style: context.textTheme.titleLarge?.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Message
                  if (alert.message != null)
                    Text(
                      alert.message!,
                      style: context.textTheme.bodyMedium,
                    ),
                  const SizedBox(height: 4),

                  // Timestamp
                  Text(
                    formattedTime,
                    style: context.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Severity chip
// =============================================================================

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (severity) {
      case 'critical':
        bg = DairyTheme.errorRed.withOpacity(0.12);
        fg = DairyTheme.errorRed;
        break;
      case 'warning':
        bg = Colors.amber.withOpacity(0.12);
        fg = Colors.amber.shade800;
        break;
      default:
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        severity.toUpperCase(),
        style: context.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

// =============================================================================
// Status chip
// =============================================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'resolved':
        bg = DairyTheme.primaryGreen.withOpacity(0.12);
        fg = DairyTheme.primaryGreen;
        break;
      case 'acknowledged':
        bg = Colors.blue.withOpacity(0.12);
        fg = Colors.blue;
        break;
      default: // active
        bg = DairyTheme.accentOrange.withOpacity(0.12);
        fg = DairyTheme.accentOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: context.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
