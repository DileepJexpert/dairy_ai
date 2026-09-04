class CartItem {
  const CartItem(
      {required this.id,
      required this.productId,
      required this.title,
      required this.quantity,
      required this.priceWhenAdded,
      required this.currentPrice,
      required this.inStock,
      required this.lineTotal,
      this.vendorName,
      this.primaryImage,
      this.unit,
      this.priceChanged = false,
      this.availableQuantity = 0});
  final String id, productId, title;
  final int quantity, availableQuantity;
  final double priceWhenAdded, currentPrice, lineTotal;
  final bool priceChanged, inStock;
  final String? vendorName, primaryImage, unit;
  factory CartItem.fromJson(Map<String, dynamic> x) => CartItem(
      id: x['id'].toString(),
      productId: x['product_id'].toString(),
      title: x['title']?.toString() ?? '',
      quantity: x['quantity'] as int? ?? 0,
      priceWhenAdded: double.parse(x['price_when_added'].toString()),
      currentPrice: double.tryParse(x['current_price']?.toString() ?? '') ?? 0,
      priceChanged: x['price_changed'] as bool? ?? false,
      availableQuantity: x['available_quantity'] as int? ?? 0,
      inStock: x['in_stock'] as bool? ?? false,
      lineTotal: double.tryParse(x['line_total']?.toString() ?? '') ?? 0,
      vendorName: x['vendor_name']?.toString(),
      primaryImage: x['primary_image']?.toString(),
      unit: x['unit']?.toString());
}

class Cart {
  const Cart(
      {required this.id,
      required this.itemCount,
      required this.subtotal,
      required this.items});
  final String id;
  final int itemCount;
  final double subtotal;
  final List<CartItem> items;
  factory Cart.fromJson(Map<String, dynamic> x) => Cart(
      id: x['id'].toString(),
      itemCount: x['item_count'] as int? ?? 0,
      subtotal: double.tryParse(x['subtotal'].toString()) ?? 0,
      items: (x['items'] as List? ?? [])
          .map((x) => CartItem.fromJson(Map<String, dynamic>.from(x as Map)))
          .toList());
}
