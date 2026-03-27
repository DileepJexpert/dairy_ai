import 'package:flutter/foundation.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';

/// Vet dashboard summary stats.
@immutable
class VetDashboardStats {
  final int pendingRequests;
  final int activeConsultations;
  final int todayCompleted;
  final double todayEarnings;
  final double overallRating;
  final int totalConsultations;
  final bool isAvailable;

  const VetDashboardStats({
    this.pendingRequests = 0,
    this.activeConsultations = 0,
    this.todayCompleted = 0,
    this.todayEarnings = 0.0,
    this.overallRating = 0.0,
    this.totalConsultations = 0,
    this.isAvailable = true,
  });

  factory VetDashboardStats.fromJson(Map<String, dynamic> json) {
    return VetDashboardStats(
      pendingRequests: json['pending_requests'] as int? ?? 0,
      activeConsultations: json['active_consultations'] as int? ?? 0,
      todayCompleted: json['today_completed'] as int? ?? 0,
      todayEarnings: (json['today_earnings'] as num?)?.toDouble() ?? 0.0,
      overallRating: (json['overall_rating'] as num?)?.toDouble() ?? 0.0,
      totalConsultations: json['total_consultations'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}

/// A consultation request in the vet's queue.
@immutable
class ConsultationQueueItem {
  final int id;
  final int farmerId;
  final String farmerName;
  final String? farmerPhone;
  final int cattleId;
  final String? cattleName;
  final String? cattleTagId;
  final String? cattleBreed;
  final ConsultationType type;
  final ConsultationStatus status;
  final List<String> symptoms;
  final String? description;
  final String? photoUrl;
  final String? triageSeverity;
  final String? aiDiagnosis;
  final double? fee;
  final DateTime createdAt;

  const ConsultationQueueItem({
    required this.id,
    required this.farmerId,
    required this.farmerName,
    this.farmerPhone,
    required this.cattleId,
    this.cattleName,
    this.cattleTagId,
    this.cattleBreed,
    required this.type,
    required this.status,
    required this.symptoms,
    this.description,
    this.photoUrl,
    this.triageSeverity,
    this.aiDiagnosis,
    this.fee,
    required this.createdAt,
  });

  factory ConsultationQueueItem.fromJson(Map<String, dynamic> json) {
    return ConsultationQueueItem(
      id: json['id'] as int,
      farmerId: json['farmer_id'] as int,
      farmerName: json['farmer_name'] as String? ?? 'Unknown Farmer',
      farmerPhone: json['farmer_phone'] as String?,
      cattleId: json['cattle_id'] as int,
      cattleName: json['cattle_name'] as String?,
      cattleTagId: json['cattle_tag_id'] as String?,
      cattleBreed: json['cattle_breed'] as String?,
      type: ConsultationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConsultationType.chat,
      ),
      status: ConsultationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConsultationStatus.requested,
      ),
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      description: json['description'] as String?,
      photoUrl: json['photo_url'] as String?,
      triageSeverity: json['triage_severity'] as String?,
      aiDiagnosis: json['ai_diagnosis'] as String?,
      fee: (json['fee'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Prescription submission payload.
@immutable
class PrescriptionPayload {
  final int consultationId;
  final List<Medicine> medicines;
  final String instructions;
  final DateTime? followUpDate;

  const PrescriptionPayload({
    required this.consultationId,
    required this.medicines,
    required this.instructions,
    this.followUpDate,
  });

  Map<String, dynamic> toJson() => {
        'consultation_id': consultationId,
        'medicines_json': medicines.map((m) => m.toJson()).toList(),
        'instructions': instructions,
        if (followUpDate != null)
          'follow_up_date': followUpDate!.toIso8601String(),
      };
}
