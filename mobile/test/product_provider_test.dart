import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';

void main() {
  test('Legacy carousel product ID resolves its live product by SKU', () async {
    final client = Dio();
    client.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      expect(request.path, '/marketplace/products');
      expect(request.queryParameters['sku'], 'MIL-GHEE-500');
      handler.resolve(Response(
        requestOptions: request,
        statusCode: 200,
        data: {
          'data': [
            {
              'id': 'a3b5d77f-4093-4ba8-a3e7-1d9ca3f15333',
              'vendor_id': 'a3b5d77f-4093-4ba8-a3e7-1d9ca3f15334',
              'title': 'Milterra A2 Desi Cow Ghee',
              'category': 'FEED_NUTRITION',
              'base_price': '799.00',
              'unit': 'jar',
              'pack_size': '500 ml',
              'in_stock': true,
              'available_quantity': 24,
            }
          ]
        },
      ));
    }));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(client),
      productsProvider(null).overrideWith((ref) async => <Product>[]),
    ]);
    addTearDown(container.dispose);

    final product =
        await container.read(productDetailProvider('mil-ghee-500').future);

    expect(product.id, 'a3b5d77f-4093-4ba8-a3e7-1d9ca3f15333');
    expect(product.price, 799);
  });
}
