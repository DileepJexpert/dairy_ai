import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/admin/models/admin_models.dart';
import 'package:dairy_ai/features/admin/providers/admin_provider.dart';

/// Analytics dashboard with registration trends, milk production,
/// consultation stats, and revenue summary.
class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(adminAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: analyticsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load analytics',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(adminAnalyticsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (analytics) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminAnalyticsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------- Registration trends ----------
              _SectionHeader(title: 'Registration Trends'),
              const SizedBox(height: 12),
              _RegistrationTrendsChart(
                  trends: analytics.registrationTrends),
              const SizedBox(height: 24),

              // ---------- Milk production trends ----------
              _SectionHeader(title: 'Milk Production Trends'),
              const SizedBox(height: 12),
              _MilkTrendsChart(trends: analytics.milkTrends),
              const SizedBox(height: 24),

              // ---------- Consultation stats ----------
              _SectionHeader(title: 'Consultation Stats'),
              const SizedBox(height: 12),
              _ConsultationStatsCard(
                  stats: analytics.consultationStats),
              const SizedBox(height: 24),

              // ---------- Revenue summary ----------
              _SectionHeader(title: 'Revenue Summary'),
              const SizedBox(height: 12),
              _RevenueSummaryCard(
                totalRevenue: analytics.totalRevenue,
                consultationRevenue:
                    analytics.consultationStats.totalRevenue,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header.
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

// ---------------------------------------------------------------------------
// Registration trends bar chart.
// ---------------------------------------------------------------------------
class _RegistrationTrendsChart extends StatelessWidget {
  final List<RegistrationTrend> trends;

  const _RegistrationTrendsChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return _EmptyChartCard(message: 'No registration data available');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend.
            Row(
              children: [
                _LegendDot(
                    color: DairyTheme.primaryGreen, label: 'Farmers'),
                const SizedBox(width: 16),
                _LegendDot(
                    color: DairyTheme.accentOrange, label: 'Cattle'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _GroupedBarChartPainter(
                  labels: trends.map((t) => t.month).toList(),
                  series: [
                    trends.map((t) => t.farmerCount.toDouble()).toList(),
                    trends.map((t) => t.cattleCount.toDouble()).toList(),
                  ],
                  colors: [
                    DairyTheme.primaryGreen,
                    DairyTheme.accentOrange,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Milk trends bar chart.
// ---------------------------------------------------------------------------
class _MilkTrendsChart extends StatelessWidget {
  final List<MilkTrend> trends;

  const _MilkTrendsChart({required this.trends});

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return _EmptyChartCard(message: 'No milk production data available');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _LegendDot(color: Colors.teal, label: 'Litres'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: _GroupedBarChartPainter(
                  labels: trends.map((t) => t.month).toList(),
                  series: [
                    trends.map((t) => t.totalLitres).toList(),
                  ],
                  colors: [Colors.teal],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Avg fat % summary.
            if (trends.isNotEmpty)
              Text(
                'Avg Fat %: ${(trends.map((t) => t.avgFatPct).reduce((a, b) => a + b) / trends.length).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consultation stats card.
// ---------------------------------------------------------------------------
class _ConsultationStatsCard extends StatelessWidget {
  final ConsultationStats stats;

  const _ConsultationStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary row.
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Total',
                    value: '${stats.totalConsultations}',
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Completed',
                    value: '${stats.completedConsultations}',
                    color: DairyTheme.primaryGreen,
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Avg Rating',
                    value: stats.avgRating.toStringAsFixed(1),
                    color: DairyTheme.accentOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // By type.
            if (stats.byType.isNotEmpty) ...[
              Text('By Type', style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: stats.byType.entries.map((e) {
                  return Chip(
                    label: Text('${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.blue.withOpacity(0.08),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // By severity.
            if (stats.bySeverity.isNotEmpty) ...[
              Text('By Severity', style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: stats.bySeverity.entries.map((e) {
                  final color = e.key == 'high'
                      ? Colors.red
                      : e.key == 'medium'
                          ? Colors.orange
                          : DairyTheme.primaryGreen;
                  return Chip(
                    label: Text('${e.key}: ${e.value}',
                        style: TextStyle(fontSize: 12, color: color)),
                    backgroundColor: color.withOpacity(0.08),
                    side: BorderSide.none,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Revenue summary card.
// ---------------------------------------------------------------------------
class _RevenueSummaryCard extends StatelessWidget {
  final double totalRevenue;
  final double consultationRevenue;

  const _RevenueSummaryCard({
    required this.totalRevenue,
    required this.consultationRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Revenue',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(totalRevenue),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: DairyTheme.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Consultation Revenue',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(consultationRevenue),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

// ---------------------------------------------------------------------------
// Reusable small stat tile.
// ---------------------------------------------------------------------------
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Legend dot.
// ---------------------------------------------------------------------------
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty chart placeholder.
// ---------------------------------------------------------------------------
class _EmptyChartCard extends StatelessWidget {
  final String message;

  const _EmptyChartCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 160,
        child: Center(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: DairyTheme.subtleGrey),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped bar chart using CustomPaint.
// ---------------------------------------------------------------------------
class _GroupedBarChartPainter extends CustomPainter {
  final List<String> labels;
  final List<List<double>> series;
  final List<Color> colors;

  _GroupedBarChartPainter({
    required this.labels,
    required this.series,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty || series.isEmpty) return;

    final seriesCount = series.length;
    final itemCount = labels.length;

    // Find max value across all series.
    double maxValue = 0;
    for (final s in series) {
      for (final v in s) {
        if (v > maxValue) maxValue = v;
      }
    }
    if (maxValue == 0) maxValue = 1;

    final chartHeight = size.height - 30;
    final groupWidth = (size.width - 20) / itemCount;
    final barWidth = math.min(
        (groupWidth - 10) / seriesCount, 28.0);

    // Draw horizontal grid lines.
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final y = chartHeight * (1 - i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw axis.
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      axisPaint,
    );

    // Draw bars.
    for (var i = 0; i < itemCount; i++) {
      final groupX = 10 + groupWidth * i;

      for (var s = 0; s < seriesCount; s++) {
        final value = i < series[s].length ? series[s][i] : 0.0;
        final barHeight = (value / maxValue) * (chartHeight - 10);
        final x = groupX + (groupWidth - barWidth * seriesCount) / 2 +
            barWidth * s;
        final y = chartHeight - barHeight;

        final paint = Paint()..color = colors[s % colors.length];
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth - 2, barHeight),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, paint);

        // Value label above bar.
        if (value > 0) {
          final span = TextSpan(
            text: value >= 1000
                ? '${(value / 1000).toStringAsFixed(1)}k'
                : value.toInt().toString(),
            style: TextStyle(
              color: colors[s % colors.length],
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          );
          final tp = TextPainter(
            text: span,
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas,
              Offset(x + (barWidth - 2) / 2 - tp.width / 2, y - 14));
        }
      }

      // Label below.
      final labelSpan = TextSpan(
        text: labels[i].length > 3
            ? labels[i].substring(0, 3)
            : labels[i],
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      final labelPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(
            groupX + groupWidth / 2 - labelPainter.width / 2,
            chartHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GroupedBarChartPainter oldDelegate) {
    return oldDelegate.labels != labels || oldDelegate.series != series;
  }
}
