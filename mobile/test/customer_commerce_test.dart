import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/cart/providers/wishlist_provider.dart';
import 'package:dairy_ai/features/cart/providers/order_repository.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import 'package:dairy_ai/features/cart/models/cart_models.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';
import 'package:dairy_ai/features/notifications/providers/notification_provider.dart';
import 'storefront_test.dart' as fixture;
import 'package:dairy_ai/features/marketplace/widgets/support_panel.dart';

Dio mock(dynamic Function(RequestOptions) respond) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
    try {
      h.resolve(Response(
          requestOptions: r, data: {'data': respond(r), 'success': true}));
    } catch (_) {
      h.reject(DioException(
          requestOptions: r, type: DioExceptionType.connectionError));
    }
  }));
  return dio;
}

void main() {
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('Backend help editor fits $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(overrides: [
        storeHelpProvider.overrideWith((ref) async => {
              'contact_message': 'Contact us here',
              'faqs': [
                {
                  'category': 'Launch',
                  'question': 'Can I order?',
                  'answer': 'Register interest.'
                }
              ]
            }),
        supportTicketsProvider.overrideWith((ref, admin) async => []),
      ], child: const MaterialApp(home: StoreHelpAdminScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit content'));
      await tester.pumpAndSettle();
      expect(find.text('Edit help content'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test(
      'Wishlist reload survives provider recreation and failed writes do not succeed',
      () async {
    final stored = <String>[];
    var fail = false;
    final dio = mock((r) {
      if (fail) throw StateError('offline');
      if (r.method == 'GET') return [...stored];
      if (r.method == 'PUT') stored.add(r.path.split('/').last);
      if (r.method == 'DELETE') stored.remove(r.path.split('/').last);
      return {};
    });
    ProviderContainer open() => ProviderContainer(overrides: [
          dioProvider.overrideWithValue(dio),
          wishlistProvider
              .overrideWith((ref) => WishlistNotifier(ref, enabled: false)),
          productDetailProvider.overrideWith(
              (ref, id) async => fixture.products.first.copyWith(id: id)),
        ]);
    final first = open();
    await first.read(wishlistProvider.notifier).add(fixture.products.first);
    first.dispose();
    final second = open();
    addTearDown(second.dispose);
    await second.read(wishlistProvider.notifier).refresh();
    expect(second.read(wishlistProvider).single.id, fixture.products.first.id);
    fail = true;
    await expectLater(
        second
            .read(wishlistProvider.notifier)
            .remove(fixture.products.first.id),
        throwsA(isA<DioException>()));
    expect(second.read(wishlistProvider), hasLength(1));
    await second.read(wishlistProvider.notifier).refresh();
    expect(second.read(wishlistErrorProvider), isNotNull);
  });

  test(
      'Order history and cancellation use server response, never local paid defaults',
      () async {
    var status = 'PENDING_PAYMENT';
    final requests = <String>[];
    Map<String, dynamic> order() => {
          'id': 'order-1',
          'created_at': '2026-09-14T00:00:00Z',
          'status': status,
          'payment_status': 'PENDING',
          'payment_method': 'upi',
          'is_prelaunch_interest': true,
          'address': {},
          'items': [],
          'subtotal': '799',
          'total': '749',
          'discount': '50',
          'timeline': []
        };
    final dio = mock((r) {
      requests.add('${r.method} ${r.path}');
      if (r.method == 'POST') {
        status = 'CANCELLED';
        return order();
      }
      return [order()];
    });
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      ordersNotifierProvider
          .overrideWith((ref) => OrderNotifier(ref, enabled: false))
    ]);
    addTearDown(container.dispose);
    await container.read(ordersNotifierProvider.notifier).refresh();
    final loaded = container.read(ordersNotifierProvider).single;
    expect(loaded.paymentStatus, 'PENDING');
    expect(loaded.trackingNumber, isEmpty);
    expect(loaded.isPrelaunchInterest, isTrue);
    await container
        .read(ordersNotifierProvider.notifier)
        .cancelOrder('order-1', reason: 'Later');
    expect(container.read(ordersNotifierProvider).single.status, 'CANCELLED');
    expect(requests, contains('POST /marketplace/orders/order-1/cancel'));
  });

  test(
      'Saved-for-later uses the atomic move endpoint, not delete then local append',
      () async {
    final requests = <String>[];
    final dio = mock((r) {
      requests.add('${r.method} ${r.path}');
      if (r.path == '/marketplace/saved-items') return [];
      if (r.path == '/marketplace/cart')
        return {'id': 'cart', 'item_count': 0, 'subtotal': '0', 'items': []};
      return {};
    });
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      savedForLaterProvider
          .overrideWith((ref) => SavedForLaterNotifier(ref, enabled: false)),
      cartProvider.overrideWith((ref) => CartNotifier(dio, null, false))
    ]);
    addTearDown(container.dispose);
    final item = CartItem.fromJson({
      'id': 'line-1',
      'product_id': 'product-1',
      'title': 'Ghee',
      'quantity': 1,
      'current_price': '799',
      'price_when_added': '799',
      'line_total': '799',
      'available_quantity': 3,
      'in_stock': true
    });
    await container.read(savedForLaterProvider.notifier).save(item);
    expect(requests.first, 'POST /marketplace/cart/items/line-1/save');
    expect(requests.any((r) => r.startsWith('DELETE')), isFalse);
  });

  test('Notifications call authenticated API contract for read and read-all',
      () async {
    final requests = <String>[];
    final notifier = NotificationNotifier(mock((r) {
      requests.add('${r.method} ${r.path}');
      return [];
    }));
    addTearDown(notifier.dispose);
    await notifier.markRead('n-1');
    await notifier.markAllRead();
    expect(requests,
        ['PUT /notifications/n-1/read', 'PUT /notifications/read-all']);
  });
}
