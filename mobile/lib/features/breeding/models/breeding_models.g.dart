// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'breeding_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BreedingRecordImpl _$$BreedingRecordImplFromJson(Map<String, dynamic> json) =>
    _$BreedingRecordImpl(
      id: json['id'] as String,
      cattleId: json['cattle_id'] as String,
      cattleName: json['cattle_name'] as String?,
      eventType:
          $enumDecode(_$BreedingEventTypeEnumMap, json['event_type']),
      date: json['date'] as String,
      bullId: json['bull_id'] as String?,
      aiTechId: json['ai_tech_id'] as String?,
      aiTechName: json['ai_tech_name'] as String?,
      result: json['result'] as String?,
      calfId: json['calf_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$$BreedingRecordImplToJson(
        _$BreedingRecordImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'cattle_id': instance.cattleId,
      'cattle_name': instance.cattleName,
      'event_type': _$BreedingEventTypeEnumMap[instance.eventType]!,
      'date': instance.date,
      'bull_id': instance.bullId,
      'ai_tech_id': instance.aiTechId,
      'ai_tech_name': instance.aiTechName,
      'result': instance.result,
      'calf_id': instance.calfId,
      'notes': instance.notes,
      'created_at': instance.createdAt,
    };

const _$BreedingEventTypeEnumMap = {
  BreedingEventType.heatDetected: 'heat_detected',
  BreedingEventType.aiDone: 'ai_done',
  BreedingEventType.pregnancyConfirmed: 'pregnancy_confirmed',
  BreedingEventType.calved: 'calved',
};

_$AddBreedingEventRequestImpl _$$AddBreedingEventRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$AddBreedingEventRequestImpl(
      cattleId: json['cattle_id'] as String,
      eventType: json['event_type'] as String,
      date: json['date'] as String,
      bullId: json['bull_id'] as String?,
      aiTechId: json['ai_tech_id'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$AddBreedingEventRequestImplToJson(
        _$AddBreedingEventRequestImpl instance) =>
    <String, dynamic>{
      'cattle_id': instance.cattleId,
      'event_type': instance.eventType,
      'date': instance.date,
      'bull_id': instance.bullId,
      'ai_tech_id': instance.aiTechId,
      'notes': instance.notes,
    };
