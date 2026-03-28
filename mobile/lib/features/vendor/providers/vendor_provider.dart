import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/vendor/models/vendor_models.dart';

// ---------------------------------------------------------------------------
// Read-only providers
// ---------------------------------------------------------------------------

/// Fetches the authenticated vendor's profile.
final vendorProfileProvider = FutureProvider<VendorProfile>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/vendor/profile');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return VendorProfile.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load vendor profile');
});

/// Fetches the vendor dashboard summary.
final vendorDashboardProvider = FutureProvider<VendorDashboard>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/vendor/dashboard');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return VendorDashboard.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load vendor dashboard');
});

// ---------------------------------------------------------------------------
// Action provider (register + update)
// ---------------------------------------------------------------------------

/// State for vendor action operations (register / update).
class VendorActionState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  const VendorActionState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  VendorActionState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return VendorActionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class VendorActionNotifier extends StateNotifier<VendorActionState> {
  final Dio _dio;
  final Ref _ref;

  VendorActionNotifier(this._dio, this._ref)
      : super(const VendorActionState());

  /// Register a new vendor profile.
  Future<void> register(Map<String, dynamic> data) async {
    state = const VendorActionState(isLoading: true);
    try {
      final response = await _dio.post('/vendor/register', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const VendorActionState(isSuccess: true);
        _ref.invalidate(vendorProfileProvider);
        _ref.invalidate(vendorDashboardProvider);
      } else {
        state = VendorActionState(
          errorMessage: body['message'] as String? ?? 'Registration failed',
        );
      }
    } on DioException catch (e) {
      state = VendorActionState(errorMessage: dioErrorMessage(e));
    }
  }

  /// Update an existing vendor profile.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    state = const VendorActionState(isLoading: true);
    try {
      final response = await _dio.put('/vendor/profile', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = const VendorActionState(isSuccess: true);
        _ref.invalidate(vendorProfileProvider);
        _ref.invalidate(vendorDashboardProvider);
      } else {
        state = VendorActionState(
          errorMessage: body['message'] as String? ?? 'Update failed',
        );
      }
    } on DioException catch (e) {
      state = VendorActionState(errorMessage: dioErrorMessage(e));
    }
  }

  /// Reset state back to idle.
  void reset() => state = const VendorActionState();
}

final vendorActionProvider =
    StateNotifierProvider<VendorActionNotifier, VendorActionState>((ref) {
  final dio = ref.watch(dioProvider);
  return VendorActionNotifier(dio, ref);
});
