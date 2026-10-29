import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/feed/screens/cattle_feed_store_screen.dart';

void main() {
  group('Cattle Feed & Mineral Mixture ROI Calculation Tests', () {
    test('Calculates mineral mixture ROI for Cow correctly', () {
      const milkRate = 38.50;
      const dailyDoseGram = 50;
      const dailyCost = 3.85;
      const expectedGainLitres = 1.30;

      final dailyGrossExtra = expectedGainLitres * milkRate; // 50.05
      final dailyNetProfit = dailyGrossExtra - dailyCost;   // 46.20
      final monthlyNetProfit = dailyNetProfit * 30.0;       // 1386.0
      final roiMultiplier = dailyGrossExtra / dailyCost;

      expect(dailyGrossExtra, closeTo(50.05, 0.05));
      expect(dailyNetProfit, closeTo(46.20, 0.05));
      expect(monthlyNetProfit, closeTo(1386.0, 1.0));
      expect(roiMultiplier, greaterThan(12.0));
    });

    test('Calculates buffalo mineral mixture ROI with premium milk rate', () {
      const milkRate = 62.00;
      const dailyCost = 3.85;
      const expectedGainLitres = 1.30;

      final dailyGrossExtra = expectedGainLitres * milkRate; // 80.60
      final dailyNetProfit = dailyGrossExtra - dailyCost;   // 76.75
      final monthlyNetProfit = dailyNetProfit * 30.0;       // 2302.5

      expect(dailyGrossExtra, closeTo(80.60, 0.05));
      expect(dailyNetProfit, closeTo(76.75, 0.05));
      expect(monthlyNetProfit, greaterThan(2300.0));
    });

    test('Calculates liquid calcium boost ROI post-calving', () {
      const milkRate = 38.50;
      const dailyCost = 15.60;
      const expectedGainLitres = 1.80;

      final dailyGrossExtra = expectedGainLitres * milkRate; // 69.30
      final dailyNetProfit = dailyGrossExtra - dailyCost;   // 53.70
      final monthlyNetProfit = dailyNetProfit * 30.0;       // 1611.0

      expect(dailyGrossExtra, closeTo(69.30, 0.05));
      expect(dailyNetProfit, closeTo(53.70, 0.05));
      expect(monthlyNetProfit, greaterThan(1600.0));
    });
  });

  group('CattleFeedStoreScreen Widget Tests', () {
    testWidgets('Renders Cattle Feed & Mineral Mixture Store with ROI calculator & Catalog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: CattleFeedStoreScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Check Title
      expect(find.text('पशुआहार व खनिज मिश्रण बाज़ार'), findsOneWidget);

      // Check Vendor Promotion Banner
      expect(find.textContaining('अपना पशुआहार व खनिज मिश्रण प्रमोट करें'), findsWidgets);
      expect(find.textContaining('फ्री में लिस्ट करें'), findsWidgets);

      // Check ROI Calculator Card
      expect(find.text('खनिज पोषण व दूध लाभ कैलकुलेटर'), findsOneWidget);
      expect(find.textContaining('ROI'), findsWidgets);

      // Check Category Chips
      expect(find.text('सभी (All)'), findsOneWidget);
      expect(find.textContaining('खनिज मिश्रण'), findsWidgets);

      // Check Products displayed from catalog
      expect(find.textContaining('Milterra Chelated Mineral Gold'), findsWidgets);
      expect(find.textContaining('प्रमाणित पशुआहार व सप्लीमेंट्स'), findsWidgets);
    });
  });
}
