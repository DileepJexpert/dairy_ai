import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/breeding/models/breeding_models.dart';
import 'package:dairy_ai/features/feed/models/feed_models.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart' show dioProvider, cattleListProvider;

// ---------------------------------------------------------------------------
// Breeding records provider — optionally filtered by cattle.
// ---------------------------------------------------------------------------
final breedingRecordsProvider = FutureProvider.autoDispose
    .family<List<BreedingRecord>, String?>((ref, cattleId) async {
  final dio = ref.watch(dioProvider);
  final queryParams = <String, dynamic>{};
  if (cattleId != null && cattleId.isNotEmpty) {
    queryParams['cattle_id'] = cattleId;
  }
  final response =
      await dio.get('/breeding-records', queryParameters: queryParams);
  final data = response.data as Map<String, dynamic>;
  if (data['success'] == true) {
    final list = (data['data'] as List)
        .map((e) => BreedingRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return list;
  }
  return [];
});

// ---------------------------------------------------------------------------
// Breeding action notifier — handles add event.
// ---------------------------------------------------------------------------
final breedingActionProvider = StateNotifierProvider.autoDispose<
    BreedingActionNotifier, BreedingActionState>((ref) {
  return BreedingActionNotifier(ref);
});

class BreedingActionState {
  final bool isSubmitting;
  final bool success;
  final String? error;

  const BreedingActionState({
    this.isSubmitting = false,
    this.success = false,
    this.error,
  });
}

class BreedingActionNotifier extends StateNotifier<BreedingActionState> {
  final Ref _ref;

  BreedingActionNotifier(this._ref) : super(const BreedingActionState());

  Future<bool> addBreedingEvent(AddBreedingEventRequest request) async {
    state = const BreedingActionState(isSubmitting: true);
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post(
        '/breeding-records',
        data: request.toJson(),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        state = const BreedingActionState(success: true);
        // Invalidate records for the cattle and the global list.
        _ref.invalidate(breedingRecordsProvider(request.cattleId));
        _ref.invalidate(breedingRecordsProvider(null));
        return true;
      } else {
        state = BreedingActionState(
            error: data['message'] ?? 'Failed to add event');
        return false;
      }
    } on DioException catch (e) {
      state = BreedingActionState(
        error: e.response?.data?['message']?.toString() ??
            'Network error. Please try again.',
      );
      return false;
    }
  }

  void reset() => state = const BreedingActionState();
}
