import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/storage.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/models/auth_state.dart';
import 'package:dairy_ai/features/auth/models/user_model.dart';

/// Provides the singleton [SecureStorageService].
final storageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// Provides the configured [Dio] HTTP client.
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(storageProvider);
  return createDioClient(storage);
});

/// Provides the current [AuthState] via a [StateNotifier].
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    dio: ref.watch(dioProvider),
    storage: ref.watch(storageProvider),
  );
});

/// Convenience provider that extracts the current [UserModel] when
/// authenticated, or `null` otherwise.
final currentUserProvider = Provider<UserModel?>((ref) {
  final state = ref.watch(authProvider);
  return state.maybeWhen(
    authenticated: (user) => user,
    orElse: () => null,
  );
});

/// Manages authentication state: OTP flow, token refresh, and logout.
class AuthNotifier extends StateNotifier<AuthState> {
  final Dio _dio;
  final SecureStorageService _storage;

  AuthNotifier({
    required Dio dio,
    required SecureStorageService storage,
  })  : _dio = dio,
        _storage = storage,
        super(const AuthState.unauthenticated());

  /// Attempt to restore a session from persisted tokens.
  Future<void> tryRestoreSession() async {
    final token = await _storage.getAccessToken();
    final userData = await _storage.getUserData();
    if (token != null && userData != null) {
      state = AuthState.authenticated(
        user: UserModel.fromJson(userData),
      );
    }
  }

  /// Request an OTP for the given phone number.
  Future<void> sendOtp(String phone) async {
    state = const AuthState.loading();
    try {
      final response = await _dio.post('/auth/send-otp', data: {
        'phone': '${AppConstants.phonePrefix}$phone',
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        state = AuthState.otpSent(phone: phone);
      } else {
        state = AuthState.error(
          message: (body['message'] as String?) ?? 'Failed to send OTP',
        );
      }
    } on DioException catch (e) {
      state = AuthState.error(message: dioErrorMessage(e));
    }
  }

  /// Verify the OTP and authenticate.
  Future<void> verifyOtp(String phone, String otp) async {
    state = const AuthState.loading();
    try {
      final response = await _dio.post('/auth/verify-otp', data: {
        'phone': '${AppConstants.phonePrefix}$phone',
        'otp': otp,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final user = UserModel(
          id: data['user']['id'] as String,
          phone: data['user']['phone'] as String,
          role: data['user']['role'] as String,
          name: data['user']['name'] as String?,
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );

        // Persist tokens and user data.
        await _storage.setAccessToken(user.accessToken!);
        await _storage.setRefreshToken(user.refreshToken!);
        await _storage.setUserData(user.toJson());

        state = AuthState.authenticated(user: user);
      } else {
        state = AuthState.error(
          message: (body['message'] as String?) ?? 'Invalid OTP',
        );
      }
    } on DioException catch (e) {
      state = AuthState.error(message: dioErrorMessage(e));
    }
  }

  /// Refresh the access token.
  Future<bool> refreshToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) {
      await logout();
      return false;
    }
    try {
      final response = await Dio(
        BaseOptions(baseUrl: AppConstants.baseUrl),
      ).post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        await _storage.setAccessToken(data['access_token'] as String);
        await _storage.setRefreshToken(data['refresh_token'] as String);
        return true;
      }
      await logout();
      return false;
    } catch (_) {
      await logout();
      return false;
    }
  }

  /// Clear tokens and reset to unauthenticated.
  Future<void> logout() async {
    await _storage.clearAll();
    state = const AuthState.unauthenticated();
  }
}
