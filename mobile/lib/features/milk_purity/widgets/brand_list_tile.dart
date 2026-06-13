import 'package:flutter/material.dart';
import '../models/milk_purity_models.dart';
import 'score_badge.dart';

class BrandListTile extends StatelessWidget {
  final BrandSummary brand;
  final int? rank;
  final VoidCallback? onTap;

  const BrandListTile({
    super.key,
    required this.brand,
    this.rank,
    this.onTap,
  });

  String _variantLabel(String variant) {
    return variant.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (rank != null)
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (brand.parentCompany != null) ...[
                          Text(
                            brand.parentCompany!,
                            style: theme.textTheme.bodySmall,
                          ),
                          const Text(' · ',
                              style: TextStyle(color: Colors.grey)),
                        ],
                        Text(
                          _variantLabel(brand.variant),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (brand.overallScore != null && brand.band != null)
                ScoreBadge(
                  score: brand.overallScore!,
                  band: brand.band!,
                  size: 48,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
