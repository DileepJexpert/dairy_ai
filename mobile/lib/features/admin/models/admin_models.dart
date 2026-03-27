import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Admin Dashboard aggregate stats.
// ---------------------------------------------------------------------------
@immutable
class AdminDashboard {
  final int totalFarmers;
  final int totalCattle;
  final int totalVets;
  final int activeConsultations;
  final double milkTodayLitres;
  final int newFarmersThisMonth;
  final int pendingVerifications;
  final List<RecentActivity> recentActivity;

  const AdminDashboard({
    required this.totalFarmers,
    required this.totalCattle,
    required this.totalVets,
    required this.activeConsultations,
    required this.milkTodayLitres,
    required this.newFarmersThisMonth,
    required this.pendingVerifications,
    required this.recentActivity,
  });

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    return AdminDashboard(
      totalFarmers: json['total_farmers'] as int? ?? 0,
      totalCattle: json['total_cattle'] as int? ?? 0,
      totalVets: json['total_vets'] as int? ?? 0,
      activeConsultations: json['active_consultations'] as int? ?? 0,
      milkTodayLitres:
          (json['milk_today_litres'] as num?)?.toDouble() ?? 0.0,
      newFarmersThisMonth: json['new_farmers_this_month'] as int? ?? 0,
      pendingVerifications: json['pending_verifications'] as int? ?? 0,
      recentActivity: (json['recent_activity'] as List<dynamic>?)
              ?.map((e) =>
                  RecentActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent activity feed item.
// ---------------------------------------------------------------------------
@immutable
class RecentActivity {
  final String type; // 'registration', 'consultation', 'verification', etc.
  final String title;
  final String description;
  final DateTime timestamp;

  const RecentActivity({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      type: json['type'] as String? ?? 'unknown',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin farmer list item.
// ---------------------------------------------------------------------------
@immutable
class AdminFarmer {
  final int id;
  final String name;
  final String phone;
  final String? village;
  final String? district;
  final String? state;
  final int cattleCount;
  final DateTime createdAt;
  final bool isActive;

  const AdminFarmer({
    required this.id,
    required this.name,
    required this.phone,
    this.village,
    this.district,
    this.state,
    required this.cattleCount,
    required this.createdAt,
    required this.isActive,
  });

  factory AdminFarmer.fromJson(Map<String, dynamic> json) {
    return AdminFarmer(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      phone: json['phone'] as String? ?? '',
      village: json['village'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      cattleCount: json['cattle_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// ---------------------------------------------------------------------------
// Paginated response wrapper.
// ---------------------------------------------------------------------------
@immutable
class PaginatedFarmers {
  final List<AdminFarmer> farmers;
  final int total;
  final int page;
  final int pageSize;

  const PaginatedFarmers({
    required this.farmers,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  int get totalPages => (total / pageSize).ceil();
  bool get hasNext => page < totalPages;
  bool get hasPrevious => page > 1;

  factory PaginatedFarmers.fromJson(Map<String, dynamic> json) {
    return PaginatedFarmers(
      farmers: (json['items'] as List<dynamic>?)
              ?.map((e) => AdminFarmer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}

// ---------------------------------------------------------------------------
// Admin vet list item.
// ---------------------------------------------------------------------------
@immutable
class AdminVet {
  final int id;
  final int userId;
  final String name;
  final String phone;
  final String licenseNo;
  final String qualification;
  final List<String> specializations;
  final double fee;
  final double rating;
  final int totalConsultations;
  final bool isVerified;

  const AdminVet({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.licenseNo,
    required this.qualification,
    required this.specializations,
    required this.fee,
    required this.rating,
    required this.totalConsultations,
    required this.isVerified,
  });

  factory AdminVet.fromJson(Map<String, dynamic> json) {
    return AdminVet(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unknown',
      phone: json['phone'] as String? ?? '',
      licenseNo: json['license_no'] as String? ?? '',
      qualification: json['qualification'] as String? ?? '',
      specializations: (json['specializations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalConsultations: json['total_consultations'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

// ---------------------------------------------------------------------------
// Admin consultation list item.
// ---------------------------------------------------------------------------
enum ConsultationStatus { requested, in_progress, completed, cancelled }

@immutable
class AdminConsultation {
  final int id;
  final String farmerName;
  final String? cattleName;
  final String? vetName;
  final String type; // 'chat', 'video', 'in_person'
  final String severity; // 'low', 'medium', 'high'
  final ConsultationStatus status;
  final String? aiDiagnosis;
  final DateTime createdAt;
  final double? fee;

  const AdminConsultation({
    required this.id,
    required this.farmerName,
    this.cattleName,
    this.vetName,
    required this.type,
    required this.severity,
    required this.status,
    this.aiDiagnosis,
    required this.createdAt,
    this.fee,
  });

  factory AdminConsultation.fromJson(Map<String, dynamic> json) {
    return AdminConsultation(
      id: json['id'] as int,
      farmerName: json['farmer_name'] as String? ?? 'Unknown',
      cattleName: json['cattle_name'] as String?,
      vetName: json['vet_name'] as String?,
      type: json['type'] as String? ?? 'chat',
      severity: json['severity'] as String? ?? 'medium',
      status: ConsultationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConsultationStatus.requested,
      ),
      aiDiagnosis: json['ai_diagnosis'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      fee: (json['fee'] as num?)?.toDouble(),
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics data models.
// ---------------------------------------------------------------------------
@immutable
class RegistrationTrend {
  final String month; // 'Jan', 'Feb', etc.
  final int farmerCount;
  final int cattleCount;

  const RegistrationTrend({
    required this.month,
    required this.farmerCount,
    required this.cattleCount,
  });

  factory RegistrationTrend.fromJson(Map<String, dynamic> json) {
    return RegistrationTrend(
      month: json['month'] as String? ?? '',
      farmerCount: json['farmer_count'] as int? ?? 0,
      cattleCount: json['cattle_count'] as int? ?? 0,
    );
  }
}

@immutable
class MilkTrend {
  final String month;
  final double totalLitres;
  final double avgFatPct;

  const MilkTrend({
    required this.month,
    required this.totalLitres,
    required this.avgFatPct,
  });

  factory MilkTrend.fromJson(Map<String, dynamic> json) {
    return MilkTrend(
      month: json['month'] as String? ?? '',
      totalLitres: (json['total_litres'] as num?)?.toDouble() ?? 0.0,
      avgFatPct: (json['avg_fat_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

@immutable
class ConsultationStats {
  final int totalConsultations;
  final int completedConsultations;
  final double avgRating;
  final double totalRevenue;
  final Map<String, int> byType; // 'chat': 5, 'video': 3, ...
  final Map<String, int> bySeverity; // 'low': 10, 'medium': 5, 'high': 2

  const ConsultationStats({
    required this.totalConsultations,
    required this.completedConsultations,
    required this.avgRating,
    required this.totalRevenue,
    required this.byType,
    required this.bySeverity,
  });

  factory ConsultationStats.fromJson(Map<String, dynamic> json) {
    return ConsultationStats(
      totalConsultations: json['total_consultations'] as int? ?? 0,
      completedConsultations:
          json['completed_consultations'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      byType: (json['by_type'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      bySeverity: (json['by_severity'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
    );
  }
}

@immutable
class AnalyticsData {
  final List<RegistrationTrend> registrationTrends;
  final List<MilkTrend> milkTrends;
  final ConsultationStats consultationStats;
  final double totalRevenue;

  const AnalyticsData({
    required this.registrationTrends,
    required this.milkTrends,
    required this.consultationStats,
    required this.totalRevenue,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    return AnalyticsData(
      registrationTrends: (json['registration_trends'] as List<dynamic>?)
              ?.map((e) =>
                  RegistrationTrend.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      milkTrends: (json['milk_trends'] as List<dynamic>?)
              ?.map((e) => MilkTrend.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      consultationStats: ConsultationStats.fromJson(
        json['consultation_stats'] as Map<String, dynamic>? ?? {},
      ),
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
