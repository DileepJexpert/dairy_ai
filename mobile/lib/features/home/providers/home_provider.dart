import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/dashboard_model.dart';

/// Provides the current farmer's dashboard stats.
/// Fetches from GET /farmers/me/dashboard.
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
        // The API groups dashboard fields into profile and stats. Keep that
        // transport contract while exposing the flat model used by the UI.
        final data = body['data'] as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>? ?? const {};
        final stats = data['stats'] as Map<String, dynamic>? ?? const {};
        return DashboardStats.fromJson({
          'farmer_name': profile['name'] ?? 'Farmer',
          'total_cattle': stats['total_cattle'] ?? 0,
          'active_cattle': stats['active_cattle'] ?? stats['total_cattle'] ?? 0,
          'today_milk_litres': stats['milk_today_litres'] ?? 0,
          'pending_health_alerts': stats['pending_health_alerts'] ?? 0,
          'upcoming_vaccinations': stats['upcoming_vaccinations'] ?? 0,
          'recent_activities': stats['recent_activities'] ?? const [],
        });
      }
      throw Exception(body['message'] ?? 'Failed to load dashboard');
    } on DioException catch (e) {
      throw Exception(dioErrorMessage(e));
    }
  }

  /// Pull-to-refresh support.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchDashboard);
  }
}
