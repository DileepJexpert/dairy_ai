import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_model.freezed.dart';
part 'dashboard_model.g.dart';

@freezed
class DashboardStats with _$DashboardStats {
  const factory DashboardStats({
    @JsonKey(name: 'farmer_name') required String farmerName,
    @JsonKey(name: 'total_cattle') required int totalCattle,
    @JsonKey(name: 'active_cattle') required int activeCattle,
    @JsonKey(name: 'today_milk_litres') required double todayMilkLitres,
    @JsonKey(name: 'pending_health_alerts') required int pendingHealthAlerts,
    @JsonKey(name: 'upcoming_vaccinations') required int upcomingVaccinations,
    @JsonKey(name: 'recent_activities')
    @Default([])
    List<RecentActivity> recentActivities,
  }) = _DashboardStats;

  factory DashboardStats.fromJson(Map<String, dynamic> json) =>
      _$DashboardStatsFromJson(json);
}

@freezed
class RecentActivity with _$RecentActivity {
  const factory RecentActivity({
    required String id,
    required String type,
    required String title,
    required String description,
    @JsonKey(name: 'created_at') required String createdAt,
    @JsonKey(name: 'cattle_name') String? cattleName,
    @JsonKey(name: 'cattle_tag') String? cattleTag,
  }) = _RecentActivity;

  factory RecentActivity.fromJson(Map<String, dynamic> json) =>
      _$RecentActivityFromJson(json);
}
