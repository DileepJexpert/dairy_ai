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
      uri.path == '/admin/commerce' ||
      uri.path.startsWith('/marketplace/')) {
    return uri.toString();
  }
  return '/shop';
}
