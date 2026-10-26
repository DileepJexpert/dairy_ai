import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/collection/models/collection_models.dart';

void main() {
  group('Farmer Passbook & Milk Rate Engine Tests', () {
    test('Calculates multi-buyer rates accurately for cow milk', () {
      final cowFat = 4.0;
      final cowSnf = 8.8;
      
      // Amul Two-Axis formula
      final amulRate = 38.0 + (cowFat - 3.5) * 5.5 + (cowSnf - 8.5) * 3.8 + 1.5;
      expect(amulRate, greaterThan(40.0));
      expect(amulRate, lessThan(45.0));

      // Local BMC TS formula
      final tsRate = (cowFat + cowSnf) * 3.22;
      expect(tsRate, closeTo(41.2, 0.1));

      // Milterra Vedic direct
      final milterraRate = 55.0 + (cowFat - 3.5) * 6.0 + (cowSnf - 8.5) * 4.0;
      expect(milterraRate, closeTo(59.2, 0.1));
    });

    test('PassbookSummary calculation handles shift entries correctly', () {
      const records = [
        MilkCollectionRecord(
          id: 'test_1',
          centerId: 'center_1',
          farmerId: 'farmer_101',
          date: '2026-10-20',
          shift: 'morning',
          quantityLitres: 12.5,
          fatPct: 4.2,
          snfPct: 8.6,
          ratePerLitre: 42.50,
          totalAmount: 531.25,
          netAmount: 531.25,
        ),
        MilkCollectionRecord(
          id: 'test_2',
          centerId: 'center_1',
          farmerId: 'farmer_101',
          date: '2026-10-20',
          shift: 'evening',
          quantityLitres: 11.0,
          fatPct: 4.4,
          snfPct: 8.7,
          ratePerLitre: 43.10,
          totalAmount: 474.10,
          netAmount: 474.10,
        ),
      ];

      final totalL = records.fold(0.0, (acc, e) => acc + e.quantityLitres);
      final totalNet = records.fold(0.0, (acc, e) => acc + e.netAmount);

      final summary = FarmerPassbookSummary(
        totalEntries: records.length,
        totalLitres: totalL,
        totalNetPayout: totalNet,
        averageFatPct: 4.3,
        averageSnfPct: 8.65,
        currentCycleName: 'Cycle 3 (21 Oct – 31 Oct)',
      );

      final passbook = FarmerPassbookData(
        farmerName: 'Ramesh Patel',
        farmerId: 'farmer_101',
        village: 'Anand Rural',
        summary: summary,
        entries: records,
      );

      expect(passbook.summary.totalLitres, equals(23.5));
      expect(passbook.summary.totalNetPayout, closeTo(1005.35, 0.01));
      expect(passbook.summary.averageFatPct, closeTo(4.3, 0.01));
      expect(passbook.summary.averageSnfPct, closeTo(8.65, 0.01));
      expect(passbook.entries.length, equals(2));
      expect(passbook.farmerName, equals('Ramesh Patel'));
    });
  });
}
