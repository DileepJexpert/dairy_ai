// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cattle_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CattleImpl _$$CattleImplFromJson(Map<String, dynamic> json) => _$CattleImpl(
      id: json['id'] as String,
      farmerId: json['farmer_id'] as String,
      tagId: json['tag_id'] as String,
      name: json['name'] as String,
      breed: json['breed'] as String,
      sex: $enumDecode(_$CattleSexEnumMap, json['sex']),
      dob: DateTime.parse(json['dob'] as String),
      photoUrl: json['photo_url'] as String?,
      status: $enumDecodeNullable(_$CattleStatusEnumMap, json['status']) ??
          CattleStatus.active,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$CattleImplToJson(_$CattleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'farmer_id': instance.farmerId,
      'tag_id': instance.tagId,
      'name': instance.name,
      'breed': instance.breed,
      'sex': _$CattleSexEnumMap[instance.sex]!,
      'dob': instance.dob.toIso8601String(),
      'photo_url': instance.photoUrl,
      'status': _$CattleStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt?.toIso8601String(),
    };

const _$CattleSexEnumMap = {
  CattleSex.female: 'female',
  CattleSex.male: 'male',
};

const _$CattleStatusEnumMap = {
  CattleStatus.active: 'active',
  CattleStatus.dry: 'dry',
  CattleStatus.sold: 'sold',
  CattleStatus.deceased: 'deceased',
};

_$CreateCattleRequestImpl _$$CreateCattleRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$CreateCattleRequestImpl(
      name: json['name'] as String,
      tagId: json['tag_id'] as String,
      breed: json['breed'] as String,
      sex: $enumDecode(_$CattleSexEnumMap, json['sex']),
      dob: DateTime.parse(json['dob'] as String),
      photoUrl: json['photo_url'] as String?,
    );

Map<String, dynamic> _$$CreateCattleRequestImplToJson(
        _$CreateCattleRequestImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'tag_id': instance.tagId,
      'breed': instance.breed,
      'sex': _$CattleSexEnumMap[instance.sex]!,
      'dob': instance.dob.toIso8601String(),
      'photo_url': instance.photoUrl,
    };

_$UpdateCattleRequestImpl _$$UpdateCattleRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$UpdateCattleRequestImpl(
      name: json['name'] as String?,
      tagId: json['tag_id'] as String?,
      breed: json['breed'] as String?,
      sex: $enumDecodeNullable(_$CattleSexEnumMap, json['sex']),
      dob: json['dob'] == null
          ? null
          : DateTime.parse(json['dob'] as String),
      photoUrl: json['photo_url'] as String?,
      status: $enumDecodeNullable(_$CattleStatusEnumMap, json['status']),
    );

Map<String, dynamic> _$$UpdateCattleRequestImplToJson(
        _$UpdateCattleRequestImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'tag_id': instance.tagId,
      'breed': instance.breed,
      'sex': _$CattleSexEnumMap[instance.sex],
      'dob': instance.dob?.toIso8601String(),
      'photo_url': instance.photoUrl,
      'status': _$CattleStatusEnumMap[instance.status],
    };
