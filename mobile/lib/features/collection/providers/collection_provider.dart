import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/collection_models.dart';

// ---------------------------------------------------------------------------
// Collection centers list
// ---------------------------------------------------------------------------

final collectionCentersProvider =
    FutureProvider.autoDispose<List<CollectionCenter>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/collection/centers');
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = body['data'] as List<dynamic>;
      return items
          .map((e) => CollectionCenter.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['message'] ?? 'Failed to load collection centers');
  } on DioException catch (e) {
    throw Exception(dioErrorMessage(e));
  }
});

// ---------------------------------------------------------------------------
// Center dashboard — parameterised by center ID
// ---------------------------------------------------------------------------

final centerDashboardProvider = FutureProvider.autoDispose
    .family<CenterDashboard, String>((ref, centerId) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/collection/centers/$centerId/dashboard');
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      return CenterDashboard.fromJson(body['data'] as Map<String, dynamic>);
    }
    throw Exception(body['message'] ?? 'Failed to load dashboard');
  } on DioException catch (e) {
    throw Exception(dioErrorMessage(e));
  }
});

// ---------------------------------------------------------------------------
// Milk collections for a center
// ---------------------------------------------------------------------------

final milkCollectionsProvider = FutureProvider.autoDispose
    .family<List<MilkCollectionRecord>, String>((ref, centerId) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/collection/milk', queryParameters: {
      'center_id': centerId,
    });
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = body['data'] as List<dynamic>;
      return items
          .map(
              (e) => MilkCollectionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['message'] ?? 'Failed to load milk collections');
  } on DioException catch (e) {
    throw Exception(dioErrorMessage(e));
  }
});

// ---------------------------------------------------------------------------
// Cold chain alerts for a center
// ---------------------------------------------------------------------------

final coldChainAlertsProvider = FutureProvider.autoDispose
    .family<List<ColdChainAlert>, String>((ref, centerId) async {
  final dio = ref.watch(dioProvider);
  try {
    final response =
        await dio.get('/collection/cold-chain/alerts', queryParameters: {
      'center_id': centerId,
    });
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      final items = body['data'] as List<dynamic>;
      return items
          .map((e) => ColdChainAlert.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception(body['message'] ?? 'Failed to load cold chain alerts');
  } on DioException catch (e) {
    throw Exception(dioErrorMessage(e));
  }
});

// ---------------------------------------------------------------------------
// Collection action state
// ---------------------------------------------------------------------------

class CollectionActionState {
  final bool isLoading;
  final String? error;
  final CollectionCenter? createdCenter;
  final MilkCollectionRecord? recordedMilk;
  final ColdChainReading? recordedReading;

  const CollectionActionState({
    this.isLoading = false,
    this.error,
    this.createdCenter,
    this.recordedMilk,
    this.recordedReading,
  });

  CollectionActionState copyWith({
    bool? isLoading,
    String? error,
    CollectionCenter? createdCenter,
    MilkCollectionRecord? recordedMilk,
    ColdChainReading? recordedReading,
  }) {
    return CollectionActionState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdCenter: createdCenter ?? this.createdCenter,
      recordedMilk: recordedMilk ?? this.recordedMilk,
      recordedReading: recordedReading ?? this.recordedReading,
    );
  }
}

// ---------------------------------------------------------------------------
// Collection action notifier — handles create, record milk, record cold chain
// ---------------------------------------------------------------------------

class CollectionActionNotifier extends StateNotifier<CollectionActionState> {
  final Dio _dio;
  final Ref _ref;

  CollectionActionNotifier(this._dio, this._ref)
      : super(const CollectionActionState());

  /// POST /collection/centers — create a new collection center.
  Future<CollectionCenter> createCenter(Map<String, dynamic> data) async {
    state = const CollectionActionState(isLoading: true);
    try {
      final response = await _dio.post('/collection/centers', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final center =
            CollectionCenter.fromJson(body['data'] as Map<String, dynamic>);
        state = CollectionActionState(createdCenter: center);
        _ref.invalidate(collectionCentersProvider);
        return center;
      }
      final msg = body['message'] as String? ?? 'Failed to create center';
      state = CollectionActionState(error: msg);
      throw Exception(msg);
    } on DioException catch (e) {
      final msg = dioErrorMessage(e);
      state = CollectionActionState(error: msg);
      throw Exception(msg);
    }
  }

