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
    if (body['success'] == true && body['data'] != null) {
      final items = (body['data'] as List<dynamic>)
          .map((e) => MilkRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      return items;
    }
  } catch (_) {}
  return const <MilkRecord>[];
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
  return const MilkSummary(
    totalLitres: 0.0,
    totalRevenue: 0.0,
    avgFatPct: 0.0,
    avgSnfPct: 0.0,
    totalRecords: 0,
    dailyEntries: [],
    cattleBreakdown: [],
  );
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
