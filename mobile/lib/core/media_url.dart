import 'constants.dart';

/// Uploaded images belong to the API host, not the Flutter development server.
String resolveMediaUrl(String value) =>
    value.startsWith('/api/v1/marketplace/media/')
        ? Uri.parse(AppConstants.apiBaseUrl).resolve(value).toString()
        : value;
