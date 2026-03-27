import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:dairy_ai/features/admin/models/admin_models.dart';

// ---------------------------------------------------------------------------
// Shared Dio provider for admin feature.
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
// Admin dashboard — aggregate stats.
// ---------------------------------------------------------------------------
final adminDashboardProvider =
    FutureProvider.autoDispose<AdminDashboard>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/admin/dashboard');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return AdminDashboard.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load admin dashboard');
});

// ---------------------------------------------------------------------------
// Admin farmers — searchable, paginated list.
// ---------------------------------------------------------------------------
class AdminFarmersFilter {
  final String search;
  final int page;
  final int pageSize;

  const AdminFarmersFilter({
    this.search = '',
    this.page = 1,
    this.pageSize = 20,
  });

  AdminFarmersFilter copyWith({String? search, int? page, int? pageSize}) {
    return AdminFarmersFilter(
      search: search ?? this.search,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

class AdminFarmersNotifier extends StateNotifier<AdminFarmersFilter> {
  AdminFarmersNotifier() : super(const AdminFarmersFilter());

  void setSearch(String query) {
    state = state.copyWith(search: query, page: 1);
  }

  void nextPage() {
    state = state.copyWith(page: state.page + 1);
  }

  void previousPage() {
    if (state.page > 1) {
      state = state.copyWith(page: state.page - 1);
    }
  }

  void goToPage(int page) {
    state = state.copyWith(page: page);
  }
}

final adminFarmersFilterProvider =
    StateNotifierProvider.autoDispose<AdminFarmersNotifier, AdminFarmersFilter>(
  (ref) => AdminFarmersNotifier(),
);

final adminFarmersProvider =
    FutureProvider.autoDispose<PaginatedFarmers>((ref) async {
  final filter = ref.watch(adminFarmersFilterProvider);
  final dio = ref.watch(_dioProvider);

  final queryParams = <String, dynamic>{
    'page': filter.page,
    'page_size': filter.pageSize,
  };
  if (filter.search.isNotEmpty) {
    queryParams['search'] = filter.search;
  }

  final response =
      await dio.get('/admin/farmers', queryParameters: queryParams);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return PaginatedFarmers.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load farmers');
});

// ---------------------------------------------------------------------------
// Admin vets — with verification filter.
// ---------------------------------------------------------------------------
enum VetFilter { all, verified, unverified }

final vetFilterProvider =
    StateProvider.autoDispose<VetFilter>((ref) => VetFilter.all);

final adminVetsProvider =
    FutureProvider.autoDispose<List<AdminVet>>((ref) async {
  final filter = ref.watch(vetFilterProvider);
  final dio = ref.watch(_dioProvider);

  final queryParams = <String, dynamic>{};
  if (filter == VetFilter.verified) {
    queryParams['is_verified'] = true;
  } else if (filter == VetFilter.unverified) {
    queryParams['is_verified'] = false;
  }

  final response =
      await dio.get('/admin/vets', queryParameters: queryParams);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => AdminVet.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load vets');
});

// ---------------------------------------------------------------------------
// Verify vet action.
// ---------------------------------------------------------------------------
Future<bool> verifyVet(Ref ref, int vetId) async {
  final dio = ref.read(_dioProvider);
  final response = await dio.post('/vet-profiles/verify', data: {
    'vet_id': vetId,
  });
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    // Invalidate caches so lists refresh.
    ref.invalidate(adminVetsProvider);
    ref.invalidate(adminDashboardProvider);
    return true;
  }
  throw Exception(body['message'] ?? 'Failed to verify vet');
}

// ---------------------------------------------------------------------------
// Admin consultations — with status filter.
// ---------------------------------------------------------------------------
final consultationStatusFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

final adminConsultationsProvider =
    FutureProvider.autoDispose<List<AdminConsultation>>((ref) async {
  final statusFilter = ref.watch(consultationStatusFilterProvider);
  final dio = ref.watch(_dioProvider);

  final queryParams = <String, dynamic>{};
  if (statusFilter != 'all') {
    queryParams['status'] = statusFilter;
  }

  final response =
      await dio.get('/admin/consultations', queryParameters: queryParams);
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return (body['data'] as List<dynamic>)
        .map((e) => AdminConsultation.fromJson(e as Map<String, dynamic>))
        .toList();
  }
  throw Exception(body['message'] ?? 'Failed to load consultations');
});

// ---------------------------------------------------------------------------
// Admin analytics.
// ---------------------------------------------------------------------------
final adminAnalyticsProvider =
    FutureProvider.autoDispose<AnalyticsData>((ref) async {
  final dio = ref.watch(_dioProvider);
  final response = await dio.get('/admin/analytics');
  final body = response.data as Map<String, dynamic>;
  if (body['success'] == true) {
    return AnalyticsData.fromJson(body['data'] as Map<String, dynamic>);
  }
  throw Exception(body['message'] ?? 'Failed to load analytics');
});
