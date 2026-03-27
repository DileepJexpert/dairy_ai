import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _baseUrl = '/api/v1';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  final storage = ref.read(secureStorageProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Attempt token refresh
          try {
            final refreshToken = await storage.read(key: 'refresh_token');
            if (refreshToken != null) {
              final response = await Dio().post(
                '$_baseUrl/auth/refresh',
                data: {'refresh_token': refreshToken},
              );
              if (response.data['success'] == true) {
                final newToken = response.data['data']['access_token'];
                final newRefresh = response.data['data']['refresh_token'];
                await storage.write(key: 'access_token', value: newToken);
                await storage.write(key: 'refresh_token', value: newRefresh);

                // Retry original request with new token
                error.requestOptions.headers['Authorization'] =
                    'Bearer $newToken';
                final retryResponse = await dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              }
            }
          } catch (_) {
            // Refresh failed — let the error propagate
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
});
