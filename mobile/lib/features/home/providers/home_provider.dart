import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/dashboard_model.dart';

/// Provides the current farmer's dashboard stats.
/// Fetches from GET /farmers/me/dashboard or provides a rich preview if unauthenticated.
final dashboardStatsProvider =
    AsyncNotifierProvider<DashboardNotifier, DashboardStats>(
  DashboardNotifier.new,
);

class DashboardNotifier extends AsyncNotifier<DashboardStats> {
  @override
  Future<DashboardStats> build() async {
    // Watch authProvider so changes in login status immediately update the dashboard.
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    if (!isAuthenticated) {
      return _emptyStats();
    }

    return _fetchDashboard();
  }

  Future<DashboardStats> _fetchDashboard() async {
    final dio = ref.read(dioProvider);
    final authState = ref.read(authProvider);
    final user = authState.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );

    if (user == null) {
      return _emptyStats();
    }

    try {
      final response = await dio.get('/farmers/me/dashboard');
      final body = response.data as Map<String, dynamic>;
      if (body['success'] == true) {
        // The API groups dashboard fields into profile and stats.
        final data = body['data'] as Map<String, dynamic>;
        final profile = data['profile'] as Map<String, dynamic>? ?? const {};
        final stats = data['stats'] as Map<String, dynamic>? ?? const {};
        return DashboardStats.fromJson({
          'farmer_name': profile['name'] ?? profile['full_name'] ?? user.name ?? 'Farmer',
          'total_cattle': stats['total_cattle'] ?? 0,
          'active_cattle': stats['active_cattle'] ?? stats['total_cattle'] ?? 0,
          'today_milk_litres': stats['milk_today_litres'] ?? 0,
          'pending_health_alerts': stats['pending_health_alerts'] ?? 0,
          'upcoming_vaccinations': stats['upcoming_vaccinations'] ?? 0,
          'recent_activities': stats['recent_activities'] ?? const [],
        });
      }
      return _fallbackStats(user.name ?? 'Farmer');
    } catch (_) {
      return _fallbackStats(user.name ?? 'Farmer');
    }
  }

  DashboardStats _emptyStats() {
    return const DashboardStats(
      farmerName: 'Guest',
      totalCattle: 0,
      activeCattle: 0,
      todayMilkLitres: 0.0,
      pendingHealthAlerts: 0,
      upcomingVaccinations: 0,
      recentActivities: [],
    );
  }

  DashboardStats _fallbackStats(String name) {
    return DashboardStats(
      farmerName: name,
      totalCattle: 0,
      activeCattle: 0,
      todayMilkLitres: 0.0,
      pendingHealthAlerts: 0,
      upcomingVaccinations: 0,
      recentActivities: const [],
    );
  }

  /// Pull-to-refresh support.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchDashboard);
  }
}
