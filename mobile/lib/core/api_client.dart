import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/storage.dart';

/// Creates and configures a [Dio] HTTP client with auth token injection,
/// automatic token refresh, and standardised error handling.
Dio createDioClient(SecureStorageService storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // --- Auth token interceptor ---
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Attempt refresh on 401
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefreshToken(dio, storage);
          if (refreshed) {
            final token = await storage.getAccessToken();
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
        }
        return handler.next(error);
      },
    ),
  );

  // --- Detailed Logging interceptor (with credential sanitization) ---
  if (kDebugMode) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          debugPrint(
              '[HTTP REQ] ${options.method} ${options.baseUrl}${options.path} data: ${_sanitizeLogPayload(options.data)} query: ${_sanitizeLogPayload(options.queryParameters)}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint(
              '[HTTP RES] ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}');
          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint(
              '[HTTP ERR] ${error.response?.statusCode} ${error.requestOptions.method} ${error.requestOptions.path}: ${error.message}');
          if (error.response?.data != null) {
            debugPrint(
                '[HTTP ERR BODY] ${_sanitizeLogPayload(error.response?.data)}');
          }
          debugPrint('[HTTP ERR STACK] ${error.stackTrace}');
          return handler.next(error);
        },
      ),
    );
  }

  return dio;
}

/// Redacts sensitive keys such as passwords, tokens, OTPs, and card details from log output.
dynamic _sanitizeLogPayload(dynamic data) {
  if (data is Map) {
    const sensitiveKeys = {
      'password',
      'token',
      'access_token',
      'refresh_token',
      'secret',
      'otp',
      'authorization',
      'card_number',
      'cvv',
      'idempotency_key',
    };
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key.toString();
      if (sensitiveKeys.contains(key.toLowerCase())) {
        sanitized[key] = '***REDACTED***';
      } else {
        sanitized[key] = _sanitizeLogPayload(entry.value);
      }
    }
    return sanitized;
  }
  if (data is Iterable) {
    return data.map(_sanitizeLogPayload).toList(growable: false);
  }
  return data;
}

/// Attempts to refresh the access token using the stored refresh token.
Future<bool> _tryRefreshToken(
  Dio dio,
  SecureStorageService storage,
) async {
  try {
    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) return false;

    final response = await Dio(
      BaseOptions(baseUrl: AppConstants.baseUrl),
    ).post(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final data = response.data;
    if (data['success'] == true) {
      await storage.setAccessToken(data['data']['access_token'] as String);
      await storage.setRefreshToken(data['data']['refresh_token'] as String);
      return true;
    }
    return false;
  } catch (_) {
    await storage.clearAll();
    return false;
  }
}

/// Riverpod provider for the Dio client.
/// Usage: final dio = ref.read(apiClientProvider);
final apiClientProvider = Provider<Dio>((ref) {
  // In production this would use the real SecureStorageService.
  // For now, return a basic configured Dio that can be overridden in tests.
  return Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );
});

/// Extracts a human-friendly error message from a [DioException].
String dioErrorMessage(DioException error) {
  if (error.response?.data is Map) {
    final msg = (error.response!.data as Map)['message'];
    if (msg is String && msg.isNotEmpty) return msg;
  }
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Connection timed out. Please check your internet.';
    case DioExceptionType.connectionError:
      return 'Could not connect to server. Please try again.';
    case DioExceptionType.badResponse:
      return 'Server error (${error.response?.statusCode}). Please try later.';
    default:
      return 'Something went wrong. Please try again.';
  }
}
