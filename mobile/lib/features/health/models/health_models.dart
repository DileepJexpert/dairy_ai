import 'package:flutter/foundation.dart';

/// Types of health records.
enum HealthRecordType { checkup, illness, treatment, surgery }

/// Known symptom options for multi-select.
class HealthSymptom {
  final String id;
  final String label;

  const HealthSymptom({required this.id, required this.label});

  static const List<HealthSymptom> all = [
    HealthSymptom(id: 'fever', label: 'Fever'),
    HealthSymptom(id: 'not_eating', label: 'Not Eating'),
    HealthSymptom(id: 'limping', label: 'Limping'),
    HealthSymptom(id: 'coughing', label: 'Coughing'),
    HealthSymptom(id: 'diarrhea', label: 'Diarrhea'),
    HealthSymptom(id: 'bloating', label: 'Bloating'),
    HealthSymptom(id: 'nasal_discharge', label: 'Nasal Discharge'),
    HealthSymptom(id: 'low_milk', label: 'Low Milk Yield'),
    HealthSymptom(id: 'lethargy', label: 'Lethargy'),
    HealthSymptom(id: 'swelling', label: 'Swelling'),
    HealthSymptom(id: 'skin_lesion', label: 'Skin Lesion'),
    HealthSymptom(id: 'eye_discharge', label: 'Eye Discharge'),
    HealthSymptom(id: 'difficulty_breathing', label: 'Difficulty Breathing'),
    HealthSymptom(id: 'weight_loss', label: 'Weight Loss'),
    HealthSymptom(id: 'abortion', label: 'Abortion/Miscarriage'),
  ];
}

/// Triage severity levels returned by the AI triage endpoint.
enum TriageSeverity { low, medium, high }

/// A single health record for a cattle.
@immutable
class HealthRecord {
  final int id;
  final int cattleId;
  final String? cattleName;
  final String? cattleTagId;
  final DateTime date;
  final HealthRecordType type;
  final List<String> symptoms;
  final String? diagnosis;
  final String? treatment;
  final int? vetId;
  final String? photoUrl;

  const HealthRecord({
    required this.id,
    required this.cattleId,
    this.cattleName,
    this.cattleTagId,
    required this.date,
    required this.type,
    required this.symptoms,
    this.diagnosis,
    this.treatment,
    this.vetId,
    this.photoUrl,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as int,
      cattleId: json['cattle_id'] as int,
      cattleName: json['cattle_name'] as String?,
      cattleTagId: json['cattle_tag_id'] as String?,
      date: DateTime.parse(json['date'] as String),
      type: HealthRecordType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => HealthRecordType.checkup,
      ),
      symptoms: (json['symptoms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      diagnosis: json['diagnosis'] as String?,
      treatment: json['treatment'] as String?,
      vetId: json['vet_id'] as int?,
      photoUrl: json['photo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'cattle_id': cattleId,
        'date': date.toIso8601String(),
        'type': type.name,
        'symptoms': symptoms,
        'diagnosis': diagnosis,
        'treatment': treatment,
        'vet_id': vetId,
        'photo_url': photoUrl,
      };
}

/// A vaccination record.
@immutable
class Vaccination {
  final int id;
  final int cattleId;
  final String? cattleName;
  final String? cattleTagId;
  final String vaccineName;
  final DateTime dateGiven;
  final DateTime? nextDue;
  final String? administeredBy;

  const Vaccination({
    required this.id,
    required this.cattleId,
    this.cattleName,
    this.cattleTagId,
    required this.vaccineName,
    required this.dateGiven,
    this.nextDue,
    this.administeredBy,
  });

  bool get isOverdue =>
      nextDue != null && nextDue!.isBefore(DateTime.now());

  bool get isUpcoming =>
      nextDue != null &&
      !isOverdue &&
      nextDue!.isBefore(DateTime.now().add(const Duration(days: 30)));

  factory Vaccination.fromJson(Map<String, dynamic> json) {
    return Vaccination(
      id: json['id'] as int,
      cattleId: json['cattle_id'] as int,
      cattleName: json['cattle_name'] as String?,
      cattleTagId: json['cattle_tag_id'] as String?,
      vaccineName: json['vaccine_name'] as String,
      dateGiven: DateTime.parse(json['date_given'] as String),
      nextDue: json['next_due'] != null
          ? DateTime.parse(json['next_due'] as String)
          : null,
      administeredBy: json['administered_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'cattle_id': cattleId,
        'vaccine_name': vaccineName,
        'date_given': dateGiven.toIso8601String(),
        'next_due': nextDue?.toIso8601String(),
        'administered_by': administeredBy,
      };
}

/// AI triage result returned by POST /triage.
@immutable
class TriageResult {
  final TriageSeverity severity;
  final String diagnosis;
  final List<String> recommendedActions;
  final double confidenceScore;
  final int? cattleId;

  const TriageResult({
    required this.severity,
    required this.diagnosis,
    required this.recommendedActions,
    required this.confidenceScore,
    this.cattleId,
  });

  factory TriageResult.fromJson(Map<String, dynamic> json) {
    return TriageResult(
      severity: TriageSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => TriageSeverity.medium,
      ),
      diagnosis: json['diagnosis'] as String? ?? '',
      recommendedActions: (json['recommended_actions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      confidenceScore:
          (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      cattleId: json['cattle_id'] as int?,
    );
  }
}

/// A sensor alert from IoT devices.
@immutable
class SensorAlert {
  final int cattleId;
  final String cattleName;
  final String? cattleTagId;
  final String alertType; // 'high_temp', 'abnormal_heart_rate', 'low_activity'
  final double value;
  final String unit;
  final DateTime timestamp;

  const SensorAlert({
    required this.cattleId,
    required this.cattleName,
    this.cattleTagId,
    required this.alertType,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  factory SensorAlert.fromJson(Map<String, dynamic> json) {
    return SensorAlert(
      cattleId: json['cattle_id'] as int,
      cattleName: json['cattle_name'] as String? ?? 'Unknown',
      cattleTagId: json['cattle_tag_id'] as String?,
      alertType: json['alert_type'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  String get alertLabel {
    switch (alertType) {
      case 'high_temp':
        return 'High Temperature';
      case 'abnormal_heart_rate':
        return 'Abnormal Heart Rate';
      case 'low_activity':
        return 'Low Activity';
      default:
        return alertType;
    }
  }
}

/// Lightweight cattle reference for dropdowns.
@immutable
class CattleRef {
  final int id;
  final String? tagId;
  final String name;
  final String? breed;

  const CattleRef({
    required this.id,
    this.tagId,
    required this.name,
    this.breed,
  });

  factory CattleRef.fromJson(Map<String, dynamic> json) {
    return CattleRef(
      id: json['id'] as int,
      tagId: json['tag_id'] as String?,
      name: json['name'] as String? ?? 'Unnamed',
      breed: json['breed'] as String?,
    );
  }

  String get displayLabel => tagId != null ? '$name ($tagId)' : name;
}
