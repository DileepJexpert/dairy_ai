import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/payments/models/payment_models.dart';
import 'package:dairy_ai/features/payments/providers/payment_provider.dart';
import 'package:dairy_ai/features/payments/screens/loan_apply_screen.dart';
import 'package:dairy_ai/features/payments/screens/insurance_screen.dart';
import 'package:dairy_ai/features/payments/screens/subsidy_screen.dart';

class FarmerLedgerScreen extends ConsumerWidget {
  final String farmerId;

  const FarmerLedgerScreen({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(farmerLedgerProvider(farmerId));
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Overview'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'loans':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LoanApplyScreen(farmerId: farmerId),
                  ));
                  break;
                case 'insurance':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => InsuranceScreen(farmerId: farmerId),
                  ));
                  break;
                case 'subsidies':
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SubsidyScreen(farmerId: farmerId),
                  ));
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'loans', child: Text('Apply for Loan')),
              PopupMenuItem(value: 'insurance', child: Text('Insurance')),
              PopupMenuItem(value: 'subsidies', child: Text('Subsidies')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(farmerLedgerProvider(farmerId));
        },
        child: ledgerAsync.when(
          data: (ledger) {
            if (ledger == null) {
              return const Center(child: Text('No financial data yet'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ---- Hero cards ----
                _HeroCards(ledger: ledger, currencyFormat: currencyFormat),
                const SizedBox(height: 24),

                // ---- Recent Payments ----
                Text(
                  'Recent Payments',
                  style: context.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (ledger.recentPayments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No payments yet')),
                  )
                else
                  ...ledger.recentPayments.take(10).map(
                        (p) => _PaymentTile(
                          payment: p,
                          currencyFormat: currencyFormat,
                        ),
                      ),
                const SizedBox(height: 24),

                // ---- Active Loans ----
                Text(
                  'Active Loans',
                  style: context.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (ledger.loans.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No active loans')),
                  )
                else
                  ...ledger.loans.map(
                    (loan) => _LoanCard(
                      loan: loan,
                      currencyFormat: currencyFormat,
                    ),
                  ),
                const SizedBox(height: 24),

                // ---- Insurance Policies ----
                Text(
                  'Insurance Policies',
                  style: context.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (ledger.insurancePolicies.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No insurance policies')),
                  )
                else
                  ...ledger.insurancePolicies.map(
                    (ins) => _InsuranceTile(
                      insurance: ins,
                      currencyFormat: currencyFormat,
                    ),
                  ),

                // Spacer for safety
                const SizedBox(height: 80),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Cards — Total Earnings, Loans Outstanding, Subsidies Received
// ---------------------------------------------------------------------------
class _HeroCards extends StatelessWidget {
  final FarmerLedger ledger;
  final NumberFormat currencyFormat;

  const _HeroCards({required this.ledger, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HeroCard(
            title: 'Total Earnings',
            amount: ledger.totalEarnings,
            currencyFormat: currencyFormat,
            color: const Color(0xFF2E7D32),
            icon: Icons.account_balance_wallet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HeroCard(
            title: 'Loans Outstanding',
            amount: ledger.totalLoansOutstanding,
            currencyFormat: currencyFormat,
            color: Colors.red.shade700,
            icon: Icons.credit_card,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _HeroCard(
            title: 'Subsidies',
            amount: ledger.totalSubsidiesReceived,
            currencyFormat: currencyFormat,
            color: Colors.blue.shade700,
            icon: Icons.volunteer_activism,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final double amount;
  final NumberFormat currencyFormat;
  final Color color;
  final IconData icon;

  const _HeroCard({
    required this.title,
    required this.amount,
    required this.currencyFormat,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: context.textTheme.labelSmall?.copyWith(color: color),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormat.format(amount),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
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
// Payment Tile — litres, avg fat%, net amount, status
// ---------------------------------------------------------------------------
class _PaymentTile extends StatelessWidget {
  final FarmerPayment payment;
  final NumberFormat currencyFormat;

  const _PaymentTile({required this.payment, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
          child: const Icon(Icons.water_drop, color: Color(0xFF2E7D32)),
        ),
        title: Text(
          currencyFormat.format(payment.netAmount),
          style: context.textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${payment.totalLitres.toStringAsFixed(1)} L  |  Fat: ${payment.avgFatPct.toStringAsFixed(1)}%',
        ),
        trailing: _StatusBadge(status: payment.status ?? 'paid'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loan Card — expandable with details
// ---------------------------------------------------------------------------
class _LoanCard extends StatelessWidget {
  final Loan loan;
  final NumberFormat currencyFormat;

  const _LoanCard({required this.loan, required this.currencyFormat});

  IconData get _loanIcon {
    switch (loan.loanType) {
      case 'cattle_purchase':
        return Icons.pets;
      case 'feed_advance':
        return Icons.grass;
      case 'equipment':
        return Icons.build;
      case 'emergency':
        return Icons.warning_amber;
      case 'dairy_infra':
        return Icons.factory;
      default:
        return Icons.monetization_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFF8F00).withOpacity(0.1),
          child: Icon(_loanIcon, color: const Color(0xFFFF8F00)),
        ),
        title: Text(
          loan.loanTypeLabel,
          style: context.textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Outstanding: ${currencyFormat.format(loan.outstandingAmount)}',
        ),
        trailing: _StatusBadge(status: loan.status),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Principal',
                  value: currencyFormat.format(loan.principalAmount),
                ),
                _DetailRow(
                  label: 'Outstanding',
                  value: currencyFormat.format(loan.outstandingAmount),
                ),
                _DetailRow(
                  label: 'EMI',
                  value: currencyFormat.format(loan.emiAmount),
                ),
                if (loan.interestRatePct != null)
                  _DetailRow(
                    label: 'Interest Rate',
                    value: '${loan.interestRatePct!.toStringAsFixed(1)}%',
                  ),
                if (loan.tenureMonths != null)
                  _DetailRow(
                    label: 'Tenure',
                    value: '${loan.tenureMonths} months',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Insurance Tile
// ---------------------------------------------------------------------------
class _InsuranceTile extends StatelessWidget {
  final CattleInsurance insurance;
  final NumberFormat currencyFormat;

  const _InsuranceTile(
      {required this.insurance, required this.currencyFormat});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.shield, color: Colors.blue),
        ),
        title: Text(
          insurance.policyNumber ?? 'Policy',
          style: context.textTheme.bodyLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Sum: ${currencyFormat.format(insurance.sumInsured)}  |  Premium: ${currencyFormat.format(insurance.farmerPremium)}',
        ),
        trailing: _StatusBadge(status: insurance.status ?? 'active'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail Row helper
// ---------------------------------------------------------------------------
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.textTheme.bodyMedium),
          Text(
            value,
            style: context.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable Status Badge
// ---------------------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'active':
      case 'approved':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'processing':
      case 'pending':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'rejected':
      case 'overdue':
      case 'claim_processing':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      case 'disbursed':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        break;
      case 'expired':
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        break;
      case 'applied':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: context.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
