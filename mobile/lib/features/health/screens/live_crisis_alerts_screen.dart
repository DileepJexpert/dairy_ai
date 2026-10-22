import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dairy_ai/features/health/providers/active_crises_provider.dart';

/// Live alerts for the signed-in farmer's own cattle only.
/// Shows an empty state when there are no real events.
class LiveCrisisAlertsScreen extends ConsumerWidget {
  const LiveCrisisAlertsScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeCrisesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _back(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xfff8fafc),
        appBar: AppBar(
          title: const Text('Health Alerts (ICU Telemetry)'),
          backgroundColor: const Color(0xff991b1b),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Home',
            onPressed: () => _back(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(activeCrisesProvider),
            ),
          ],
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load alerts: $e')),
          data: (data) {
            if (data.crises.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 56, color: Colors.green),
                      SizedBox(height: 12),
                      Text('No active alerts',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text(
                        'Alerts appear here when your own cattle send abnormal collar readings.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final cr in data.crises) _CrisisTile(crisis: cr),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CrisisTile extends StatelessWidget {
  final CattleCrisis crisis;
  const _CrisisTile({required this.crisis});

  @override
  Widget build(BuildContext context) {
    final color = crisis.isCritical ? const Color(0xffdc2626) : const Color(0xffea580c);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${crisis.cattleName} (#${crisis.tagId})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Text(crisis.isCritical ? 'CRITICAL' : 'WARNING',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            for (final a in crisis.alerts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text('• ${a.message}  (${a.createdAt})',
                    style: const TextStyle(fontSize: 13)),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => context.push('/herd/${crisis.cattleId}/sensors?name=${Uri.encodeComponent(crisis.cattleName)}'),
                child: const Text('View live sensors'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
