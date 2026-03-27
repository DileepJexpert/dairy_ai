import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../models/dashboard_model.dart';

/// Provides the current farmer's dashboard stats.
/// Fetches from GET /api/v1/farmers/me/dashboard.
final dashboardStatsProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardStats>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    return _fetchDashboard();
  }

  Future<DashboardStats> _fetchDashboard() async {
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/farmers/me/dashboard');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        return DashboardStats.fromJson(body['data'] as Map<String, dynamic>);
      }
      throw Exception(body['message'] ?? 'Failed to load dashboard');
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?['message'] ?? 'Network error loading dashboard',
      );
    }
  }

  /// Pull-to-refresh support.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchDashboard);
  }
}
