/// Application-wide constants for DairyAI.
class AppConstants {
  AppConstants._();

  static const String appName = 'DairyAI';
  static const String appTagline = 'Smart Dairy Management';

  // API
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const String apiVersion = '/api/v1';
  static const String baseUrl = '$apiBaseUrl$apiVersion';

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
  static const String roleAdmin = 'admin';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
