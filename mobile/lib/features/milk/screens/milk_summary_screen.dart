import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/milk/models/milk_models.dart';
import 'package:dairy_ai/features/milk/providers/milk_provider.dart';

/// Milk analytics screen with daily/weekly/monthly totals,
/// a production bar chart, per-cattle breakdown, and revenue summary.
class MilkSummaryScreen extends ConsumerWidget {
  const MilkSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(milkPeriodProvider);
    final summaryAsync = ref.watch(milkSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(milkSummaryProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<MilkPeriod>(
              segments: const [
                ButtonSegment(
                    value: MilkPeriod.daily, label: Text('Daily')),
                ButtonSegment(
                    value: MilkPeriod.weekly, label: Text('Weekly')),
                ButtonSegment(
                    value: MilkPeriod.monthly, label: Text('Monthly')),
              ],
              selected: {period},
              onSelectionChanged: (s) =>
                  ref.read(milkPeriodProvider.notifier).state = s.first,
              showSelectedIcon: false,
            ),
          ),

          Expanded(
            child: summaryAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: context.colorScheme.error),
                      const SizedBox(height: 12),
                      Text('Failed to load analytics',
                          style: context.textTheme.bodyLarge),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () =>
                            ref.invalidate(milkSummaryProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (summary) => _SummaryContent(summary: summary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  final MilkSummary summary;
  const _SummaryContent({required this.summary});

  @override
  Widget build(BuildContext context) {
    final rupeeFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs ',
      decimalDigits: 0,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Top stat cards ---
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Milk',
                value: '${summary.totalLitres.toStringAsFixed(1)} L',
                icon: Icons.water_drop,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Revenue',
                value: rupeeFormat.format(summary.totalRevenue),
                icon: Icons.currency_rupee,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Avg Fat',
                value: '${summary.avgFatPct.toStringAsFixed(1)}%',
                icon: Icons.science,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Avg SNF',
                value: '${summary.avgSnfPct.toStringAsFixed(1)}%',
                icon: Icons.science_outlined,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // --- Bar chart ---
        Text(
          'Daily Production',
          style: context.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: summary.dailyEntries.isEmpty
              ? Center(
                  child: Text(
                    'No data to display',
                    style: context.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey),
                  ),
                )
              : _MilkBarChart(entries: summary.dailyEntries),
        ),
        const SizedBox(height: 24),

        // --- Per-cattle breakdown ---
        Text(
          'Per-Cattle Breakdown',
          style: context.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (summary.cattleBreakdown.isEmpty)
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('No cattle data available')),
            ),
          )
        else
          ...summary.cattleBreakdown.map(
            (cb) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      context.colorScheme.primaryContainer,
                  child: Text(
                    cb.cattleName.isNotEmpty
                        ? cb.cattleName[0].toUpperCase()
                        : '#',
                    style: TextStyle(
                      color: context.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  cb.cattleTagId != null
                      ? '${cb.cattleName} (${cb.cattleTagId})'
                      : cb.cattleName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                    'Avg ${cb.avgDaily.toStringAsFixed(1)} L/day'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${cb.totalLitres.toStringAsFixed(1)} L',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      rupeeFormat.format(cb.totalRevenue),
                      style: context.textTheme.bodySmall
                          ?.copyWith(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card
// ---------------------------------------------------------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: context.textTheme.bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: context.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simple bar chart using CustomPainter (no external dependency needed)
// ---------------------------------------------------------------------------
class _MilkBarChart extends StatelessWidget {
  final List<DailyMilkEntry> entries;
  const _MilkBarChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BarChartPainter(
        entries: entries,
        barColor: context.colorScheme.primary,
        labelColor: context.colorScheme.onSurface.withOpacity(0.6),
        gridColor: Colors.grey.withOpacity(0.15),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyMilkEntry> entries;
  final Color barColor;
  final Color labelColor;
  final Color gridColor;

  _BarChartPainter({
    required this.entries,
    required this.barColor,
    required this.labelColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    const bottomPadding = 28.0;
    const topPadding = 16.0;
    const leftPadding = 36.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final chartWidth = size.width - leftPadding;

    final maxVal = entries.map((e) => e.litres).reduce(math.max);
    final yMax = maxVal > 0 ? maxVal * 1.15 : 10.0;

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final gridCount = 4;
    for (var i = 0; i <= gridCount; i++) {
      final y = topPadding + chartHeight * (1 - i / gridCount);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        gridPaint,
      );
      // Y-axis label
      final labelVal = (yMax * i / gridCount).toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(
          text: labelVal,
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPadding - tp.width - 4, y - tp.height / 2));
    }

    // Bars
    final barCount = entries.length;
    final totalBarSpace = chartWidth;
    final barWidth =
        (totalBarSpace / barCount * 0.6).clamp(4.0, 32.0);
    final spacing = totalBarSpace / barCount;

    final barPaint = Paint()..color = barColor;
    final dateFormat = DateFormat('dd/MM');

    for (var i = 0; i < barCount; i++) {
      final entry = entries[i];
      final barHeight = (entry.litres / yMax) * chartHeight;
      final x = leftPadding + spacing * i + (spacing - barWidth) / 2;
      final y = topPadding + chartHeight - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, barPaint);

      // X-axis label (show every Nth label if too many)
      final showLabel = barCount <= 14 || i % (barCount ~/ 7 + 1) == 0;
      if (showLabel) {
        final label = dateFormat.format(entry.date);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 9, color: labelColor),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            x + barWidth / 2 - tp.width / 2,
            topPadding + chartHeight + 6,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      entries != oldDelegate.entries;
}
