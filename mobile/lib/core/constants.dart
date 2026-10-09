import 'package:flutter/foundation.dart';

/// Application-wide constants for DairyAI.
class AppConstants {
  AppConstants._();

  static const String appName = 'Milterra';
  static const String appTagline = 'A little goodness, every day.';
  static const bool flowSimulation =
      bool.fromEnvironment('FLOW_SIMULATION', defaultValue: false);

  // API
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  // Allows verified customer auth to launch before the commerce API cutover.
  static const String _envAuthApiOrigin =
      String.fromEnvironment('AUTH_API_BASE_URL', defaultValue: '');

  static String get authApiOrigin {
    if (_envAuthApiOrigin.isNotEmpty) return _envAuthApiOrigin;
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.contains('milterrafoods.com') || host.contains('pages.dev')) {
        return 'https://milterra-api-staging.todileepmaurya.workers.dev';
      }
    }
    return '';
  }

  static bool get separateCustomerAuth => authApiOrigin.isNotEmpty;
  static String get authBaseUrl =>
      '${separateCustomerAuth ? authApiOrigin : apiBaseUrl}$apiVersion';

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.contains('milterrafoods.com') || host.contains('pages.dev')) {
        return 'https://milterra-api-staging.todileepmaurya.workers.dev';
      }
      final fallbackHost = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return 'http://$fallbackHost:8000';
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  static const String apiVersion = '/api/v1';
  static String get baseUrl => '$apiBaseUrl$apiVersion';

  // Auth
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // OTP
  static const int otpLength = 6;
  static const int otpResendSeconds = 30;

  // Phone
  static const String phonePrefix = '+91';
  static const int phoneLength = 10;

  // Roles
  static const String roleFarmer = 'farmer';
  static const String roleVet = 'vet';
  static const String roleVendor = 'vendor';
  static const String roleCooperative = 'cooperative';
  static const String roleAdmin = 'admin';
  static const String roleSuperAdmin = 'super_admin';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
