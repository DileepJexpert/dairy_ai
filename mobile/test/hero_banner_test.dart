import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/marketplace/models/hero_showcase_config.dart';
import 'package:dairy_ai/features/marketplace/models/home_hero_config.dart';
import 'package:dairy_ai/features/marketplace/widgets/hero_split_showcase.dart';

void main() {
  group('Hero Banner & Panoramic Assets Tests', () {
    test('home_hero.json contains valid panoramic milk bottle asset', () {
      final file = File('assets/catalogue/home_hero.json');
      expect(file.existsSync(), isTrue, reason: 'home_hero.json must exist');

      final content = file.readAsStringSync();
      final config = HomeHeroConfig.parse(content);

      // Verify product 9ab837fd-142d-4799-85ef-02a58e93bb8c
      final milkSlide = config.productSlides.firstWhere(
        (s) => s.productId == '9ab837fd-142d-4799-85ef-02a58e93bb8c',
      );
      expect(
        milkSlide.heroImage,
        equals('assets/store/panoramic-milk-bottle-hero.jpg'),
        reason: 'Milk bottle hero image must be the seamless 1920x340 panoramic banner',
      );

      // Verify asset file exists on disk
      final assetFile = File('assets/store/panoramic-milk-bottle-hero.jpg');
      expect(
        assetFile.existsSync(),
        isTrue,
        reason: 'panoramic-milk-bottle-hero.jpg must exist in assets/store',
      );
    });

    testWidgets('HeroSplitShowcase renders milk bottle slide cleanly without overflow on desktop and mobile', (tester) async {
      final slide = HeroProductSlide(
        id: '9ab837fd-142d-4799-85ef-02a58e93bb8c',
        category: 'Fresh Milk',
        badge: 'Farm Fresh A2 Milk',
        name: 'MILTERRA Pure A2 Sahiwal Cow Milk (1 Litre Glass Bottle)',
        packSize: '1 Litre',
        price: 85.0,
        originalPrice: 95.0,
        description: 'Farm-fresh raw chilled A2 Sahiwal cow milk',
        imagePath: 'assets/store/panoramic-milk-bottle-hero.jpg',
        targetRoute: '/shop/product/9ab837fd-142d-4799-85ef-02a58e93bb8c',
      );

      // Desktop Viewport Test
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroSplitShowcase(
                screenWidth: 1400,
                productSlides: [slide],
                autoPlay: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 LITRE MILTERRA PURE A2 SAHIWAL COW MILK (1 LITRE GLASS BOTTLE)'), findsOneWidget);
      expect(find.text('SAVE ₹10'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Zero rendering or overflow exceptions on desktop');

      // Mobile Viewport Test
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HeroSplitShowcase(
                screenWidth: 390,
                productSlides: [slide],
                autoPlay: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 LITRE MILTERRA PURE A2 SAHIWAL COW MILK (1 LITRE GLASS BOTTLE)'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Zero rendering or overflow exceptions on mobile');
    });
  });
}
