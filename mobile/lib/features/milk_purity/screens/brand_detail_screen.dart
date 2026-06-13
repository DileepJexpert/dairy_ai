import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/milk_purity_provider.dart';
import '../widgets/score_badge.dart';
import '../widgets/score_breakdown_card.dart';

class BrandDetailScreen extends ConsumerWidget {
  final String brandSlug;

  const BrandDetailScreen({super.key, required this.brandSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(brandScoreProvider(brandSlug));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Brand Score')),
      body: scoreAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('Brand not found',
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(brandScoreProvider(brandSlug)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final brand = data.brand;
          final score = data.score;

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(brandScoreProvider(brandSlug)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Brand header + score
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    brand.name,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (brand.parentCompany != null)
                                    Text(
                                      brand.parentCompany!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      _Chip(
                                          label: brand.variant
                                              .replaceAll('_', ' ')),
                                      if (brand.labelFatPct != null)
                                        _Chip(
                                            label:
                                                'Fat: ${brand.labelFatPct}%'),
                                      if (brand.labelSnfPct != null)
                                        _Chip(
                                            label:
                                                'SNF: ${brand.labelSnfPct}%'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ScoreBadge(
                              score: score.overallScore,
                              band: score.band,
                              size: 80,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Score breakdown
                ScoreBreakdownCard(score: score),

                const SizedBox(height: 12),

                // Lab reports
                if (data.labReports.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lab Reports (${data.labReports.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...data.labReports.map((report) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.science,
                                      size: 18,
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            report.labName,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            report.reportDate,
                                            style:
                                                theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (report.ureaDetected ||
                                        report.detergentDetected)
                                      const Icon(Icons.warning_amber,
                                          color: Colors.red, size: 18)
                                    else
                                      Icon(Icons.check_circle,
                                          color: Colors.green.shade600,
                                          size: 18),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Violations
                if (data.violations.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.gavel,
                                  size: 20, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                'FSSAI Violations (${data.violations.length})',
                                style:
                                    theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...data.violations.map((v) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    _SeverityDot(severity: v.severity),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            v.violationType,
                                            style:
                                                theme.textTheme.bodyMedium,
                                          ),
                                          Text(
                                            '${v.violationDate} · ${v.severity}',
                                            style:
                                                theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Disclaimer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'This score is an informational assessment based on publicly '
                    'available data and independently commissioned lab reports. '
                    'It is not a certification.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  Color get _color {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'major':
        return Colors.orange;
      case 'minor':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }
}
