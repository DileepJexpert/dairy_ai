import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/finance/models/finance_models.dart';
import 'package:dairy_ai/features/finance/providers/finance_provider.dart';
import 'package:dairy_ai/features/finance/screens/add_transaction_screen.dart';
import 'package:dairy_ai/features/finance/screens/finance_report_screen.dart';

class FinanceDashboardScreen extends ConsumerWidget {
  const FinanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financeSummaryProvider(null));
    final transactionsAsync = ref.watch(transactionsProvider(null));
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reports',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const FinanceReportScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeSummaryProvider(null));
          ref.invalidate(transactionsProvider(null));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -- Summary cards --
            summaryAsync.when(
              data: (summary) {
                if (summary == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No financial data yet')),
                    ),
                  );
                }
                return Column(
                  children: [
                    // Profit / Loss hero card
                    _ProfitLossCard(
                      summary: summary,
                      currencyFormat: currencyFormat,
                    ),
                    const SizedBox(height: 12),
                    // Income & Expense row
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Income',
                            amount: summary.totalIncome,
                            currencyFormat: currencyFormat,
                            icon: Icons.arrow_downward,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Expense',
                            amount: summary.totalExpense,
                            currencyFormat: currencyFormat,
                            icon: Icons.arrow_upward,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Category breakdown
                    if (summary.expenseBreakdown.isNotEmpty) ...[
                      _CategoryBreakdownSection(
                        title: 'Expense Breakdown',
                        breakdowns: summary.expenseBreakdown,
                        currencyFormat: currencyFormat,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (summary.incomeBreakdown.isNotEmpty) ...[
                      _CategoryBreakdownSection(
                        title: 'Income Breakdown',
                        breakdowns: summary.incomeBreakdown,
                        currencyFormat: currencyFormat,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error: $e'),
                ),
              ),
            ),

            // -- Recent transactions --
            Text('Recent Transactions',
                style: context.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            transactionsAsync.when(
              data: (txns) {
                if (txns.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No transactions yet')),
                  );
                }
                // Show latest 20
                final display = txns.length > 20 ? txns.sublist(0, 20) : txns;
                return Column(
                  children: display
                      .map((txn) => _TransactionTile(
                            transaction: txn,
                            currencyFormat: currencyFormat,
                          ))
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
            ),

            // Spacer for FAB
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profit / Loss Card
// ---------------------------------------------------------------------------
class _ProfitLossCard extends StatelessWidget {
  final FinanceSummary summary;
  final NumberFormat currencyFormat;

  const _ProfitLossCard({
    required this.summary,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isProfitable = summary.isProfitable;

    return Card(
      color: isProfitable ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              isProfitable ? 'Net Profit' : 'Net Loss',
              style: context.textTheme.titleSmall?.copyWith(
                color: isProfitable
                    ? Colors.green.shade800
                    : Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(summary.netProfit.abs()),
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isProfitable
                    ? Colors.green.shade800
                    : Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This Month',
              style: context.textTheme.bodySmall?.copyWith(
                color: isProfitable
                    ? Colors.green.shade600
                    : Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Card (Income / Expense)
// ---------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final NumberFormat currencyFormat;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.currencyFormat,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(title, style: context.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormat.format(amount),
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category Breakdown Section
// ---------------------------------------------------------------------------
class _CategoryBreakdownSection extends StatelessWidget {
  final String title;
  final List<CategoryBreakdown> breakdowns;
  final NumberFormat currencyFormat;
  final Color color;

  const _CategoryBreakdownSection({
    required this.title,
    required this.breakdowns,
    required this.currencyFormat,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: context.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...breakdowns.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_categoryLabel(b.category),
                              style: context.textTheme.bodyMedium),
                          Text(
                            currencyFormat.format(b.amount),
                            style: context.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: b.percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          color.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(TransactionCategory cat) {
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
// Transaction Tile
// ---------------------------------------------------------------------------
class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final NumberFormat currencyFormat;

  const _TransactionTile({
    required this.transaction,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final dateFormat = DateFormat('dd MMM');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor:
            isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncome ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(transaction.categoryLabel),
      subtitle: Text(
        transaction.description ?? _formatDate(transaction.date, dateFormat),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'} ${currencyFormat.format(transaction.amount)}',
        style: context.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isIncome ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  String _formatDate(String isoDate, DateFormat fmt) {
    try {
      return fmt.format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }
}
