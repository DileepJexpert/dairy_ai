import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/app/shopping_navigation.dart';
import 'package:dairy_ai/features/commerce/models/taxonomy.dart';
import 'package:dairy_ai/features/commerce/providers/commerce_provider.dart';
import 'package:dairy_ai/features/commerce/screens/commerce_categories_screen.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/marketplace/widgets/store_design.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';
import 'package:dairy_ai/features/marketplace/screens/product_list_screen.dart';

const nodes = [
  TaxonomyNode(
      id: 'food', kind: 'department', name: 'Dairy Foods', slug: 'dairy-foods'),
  TaxonomyNode(
      id: 'ghee',
      kind: 'category',
      name: 'Cow ghee',
      slug: 'cow-ghee',
      parentId: 'food'),
  TaxonomyNode(
      id: 'farm',
      kind: 'department',
      name: 'Farm Essentials',
      slug: 'farm-essentials'),
];

void main() {
  setUpAll(() async {
    final font = FontLoader('CormorantGaramond')
      ..addFont(rootBundle.load('assets/fonts/CormorantGaramond.ttf'));
    await font.load();
  });
  testWidgets('Public shop renders server departments without sign-in',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          taxonomyProvider.overrideWith((ref) async =>
              const TaxonomyCatalogue(enabled: true, nodes: nodes)),
          productsProvider(null).overrideWith((ref) async => []),
        ],
        child: MaterialApp(
            theme: StoreTheme.light, home: const ProductListScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Dairy Foods'), findsWidgets);
    expect(find.text('Farm Essentials'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  test('Shopping returns stay internal and do not choose role dashboards', () {
    for (final input in [
      null,
      '',
      'https://evil.example/shop',
      '//evil.example/shop',
      '/home',
      '/vendor-dashboard'
    ]) {
      expect(shoppingReturnPath(input), '/shop');
    }
    expect(shoppingReturnPath('/marketplace/cart'), '/marketplace/cart');
    expect(shoppingReturnPath('/admin/commerce'), '/admin/commerce');
  });
  test('Department closure includes its categories only', () {
    const catalogue = TaxonomyCatalogue(enabled: true, nodes: nodes);
    expect(catalogue.descendants('food'), {'food', 'ghee'});
  });
  test('Enabled taxonomy never infers animal or human use from a title', () {
    final product = Product.fromJson({
      'id': '1',
      'vendor_id': '2',
      'title': 'Ghee named supplement',
      'category': 'FEED_NUTRITION',
      'base_price': '10',
      'taxonomy': null
    });
    expect(storeCategory(product), 'Uncategorized');
  });
  testWidgets('Customer cannot see category mutation controls', (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          commerceAccessProvider
              .overrideWith((ref) async => {'can_manage_taxonomy': false}),
        ],
        child: MaterialApp(
            theme: StoreTheme.light, home: const CommerceCategoriesScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('requires an authorized staff account'),
        findsOneWidget);
    expect(find.text('Add department'), findsNothing);
  });
  testWidgets('Admin taxonomy fits narrow and desktop layouts', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [360.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            commerceAccessProvider.overrideWith((ref) async =>
                {'can_manage_taxonomy': true, 'taxonomy_enabled': true}),
            adminTaxonomyProvider.overrideWith((ref) async => nodes),
          ],
          child: MaterialApp(
              theme: StoreTheme.light,
              home: const CommerceCategoriesScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Departments & categories'), findsOneWidget);
      expect(find.text('Farm Essentials'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
