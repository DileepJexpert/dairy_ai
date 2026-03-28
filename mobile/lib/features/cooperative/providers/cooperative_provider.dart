import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/cooperative/models/cooperative_models.dart';

// ---------------------------------------------------------------------------
// Read-only providers
// ---------------------------------------------------------------------------

/// Fetches the authenticated cooperative's profile.
final cooperativeProfileProvider =
    FutureProvider<CooperativeProfile>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/cooperative/profile');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return CooperativeProfile.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load cooperative profile');
});

/// Fetches the cooperative dashboard summary.
final cooperativeDashboardProvider =
    FutureProvider<CooperativeDashboard>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/cooperative/dashboard');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return CooperativeDashboard.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load cooperative dashboard');
});

// ---------------------------------------------------------------------------
// Action provider (register + update)
// ---------------------------------------------------------------------------

/// State for cooperative action operations (register / update).
class CooperativeActionState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const CooperativeActionState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  CooperativeActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return CooperativeActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class CooperativeActionNotifier extends StateNotifier<CooperativeActionState> {
  final Dio _dio;
  final Ref _ref;

  CooperativeActionNotifier(this._dio, this._ref)
      : super(const CooperativeActionState());

  /// Register a new cooperative.
  Future<void> register(Map<String, dynamic> data) async {
    state = const CooperativeActionState(isLoading: true);
    try {
      final response = await _dio.post('/cooperative/register', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const CooperativeActionState(isSuccess: true);
        _ref.invalidate(cooperativeProfileProvider);
        _ref.invalidate(cooperativeDashboardProvider);
      } else {
        state = CooperativeActionState(
          errorMessage: body['message'] as String? ?? 'Registration failed',
        );
      }
    } on DioException catch (e) {
      state = CooperativeActionState(errorMessage: dioErrorMessage(e));
    }
  }

  /// Update the cooperative profile.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = const CooperativeActionState(isLoading: true);
    try {
      final response = await _dio.put('/cooperative/profile', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const CooperativeActionState(isSuccess: true);
        _ref.invalidate(cooperativeProfileProvider);
        _ref.invalidate(cooperativeDashboardProvider);
      } else {
        state = CooperativeActionState(
          errorMessage: body['message'] as String? ?? 'Update failed',
        );
      }
    } on DioException catch (e) {
      state = CooperativeActionState(errorMessage: dioErrorMessage(e));
    }
  }

  /// Reset state back to idle.
  void reset() => state = const CooperativeActionState();
}

final cooperativeActionProvider =
    StateNotifierProvider<CooperativeActionNotifier, CooperativeActionState>(
        (ref) {
  final dio = ref.watch(dioProvider);
  return CooperativeActionNotifier(dio, ref);
});
