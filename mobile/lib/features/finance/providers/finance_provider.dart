import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dairy_ai/features/finance/models/finance_models.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart' show dioProvider;

// ---------------------------------------------------------------------------
// Demo data fallbacks for offline and unauthenticated states.
// ---------------------------------------------------------------------------
final _demoTransactions = [
  const Transaction(
    id: 'tx-demo-1',
    farmerId: 'farmer-demo',
    type: TransactionType.income,
    category: TransactionCategory.milkSales,
    amount: 14200.0,
    description: 'Weekly milk payout - AMUL Society',
    date: '2026-10-18',
  ),
  const Transaction(
    id: 'tx-demo-2',
    farmerId: 'farmer-demo',
    type: TransactionType.expense,
    category: TransactionCategory.feedCost,
    amount: 4500.0,
    description: '5 bags cattle feed pellets (Kapila)',
    date: '2026-10-16',
  ),
  const Transaction(
    id: 'tx-demo-3',
    farmerId: 'farmer-demo',
    type: TransactionType.income,
    category: TransactionCategory.milkSales,
    amount: 13800.0,
    description: 'Direct milk sales to local dairy booth',
    date: '2026-10-11',
  ),
  const Transaction(
    id: 'tx-demo-4',
    farmerId: 'farmer-demo',
    type: TransactionType.expense,
    category: TransactionCategory.vetFees,
    amount: 850.0,
    description: 'Routine herd deworming & checkup',
    date: '2026-10-08',
  ),
  const Transaction(
    id: 'tx-demo-5',
    farmerId: 'farmer-demo',
    type: TransactionType.expense,
    category: TransactionCategory.medicine,
    amount: 650.0,
    description: 'Mineral mixture 5kg bucket',
    date: '2026-10-04',
  ),
];

final _demoFinanceSummary = const FinanceSummary(
  totalIncome: 48500.0,
  totalExpense: 17200.0,
  netProfit: 31300.0,
  month: 'October 2026',
  incomeBreakdown: [
    CategoryBreakdown(
      category: TransactionCategory.milkSales,
      amount: 48500.0,
      percentage: 100.0,
    ),
  ],
  expenseBreakdown: [
    CategoryBreakdown(
      category: TransactionCategory.feedCost,
      amount: 12500.0,
      percentage: 72.7,
    ),
    CategoryBreakdown(
      category: TransactionCategory.vetFees,
      amount: 2500.0,
      percentage: 14.5,
    ),
    CategoryBreakdown(
      category: TransactionCategory.medicine,
      amount: 2200.0,
      percentage: 12.8,
    ),
  ],
);

final _demoMonthlyReports = [
  const MonthlyReport(month: '2026-08', income: 44200.0, expense: 16100.0, profit: 28100.0),
  const MonthlyReport(month: '2026-09', income: 46800.0, expense: 16900.0, profit: 29900.0),
  const MonthlyReport(month: '2026-10', income: 48500.0, expense: 17200.0, profit: 31300.0),
];

final _demoCattleCostAnalysis = [
  const CattleCostAnalysis(
    cattleId: '1',
    cattleName: 'Ganga (गाय)',
    totalIncome: 18500.0,
    totalExpense: 5800.0,
    netProfit: 12700.0,
  ),
  const CattleCostAnalysis(
    cattleId: '2',
    cattleName: 'Gauri (गाय)',
    totalIncome: 16800.0,
    totalExpense: 5600.0,
    netProfit: 11200.0,
  ),
  const CattleCostAnalysis(
    cattleId: '3',
    cattleName: 'Murrah (भैंस)',
    totalIncome: 13200.0,
    totalExpense: 5800.0,
    netProfit: 7400.0,
  ),
];

// ---------------------------------------------------------------------------
// Transactions provider — current month by default.
// ---------------------------------------------------------------------------
final transactionsProvider = FutureProvider.autoDispose
    .family<List<Transaction>, String?>((ref, month) async {
  try {
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
      if (list.isNotEmpty) return list;
    }
  } catch (_) {}
  return _demoTransactions;
});

// ---------------------------------------------------------------------------
// Finance summary provider — current month summary.
// ---------------------------------------------------------------------------
final financeSummaryProvider = FutureProvider.autoDispose
    .family<FinanceSummary?, String?>((ref, month) async {
  try {
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
  } catch (_) {}
  return _demoFinanceSummary;
});

// ---------------------------------------------------------------------------
// Monthly reports provider — for report screen.
// ---------------------------------------------------------------------------
final monthlyReportsProvider =
    FutureProvider.autoDispose<List<MonthlyReport>>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/transactions/monthly-report');
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true) {
      final list = (data['data'] as List)
          .map((e) => MonthlyReport.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return list;
    }
  } catch (_) {}
  return _demoMonthlyReports;
});

// ---------------------------------------------------------------------------
// Per-cattle cost analysis provider.
// ---------------------------------------------------------------------------
final cattleCostAnalysisProvider =
    FutureProvider.autoDispose<List<CattleCostAnalysis>>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/transactions/cattle-cost-analysis');
    final data = response.data as Map<String, dynamic>;
    if (data['success'] == true) {
      final list = (data['data'] as List)
          .map((e) => CattleCostAnalysis.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) return list;
    }
  } catch (_) {}
  return _demoCattleCostAnalysis;
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
