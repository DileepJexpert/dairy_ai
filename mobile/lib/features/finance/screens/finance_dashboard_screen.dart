import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/finance/models/finance_models.dart';
import 'package:dairy_ai/features/finance/providers/finance_provider.dart';
import 'package:dairy_ai/features/finance/providers/pashu_credit_provider.dart';
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeSummaryProvider(null));
          ref.invalidate(transactionsProvider(null));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // -- Pashu CIBIL Credit Score & KCC Banner --
            const _PashuCreditPromoCard(),

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
              error: (e, _) {
                final isAuth = e.toString().toLowerCase().contains('authentication required') || e.toString().contains('401');
                if (isAuth) {
                  return Card(
                    color: const Color(0xffecfdf5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xffa7f3d0)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(Icons.lock_outline, size: 44, color: Color(0xff047857)),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign In to View Dairy Finance',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xff065f46)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Manage your milk payouts, feed expenses, and profit & loss statements.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xff047857)),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/login?next=/finance'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff047857),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('Sign In (1-Click Demo Available)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
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
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Spacer for FAB
            const SizedBox(height: 80),
          ],
        ),
      ),
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

// ---------------------------------------------------------------------------
// Pashu CIBIL Credit & KCC Loan Promotional Card
// ---------------------------------------------------------------------------
class _PashuCreditPromoCard extends ConsumerWidget {
  const _PashuCreditPromoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditAsync = ref.watch(pashuCreditScoreProvider);
    final score = creditAsync.value?.score ?? 835;
    final rating = creditAsync.value?.grade ?? 'A+ Prime';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff064e3b), Color(0xff047857), Color(0xff0f766e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff064e3b).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/finance/pashu-credit'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_outlined,
                        color: Colors.amberAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade400,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'PASHU CIBIL: $score ★ $rating',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff78350f),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'पूर्व-स्वीकृत KCC लोन: ₹1,60,000 @ 4%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'टीकाकरण व दूध पर्ची समर्थित बिना गारंटी बैंक लोन',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.water_drop,
                              size: 14, color: Colors.lightBlueAccent),
                          const SizedBox(width: 6),
                          Text(
                            'दैनिक दूध एस्क्रो: ₹125/दिन',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'लोन व स्कोर देखें →',
                          style: TextStyle(
                            color: Color(0xff064e3b),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
