import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/milk_purity_provider.dart';
import '../models/milk_purity_models.dart';
import '../widgets/score_badge.dart';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  BrandSummary? _brandA;
  BrandSummary? _brandB;
  bool _comparing = false;
  CompareResult? _result;
  String? _error;

  Future<void> _compare() async {
    if (_brandA == null || _brandB == null) return;
    setState(() {
      _comparing = true;
      _error = null;
    });
    try {
      final repo = ref.read(milkPurityRepoProvider);
      final result =
          await repo.compareBrands(_brandA!.slug, _brandB!.slug);
      setState(() {
        _result = result;
        _comparing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not compare brands';
        _comparing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Brands')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Brand selectors
          Row(
            children: [
              Expanded(
                child: _BrandSelector(
                  label: 'Brand A',
                  selected: _brandA,
                  onSelected: (b) => setState(() => _brandA = b),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: _BrandSelector(
                  label: 'Brand B',
                  selected: _brandB,
                  onSelected: (b) => setState(() => _brandB = b),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          FilledButton(
            onPressed: _brandA != null && _brandB != null && !_comparing
                ? _compare
                : null,
            child: _comparing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Compare'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],

          if (_result != null) ...[
            const SizedBox(height: 24),
            _ComparisonTable(result: _result!),
          ],
        ],
      ),
    );
  }
}

class _BrandSelector extends ConsumerStatefulWidget {
  final String label;
  final BrandSummary? selected;
  final ValueChanged<BrandSummary?> onSelected;

  const _BrandSelector({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  ConsumerState<_BrandSelector> createState() => _BrandSelectorState();
}

class _BrandSelectorState extends ConsumerState<_BrandSelector> {
  final _controller = TextEditingController();
  List<BrandSummary>? _suggestions;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = ref.read(milkPurityRepoProvider);
      final results = await repo.searchBrands(query);
      setState(() {
        _suggestions = results;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.selected != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                widget.selected!.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              if (widget.selected!.overallScore != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ScoreBadge(
                    score: widget.selected!.overallScore!,
                    band: widget.selected!.band ?? 'good',
                    size: 48,
                  ),
                ),
              TextButton(
                onPressed: () {
                  _controller.clear();
                  setState(() => _suggestions = null);
                  widget.onSelected(null);
                },
                child: const Text('Change'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _search,
          decoration: InputDecoration(
            hintText: widget.label,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_suggestions != null && _suggestions!.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions!.length,
              itemBuilder: (context, index) {
                final brand = _suggestions![index];
                return ListTile(
                  dense: true,
                  title: Text(brand.name),
                  subtitle: brand.parentCompany != null
                      ? Text(brand.parentCompany!)
                      : null,
                  trailing: brand.overallScore != null
                      ? Text('${brand.overallScore!.toStringAsFixed(0)}/100')
                      : null,
                  onTap: () {
                    widget.onSelected(brand);
                    setState(() => _suggestions = null);
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final CompareResult result;

  const _ComparisonTable({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = result.brandA;
    final b = result.brandB;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    a.brand.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    b.brand.name,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Overall score
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: ScoreBadge(
                      score: a.score.overallScore,
                      band: a.score.band,
                      size: 64,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ScoreBadge(
                      score: b.score.overallScore,
                      band: b.score.band,
                      size: 64,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row comparisons
            _CompareRow(
                label: 'Fat Accuracy',
                valueA: a.score.fatAccuracyScore,
                valueB: b.score.fatAccuracyScore),
            _CompareRow(
                label: 'SNF Compliance',
                valueA: a.score.snfComplianceScore,
                valueB: b.score.snfComplianceScore),
            _CompareRow(
                label: 'Adulteration',
                valueA: a.score.adulterationScore,
                valueB: b.score.adulterationScore),
            _CompareRow(
                label: 'Bacterial Safety',
                valueA: a.score.bacterialScore,
                valueB: b.score.bacterialScore),
            _CompareRow(
                label: 'FSSAI Compliance',
                valueA: a.score.fssaiComplianceScore,
                valueB: b.score.fssaiComplianceScore),
          ],
        ),
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String label;
  final double valueA;
  final double valueB;

  const _CompareRow({
    required this.label,
    required this.valueA,
    required this.valueB,
  });

  Color _scoreColor(double v) {
    if (v >= 85) return const Color(0xFF2E7D32);
    if (v >= 70) return const Color(0xFFF9A825);
    if (v >= 50) return const Color(0xFFEF6C00);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final better = valueA > valueB
        ? 'a'
        : valueB > valueA
            ? 'b'
            : 'tie';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              valueA.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight:
                    better == 'a' ? FontWeight.bold : FontWeight.normal,
                color: _scoreColor(valueA),
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              valueB.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight:
                    better == 'b' ? FontWeight.bold : FontWeight.normal,
                color: _scoreColor(valueB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