  /// POST /collection/milk — record a milk collection.
  Future<MilkCollectionRecord> recordMilk(Map<String, dynamic> data) async {
    state = const CollectionActionState(isLoading: true);
    try {
      final response = await _dio.post('/collection/milk', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final record = MilkCollectionRecord.fromJson(
            body['data'] as Map<String, dynamic>);
        state = CollectionActionState(recordedMilk: record);
        // Invalidate collections list and dashboard for the center.
        final centerId = data['center_id'] as String?;
        if (centerId != null) {
          _ref.invalidate(milkCollectionsProvider(centerId));
          _ref.invalidate(centerDashboardProvider(centerId));
        }
        return record;
      }
      final msg = body['message'] as String? ?? 'Failed to record milk';
      state = CollectionActionState(error: msg);
      throw Exception(msg);
    } on DioException catch (e) {
      final msg = dioErrorMessage(e);
      state = CollectionActionState(error: msg);
      throw Exception(msg);
    }
  }

  /// POST /collection/cold-chain/reading — record a cold chain reading.
  Future<ColdChainReading> recordColdChain(Map<String, dynamic> data) async {
    state = const CollectionActionState(isLoading: true);
    try {
      final response =
          await _dio.post('/collection/cold-chain/reading', data: data);
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final reading =
            ColdChainReading.fromJson(body['data'] as Map<String, dynamic>);
        state = CollectionActionState(recordedReading: reading);
        // Invalidate alerts and dashboard for the center.
        final centerId = data['center_id'] as String?;
        if (centerId != null) {
          _ref.invalidate(coldChainAlertsProvider(centerId));
          _ref.invalidate(centerDashboardProvider(centerId));
        }
        return reading;
      }
      final msg = body['message'] as String? ?? 'Failed to record reading';
      state = CollectionActionState(error: msg);
      throw Exception(msg);
    } on DioException catch (e) {
      final msg = dioErrorMessage(e);
      state = CollectionActionState(error: msg);
      throw Exception(msg);
    }
  }

  void clear() => state = const CollectionActionState();
}

final collectionActionProvider =
    StateNotifierProvider.autoDispose<CollectionActionNotifier, CollectionActionState>(
        (ref) {
  return CollectionActionNotifier(ref.watch(dioProvider), ref);
});


// ---------------------------------------------------------------------------
// Farmer Personal Milk Passbook & Dugdha Parchi Provider
// ---------------------------------------------------------------------------

