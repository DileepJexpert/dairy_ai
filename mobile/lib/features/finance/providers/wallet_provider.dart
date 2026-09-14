import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';

class MilterraWalletState {
  const MilterraWalletState({
    this.message = 'Sign in to check wallet availability.',
    required this.totalBalance,
    required this.milkPayoutBalance,
    required this.storeCreditBalance,
    required this.transactions,
  });

  final String message;
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
        message: message,
        totalBalance: totalBalance ?? this.totalBalance,
        milkPayoutBalance: milkPayoutBalance ?? this.milkPayoutBalance,
        storeCreditBalance: storeCreditBalance ?? this.storeCreditBalance,
        transactions: transactions ?? this.transactions,
      );
}

class MilterraWalletNotifier extends StateNotifier<MilterraWalletState> {
  MilterraWalletNotifier(this.dio, {bool enabled = true})
      : super(const MilterraWalletState(
            totalBalance: 0,
            milkPayoutBalance: 0,
            storeCreditBalance: 0,
            transactions: [])) {
    if (enabled) refresh();
  }
  final Dio dio;
  Future<void> refresh() async {
    try {
      final response = await dio.get('/marketplace/wallet');
      final j = response.data['data'];
      if (!mounted) return;
      state = MilterraWalletState(
          totalBalance: double.parse(j['total_balance'].toString()),
          milkPayoutBalance: double.parse(j['milk_payout_balance'].toString()),
          storeCreditBalance:
              double.parse(j['store_credit_balance'].toString()),
          transactions: (j['transactions'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          message: j['message'].toString());
    } catch (_) {
      if (mounted)
        state = const MilterraWalletState(
            totalBalance: 0,
            milkPayoutBalance: 0,
            storeCreditBalance: 0,
            transactions: [],
            message: 'Wallet status could not be loaded. Please retry.');
    }
  }
}

final milterraWalletProvider =
    StateNotifierProvider<MilterraWalletNotifier, MilterraWalletState>((ref) =>
        MilterraWalletNotifier(ref.watch(dioProvider),
            enabled: ref.watch(currentUserProvider) != null));
