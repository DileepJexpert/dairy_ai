import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/milk/models/milk_models.dart';

// ---------------------------------------------------------------------------
// Dio provider (shared with health — in prod this comes from a global scope).
// ---------------------------------------------------------------------------
final _dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider);
});

// ---------------------------------------------------------------------------
// Period filter for milk summary.
// ---------------------------------------------------------------------------
enum MilkPeriod { daily, weekly, monthly }

final milkPeriodProvider = StateProvider<MilkPeriod>((ref) => MilkPeriod.weekly);

// ---------------------------------------------------------------------------
// Demo data fallbacks for offline and unauthenticated states.
// ---------------------------------------------------------------------------
final _demoMilkRecords = [
  MilkRecord(
    id: 1,
    cattleId: 1,
    cattleName: 'Ganga (गाय)',
    cattleTagId: 'MIL-0842',
    date: DateTime.now(),
    session: MilkSession.morning,
    quantityLitres: 12.5,
    fatPct: 4.8,
    snfPct: 8.9,
    buyerType: BuyerType.cooperative,
    buyerName: 'AMUL Dairy Cooperative',
    pricePerLitre: 42.0,
  ),
  MilkRecord(
    id: 2,
    cattleId: 2,
    cattleName: 'Gauri (गाय)',
    cattleTagId: 'MIL-0911',
    date: DateTime.now(),
    session: MilkSession.morning,
    quantityLitres: 10.0,
    fatPct: 4.5,
    snfPct: 8.7,
    buyerType: BuyerType.cooperative,
    buyerName: 'AMUL Dairy Cooperative',
    pricePerLitre: 40.5,
  ),
  MilkRecord(
    id: 3,
    cattleId: 3,
    cattleName: 'Murrah (भैंस)',
    cattleTagId: 'MIL-1024',
    date: DateTime.now(),
    session: MilkSession.morning,
    quantityLitres: 14.0,
    fatPct: 7.2,
    snfPct: 9.3,
    buyerType: BuyerType.private_buyer,
    buyerName: 'Local Sweet Center',
    pricePerLitre: 62.0,
  ),
];

final _demoMilkSummary = MilkSummary(
  totalLitres: 36.5,
  totalRevenue: 1698.0,
  avgFatPct: 5.5,
  avgSnfPct: 8.96,
  totalRecords: 3,
  dailyEntries: [
    DailyMilkEntry(
      date: DateTime.now().subtract(const Duration(days: 2)),
      litres: 34.0,
      revenue: 1580.0,
    ),
    DailyMilkEntry(
      date: DateTime.now().subtract(const Duration(days: 1)),
      litres: 35.5,
      revenue: 1650.0,
    ),
    DailyMilkEntry(
      date: DateTime.now(),
      litres: 36.5,
      revenue: 1698.0,
    ),
  ],
  cattleBreakdown: const [
    CattleMilkBreakdown(
      cattleId: 1,
      cattleName: 'Ganga (गाय)',
      cattleTagId: 'MIL-0842',
      totalLitres: 12.5,
      totalRevenue: 525.0,
      avgDaily: 12.5,
    ),
    CattleMilkBreakdown(
      cattleId: 2,
      cattleName: 'Gauri (गाय)',
      cattleTagId: 'MIL-0911',
      totalLitres: 10.0,
      totalRevenue: 405.0,
      avgDaily: 10.0,
    ),
    CattleMilkBreakdown(
      cattleId: 3,
      cattleName: 'Murrah (भैंस)',
      cattleTagId: 'MIL-1024',
      totalLitres: 14.0,
      totalRevenue: 868.0,
      avgDaily: 14.0,
    ),
  ],
);

final _demoMilkPrices = [
  MilkPrice(
    id: 1,
    district: 'Anand (Gujarat)',
    buyerName: 'AMUL Fed Dairy',
    pricePerLitre: 44.5,
    fatPct: 4.5,
    date: DateTime.now(),
  ),
  MilkPrice(
    id: 2,
    district: 'Mehsana (Gujarat)',
    buyerName: 'Dudhsagar Cooperative',
    pricePerLitre: 43.8,
    fatPct: 4.5,
    date: DateTime.now(),
  ),
  MilkPrice(
    id: 3,
    district: 'Kolhapur (Maharashtra)',
    buyerName: 'Gokul Dairy Cooperative',
    pricePerLitre: 45.0,
    fatPct: 4.5,
    date: DateTime.now(),
  ),
  MilkPrice(
    id: 4,
    district: 'Jaipur (Rajasthan)',
    buyerName: 'Saras Dairy Federation',
    pricePerLitre: 43.0,
    fatPct: 4.5,
    date: DateTime.now(),
  ),
];

