import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    try {
      final token = await _storage.getAccessToken();
      final userData = await _storage.getUserData();
      if (token != null && userData != null) {
        state = AuthState.authenticated(
          user: UserModel.fromJson(userData),
        );
      }
    } catch (e, st) {
      debugPrint('tryRestoreSession failed, resetting session: $e\n$st');
      await _storage.clearAll();
      state = const AuthState.unauthenticated();
    }
  }

  /// Direct login using username/email and password (no OTP required).
  Future<bool> loginWithPassword({
    required String username,
    required String password,
  }) async {
    state = const AuthState.loading();
    try {
      final response = await _dio.post('/auth/login', data: {
        'username': username.trim(),
        'password': password,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['access_token'] is String) {
        final accessToken = body['access_token'] as String;
        final refreshToken = (body['refresh_token'] as String?) ?? accessToken;
        final profile =
            (body['user'] ?? body['data']) as Map<String, dynamic>?;
        final user = UserModel(
          id: profile?['id']?.toString() ?? 'usr_${username.toLowerCase()}',
          name: profile?['name']?.toString() ?? username,
          phone: profile?['phone']?.toString() ?? '+91 98765 43210',
          role: profile?['role']?.toString() ?? 'customer',
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        await _storage.setAccessToken(user.accessToken!);
        await _storage.setRefreshToken(user.refreshToken!);
        await _storage.setUserData(user.toJson());
        state = AuthState.authenticated(user: user);
        return true;
      }
      state = AuthState.error(
        message: (body['message'] as String?) ?? 'Invalid credentials',
      );
      return false;
    } on DioException catch (e) {
      state = AuthState.error(message: dioErrorMessage(e));
      return false;
    } catch (e) {
      state = AuthState.error(message: 'Login failed: ${e.toString()}');
      return false;
    }
  }

  /// Register new user profile (Full Name, Username, Phone, Password, Role) without OTP.
  Future<bool> register({
    required String name,
    required String username,
    required String password,
    String? phone,
    String role = 'customer',
  }) async {
    state = const AuthState.loading();
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name.trim(),
        'username': username.trim(),
        'password': password,
        'phone': phone?.trim() ?? '',
        'role': role,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['access_token'] is String) {
        final accessToken = body['access_token'] as String;
        final refreshToken = (body['refresh_token'] as String?) ?? accessToken;
        final profile =
            (body['user'] ?? body['data']) as Map<String, dynamic>?;
        final user = UserModel(
          id: profile?['id']?.toString() ?? 'usr_${username.toLowerCase()}',
          name: name.trim(),
          phone: phone?.trim().isNotEmpty == true
              ? phone!.trim()
              : '+91 98765 43210',
          role: role,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        await _storage.setAccessToken(user.accessToken!);
        await _storage.setRefreshToken(user.refreshToken!);
        await _storage.setUserData(user.toJson());
        state = AuthState.authenticated(user: user);
        return true;
      }
      state = AuthState.error(
        message: (body['message'] as String?) ?? 'Registration failed',
      );
      return false;
    } on DioException catch (e) {
      state = AuthState.error(message: dioErrorMessage(e));
      return false;
    } catch (e) {
      state = AuthState.error(message: 'Registration failed: ${e.toString()}');
      return false;
    }
  }

  /// Request an OTP for the given phone number.
  Future<void> sendOtp(String phone) async {
    state = const AuthState.loading();
    try {
      final response = await _dio.post('/auth/send-otp', data: {
        // The API stores and validates Indian mobile numbers as 10 digits.
        'phone': phone,
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
        'phone': phone,
        'otp': otp,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['access_token'] is String && body['refresh_token'] is String) {
        final accessToken = body['access_token'] as String;
        final profileResponse = await Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            headers: {'Authorization': 'Bearer $accessToken'},
          ),
        ).get('/auth/me');
        final profile = profileResponse.data['data'] as Map<String, dynamic>;
        final user = UserModel(
          id: profile['id'] as String,
          phone: profile['phone'] as String,
          role: profile['role'] as String,
          accessToken: accessToken,
          refreshToken: body['refresh_token'] as String,
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
