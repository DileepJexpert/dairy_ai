import 'package:flutter/material.dart';
import '../models/milk_purity_models.dart';

class ScoreBreakdownCard extends StatelessWidget {
  final ScoreDetail score;

  const ScoreBreakdownCard({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Score Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _ScoreRow(
              label: 'Fat Accuracy',
              score: score.fatAccuracyScore,
              weight: '20%',
            ),
            _ScoreRow(
              label: 'SNF Compliance',
              score: score.snfComplianceScore,
              weight: '15%',
            ),
            _ScoreRow(
              label: 'Adulteration',
              score: score.adulterationScore,
              weight: '30%',
            ),
            _ScoreRow(
              label: 'Bacterial Safety',
              score: score.bacterialScore,
              weight: '20%',
            ),
            _ScoreRow(
              label: 'FSSAI Compliance',
              score: score.fssaiComplianceScore,
              weight: '15%',
            ),
            if (score.hasLimitedData) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Limited data available (${score.dataSourcesCount} source${score.dataSourcesCount == 1 ? '' : 's'})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  final String weight;

  const _ScoreRow({
    required this.label,
    required this.score,
    required this.weight,
  });

  Color get _barColor {
    if (score >= 85) return const Color(0xFF2E7D32);
    if (score >= 70) return const Color(0xFFF9A825);
    if (score >= 50) return const Color(0xFFEF6C00);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                '${score.toStringAsFixed(0)}/100  ($weight)',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: _barColor.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(_barColor),
            ),
          ),
        ],
      ),
    );
  }
}
