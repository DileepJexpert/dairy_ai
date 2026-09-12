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
      uri.path == '/admin/ecommerce' ||
      uri.path == '/admin-dashboard' ||
      uri.path == '/admin-farmers' ||
      uri.path == '/admin-vets' ||
      uri.path == '/seller/dashboard' ||
      uri.path == '/vendor-dashboard' ||
      uri.path == '/vendor-orders' ||
      uri.path == '/vendor-profile' ||
      uri.path == '/vendor/products' ||
      uri.path.startsWith('/marketplace/')) {
    return uri.toString();
  }
  return '/shop';
}
