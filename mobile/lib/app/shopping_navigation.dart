/// Only internal, known route families may be resumed after authentication.
/// The destination screen/API still enforces the user's workspace permissions.
String shoppingReturnPath(String? candidate) {
  final uri = candidate == null ? null : Uri.tryParse(candidate);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/') ||
      candidate!.contains('\\')) {
    return '/shop';
  }
  if (uri.path == '/shop' ||
      uri.path == '/account' ||
      uri.path == '/shop/account' ||
      uri.path == '/profile' ||
      uri.path == '/wishlist' ||
      uri.path == '/balance' ||
      uri.path.startsWith('/admin') ||
      uri.path.startsWith('/seller') ||
      uri.path.startsWith('/vendor') ||
      uri.path.startsWith('/marketplace')) {
    return uri.toString();
  }
  return '/shop';
}
