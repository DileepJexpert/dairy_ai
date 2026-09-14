import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/admin/providers/admin_marketplace_provider.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/auth/models/user_model.dart';
import 'package:dairy_ai/features/cart/providers/coupon_provider.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';

Map<String, dynamic> snapshot({String price = '799.00'}) => {
      'sellers': [],
      'coupons': [],
      'audit_logs': [],
      'batch_certificates': [],
      'offers': [
        {
          'id': 'product-1',
          'product_id': 'product-1',
          'seller_id': 'seller-1',
          'seller_name': 'Database Seller',
          'seller_sku': 'BACKEND-SKU',
          'mrp': '999.00',
          'selling_price': price,
          'discount_percent': 20,
          'available_stock': 12,
          'low_stock_threshold': 2,
          'offer_status': 'active',
          'seller_rating': 0,
        }
      ],
    };

Dio clientWith(
    void Function(RequestOptions, RequestInterceptorHandler) handler) {
  final client = Dio();
  client.interceptors.add(InterceptorsWrapper(onRequest: handler));
  return client;
}

void main() {
  test('Admin refresh has no demo fallback and exposes backend errors',
      () async {
    final dio = clientWith((request, handler) => handler.reject(DioException(
        requestOptions: request, type: DioExceptionType.connectionError)));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      adminMarketplaceProvider.overrideWith((ref) =>
          AdminMarketplaceNotifier(ref, dio, admin: true, enabled: false)),
    ]);
    addTearDown(container.dispose);
    await container.read(adminMarketplaceProvider.notifier).refresh();
    final state = container.read(adminMarketplaceProvider);
    expect(state.offers, isEmpty);
    expect(state.coupons, isEmpty);
    expect(state.batchCertificates, isEmpty);
    expect(state.error, isNotNull);
  });

  test(
      'Admin price save waits for the API, reloads, and survives a new container',
      () async {
    var price = '799.00';
    var reject = false;
    final requests = <String>[];
    final dio = clientWith((request, handler) {
      requests.add('${request.method} ${request.path}');
      if (request.method == 'PATCH') {
        if (reject) {
          handler.reject(DioException(
              requestOptions: request,
              response: Response(
                  requestOptions: request,
                  statusCode: 422,
                  data: {'detail': 'MRP too low'})));
          return;
        }
        price = request.data['selling_price'].toString();
        handler.resolve(
            Response(requestOptions: request, data: {'success': true}));
      } else {
        handler.resolve(Response(
            requestOptions: request, data: {'data': snapshot(price: price)}));
      }
    });
    ProviderContainer open() => ProviderContainer(overrides: [
          dioProvider.overrideWithValue(dio),
          adminMarketplaceProvider.overrideWith((ref) =>
              AdminMarketplaceNotifier(ref, dio, admin: true, enabled: false)),
        ]);
    final first = open();
    addTearDown(first.dispose);
    final notifier = first.read(adminMarketplaceProvider.notifier);
    await notifier.refresh();
    await notifier.updateOfferPrice('product-1', 650, 999);
    expect(
        first.read(adminMarketplaceProvider).offers.single.sellingPrice, 650);
    expect(requests, contains('PATCH /admin/commerce/offers/product-1'));
    reject = true;
    await expectLater(notifier.updateOfferPrice('product-1', 700, 1),
        throwsA(isA<DioException>()));
    expect(
        first.read(adminMarketplaceProvider).offers.single.sellingPrice, 650);
    final second = open();
    addTearDown(second.dispose);
    await second.read(adminMarketplaceProvider.notifier).refresh();
    expect(
        second.read(adminMarketplaceProvider).offers.single.sellingPrice, 650);
  });

  test('Customer coupons are loaded and validated by backend, including cap',
      () async {
    final coupon = {
      'code': 'DB10',
      'description': 'Database coupon',
      'discount_type': 'percentage',
      'discount_value': '10.00',
      'min_order_value': '100.00',
      'max_discount_cap': '50.00'
    };
    final dio = clientWith((request, handler) {
      if (request.method == 'POST') {
        expect(request.path, '/marketplace/coupons/quote');
        expect(request.data, {'code': 'DB10'});
        handler.resolve(Response(requestOptions: request, data: {
          'data': {'coupon': coupon}
        }));
      } else {
        expect(request.path, '/marketplace/coupons');
        handler.resolve(Response(requestOptions: request, data: {
          'data': [coupon]
        }));
      }
    });
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      currentUserProvider.overrideWithValue(
          const UserModel(id: 'u', phone: '1234567890', role: 'farmer'))
    ]);
    addTearDown(container.dispose);
    expect((await container.read(availableCouponsProvider.future)).single.code,
        'DB10');
    expect(
        await container
            .read(appliedCouponProvider.notifier)
            .applyCoupon(' db10 ', 799),
        isTrue);
    expect(container.read(appliedCouponProvider)!.calculateDiscount(799), 50);
    expect(container.read(appliedCouponProvider)!.calculateDiscount(99), 0);
  });

  test('Unavailable API never injects hardcoded catalogue products', () async {
    final dio = clientWith((r, h) => h.reject(DioException(requestOptions: r)));
    final container =
        ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(container.dispose);
    await expectLater(container.read(productsProvider(null).future),
        throwsA(isA<DioException>()));
  });

  test('Published backend concept families are included without purchasing',
      () async {
    final dio = clientWith((r, h) => h.resolve(Response(
        requestOptions: r,
        data: r.path.endsWith('/families')
            ? {
                'data': [
                  {
                    'id': 'family-id',
                    'vendor_id': 'seller-id',
                    'title': 'New Backend Concept',
                    'brand': 'MILTERRA',
                    'department': 'Farm Essentials',
                    'collection': 'Animal Nutrition',
                    'description': 'In development',
                    'is_concept': true,
                    'is_published': true,
                    'primary_image': 'assets/store/minera-360-jar.jpg'
                  }
                ]
              }
            : {'data': [], 'total': 0})));
    final container =
        ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(container.dispose);
    final product =
        (await container.read(productsProvider(null).future)).single;
    expect(product.id, 'family-family-id');
    expect(product.title, 'New Backend Concept');
    expect(product.isConcept, isTrue);
    expect(product.canPurchase, isFalse);
    expect(product.media, ['assets/store/minera-360-jar.jpg']);
  });

  test('Family concepts do not borrow unrelated public certificates', () async {
    final dio = clientWith(
        (r, h) => fail('No certificate request expected for a concept family'));
    final container =
        ProviderContainer(overrides: [dioProvider.overrideWithValue(dio)]);
    addTearDown(container.dispose);
    expect(
        await container
            .read(publicCertificatesProvider('family-example').future),
        isEmpty);
  });
}
