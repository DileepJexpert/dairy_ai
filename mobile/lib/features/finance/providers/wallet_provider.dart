import 'package:flutter_riverpod/flutter_riverpod.dart';

class MilterraWalletState {
  const MilterraWalletState({
    required this.totalBalance,
    required this.milkPayoutBalance,
    required this.storeCreditBalance,
    required this.transactions,
  });

  final double totalBalance;
  final double milkPayoutBalance;
  final double storeCreditBalance;
  final List<Map<String, dynamic>> transactions;

  MilterraWalletState copyWith({
    double? totalBalance,
    double? milkPayoutBalance,
    double? storeCreditBalance,
    List<Map<String, dynamic>>? transactions,
  }) =>
      MilterraWalletState(
        totalBalance: totalBalance ?? this.totalBalance,
        milkPayoutBalance: milkPayoutBalance ?? this.milkPayoutBalance,
        storeCreditBalance: storeCreditBalance ?? this.storeCreditBalance,
        transactions: transactions ?? this.transactions,
      );
}

class MilterraWalletNotifier extends StateNotifier<MilterraWalletState> {
  MilterraWalletNotifier()
      : super(
          const MilterraWalletState(
            totalBalance: 4850.00,
            milkPayoutBalance: 3600.00,
            storeCreditBalance: 1250.00,
            transactions: [
              {
                'id': 'TXN-98421',
                'title': 'Milk Procurement Settlement',
                'subtitle':
                    '42.5 Litres · Fat 4.4% · SNF 8.6% · Anand Collection Center',
                'type': 'payout',
                'amount': 1420.00,
                'isCredit': true,
                'date': 'Today, 08:30 AM',
                'status': 'Settled',
              },
              {
                'id': 'TXN-98315',
                'title': 'Shop Order #MLT-8921',
                'subtitle': 'Milterra Calci-Pro (1L) · Fast Delivery',
                'type': 'orders',
                'amount': 340.00,
                'isCredit': false,
                'date': 'Yesterday, 04:15 PM',
                'status': 'Paid',
              },
              {
                'id': 'TXN-98204',
                'title': 'Milk Procurement Settlement',
                'subtitle':
                    '38.0 Litres · Fat 4.2% · SNF 8.5% · Anand Collection Center',
                'type': 'payout',
                'amount': 1280.00,
                'isCredit': true,
                'date': '09 Sep 2026',
                'status': 'Settled',
              },
              {
                'id': 'TXN-98110',
                'title': 'Shop Order #MLT-8902',
                'subtitle': 'Milterra A2 Desi Cow Ghee (500ml Glass Jar)',
                'type': 'orders',
                'amount': 799.00,
                'isCredit': false,
                'date': '08 Sep 2026',
                'status': 'Paid',
              },
              {
                'id': 'TXN-97992',
                'title': 'Farmer Referral Incentive',
                'subtitle': 'Village Dairy Community Onboarding Bonus',
                'type': 'cashback',
                'amount': 250.00,
                'isCredit': true,
                'date': '06 Sep 2026',
                'status': 'Credited',
              },
              {
                'id': 'TXN-97880',
                'title': 'Milterra Store Welcome Bonus',
                'subtitle': '100% Guaranteed Pure Farm Commerce Credit',
                'type': 'cashback',
                'amount': 1000.00,
                'isCredit': true,
                'date': '01 Sep 2026',
                'status': 'Credited',
              },
            ],
          ),
        );

  void creditMilkIntake({
    required double amount,
    required double litres,
    required double fatPct,
    required double snfPct,
    required String farmerName,
    String? centerName,
  }) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final txnId = 'TXN-${(10000 + state.transactions.length * 111)}';

    final newTxn = {
      'id': txnId,
      'title': 'Instant Milk Procurement Settlement',
      'subtitle':
          '${litres.toStringAsFixed(1)} L · Fat ${fatPct.toStringAsFixed(1)}% · SNF ${snfPct.toStringAsFixed(1)}% · ${centerName ?? "Anand Collection Center"}',
      'type': 'payout',
      'amount': amount,
      'isCredit': true,
      'date': 'Just now, $timeStr',
      'status': 'Settled',
    };

    state = state.copyWith(
      totalBalance: state.totalBalance + amount,
      milkPayoutBalance: state.milkPayoutBalance + amount,
      transactions: [newTxn, ...state.transactions],
    );
  }

  bool withdraw(double amount) {
    if (amount <= 0 || amount > state.totalBalance) return false;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final txnId = 'TXN-${(20000 + state.transactions.length * 77)}';

    final newTxn = {
      'id': txnId,
      'title': 'Bank Payout Withdrawal',
      'subtitle': 'Direct NEFT/IMPS Transfer to Linked Farmer Account',
      'type': 'payout',
      'amount': amount,
      'isCredit': false,
      'date': 'Just now, $timeStr',
      'status': 'Processing',
    };

    final newPayoutBal =
        (state.milkPayoutBalance - amount).clamp(0.0, double.infinity);
    final remainderToDeductFromCredit =
        (amount - state.milkPayoutBalance).clamp(0.0, double.infinity);

    state = state.copyWith(
      totalBalance: state.totalBalance - amount,
      milkPayoutBalance: newPayoutBal,
      storeCreditBalance: state.storeCreditBalance - remainderToDeductFromCredit,
      transactions: [newTxn, ...state.transactions],
    );
    return true;
  }

  bool payOrder(double amount, String orderId) {
    if (amount <= 0 || amount > state.totalBalance) return false;
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final txnId = 'TXN-${(30000 + state.transactions.length * 89)}';

    final newTxn = {
      'id': txnId,
      'title': 'Milterra Store Order #$orderId',
      'subtitle': 'Paid via Milterra Wallet Balance',
      'type': 'orders',
      'amount': amount,
      'isCredit': false,
      'date': 'Just now, $timeStr',
      'status': 'Paid',
    };

    final deductCredit =
        amount <= state.storeCreditBalance ? amount : state.storeCreditBalance;
    final deductPayout = amount - deductCredit;

    state = state.copyWith(
      totalBalance: state.totalBalance - amount,
      storeCreditBalance: state.storeCreditBalance - deductCredit,
      milkPayoutBalance: state.milkPayoutBalance - deductPayout,
      transactions: [newTxn, ...state.transactions],
    );
    return true;
  }

  void refundOrder(double amount, String orderId) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final txnId = 'TXN-${(40000 + state.transactions.length * 93)}';

    final newTxn = {
      'id': txnId,
      'title': 'Refund: Order #$orderId',
      'subtitle': 'Full refund credited for cancelled order',
      'type': 'refund',
      'amount': amount,
      'isCredit': true,
      'date': 'Just now, $timeStr',
      'status': 'Refunded',
    };

    state = state.copyWith(
      totalBalance: state.totalBalance + amount,
      storeCreditBalance: state.storeCreditBalance + amount,
      transactions: [newTxn, ...state.transactions],
    );
  }
}

final milterraWalletProvider =
    StateNotifierProvider<MilterraWalletNotifier, MilterraWalletState>((ref) {
  return MilterraWalletNotifier();
});
