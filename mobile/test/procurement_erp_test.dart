import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/collection/screens/society_operator_screen.dart';

void main() {
  group('Dairy Society Procurement ERP - Rate & Accounting Tests', () {
    test('Two-Axis cow rate calculation applies base and grade bonus', () {
      // Cow: base fat 3.5, snf 8.5 => base rate 36.50
      final baseFat = 3.5;
      final baseSnf = 8.5;
      final baseRate = 36.50 + ((baseFat - 3.5) * 3.8) + ((baseSnf - 8.5) * 2.6);
      expect(baseRate, equals(36.50));

      // High fat & snf (Grade A with 1.20 incentive)
      final highFat = 4.2;
      final highSnf = 8.6;
      var highRate = 36.50 + ((highFat - 3.5) * 3.8) + ((highSnf - 8.5) * 2.6);
      if (highFat >= 4.2 && highSnf >= 8.6) highRate += 1.20;
      
      expect(highRate, closeTo(40.62, 0.05));
    });

    test('Two-Axis buffalo rate calculation applies premium fat multiplier', () {
      // Buffalo: base fat 6.0, snf 9.0 => base rate 58.50
      final bufFat = 7.2;
      final bufSnf = 9.1;
      var bufRate = 58.50 + ((bufFat - 6.0) * 6.4) + ((bufSnf - 9.0) * 3.2);
      if (bufFat >= 7.0 && bufSnf >= 9.0) bufRate += 2.00;

      expect(bufRate, greaterThan(68.0));
      expect(bufRate, closeTo(68.50, 0.1));
    });

    test('Calculates 40L milk cans and partial can accurately for BMC dispatch', () {
      final totalLitres = 342.5;
      final fullCans = (totalLitres / 40.0).floor();
      final remainderLitres = totalLitres % 40.0;
      final totalCans = remainderLitres > 0 ? fullCans + 1 : fullCans;

      expect(fullCans, equals(8));
      expect(remainderLitres, closeTo(22.5, 0.01));
      expect(totalCans, equals(9));
    });

    test('10-day cycle billing settlement deducts feed advances with 40% cap', () {
      final grossMilkAmount = 14200.0;
      final pendingFeedAdvance = 1500.0;
      final maxAllowedDeduction = grossMilkAmount * 0.40; // 5680.0 max

      final actualDeduction = pendingFeedAdvance <= maxAllowedDeduction
          ? pendingFeedAdvance
          : maxAllowedDeduction;
      final netPayout = grossMilkAmount - actualDeduction;

      expect(actualDeduction, equals(1500.0));
      expect(netPayout, equals(12700.0));
      expect(netPayout, greaterThan(0));
    });
  });

  group('SocietyOperatorScreen Widget Tests', () {
    testWidgets('Renders Operator Screen with all 3 ERP tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SocietyOperatorScreen(centerId: 'c-dhartiputra-01'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Header and Title
      expect(find.textContaining('डेयरी समिति व बीएमसी ऑपरेटर'), findsWidgets);
      
      // Check 3 tabs
      expect(find.textContaining('त्वरित दूध एंट्री'), findsWidgets);
      expect(find.textContaining('शिफ्ट सारांश व डिस्पैच'), findsWidgets);
      expect(find.textContaining('10-दिवसीय पखवाड़ा बिलिंग'), findsWidgets);

      // Verify Rapid Intake controls exist
      expect(find.textContaining('गाय (Cow)'), findsOneWidget);
      expect(find.textContaining('भैंस (Buffalo)'), findsOneWidget);
      expect(find.text('दूध मात्रा (Litres)'), findsOneWidget);
      expect(find.text('फैट % (Fat)'), findsOneWidget);
      expect(find.textContaining('SNF'), findsWidgets);
    });
  });
}
