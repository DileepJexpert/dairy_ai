import 'package:flutter/foundation.dart' show kIsWeb;

/// Only internal, known route families may be resumed after authentication.
/// The destination screen/API still enforces the user's workspace permissions.
String shoppingReturnPath(String? candidate) {
  final fallback = _defaultReturnPath();
  final uri = candidate == null ? null : Uri.tryParse(candidate);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      candidate!.contains('\\')) {
    return fallback;
  }
  if (uri.path == '/shop' ||
      uri.path == '/account' ||
      uri.path == '/shop/account' ||
      uri.path == '/profile' ||
      uri.path == '/wishlist' ||
      uri.path == '/balance' ||
      uri.path == '/home' ||
      uri.path.startsWith('/home') ||
      uri.path.startsWith('/herd') ||
      uri.path.startsWith('/health') ||
      uri.path.startsWith('/finance') ||
      uri.path.startsWith('/more') ||
      uri.path.startsWith('/vet') ||
      uri.path.startsWith('/admin') ||
      uri.path.startsWith('/seller') ||
      uri.path.startsWith('/vendor') ||
      uri.path.startsWith('/marketplace') ||
      uri.path.startsWith('/cooperative') ||
      uri.path.startsWith('/purity')) {
    return uri.toString();
  }
  return fallback;
}

String _defaultReturnPath() {
  if (kIsWeb) {
    try {
      final host = Uri.base.host.toLowerCase();
      if (host.startsWith('farmers.') || host.startsWith('farmer.')) {
        return '/home';
      }
    } catch (_) {}
  }
  return '/shop';
}
