import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/feed/models/feed_models.dart';

// ---------------------------------------------------------------------------
// Dio provider — reuse across features (shared singleton).
// ---------------------------------------------------------------------------
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
  return dio;
});

// ---------------------------------------------------------------------------
// Cattle list provider — lightweight list for dropdowns.
// ---------------------------------------------------------------------------
final cattleListProvider =
    FutureProvider.autoDispose<List<CattleRef>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/cattle');
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => CattleRef.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  throw Exception(data['message'] ?? 'Failed to load cattle');
});

// ---------------------------------------------------------------------------
// Feed plan provider — per cattle.
// ---------------------------------------------------------------------------
final feedPlanProvider = FutureProvider.autoDispose
    .family<FeedPlan?, String>((ref, cattleId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/feed-plans', queryParameters: {
    'cattle_id': cattleId,
    'latest': true,
  });
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true && data['data'] != null) {
    return FeedPlan.fromJson(data['data'] as Map<String, dynamic>);
  }
  return null;
});

// ---------------------------------------------------------------------------
// Feed plan history provider — per cattle.
// ---------------------------------------------------------------------------
final feedPlanHistoryProvider = FutureProvider.autoDispose
    .family<List<FeedPlan>, String>((ref, cattleId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/feed-plans', queryParameters: {
    'cattle_id': cattleId,
  });
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => FeedPlan.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Feed notifier — handles generate action.
// ---------------------------------------------------------------------------
final feedActionProvider =
    StateNotifierProvider.autoDispose<FeedActionNotifier, FeedActionState>(
        (ref) {
  return FeedActionNotifier(ref);
});

class FeedActionState {
  final bool isGenerating;
  final FeedPlan? generatedPlan;
  final String? error;

  const FeedActionState({
    this.isGenerating = false,
    this.generatedPlan,
    this.error,
  });

  FeedActionState copyWith({
    bool? isGenerating,
    FeedPlan? generatedPlan,
    String? error,
  }) {
    return FeedActionState(
      isGenerating: isGenerating ?? this.isGenerating,
      generatedPlan: generatedPlan ?? this.generatedPlan,
      error: error,
    );
  }
}

class FeedActionNotifier extends StateNotifier<FeedActionState> {
  final Ref _ref;

  FeedActionNotifier(this._ref) : super(const FeedActionState());

  /// Calls the backend AI feed optimizer and returns the new plan.
  Future<FeedPlan?> generateFeedPlan(String cattleId) async {
    state = const FeedActionState(isGenerating: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post('/feed-plans/generate', data: {
        'cattle_id': cattleId,
      });
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final plan = FeedPlan.fromJson(data['data'] as Map<String, dynamic>);
        state = FeedActionState(generatedPlan: plan);
        // Invalidate caches so list/current plan refresh.
        _ref.invalidate(feedPlanProvider(cattleId));
        _ref.invalidate(feedPlanHistoryProvider(cattleId));
        return plan;
      } else {
        state = FeedActionState(error: data['message'] ?? 'Generation failed');
        return null;
      }
    } on DioException catch (e) {
      state = FeedActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return null;
    }
  }

  void reset() => state = const FeedActionState();
}
