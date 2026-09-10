import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/app/store_theme.dart';
import 'package:dairy_ai/features/commerce/models/taxonomy.dart';
import 'package:dairy_ai/features/commerce/providers/commerce_provider.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/auth/models/user_model.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';
import 'package:dairy_ai/features/marketplace/screens/product_list_screen.dart';
import 'package:dairy_ai/features/marketplace/screens/product_detail_screen.dart';

const products = [
  Product(
      id: 'cow500',
      vendorId: 'seller',
      title: 'Milterra A2 Desi Cow Ghee',
      category: ProductCategory.feedNutrition,
      price: 799,
      unit: 'jar',
      packSize: '500 ml',
      brand: 'Milterra',
      inStock: true,
      availableQuantity: 3,
      vendor: {'business_name': 'Milterra Dairy'}),
  Product(
      id: 'cow1000',
      vendorId: 'seller',
      title: 'Milterra A2 Desi Cow Ghee',
      category: ProductCategory.feedNutrition,
      price: 1499,
      unit: 'jar',
      packSize: '1 litre',
      inStock: true,
      availableQuantity: 4),
  Product(
      id: 'paneer',
      vendorId: 'seller',
      title: 'Milterra Fresh Paneer',
      category: ProductCategory.feedNutrition,
      price: 160,
      unit: 'pack',
      packSize: '200 g',
      inStock: true,
      availableQuantity: 5),
  Product(
      id: 'buffalo',
      vendorId: 'seller',
      title: 'Milterra Buffalo Ghee',
      category: ProductCategory.feedNutrition,
      price: 699,
      unit: 'jar',
      packSize: '500 ml'),
];

