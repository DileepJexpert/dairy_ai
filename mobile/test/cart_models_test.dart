import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/cart/models/cart_models.dart';

void main() {
  test('cart parsing retains price-change and subtotal data', () {
    final cart = Cart.fromJson({
      'id': 'cart-1',
      'item_count': 2,
      'subtotal': '1800',
      'items': [
        {
          'id': 'item-1',
          'product_id': 'product-1',
          'title': 'Mineral Mixture',
          'quantity': 2,
          'price_when_added': '850',
          'current_price': '900',
          'price_changed': true,
          'available_quantity': 4,
          'in_stock': true,
          'line_total': '1800'
        }
      ]
    });
    expect(cart.itemCount, 2);
    expect(cart.subtotal, 1800);
    expect(cart.items.single.priceChanged, isTrue);
    expect(cart.items.single.lineTotal, 1800);
  });
}
