import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/cattle_model.dart';

final demoCattleList = [
  Cattle(
    id: 'cattle-demo-1',
    farmerId: 'farmer-demo',
    tagId: 'MIL-2024-0842',
    name: 'Gauri (Gir Cow)',
    breed: 'Gir',
    sex: CattleSex.female,
    photoUrl:
        'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=500&auto=format&fit=crop&q=80',
    status: CattleStatus.active,
    createdAt: DateTime.now().subtract(const Duration(days: 120)),
  ),
  Cattle(
    id: 'cattle-demo-2',
    farmerId: 'farmer-demo',
    tagId: 'MIL-2024-0843',
    name: 'Kamdhenu (Sahiwal)',
    breed: 'Sahiwal',
    sex: CattleSex.female,
    photoUrl:
        'https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=500&auto=format&fit=crop&q=80',
    status: CattleStatus.active,
    createdAt: DateTime.now().subtract(const Duration(days: 90)),
  ),
  Cattle(
    id: 'cattle-demo-3',
    farmerId: 'farmer-demo',
    tagId: 'MIL-2024-0844',
    name: 'Nandi (Murrah Buffalo)',
    breed: 'Murrah',
    sex: CattleSex.female,
    photoUrl:
        'https://images.unsplash.com/photo-1527153857715-3908f2bae5e8?w=500&auto=format&fit=crop&q=80',
    status: CattleStatus.dry,
    createdAt: DateTime.now().subtract(const Duration(days: 60)),
  ),
];

// ---------------------------------------------------------------------------
// Cattle list — parameterised by farmer ID
// ---------------------------------------------------------------------------

final cattleListProvider =
    AsyncNotifierProvider.family<CattleListNotifier, List<Cattle>, String>(
  CattleListNotifier.new,
);

class CattleListNotifier extends FamilyAsyncNotifier<List<Cattle>, String> {
  @override
  Future<List<Cattle>> build(String farmerId) async {
    return _fetchCattle(farmerId);
  }

  Future<List<Cattle>> _fetchCattle(String farmerId) async {
    if (farmerId.isEmpty) {
      return demoCattleList;
    }

    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/cattle', queryParameters: {
        'farmer_id': farmerId,
      });
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final items = body['data'] as List<dynamic>;
        if (items.isNotEmpty) {
          return items
              .map((e) => Cattle.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // In demo / unauthenticated mode, gracefully fall back to demo cattle
    }
    return demoCattleList;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchCattle(arg));
  }

  /// Adds a new cattle entry. Returns the newly created [Cattle].
  Future<Cattle> addCattle(CreateCattleRequest request) async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.post('/cattle', data: request.toJson());
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final created = Cattle.fromJson(body['data'] as Map<String, dynamic>);
        // Append to current list optimistically
        state = AsyncData([...state.value ?? [], created]);
        return created;
      }
      throw Exception(body['message'] ?? 'Failed to add cattle');
    } on DioException catch (e) {
      throw Exception(dioErrorMessage(e));
    }
  }

  /// Updates an existing cattle entry.
  Future<Cattle> updateCattle(
      String cattleId, UpdateCattleRequest request) async {
    final dio = ref.read(dioProvider);
    try {
      final response =
          await dio.put('/cattle/$cattleId', data: request.toJson());
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        final updated = Cattle.fromJson(body['data'] as Map<String, dynamic>);
        // Replace in current list
        state = AsyncData([
          for (final c in state.value ?? [])
            if (c.id == cattleId) updated else c,
        ]);
        return updated;
      }
      throw Exception(body['message'] ?? 'Failed to update cattle');
    } on DioException catch (e) {
      throw Exception(dioErrorMessage(e));
    }
  }
}

// ---------------------------------------------------------------------------
// Single cattle detail — by cattle ID
// ---------------------------------------------------------------------------

final cattleDetailProvider =
    FutureProvider.family<Cattle, String>((ref, cattleId) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/cattle/$cattleId');
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      return Cattle.fromJson(body['data'] as Map<String, dynamic>);
    }
  } catch (_) {
    // In demo / unauthenticated mode, return matching demo cow
  }
  return demoCattleList.firstWhere(
    (c) => c.id == cattleId,
    orElse: () => Cattle(
      id: cattleId,
      farmerId: 'farmer-demo',
      tagId: 'MIL-2024-0842',
      name: 'Gauri (Gir Cow)',
      breed: 'Gir',
      sex: CattleSex.female,
      photoUrl:
          'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=500&auto=format&fit=crop&q=80',
      status: CattleStatus.active,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
  );
});

// ---------------------------------------------------------------------------
// Filter state for the herd list screen
// ---------------------------------------------------------------------------

final cattleStatusFilterProvider = StateProvider<CattleStatus?>((ref) => null);

final cattleSearchQueryProvider = StateProvider<String>((ref) => '');

/// Derived provider that applies filters + search to the cattle list.
final filteredCattleListProvider =
    Provider.family<AsyncValue<List<Cattle>>, String>((ref, farmerId) {
  final listAsync = ref.watch(cattleListProvider(farmerId));
  final statusFilter = ref.watch(cattleStatusFilterProvider);
  final query = ref.watch(cattleSearchQueryProvider).toLowerCase();

  return listAsync.whenData((cattle) {
    var filtered = cattle;
    if (statusFilter != null) {
      filtered = filtered.where((c) => c.status == statusFilter).toList();
    }
    if (query.isNotEmpty) {
      filtered = filtered.where((c) {
        return c.name.toLowerCase().contains(query) ||
            c.tagId.toLowerCase().contains(query);
      }).toList();
    }
    return filtered;
  });
});