Future<GoRouter> openStore(WidgetTester tester,
    {double width = 1440,
    String path = '/shop',
    bool fail = false,
    Dio? client}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: path, routes: [
    GoRoute(
        path: '/shop',
        builder: (_, __) =>
            const ProductListScreen(category: ProductCategory.feedNutrition)),
    GoRoute(
        path: '/marketplace/product/:id',
        builder: (_, s) =>
            ProductDetailScreen(productId: s.pathParameters['id']!)),
    GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: Text('Sign in to continue'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(overrides: [
    currentUserProvider.overrideWith((ref) => client == null
        ? null
        : const UserModel(id: 'shopper', phone: '9999900001', role: 'farmer')),
    commerceAccessProvider
        .overrideWith((ref) async => {'can_manage_taxonomy': false}),
    if (client != null) dioProvider.overrideWithValue(client),
    taxonomyProvider.overrideWith(
        (ref) async => const TaxonomyCatalogue(enabled: false, nodes: [])),
    productsProvider(ProductCategory.feedNutrition).overrideWith((ref) async {
      if (fail) throw Exception('offline');
      return products;
    }),
    for (final p in products)
      productDetailProvider(p.id).overrideWith((ref) async => p),
  ], child: MaterialApp.router(theme: StoreTheme.light, routerConfig: router)));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUpAll(() async {
    final font = FontLoader('CormorantGaramond')
      ..addFont(rootBundle.load('assets/fonts/CormorantGaramond.ttf'));
    await font.load();
  });
  for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('Storefront and detail fit width $width', (tester) async {
      final router = await openStore(tester, width: width);
      expect(find.text('Shop by category'), findsOneWidget);
      expect(find.text('3 products'), findsOneWidget);
      expect(tester.takeException(), isNull);
      router.go('/marketplace/product/cow500');
      await tester.pumpAndSettle();
      expect(find.text('About this item'), findsOneWidget);
      expect(find.text('Product information'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Search, clear, category and price sort affect actual products',
      (tester) async {
    await openStore(tester);
    await tester.enterText(find.byType(TextField), 'paneer');
    await tester.pumpAndSettle();
    expect(find.text('1 products for “paneer”'), findsOneWidget);
    expect(find.text('Fresh Paneer'), findsOneWidget);
    expect(find.text('Buffalo Ghee'), findsNothing);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cow ghee').first);
    await tester.pumpAndSettle();
    expect(find.text('1 products'), findsOneWidget);
    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sort: Featured'));
    await tester.tap(find.text('Sort: Featured'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort: Price: low to high').last);
    await tester.pumpAndSettle();
    final paneer = tester.getTopLeft(find.text('Fresh Paneer'));
    final buffalo = tester.getTopLeft(find.text('Buffalo Ghee'));
    expect(paneer.dx, lessThan(buffalo.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mobile filter sheet works and empty results can be cleared',
      (tester) async {
    await openStore(tester, width: 390);
    await tester.ensureVisible(find.byTooltip('Filter products'));
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In stock only'));
    await tester.tap(find.text('Show products'));
    await tester.pumpAndSettle();
    expect(find.text('2 products'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'not a product');
    await tester.pumpAndSettle();
    expect(find.text('No products found'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear filters'));
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('3 products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Quantity is stock bounded and guest purchase preserves destination',
      (tester) async {
    final router = await openStore(tester, path: '/marketplace/product/cow500');
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Item total: ₹2,397'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Increase quantity'))
            .onPressed,
        isNull);
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Add to cart').first);
    await tester.tap(find.widgetWithText(FilledButton, 'Add to cart').first);
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.queryParameters['next'],
        '/marketplace/product/cow500');
  });

  testWidgets('Pack choice navigates to the matching real product',
      (tester) async {
    await openStore(tester, path: '/marketplace/product/cow500');
    await tester.tap(find.widgetWithText(ChoiceChip, '1 litre').first);
    await tester.pumpAndSettle();
    expect(find.text('₹1,499'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Unavailable product cannot be purchased', (tester) async {
    await openStore(tester, path: '/marketplace/product/buffalo');
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Add to cart').first)
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Proceed to checkout'))
            .onPressed,
        isNull);
  });

  testWidgets('Back from a product restores search and scroll position',
      (tester) async {
    final router = await openStore(tester);
    await tester.enterText(find.byType(TextField), 'paneer');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Fresh Paneer'));
    final before = tester.getTopLeft(find.text('Fresh Paneer')).dy;
    await tester.tap(find.text('Fresh Paneer'));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    await tester.tap(find.text('Back to shop'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'paneer');
    expect(find.text('1 products for “paneer”'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Fresh Paneer')).dy, closeTo(before, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selected catalogue pack keeps its own price and detail ID',
      (tester) async {
    final router = await openStore(tester);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, '1 litre'));
    await tester.tap(find.widgetWithText(ChoiceChip, '1 litre'));
    await tester.pumpAndSettle();
    expect(find.text('₹1,499'), findsOneWidget);
    expect(find.text('₹799'), findsNothing);
    await tester.ensureVisible(find.text('A2 Desi Cow Ghee'));
    await tester.tap(find.text('A2 Desi Cow Ghee'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
            .productId,
        'cow1000');
    expect(router.canPop(), isTrue);
  });

  testWidgets(
      'Authenticated add opens cart drawer and continue keeps product state',
      (tester) async {
    Map<String, dynamic>? submitted;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      if (request.method == 'POST') {
        submitted = Map<String, dynamic>.from(request.data);
      }
      handler.resolve(Response(requestOptions: request, statusCode: 200, data: {
        'data': {
          'id': 'cart',
          'item_count': submitted == null ? 0 : 2,
          'subtotal': submitted == null ? '0' : '1598',
          'items': submitted == null
              ? []
              : [
                  {
                    'id': 'line',
                    'product_id': 'cow500',
                    'title': products.first.title,
                    'quantity': 2,
                    'price_when_added': '799',
                    'current_price': '799',
                    'line_total': '1598',
                    'in_stock': true,
                    'available_quantity': 3,
                  }
                ],
        }
      }));
    }));
    final router = await openStore(tester,
        path: '/marketplace/product/cow500', client: dio);
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Add to cart').first);
    await tester.tap(find.widgetWithText(FilledButton, 'Add to cart').first);
    await tester.pumpAndSettle();
    expect(submitted, {'product_id': 'cow500', 'quantity': 2});
    expect(find.text('Your shopping bag'), findsOneWidget);
    expect(find.text('₹1,598'), findsNWidgets(2));
    await tester.tap(find.text('Continue shopping'));
    await tester.pumpAndSettle();
    expect(find.text('Your shopping bag'), findsNothing);
    expect(find.text('Item total: ₹1,598'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path,
        '/marketplace/product/cow500');
    expect(tester.takeException(), isNull);
  });

  testWidgets('API failure offers retry instead of demo products',
      (tester) async {
    await openStore(tester, fail: true);
    expect(find.text('We couldn’t load the collection'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Fresh Paneer'), findsNothing);
  });
}
