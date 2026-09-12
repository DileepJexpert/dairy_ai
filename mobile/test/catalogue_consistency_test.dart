import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/marketplace/models/concept_catalogue.dart';
import 'package:dairy_ai/features/marketplace/widgets/store_product_card.dart';
import 'package:dairy_ai/features/cart/providers/wishlist_provider.dart';
import 'storefront_test.dart' as harness;

void main() {
  setUpAll(() async {
    final font = FontLoader('CormorantGaramond')
      ..addFont(rootBundle.load('assets/fonts/CormorantGaramond.ttf'));
    await font.load();
  });

  test('Families preserve SKU IDs and never combine separate sellers', () {
    final groups = storeProductGroups([
      ...harness.products,
      harness.products.first
          .copyWith(id: 'another-offer', vendorId: 'other-seller'),
    ]);
    expect(groups.length, 4);
    expect(groups.first.map((p) => p.id), ['cow500', 'cow1000']);
    expect(groups.last.single.id, 'another-offer');
    expect(harness.products.first.isConcept, isFalse);
    expect(
        harness.products.first.copyWith(title: 'Calcium supplement').isConcept,
        isFalse);
  });

  test('Concept manifest keeps stable IDs and all image assets exist',
      () async {
    expect(conceptCatalogue.any((p) => p.id == 'feed-janam-42'), isTrue);
    expect(conceptCatalogue.any((p) => p.id == 'mil-butter-250'), isTrue);
    for (final p in conceptCatalogue) {
      expect(p.canPurchase, isFalse);
      expect(p.inStock, isFalse);
      expect(p.description, Product.conceptExplanation);
      for (final path in p.media) {
        expect((await rootBundle.load(path)).lengthInBytes, greaterThan(0));
      }
    }
  });

  test('Wishlist starts empty and saves/removes the actual selected variant',
      () {
    final wishlist = WishlistNotifier();
    addTearDown(wishlist.dispose);
    expect(wishlist.state, isEmpty);
    wishlist.toggle(harness.products[1]);
    expect(wishlist.state.single.id, 'cow1000');
    wishlist.toggle(harness.products[1]);
    expect(wishlist.state, isEmpty);
    wishlist.toggle(conceptCatalogue.first);
    expect(wishlist.state.single.isConcept, isTrue);
  });

  for (final width in [360.0, 390.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('JANAM concept layout and purchase policy at $width',
        (tester) async {
      await harness.openStore(tester,
          width: width,
          path: '/shop/product/feed-janam-42',
          catalogue: [...harness.products, ...conceptCatalogue]);
      expect(find.text('Concept Preview'), findsWidgets);
      expect(find.text('Share Farmer Feedback'), findsOneWidget);
      expect(find.text('Register for Updates'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-add-to-cart')), findsNothing);
      expect(find.byKey(const ValueKey('detail-buy-now')), findsNothing);
      expect(find.textContaining('₹0'), findsNothing);
      expect(find.textContaining('129 ratings'), findsNothing);
      expect(find.textContaining('49 answered questions'), findsNothing);
      expect(find.text('Customer reviews'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Register for Updates'));
      await tester.tap(find.text('Register for Updates'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('registration is not open yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('Concept-only collection hides price and stock controls',
      (tester) async {
    await harness.openStore(tester,
        path: '/shop?category=Stage-Based%20Nutrition',
        catalogue: [...harness.products, ...conceptCatalogue]);
    expect(find.byKey(const ValueKey('catalogue-open-feed-janam-42')),
        findsOneWidget);
    expect(find.text('PRICE'), findsNothing);
    expect(find.text('In Stock only'), findsNothing);
    expect(find.textContaining('₹0'), findsNothing);
    await tester.ensureVisible(find.text('Sort: Featured'));
    await tester.tap(find.text('Sort: Featured'));
    await tester.pumpAndSettle();
    expect(find.text('Sort: Price: low to high'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Butter uses the same concept image on its detail page',
      (tester) async {
    await harness.openStore(tester,
        width: 390,
        path: '/shop/product/mil-butter-250',
        catalogue: [...harness.products, ...conceptCatalogue]);
    final images = tester.widgetList<Image>(find.byType(Image));
    expect(
        images.any((image) =>
            image.image is AssetImage &&
            (image.image as AssetImage).assetName ==
                'assets/store/white-butter-concept.png'),
        isTrue);
    expect(find.textContaining('Concept packaging image'), findsWidgets);
    expect(find.byKey(const ValueKey('detail-add-to-cart')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
