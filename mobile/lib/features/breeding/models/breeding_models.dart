import 'package:freezed_annotation/freezed_annotation.dart';

part 'breeding_models.freezed.dart';
part 'breeding_models.g.dart';

enum BreedingEventType {
  @JsonValue('heat_detected')
  heatDetected,
  @JsonValue('ai_done')
  aiDone,
  @JsonValue('pregnancy_confirmed')
  pregnancyConfirmed,
  @JsonValue('calved')
  calved,
}

@freezed
class BreedingRecord with _$BreedingRecord {
  const BreedingRecord._();

  const factory BreedingRecord({
    required String id,
    @JsonKey(name: 'cattle_id') required String cattleId,
    @JsonKey(name: 'cattle_name') String? cattleName,
    @JsonKey(name: 'event_type') required BreedingEventType eventType,
    required String date,
    @JsonKey(name: 'bull_id') String? bullId,
    @JsonKey(name: 'ai_tech_id') String? aiTechId,
    @JsonKey(name: 'ai_tech_name') String? aiTechName,
    String? result,
    @JsonKey(name: 'calf_id') String? calfId,
    String? notes,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _BreedingRecord;

  factory BreedingRecord.fromJson(Map<String, dynamic> json) =>
      _$BreedingRecordFromJson(json);

  /// Calculates expected calving date: 283 days from AI date.
  DateTime? get expectedCalvingDate {
    if (eventType == BreedingEventType.aiDone) {
      return DateTime.parse(date).add(const Duration(days: 283));
    }
    return null;
  }

  String get eventTypeLabel {
    switch (eventType) {
      case BreedingEventType.heatDetected:
        return 'Heat Detected';
      case BreedingEventType.aiDone:
        return 'AI Done';
      case BreedingEventType.pregnancyConfirmed:
        return 'Pregnancy Confirmed';
      case BreedingEventType.calved:
        return 'Calved';
    }
  }
}

@freezed
class AddBreedingEventRequest with _$AddBreedingEventRequest {
  const factory AddBreedingEventRequest({
    @JsonKey(name: 'cattle_id') required String cattleId,
    @JsonKey(name: 'event_type') required String eventType,
    required String date,
    @JsonKey(name: 'bull_id') String? bullId,
    @JsonKey(name: 'ai_tech_id') String? aiTechId,
    String? notes,
  }) = _AddBreedingEventRequest;

  factory AddBreedingEventRequest.fromJson(Map<String, dynamic> json) =>
      _$AddBreedingEventRequestFromJson(json);
}
