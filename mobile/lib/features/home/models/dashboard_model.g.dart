// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DashboardStatsImpl _$$DashboardStatsImplFromJson(
        Map<String, dynamic> json) =>
    _$DashboardStatsImpl(
      farmerName: json['farmer_name'] as String,
      totalCattle: (json['total_cattle'] as num).toInt(),
      activeCattle: (json['active_cattle'] as num).toInt(),
      todayMilkLitres: (json['today_milk_litres'] as num).toDouble(),
      pendingHealthAlerts: (json['pending_health_alerts'] as num).toInt(),
      upcomingVaccinations: (json['upcoming_vaccinations'] as num).toInt(),
      recentActivities: (json['recent_activities'] as List<dynamic>?)
              ?.map(
                  (e) => RecentActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$DashboardStatsImplToJson(
        _$DashboardStatsImpl instance) =>
    <String, dynamic>{
      'farmer_name': instance.farmerName,
      'total_cattle': instance.totalCattle,
      'active_cattle': instance.activeCattle,
      'today_milk_litres': instance.todayMilkLitres,
      'pending_health_alerts': instance.pendingHealthAlerts,
      'upcoming_vaccinations': instance.upcomingVaccinations,
      'recent_activities': instance.recentActivities,
    };

_$RecentActivityImpl _$$RecentActivityImplFromJson(
        Map<String, dynamic> json) =>
    _$RecentActivityImpl(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: json['created_at'] as String,
      cattleName: json['cattle_name'] as String?,
      cattleTag: json['cattle_tag'] as String?,
    );

Map<String, dynamic> _$$RecentActivityImplToJson(
        _$RecentActivityImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'title': instance.title,
      'description': instance.description,
      'created_at': instance.createdAt,
      'cattle_name': instance.cattleName,
      'cattle_tag': instance.cattleTag,
    };
