import 'package:dio/dio.dart';
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

  // --- Logging interceptor (debug builds only) ---
  dio.interceptors.add(
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) {
        assert(() {
          // ignore: avoid_print
          print(obj);
          return true;
        }());
      },
    ),
  );

  return dio;
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
