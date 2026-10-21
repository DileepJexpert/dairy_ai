import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';

class MilterraWalletState {
  const MilterraWalletState({
    this.message = 'Sign in to check wallet availability.',
    this.enabled = false,
    required this.totalBalance,
    required this.milkPayoutBalance,
    required this.storeCreditBalance,
    required this.transactions,
    this.upiId = '',
    this.farmerName = '',
    this.currentCycle,
  });

  final String message;
  final bool enabled;
  final double totalBalance;
  final double milkPayoutBalance;
  final double storeCreditBalance;
  final List<Map<String, dynamic>> transactions;
  final String upiId;
  final String farmerName;
  final Map<String, dynamic>? currentCycle;

  MilterraWalletState copyWith({
    String? message,
    bool? enabled,
    double? totalBalance,
    double? milkPayoutBalance,
    double? storeCreditBalance,
    List<Map<String, dynamic>>? transactions,
    String? upiId,
    String? farmerName,
    Map<String, dynamic>? currentCycle,
  }) =>
      MilterraWalletState(
        message: message ?? this.message,
        enabled: enabled ?? this.enabled,
        totalBalance: totalBalance ?? this.totalBalance,
        milkPayoutBalance: milkPayoutBalance ?? this.milkPayoutBalance,
        storeCreditBalance: storeCreditBalance ?? this.storeCreditBalance,
        transactions: transactions ?? this.transactions,
        upiId: upiId ?? this.upiId,
        farmerName: farmerName ?? this.farmerName,
        currentCycle: currentCycle ?? this.currentCycle,
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
          enabled: j['enabled'] == true,
          totalBalance: double.parse(j['total_balance'].toString()),
          milkPayoutBalance: double.parse(j['milk_payout_balance'].toString()),
          storeCreditBalance:
              double.parse(j['store_credit_balance'].toString()),
          transactions: (j['transactions'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
          upiId: j['upi_id']?.toString() ?? '',
          farmerName: j['farmer_name']?.toString() ?? '',
          currentCycle: j['current_cycle'] is Map<String, dynamic>
              ? j['current_cycle'] as Map<String, dynamic>
              : null,
          message: j['message'].toString());
    } catch (_) {
      if (mounted) {
        state = const MilterraWalletState(
            totalBalance: 0,
            milkPayoutBalance: 0,
            storeCreditBalance: 0,
            transactions: [],
            message: 'Wallet status could not be loaded. Please retry.');
      }
    }
  }

  Future<Map<String, dynamic>> withdrawUpi({
    required double amount,
    required String upiId,
    String? notes,
  }) async {
    try {
      final response = await dio.post('/api/v1/finance/payout/upi', data: {
        'amount': amount,
        'upi_id': upiId,
        'notes': notes ?? '1-Click Instant UPI Withdrawal',
      });
      await refresh();
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        return Map<String, dynamic>.from(e.response!.data as Map);
      }
      return {
        'success': false,
        'message': 'Failed to process UPI withdrawal. Please check your network and try again.'
      };
    }
  }
}

final milterraWalletProvider =
    StateNotifierProvider<MilterraWalletNotifier, MilterraWalletState>((ref) =>
        MilterraWalletNotifier(ref.watch(dioProvider),
            enabled: ref.watch(currentUserProvider) != null));
