import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';

/// Displays the AI triage result with severity indicator, diagnosis,
/// recommended actions, confidence score, and a "Call Vet" button
/// when severity is high.
class TriageResultScreen extends ConsumerWidget {
  const TriageResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triageState = ref.watch(triageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Triage Result'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(triageProvider.notifier).clear();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: _buildBody(context, ref, triageState),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, TriageState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 20),
            Text('Running AI diagnosis...'),
            SizedBox(height: 8),
            Text(
              'Analyzing symptoms and cattle history',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 64, color: context.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Triage Failed',
                style: context.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colorScheme.error),
              ),
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final result = state.result;
    if (result == null) {
      return const Center(child: Text('No triage data available.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- Severity indicator ---
        _SeverityCard(severity: result.severity),
        const SizedBox(height: 24),

        // --- Confidence score ---
        _ConfidenceIndicator(score: result.confidenceScore),
        const SizedBox(height: 24),

        // --- AI Diagnosis ---
        Text(
          'AI Diagnosis',
          style: context.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              result.diagnosis,
              style: context.textTheme.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // --- Recommended actions ---
        Text(
          'Recommended Actions',
          style: context.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...result.recommendedActions.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: context.colorScheme.primaryContainer,
                  child: Text(
                    '${entry.key + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.colorScheme.primary,
                    ),
                  ),
                ),
                title: Text(entry.value),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),

        // --- Call Vet button (if severity is high) ---
        if (result.severity == TriageSeverity.high) ...[
          FilledButton.icon(
            onPressed: () {
              // Navigate to vet consultation booking.
              Navigator.of(context).pushNamed('/vet/book',
                  arguments: {'cattle_id': result.cattleId});
            },
            icon: const Icon(Icons.phone),
            label: const Text('Call Vet Now'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'High severity detected. We strongly recommend consulting a veterinarian immediately.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Done button ---
        OutlinedButton(
          onPressed: () {
            ref.read(triageProvider.notifier).clear();
            Navigator.of(context).pop();
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text('Done'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Severity card with color indicator
// ---------------------------------------------------------------------------
class _SeverityCard extends StatelessWidget {
  final TriageSeverity severity;
  const _SeverityCard({required this.severity});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;
    final String description;

    switch (severity) {
      case TriageSeverity.low:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Low Severity';
        description = 'Condition appears manageable with basic care.';
        break;
      case TriageSeverity.medium:
        color = Colors.orange;
        icon = Icons.warning_amber_rounded;
        label = 'Medium Severity';
        description = 'Monitor closely. Consult a vet if symptoms worsen.';
        break;
      case TriageSeverity.high:
        color = Colors.red;
        icon = Icons.dangerous;
        label = 'High Severity';
        description = 'Urgent attention needed. Contact a vet immediately.';
        break;
    }

    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: color, size: 56),
            const SizedBox(height: 12),
            Text(
              label,
              style: context.textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium?.copyWith(
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confidence score indicator
// ---------------------------------------------------------------------------
class _ConfidenceIndicator extends StatelessWidget {
  final double score;
  const _ConfidenceIndicator({required this.score});

  @override
  Widget build(BuildContext context) {
    final pct = (score * 100).round();
    final color = pct >= 80
        ? Colors.green
        : pct >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score,
                    strokeWidth: 5,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                  Center(
                    child: Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Confidence',
                    style: context.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pct >= 80
                        ? 'High confidence in this assessment'
                        : pct >= 50
                            ? 'Moderate confidence - vet review recommended'
                            : 'Low confidence - please consult a vet',
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
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
