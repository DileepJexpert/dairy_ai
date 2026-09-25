import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/marketplace/providers/merchandising_provider.dart';
import 'package:dairy_ai/features/marketplace/widgets/storefront_highlight_strip.dart';

void main() {
  const testProduct = Product(
    id: 'ghee-vedic-500',
    vendorId: 'milterra-farm',
    title: 'Milterra A2 Gir Cow Vedic Bilona Ghee',
    category: ProductCategory.feedNutrition,
    price: 1499,
    compareAtPrice: 1799,
    unit: 'jar',
    packSize: '500ml',
    brand: 'Milterra',
    inStock: true,
    availableQuantity: 10,
    media: ['assets/store/cow-ghee.png'],
  );

  Widget createHarness({
    required List<StorefrontPlacement> placements,
    String? currentProductId,
    GoRouter? router,
  }) {
    final effectiveRouter = router ??
        GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                body: StorefrontHighlightStrip(
                  currentProductId: currentProductId,
                ),
              ),
            ),
            GoRoute(
              path: '/shop/product/:id',
              builder: (_, state) => Scaffold(
                body: Text('ProductPage: ${state.pathParameters['id']}'),
              ),
            ),
          ],
        );

    return ProviderScope(
      overrides: [
        storefrontPlacementsProvider.overrideWith((ref) async => placements),
      ],
      child: MaterialApp.router(
        routerConfig: effectiveRouter,
      ),
    );
  }

  testWidgets('Renders Deal of the Day theme with flashing badge and discount',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final placement = StorefrontPlacement(
      id: 'deal-1',
      productId: testProduct.id,
      placementType: 'deal',
      headline: 'Today Special Offer: Pure Bilona Ghee',
      product: testProduct,
    );

    await tester.pumpWidget(createHarness(placements: [placement]));
    await tester.pumpAndSettle();

    expect(find.text('⚡ DEAL OF THE DAY'), findsOneWidget);
    expect(find.text('Today Special Offer: Pure Bilona Ghee'), findsOneWidget);
    expect(find.text('₹1,499'), findsOneWidget);
    expect(find.text('₹1,799'), findsOneWidget);
    expect(find.text('-17%'), findsOneWidget);
    expect(find.text('Grab Deal'), findsOneWidget);
  });

  testWidgets('Renders New Launch theme with custom badge and navigates on tap',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final placement = StorefrontPlacement(
      id: 'launch-1',
      productId: testProduct.id,
      placementType: 'new_launch',
      headline: 'New Launch: Hand-Churned Vedic Ghee',
      badge: '🔥 NEW LAUNCH SPECIAL',
      product: testProduct,
    );

    await tester.pumpWidget(createHarness(placements: [placement]));
    await tester.pumpAndSettle();

    expect(find.text('🔥 NEW LAUNCH SPECIAL'), findsOneWidget);
    expect(find.text('Shop Now'), findsOneWidget);

    // Tap to navigate
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('ProductPage: ghee-vedic-500'), findsOneWidget);
  });

  testWidgets('Adapts responsively to mobile layout with compact high-impact UI',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final placement = StorefrontPlacement(
      id: 'deal-mob',
      productId: testProduct.id,
      placementType: 'deal',
      headline: 'Limited Batch Offer',
      badge: 'MAXIMUM DISCOUNT 20%',
      product: testProduct,
    );

    await tester.pumpWidget(createHarness(placements: [placement]));
    await tester.pumpAndSettle();

    expect(find.text('MAXIMUM DISCOUNT 20%'), findsOneWidget);
    expect(find.text('Limited Batch Offer'), findsOneWidget);
    expect(find.text('₹1,499'), findsOneWidget);
    expect(find.text('Deal'), findsOneWidget);
  });
}
