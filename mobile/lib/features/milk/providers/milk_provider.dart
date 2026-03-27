import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/milk/models/milk_models.dart';

// ---------------------------------------------------------------------------
// Dio provider (shared with health — in prod this comes from a global scope).
// ---------------------------------------------------------------------------
final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
    headers: {'Content-Type': 'application/json'},
  ));
  return dio;
});

// ---------------------------------------------------------------------------
// Period filter for milk summary.
// ---------------------------------------------------------------------------
enum MilkPeriod { daily, weekly, monthly }

final milkPeriodProvider = StateProvider<MilkPeriod>((ref) => MilkPeriod.weekly);

// ---------------------------------------------------------------------------
// Milk records — optionally filtered by cattle and/or date range.
// ---------------------------------------------------------------------------
final milkRecordsProvider = FutureProvider.autoDispose
    .family<List<MilkRecord>, int?>((ref, cattleId) async {
  final dio = ref.watch(_dioProvider);
  final queryParams = <String, dynamic>{};
  if (cattleId != null) queryParams['cattle_id'] = cattleId;
  final response =
      await dio.get('/milk-records', queryParameters: queryParams);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => MilkRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load milk records');
});

// ---------------------------------------------------------------------------
// Milk summary — analytics (daily/weekly/monthly totals).
// ---------------------------------------------------------------------------
final milkSummaryProvider =
    FutureProvider.autoDispose<MilkSummary>((ref) async {
  final dio = ref.watch(_dioProvider);
  final period = ref.watch(milkPeriodProvider);
  final response = await dio.get('/milk-records/summary',
      queryParameters: {'period': period.name});
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return MilkSummary.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load milk summary');
});

// ---------------------------------------------------------------------------
// Milk prices by district.
// ---------------------------------------------------------------------------
final milkDistrictProvider = StateProvider<String?>((ref) => null);

final milkPricesProvider =
    FutureProvider.autoDispose<List<MilkPrice>>((ref) async {
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
    return (body['data'] as List<dynamic>)
        .map((e) => MilkPrice.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load milk prices');
});

// ---------------------------------------------------------------------------
// Action: record milk (single entry).
// ---------------------------------------------------------------------------
Future<MilkRecord> recordMilk(
  Ref ref, {
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
  Ref ref, {
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
