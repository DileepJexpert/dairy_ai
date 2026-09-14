import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/commerce/screens/commerce_products_screen.dart';

void main() {
  testWidgets(
      'Flat SKU price and stock save to backend, failed edits retain form',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var price = 799.0;
    var stock = 9;
    var fail = false;
    var patches = 0;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
      if (r.method == 'PATCH') {
        expect(r.path, '/admin/commerce/offers/p1');
        patches++;
        if (fail) {
          h.reject(DioException(
              requestOptions: r, type: DioExceptionType.connectionError));
          return;
        }
        price = (r.data['selling_price'] as num).toDouble();
        stock = r.data['available_stock'] as int? ?? stock;
      }
      final data = r.path == '/vendor/products'
          ? [
              {
                'id': 'p1',
                'vendor_id': 'v1',
                'title': 'Milterra Test Ghee',
                'base_price': '$price',
                'unit': 'jar',
                'pack_size': '500 ml',
                'in_stock': stock > 0,
                'available_quantity': stock,
                'publication_status': 'published',
                'category': 'FEED_NUTRITION',
                'media': []
              }
            ]
          : [];
      h.resolve(
          Response(requestOptions: r, data: {'success': true, 'data': data}));
    }));
    await tester.pumpWidget(ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: CommerceProductsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All SKU Inventory Table (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('₹799').first);
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(fields.at(0), '850');
    await tester.enterText(fields.at(1), '7');
    await tester.tap(find.text('Save Price & Stock'));
    await tester.pumpAndSettle();
    expect(patches, 1);
    expect(price, 850);
    expect(stock, 7);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    fail = true;
    await tester.tap(find.text('₹850').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField))
            .first,
        '900');
    await tester.tap(find.text('Save Price & Stock'));
    await tester.pumpAndSettle();
    expect(price, 850);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
