import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dairy_ai/features/finance/models/finance_models.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart' show dioProvider;

// ---------------------------------------------------------------------------
// Transactions provider — current month by default.
// ---------------------------------------------------------------------------
final transactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String?>((ref, month) async {
  final dio = ref.watch(dioProvider);
  final queryParams = <String, dynamic>{};
  if (month != null && month.isNotEmpty) {
    queryParams['month'] = month;
  }
  final response =
      await dio.get('/transactions', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Finance summary provider — current month summary.
// ---------------------------------------------------------------------------
final financeSummaryProvider = FutureProvider.autoDispose
    .family<FinanceSummary?, String?>((ref, month) async {
  final dio = ref.watch(dioProvider);
  final queryParams = <String, dynamic>{};
  if (month != null && month.isNotEmpty) {
    queryParams['month'] = month;
  }
  final response =
      await dio.get('/transactions/summary', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true && data['data'] != null) {
    return FinanceSummary.fromJson(data['data'] as Map<String, dynamic>);
  }
  return null;
});

// ---------------------------------------------------------------------------
// Monthly reports provider — for report screen.
// ---------------------------------------------------------------------------
final monthlyReportsProvider =
    FutureProvider.autoDispose<List<MonthlyReport>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/transactions/monthly-report');
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => MonthlyReport.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Per-cattle cost analysis provider.
// ---------------------------------------------------------------------------
final cattleCostAnalysisProvider =
    FutureProvider.autoDispose<List<CattleCostAnalysis>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/transactions/cattle-cost-analysis');
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => CattleCostAnalysis.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Finance action notifier — handles add transaction.
// ---------------------------------------------------------------------------
final financeActionProvider = StateNotifierProvider.autoDispose<
    FinanceActionNotifier, FinanceActionState>((ref) {
  return FinanceActionNotifier(ref);
});

class FinanceActionState {
  final bool isSubmitting;
  final bool success;
  final String? error;

  const FinanceActionState({
    this.isSubmitting = false,
    this.success = false,
    this.error,
  });
}

class FinanceActionNotifier extends StateNotifier<FinanceActionState> {
  final Ref _ref;

  FinanceActionNotifier(this._ref) : super(const FinanceActionState());

  Future<bool> addTransaction(AddTransactionRequest request) async {
    state = const FinanceActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post(
        '/transactions',
        data: request.toJson(),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        state = const FinanceActionState(success: true);
        // Invalidate caches so lists refresh.
        _ref.invalidate(transactionsProvider(null));
        _ref.invalidate(financeSummaryProvider(null));
        return true;
      } else {
        state = FinanceActionState(
            error: data['message'] ?? 'Failed to add transaction');
        return false;
      }
    } on DioException catch (e) {
      state = FinanceActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const FinanceActionState();
}