final farmerPassbookProvider =
    FutureProvider.autoDispose<FarmerPassbookData>((ref) async {
  final dio = ref.watch(dioProvider);
  final user = ref.watch(currentUserProvider);
  final userName = user?.name ?? 'दूध उत्पादक किसान';
  const userVillage = 'आनंद ग्रामीण';

  try {
    if (user != null) {
      final response = await dio.get('/collection/farmers/me/passbook');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final data = body['data'] as Map<String, dynamic>;
        final farmerObj = data['farmer'] as Map<String, dynamic>? ?? {};
        final summaryObj = data['summary'] as Map<String, dynamic>? ?? {};
        final entriesList = (data['entries'] as List<dynamic>? ?? [])
            .map((e) => MilkCollectionRecord.fromJson(e as Map<String, dynamic>))
            .toList();

        return FarmerPassbookData(
          farmerName: farmerObj['name'] as String? ?? userName,
          farmerId: farmerObj['id'] as String?,
          village: farmerObj['village'] as String? ?? '',
          summary: FarmerPassbookSummary.fromJson(summaryObj),
          entries: entriesList,
        );
      }
      return FarmerPassbookData(
        farmerName: userName,
        farmerId: null,
        village: '',
        summary: const FarmerPassbookSummary(
          totalEntries: 0,
          totalLitres: 0.0,
          totalNetPayout: 0.0,
          averageFatPct: 0.0,
          averageSnfPct: 0.0,
        ),
        entries: const [],
      );
    }
  } catch (_) {
    if (user != null) {
      return FarmerPassbookData(
        farmerName: userName,
        farmerId: null,
        village: '',
        summary: const FarmerPassbookSummary(
          totalEntries: 0,
          totalLitres: 0.0,
          totalNetPayout: 0.0,
          averageFatPct: 0.0,
          averageSnfPct: 0.0,
        ),
        entries: const [],
      );
    }
  }

  // High-fidelity fallback / demo passbook data
  final demoEntries = [
    const MilkCollectionRecord(
      id: 'col-live-101',
      centerId: 'bmc-anand-01',
      farmerId: 'farmer-ramesh',
      date: '2026-10-21',
      shift: 'morning',
      quantityLitres: 35.5,
      fatPct: 4.4,
      snfPct: 8.7,
      temperatureCelsius: 4.2,
      milkGrade: 'A',
      ratePerLitre: 45.20,
      totalAmount: 1604.60,
      qualityBonus: 50.0,
      netAmount: 1654.60,
      whatsappSlipText:
          'Namaste Ramesh Patel ji! Morning pour: 35.5 L | Fat: 4.4% | SNF: 8.7 | Rate: ₹45.20/L | Net: ₹1,654.60 credited to Milterra Wallet.',
    ),
    const MilkCollectionRecord(
      id: 'col-live-102',
      centerId: 'bmc-anand-01',
      farmerId: 'farmer-ramesh',
      date: '2026-10-20',
      shift: 'evening',
      quantityLitres: 32.0,
      fatPct: 4.3,
      snfPct: 8.6,
      temperatureCelsius: 4.0,
      milkGrade: 'A',
      ratePerLitre: 44.50,
      totalAmount: 1424.00,
      qualityBonus: 40.0,
      netAmount: 1464.00,
      whatsappSlipText:
          'Namaste Ramesh Patel ji! Evening pour: 32.0 L | Fat: 4.3% | SNF: 8.6 | Rate: ₹44.50/L | Net: ₹1,464.00 credited to Milterra Wallet.',
    ),
    const MilkCollectionRecord(
      id: 'col-live-103',
      centerId: 'bmc-anand-01',
      farmerId: 'farmer-ramesh',
      date: '2026-10-20',
      shift: 'morning',
      quantityLitres: 35.0,
      fatPct: 4.5,
      snfPct: 8.8,
      temperatureCelsius: 3.9,
      milkGrade: 'A',
      ratePerLitre: 46.20,
      totalAmount: 1617.00,
      qualityBonus: 70.0,
      netAmount: 1687.00,
      whatsappSlipText:
          'Namaste Ramesh Patel ji! Morning pour: 35.0 L | Fat: 4.5% | SNF: 8.8 | Rate: ₹46.20/L | Net: ₹1,687.00 credited to Milterra Wallet.',
    ),
    const MilkCollectionRecord(
      id: 'col-live-104',
      centerId: 'bmc-anand-01',
      farmerId: 'farmer-ramesh',
      date: '2026-10-19',
      shift: 'evening',
      quantityLitres: 31.5,
      fatPct: 4.2,
      snfPct: 8.5,
      temperatureCelsius: 4.1,
      milkGrade: 'B',
      ratePerLitre: 43.80,
      totalAmount: 1379.70,
      qualityBonus: 0.0,
      netAmount: 1379.70,
      whatsappSlipText:
          'Namaste Ramesh Patel ji! Evening pour: 31.5 L | Fat: 4.2% | SNF: 8.5 | Rate: ₹43.80/L | Net: ₹1,379.70 credited to Milterra Wallet.',
    ),
    const MilkCollectionRecord(
      id: 'col-live-105',
      centerId: 'bmc-anand-01',
      farmerId: 'farmer-ramesh',
      date: '2026-10-19',
      shift: 'morning',
      quantityLitres: 34.8,
      fatPct: 4.4,
      snfPct: 8.7,
      temperatureCelsius: 4.0,
      milkGrade: 'A',
      ratePerLitre: 45.00,
      totalAmount: 1566.00,
      qualityBonus: 40.0,
      netAmount: 1606.00,
      whatsappSlipText:
          'Namaste Ramesh Patel ji! Morning pour: 34.8 L | Fat: 4.4% | SNF: 8.7 | Rate: ₹45.00/L | Net: ₹1,606.00 credited to Milterra Wallet.',
    ),
  ];

  double totalL = demoEntries.fold(0.0, (acc, e) => acc + e.quantityLitres);
  double totalAmt = demoEntries.fold(0.0, (acc, e) => acc + e.netAmount);
  double avgFat = demoEntries.fold(0.0, (acc, e) => acc + (e.fatPct ?? 0)) / demoEntries.length;
  double avgSnf = demoEntries.fold(0.0, (acc, e) => acc + (e.snfPct ?? 0)) / demoEntries.length;

  return FarmerPassbookData(
    farmerName: userName,
    village: userVillage,
    summary: FarmerPassbookSummary(
      totalEntries: demoEntries.length,
      totalLitres: double.parse(totalL.toStringAsFixed(1)),
      totalNetPayout: double.parse(totalAmt.toStringAsFixed(2)),
      averageFatPct: double.parse(avgFat.toStringAsFixed(1)),
      averageSnfPct: double.parse(avgSnf.toStringAsFixed(1)),
      currentCycleName: 'Cycle 3 (21 Oct – 31 Oct)',
      cycleDaysRemaining: 10,
      cycleEstimatedPayout: double.parse((totalAmt * 2).toStringAsFixed(2)),
    ),
    entries: demoEntries,
  );
});
