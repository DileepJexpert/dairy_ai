import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/finance/models/finance_models.dart';
import 'package:dairy_ai/features/finance/providers/finance_provider.dart';

class FinanceReportScreen extends ConsumerStatefulWidget {
  const FinanceReportScreen({super.key});

  @override
  ConsumerState<FinanceReportScreen> createState() =>
      _FinanceReportScreenState();
}

class _FinanceReportScreenState extends ConsumerState<FinanceReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Financial Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Monthly P&L'),
            Tab(text: 'Categories'),
            Tab(text: 'Per Cattle'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MonthlyPnLTab(),
          _CategoryTab(),
          _PerCattleTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly P&L Tab
// ---------------------------------------------------------------------------
class _MonthlyPnLTab extends ConsumerWidget {
  const _MonthlyPnLTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(monthlyReportsProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return reportsAsync.when(
      data: (reports) {
        if (reports.isEmpty) {
          return const Center(child: Text('No report data available'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            final isProfitable = report.profit >= 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMonth(report.month),
                      style: context.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    // Income / Expense / Profit row
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Income',
                            value: currencyFormat.format(report.income),
                            color: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Expense',
                            value: currencyFormat.format(report.expense),
                            color: Colors.red,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: isProfitable ? 'Profit' : 'Loss',
                            value:
                                currencyFormat.format(report.profit.abs()),
                            color:
                                isProfitable ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Visual bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            if (report.income > 0)
                              Expanded(
                                flex: (report.income * 100).toInt(),
                                child: Container(color: Colors.green),
                              ),
                            if (report.expense > 0)
                              Expanded(
                                flex: (report.expense * 100).toInt(),
                                child: Container(color: Colors.red),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  String _formatMonth(String monthStr) {
    try {
      // Expects "2026-03" or similar
      final parts = monthStr.split('-');
      if (parts.length >= 2) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('MMMM yyyy').format(dt);
      }
      return monthStr;
    } catch (_) {
      return monthStr;
    }
  }
}

// ---------------------------------------------------------------------------
// Category Breakdown Tab
// ---------------------------------------------------------------------------
class _CategoryTab extends ConsumerWidget {
  const _CategoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financeSummaryProvider(null));
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return summaryAsync.when(
      data: (summary) {
        if (summary == null) {
          return const Center(child: Text('No data available'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (summary.incomeBreakdown.isNotEmpty) ...[
              Text('Income Categories',
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...summary.incomeBreakdown
                  .map((b) => _CategoryBar(
                        breakdown: b,
                        currencyFormat: currencyFormat,
                        color: Colors.green,
                      )),
              const SizedBox(height: 24),
            ],

            if (summary.expenseBreakdown.isNotEmpty) ...[
              Text('Expense Categories',
                  style: context.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...summary.expenseBreakdown
                  .map((b) => _CategoryBar(
                        breakdown: b,
                        currencyFormat: currencyFormat,
                        color: Colors.red,
                      )),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  final CategoryBreakdown breakdown;
  final NumberFormat currencyFormat;
  final Color color;

  const _CategoryBar({
    required this.breakdown,
    required this.currencyFormat,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_label(breakdown.category),
                  style: context.textTheme.bodyMedium),
              Text(
                '${currencyFormat.format(breakdown.amount)} (${breakdown.percentage.toStringAsFixed(1)}%)',
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: breakdown.percentage / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
            ),
          ),
        ],
      ),
    );
  }

  String _label(TransactionCategory cat) {
    switch (cat) {
      case TransactionCategory.milkSales:
        return 'Milk Sales';
      case TransactionCategory.feedCost:
        return 'Feed Cost';
      case TransactionCategory.vetFees:
        return 'Vet Fees';
      case TransactionCategory.medicine:
        return 'Medicine';
      case TransactionCategory.cattlePurchase:
        return 'Cattle Purchase';
      case TransactionCategory.cattleSale:
        return 'Cattle Sale';
      case TransactionCategory.equipment:
        return 'Equipment';
      case TransactionCategory.labour:
        return 'Labour';
      case TransactionCategory.other:
        return 'Other';
    }
  }
}

// ---------------------------------------------------------------------------
// Per-Cattle Cost Analysis Tab
// ---------------------------------------------------------------------------
class _PerCattleTab extends ConsumerWidget {
  const _PerCattleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(cattleCostAnalysisProvider);
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return analysisAsync.when(
      data: (analyses) {
        if (analyses.isEmpty) {
          return const Center(child: Text('No per-cattle data available'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: analyses.length,
          itemBuilder: (context, index) {
            final a = analyses[index];
            final isProfitable = a.netProfit >= 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pets, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.cattleName,
                            style: context.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isProfitable
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isProfitable
                                ? '+${currencyFormat.format(a.netProfit)}'
                                : currencyFormat.format(a.netProfit),
                            style: context.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color:
                                  isProfitable ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStat(
                            label: 'Income',
                            value: currencyFormat.format(a.totalIncome),
                            color: Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _MiniStat(
                            label: 'Expense',
                            value: currencyFormat.format(a.totalExpense),
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widget
// ---------------------------------------------------------------------------
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
