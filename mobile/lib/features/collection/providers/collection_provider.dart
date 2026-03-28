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
