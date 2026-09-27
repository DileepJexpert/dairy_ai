import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/core/storage.dart';

class MemoryStorage extends SecureStorageService {
  int refreshReads = 0;
  @override
  Future<String?> getAccessToken() async => 'test-session';
  @override
  Future<String?> getRefreshToken() async {
    refreshReads++;
    return null;
  }
}

void main() {
  test('auth uses its verified origin and retains the API path', () async {
    final dio = createDioClient(MemoryStorage());
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.uri.toString(), '${AppConstants.authBaseUrl}/auth/me');
      expect(options.headers['Authorization'], 'Bearer test-session');
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {}));
    }));
    await dio.get('/auth/me');
  });

  test('bad credentials never trigger a session refresh', () async {
    final storage = MemoryStorage();
    final dio = createDioClient(storage);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.reject(DioException(requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: options, statusCode: 401)), true);
    }));
    await expectLater(dio.post('/auth/login-password', data: {
      'identifier': 'customer', 'password': 'incorrect-password',
    }), throwsA(isA<DioException>()));
    expect(storage.refreshReads, 0);
  });

  test('auth-only release blocks commerce before network or credentials', () async {
    if (!AppConstants.separateCustomerAuth) return;
    final dio = createDioClient(MemoryStorage());
    var networkReached = false;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      networkReached = true;
      handler.resolve(Response(requestOptions: options, statusCode: 200));
    }));
    await expectLater(dio.post('/marketplace/checkout'), throwsA(
      isA<DioException>().having((e) => e.response?.statusCode, 'status', 503),
    ));
    expect(networkReached, isFalse);
  });
}
