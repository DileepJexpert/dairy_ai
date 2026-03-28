import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dairy_ai/features/payments/models/payment_models.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart' show dioProvider;

// ---------------------------------------------------------------------------
// Payment Cycles — GET /payments/cycles
// ---------------------------------------------------------------------------
final paymentCyclesProvider =
    FutureProvider.autoDispose<List<PaymentCycle>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/payments/cycles');
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => PaymentCycle.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Farmer Ledger — GET /payments/ledger/{farmerId}
// ---------------------------------------------------------------------------
final farmerLedgerProvider = FutureProvider.autoDispose
    .family<FarmerLedger?, String>((ref, farmerId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/payments/ledger/$farmerId');
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true && data['data'] != null) {
    return FarmerLedger.fromJson(data['data'] as Map<String, dynamic>);
  }
  return null;
});

// ---------------------------------------------------------------------------
// Loans — GET /payments/loans?farmer_id=X
// ---------------------------------------------------------------------------
final loansProvider = FutureProvider.autoDispose
    .family<List<Loan>, String>((ref, farmerId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/payments/loans',
    queryParameters: {'farmer_id': farmerId},
  );
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => Loan.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Insurance — GET /payments/insurance?farmer_id=X
// ---------------------------------------------------------------------------
final insuranceProvider = FutureProvider.autoDispose
    .family<List<CattleInsurance>, String>((ref, farmerId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/payments/insurance',
    queryParameters: {'farmer_id': farmerId},
  );
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => CattleInsurance.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Subsidies — GET /payments/subsidies?farmer_id=X
// ---------------------------------------------------------------------------
final subsidiesProvider = FutureProvider.autoDispose
    .family<List<SubsidyApplication>, String>((ref, farmerId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/payments/subsidies',
    queryParameters: {'farmer_id': farmerId},
  );
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => SubsidyApplication.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Payment Action Notifier — handles all POST mutations.
// ---------------------------------------------------------------------------
final paymentActionProvider = StateNotifierProvider.autoDispose<
    PaymentActionNotifier, PaymentActionState>((ref) {
  return PaymentActionNotifier(ref);
});

class PaymentActionState {
  final bool isSubmitting;
  final bool success;
  final String? error;
  final Map<String, dynamic>? resultData;

  const PaymentActionState({
    this.isSubmitting = false,
    this.success = false,
    this.error,
    this.resultData,
  });
}

class PaymentActionNotifier extends StateNotifier<PaymentActionState> {
  final Ref _ref;

  PaymentActionNotifier(this._ref) : super(const PaymentActionState());

  // POST /payments/cycles
  Future<bool> createCycle(Map<String, dynamic> data) async {
    state = const PaymentActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/payments/cycles', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const PaymentActionState(success: true);
        _ref.invalidate(paymentCyclesProvider);
        return true;
      } else {
        state = PaymentActionState(
            error: body['message']?.toString() ?? 'Failed to create cycle');
        return false;
      }
    } on DioException catch (e) {
      state = PaymentActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  // POST /payments/cycles/{id}/process
  Future<bool> processCycle(String cycleId) async {
    state = const PaymentActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/payments/cycles/$cycleId/process');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const PaymentActionState(success: true);
        _ref.invalidate(paymentCyclesProvider);
        return true;
      } else {
        state = PaymentActionState(
            error: body['message']?.toString() ?? 'Failed to process cycle');
        return false;
      }
    } on DioException catch (e) {
      state = PaymentActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  // POST /payments/loans/apply
  Future<bool> applyLoan(Map<String, dynamic> data) async {
    state = const PaymentActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/payments/loans/apply', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = PaymentActionState(
          success: true,
          resultData: body['data'] as Map<String, dynamic>?,
        );
        return true;
      } else {
        state = PaymentActionState(
            error: body['message']?.toString() ?? 'Failed to apply for loan');
        return false;
      }
    } on DioException catch (e) {
      state = PaymentActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  // POST /payments/insurance
  Future<bool> createInsurance(Map<String, dynamic> data) async {
    state = const PaymentActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/payments/insurance', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const PaymentActionState(success: true);
        return true;
      } else {
        state = PaymentActionState(
            error:
                body['message']?.toString() ?? 'Failed to create insurance');
        return false;
      }
    } on DioException catch (e) {
      state = PaymentActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  // POST /payments/insurance/{id}/claim
  Future<bool> fileClaim(
      String insuranceId, Map<String, dynamic> data) async {
    state = const PaymentActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response =
          await dio.post('/payments/insurance/$insuranceId/claim', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const PaymentActionState(success: true);
        return true;
      } else {
        state = PaymentActionState(
            error: body['message']?.toString() ?? 'Failed to file claim');
        return false;
      }
    } on DioException catch (e) {
      state = PaymentActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  // POST /payments/subsidies
  Future<bool> applySubsidy(Map<String, dynamic> data) async {
    state = const PaymentActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/payments/subsidies', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const PaymentActionState(success: true);
        return true;
      } else {
        state = PaymentActionState(
            error:
                body['message']?.toString() ?? 'Failed to apply for subsidy');
        return false;
      }
    } on DioException catch (e) {
      state = PaymentActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const PaymentActionState();
}
