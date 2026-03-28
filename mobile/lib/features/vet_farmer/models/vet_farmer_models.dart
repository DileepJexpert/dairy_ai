import 'package:flutter/foundation.dart';

/// Consultation type options.
enum ConsultationType { chat, video, in_person }

/// Consultation status lifecycle.
enum ConsultationStatus {
  requested,
  accepted,
  in_progress,
  completed,
  cancelled,
}

/// Vet specialization categories.
class VetSpecialization {
  static const List<String> all = [
    'General',
    'Surgery',
    'Reproduction',
    'Nutrition',
    'Dermatology',
    'Orthopedic',
    'Internal Medicine',
    'Mastitis',
  ];
}

/// Languages supported by vets.
class VetLanguage {
  static const List<String> all = [
    'Hindi',
    'English',
    'Marathi',
    'Gujarati',
    'Punjabi',
    'Tamil',
    'Telugu',
    'Kannada',
    'Bengali',
    'Malayalam',
  ];
}

/// A verified vet profile as returned by GET /vet-profiles.
@immutable
class VetProfile {
  final int id;
  final int userId;
  final String name;
  final String? photoUrl;
  final String licenseNo;
  final String qualification;
  final List<String> specializations;
  final List<String> languages;
  final double fee;
  final double rating;
  final int totalConsultations;
  final bool isAvailable;

  // Location fields
  final double? distanceKm;
  final String? city;
  final String? district;
  final String? pincode;
  final double? lat;
  final double? lng;
  final double? serviceRadiusKm;

  const VetProfile({
    required this.id,
    required this.userId,
    required this.name,
    this.photoUrl,
    required this.licenseNo,
    required this.qualification,
    required this.specializations,
    required this.languages,
    required this.fee,
    required this.rating,
    this.totalConsultations = 0,
    this.isAvailable = true,
    this.distanceKm,
    this.city,
    this.district,
    this.pincode,
    this.lat,
    this.lng,
    this.serviceRadiusKm,
  });

  /// Human-readable location string (e.g. "Jaipur, Rajasthan").
  String? get locationLabel {
    final parts = <String>[
      if (city != null && city!.isNotEmpty) city!,
      if (district != null && district!.isNotEmpty) district!,
    ];
    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  factory VetProfile.fromJson(Map<String, dynamic> json) {
    return VetProfile(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String? ?? 'Unknown',
      photoUrl: json['photo_url'] as String?,
      licenseNo: json['license_no'] as String? ?? '',
      qualification: json['qualification'] as String? ?? '',
      specializations: (json['specializations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      languages: (json['languages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      fee: (json['fee'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalConsultations: json['total_consultations'] as int? ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      city: json['city'] as String?,
      district: json['district'] as String?,
      pincode: json['pincode'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      serviceRadiusKm: (json['service_radius_km'] as num?)?.toDouble(),
    );
  }
}

/// Request payload for creating a consultation.
@immutable
class ConsultationRequest {
  final int cattleId;
  final int vetId;
  final ConsultationType type;
  final List<String> symptoms;
  final String description;
  final String? photoUrl;

  const ConsultationRequest({
    required this.cattleId,
    required this.vetId,
    required this.type,
    required this.symptoms,
    required this.description,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
        'cattle_id': cattleId,
        'vet_id': vetId,
        'type': type.name,
        'symptoms': symptoms,
        'description': description,
        if (photoUrl != null) 'photo_url': photoUrl,
      };
}

/// A consultation record.
@immutable
class Consultation {
  final int id;
  final int farmerId;
  final int cattleId;
  final String? cattleName;
  final String? cattleTagId;
  final int vetId;
  final String? vetName;
  final ConsultationType type;
  final ConsultationStatus status;
  final String? triageSeverity;
  final String? aiDiagnosis;
  final String? vetDiagnosis;
  final double? fee;
  final double? rating;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final Prescription? prescription;

  const Consultation({
    required this.id,
    required this.farmerId,
    required this.cattleId,
    this.cattleName,
    this.cattleTagId,
    required this.vetId,
    this.vetName,
    required this.type,
    required this.status,
    this.triageSeverity,
    this.aiDiagnosis,
    this.vetDiagnosis,
    this.fee,
    this.rating,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    this.prescription,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'] as int,
      farmerId: json['farmer_id'] as int,
      cattleId: json['cattle_id'] as int,
      cattleName: json['cattle_name'] as String?,
      cattleTagId: json['cattle_tag_id'] as String?,
      vetId: json['vet_id'] as int,
      vetName: json['vet_name'] as String?,
      type: ConsultationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ConsultationType.chat,
      ),
      status: ConsultationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConsultationStatus.requested,
      ),
      triageSeverity: json['triage_severity'] as String?,
      aiDiagnosis: json['ai_diagnosis'] as String?,
      vetDiagnosis: json['vet_diagnosis'] as String?,
      fee: (json['fee'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      prescription: json['prescription'] != null
          ? Prescription.fromJson(json['prescription'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Chat message within a consultation.
@immutable
class ChatMessage {
  final int id;
  final int consultationId;
  final String senderRole; // 'farmer' or 'vet'
  final String message;
  final String? imageUrl;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.consultationId,
    required this.senderRole,
    required this.message,
    this.imageUrl,
    required this.sentAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      consultationId: json['consultation_id'] as int,
      senderRole: json['sender_role'] as String? ?? 'farmer',
      message: json['message'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      sentAt: DateTime.parse(json['sent_at'] as String),
    );
  }
}

/// A prescription attached to a consultation.
@immutable
class Prescription {
  final int id;
  final int consultationId;
  final List<Medicine> medicines;
  final String instructions;
  final DateTime? followUpDate;

  const Prescription({
    required this.id,
    required this.consultationId,
    required this.medicines,
    required this.instructions,
    this.followUpDate,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final medicinesRaw = json['medicines_json'] ?? json['medicines'];
    List<Medicine> medicines = [];
    if (medicinesRaw is List) {
      medicines = medicinesRaw
          .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return Prescription(
      id: json['id'] as int,
      consultationId: json['consultation_id'] as int,
      medicines: medicines,
      instructions: json['instructions'] as String? ?? '',
      followUpDate: json['follow_up_date'] != null
          ? DateTime.parse(json['follow_up_date'] as String)
          : null,
    );
  }
}

/// A single medicine entry in a prescription.
@immutable
class Medicine {
  final String name;
  final String dosage;
  final String frequency;
  final String duration;

  const Medicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.duration,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'duration': duration,
      };
}