// ---------------------------------------------------------------------------
// Milk records — optionally filtered by cattle and/or date range.
// ---------------------------------------------------------------------------
final milkRecordsProvider = FutureProvider.autoDispose
    .family<List<MilkRecord>, int?>((ref, cattleId) async {
  try {
    final dio = ref.watch(_dioProvider);
    final queryParams = <String, dynamic>{};
    if (cattleId != null) queryParams['cattle_id'] = cattleId;
    final response =
        await dio.get('/milk-records', queryParameters: queryParams);
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => MilkRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    }
  } catch (_) {}
  if (cattleId != null) {
    return _demoMilkRecords.where((r) => r.cattleId == cattleId).toList();
  }
  return _demoMilkRecords;
});

// ---------------------------------------------------------------------------
// Milk summary — analytics (daily/weekly/monthly totals).
// ---------------------------------------------------------------------------
final milkSummaryProvider =
    FutureProvider.autoDispose<MilkSummary>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final period = ref.watch(milkPeriodProvider);
    final response = await dio.get('/milk-records/summary',
        queryParameters: {'period': period.name});
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true && body['data'] != null) {
      return MilkSummary.fromJson(body['data'] as Map<String, dynamic>);
    }
  } catch (_) {}
  return _demoMilkSummary;
});

// ---------------------------------------------------------------------------
// Milk prices by district.
// ---------------------------------------------------------------------------
final milkDistrictProvider = StateProvider<String?>((ref) => null);

final milkPricesProvider =
    FutureProvider.autoDispose<List<MilkPrice>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final district = ref.watch(milkDistrictProvider);
    final queryParams = <String, dynamic>{};
    if (district != null && district.isNotEmpty) {
      queryParams['district'] = district;
    }
    final response =
        await dio.get('/milk-prices', queryParameters: queryParams);
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => MilkPrice.fromJson(e as Map<String, dynamic>))
          .toList();
      if (items.isNotEmpty) return items;
    }
  } catch (_) {}
  return _demoMilkPrices;
});

// ---------------------------------------------------------------------------
// Action: record milk (single entry).
// ---------------------------------------------------------------------------
Future<MilkRecord> recordMilk(
  WidgetRef ref, {
  required int cattleId,
  required DateTime date,
  required MilkSession session,
  required double quantityLitres,
  double? fatPct,
  double? snfPct,
  required BuyerType buyerType,
  String? buyerName,
  double? pricePerLitre,
}) async {
  final dio = ref.read(_dioProvider);
  final record = MilkRecord(
    cattleId: cattleId,
    date: date,
    session: session,
    quantityLitres: quantityLitres,
    fatPct: fatPct,
    snfPct: snfPct,
    buyerType: buyerType,
    buyerName: buyerName,
    pricePerLitre: pricePerLitre,
  );

  final response = await dio.post('/milk-records', data: record.toJson());
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to record milk');
  }

  final saved = MilkRecord.fromJson(body['data'] as Map<String, dynamic>);

  // Invalidate caches.
  ref.invalidate(milkRecordsProvider);
  ref.invalidate(milkSummaryProvider);

  return saved;
}

// ---------------------------------------------------------------------------
// Action: batch record milk for multiple cattle.
// ---------------------------------------------------------------------------
Future<List<MilkRecord>> recordMilkBatch(
  WidgetRef ref, {
  required List<MilkRecord> records,
}) async {
  final dio = ref.read(_dioProvider);
  final payload = records.map((r) => r.toJson()).toList();
  final response = await dio.post('/milk-records/batch', data: {'records': payload});
  final body = response.data as Map<String, dynamic>;
  if (body['success'] != true) {
    throw Exception(body['message'] ?? 'Failed to batch record milk');
  }
  final saved = (body['data'] as List<dynamic>)
      .map((e) => MilkRecord.fromJson(e as Map<String, dynamic>))
      .toList();

  ref.invalidate(milkRecordsProvider);
  ref.invalidate(milkSummaryProvider);

  return saved;
}
