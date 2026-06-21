// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'breeding_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

BreedingRecord _$BreedingRecordFromJson(Map<String, dynamic> json) {
  return _BreedingRecord.fromJson(json);
}

/// @nodoc
mixin _$BreedingRecord {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_id')
  String get cattleId => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_name')
  String? get cattleName => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_type')
  BreedingEventType get eventType => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'bull_id')
  String? get bullId => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_tech_id')
  String? get aiTechId => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_tech_name')
  String? get aiTechName => throw _privateConstructorUsedError;
  String? get result => throw _privateConstructorUsedError;
  @JsonKey(name: 'calf_id')
  String? get calfId => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this BreedingRecord to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BreedingRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BreedingRecordCopyWith<BreedingRecord> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BreedingRecordCopyWith<$Res> {
  factory $BreedingRecordCopyWith(
          BreedingRecord value, $Res Function(BreedingRecord) then) =
      _$BreedingRecordCopyWithImpl<$Res, BreedingRecord>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'cattle_name') String? cattleName,
      @JsonKey(name: 'event_type') BreedingEventType eventType,
      String date,
      @JsonKey(name: 'bull_id') String? bullId,
      @JsonKey(name: 'ai_tech_id') String? aiTechId,
      @JsonKey(name: 'ai_tech_name') String? aiTechName,
      String? result,
      @JsonKey(name: 'calf_id') String? calfId,
      String? notes,
      @JsonKey(name: 'created_at') String? createdAt});
}

/// @nodoc
class _$BreedingRecordCopyWithImpl<$Res, $Val extends BreedingRecord>
    implements $BreedingRecordCopyWith<$Res> {
  _$BreedingRecordCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BreedingRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cattleId = null,
    Object? cattleName = freezed,
    Object? eventType = null,
    Object? date = null,
    Object? bullId = freezed,
    Object? aiTechId = freezed,
    Object? aiTechName = freezed,
    Object? result = freezed,
    Object? calfId = freezed,
    Object? notes = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      cattleId: null == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String,
      cattleName: freezed == cattleName
          ? _value.cattleName
          : cattleName // ignore: cast_nullable_to_non_nullable
              as String?,
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as BreedingEventType,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      bullId: freezed == bullId
          ? _value.bullId
          : bullId // ignore: cast_nullable_to_non_nullable
              as String?,
      aiTechId: freezed == aiTechId
          ? _value.aiTechId
          : aiTechId // ignore: cast_nullable_to_non_nullable
              as String?,
      aiTechName: freezed == aiTechName
          ? _value.aiTechName
          : aiTechName // ignore: cast_nullable_to_non_nullable
              as String?,
      result: freezed == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as String?,
      calfId: freezed == calfId
          ? _value.calfId
          : calfId // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BreedingRecordImplCopyWith<$Res>
    implements $BreedingRecordCopyWith<$Res> {
  factory _$$BreedingRecordImplCopyWith(_$BreedingRecordImpl value,
          $Res Function(_$BreedingRecordImpl) then) =
      __$$BreedingRecordImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'cattle_name') String? cattleName,
      @JsonKey(name: 'event_type') BreedingEventType eventType,
      String date,
      @JsonKey(name: 'bull_id') String? bullId,
      @JsonKey(name: 'ai_tech_id') String? aiTechId,
      @JsonKey(name: 'ai_tech_name') String? aiTechName,
      String? result,
      @JsonKey(name: 'calf_id') String? calfId,
      String? notes,
      @JsonKey(name: 'created_at') String? createdAt});
}

/// @nodoc
class __$$BreedingRecordImplCopyWithImpl<$Res>
    extends _$BreedingRecordCopyWithImpl<$Res, _$BreedingRecordImpl>
    implements _$$BreedingRecordImplCopyWith<$Res> {
  __$$BreedingRecordImplCopyWithImpl(
      _$BreedingRecordImpl _value, $Res Function(_$BreedingRecordImpl) _then)
      : super(_value, _then);

  /// Create a copy of BreedingRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cattleId = null,
    Object? cattleName = freezed,
    Object? eventType = null,
    Object? date = null,
    Object? bullId = freezed,
    Object? aiTechId = freezed,
    Object? aiTechName = freezed,
    Object? result = freezed,
    Object? calfId = freezed,
    Object? notes = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$BreedingRecordImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      cattleId: null == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String,
      cattleName: freezed == cattleName
          ? _value.cattleName
          : cattleName // ignore: cast_nullable_to_non_nullable
              as String?,
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as BreedingEventType,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      bullId: freezed == bullId
          ? _value.bullId
          : bullId // ignore: cast_nullable_to_non_nullable
              as String?,
      aiTechId: freezed == aiTechId
          ? _value.aiTechId
          : aiTechId // ignore: cast_nullable_to_non_nullable
              as String?,
      aiTechName: freezed == aiTechName
          ? _value.aiTechName
          : aiTechName // ignore: cast_nullable_to_non_nullable
              as String?,
      result: freezed == result
          ? _value.result
          : result // ignore: cast_nullable_to_non_nullable
              as String?,
      calfId: freezed == calfId
          ? _value.calfId
          : calfId // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$BreedingRecordImpl extends _BreedingRecord {
  const _$BreedingRecordImpl(
      {required this.id,
      @JsonKey(name: 'cattle_id') required this.cattleId,
      @JsonKey(name: 'cattle_name') this.cattleName,
      @JsonKey(name: 'event_type') required this.eventType,
      required this.date,
      @JsonKey(name: 'bull_id') this.bullId,
      @JsonKey(name: 'ai_tech_id') this.aiTechId,
      @JsonKey(name: 'ai_tech_name') this.aiTechName,
      this.result,
      @JsonKey(name: 'calf_id') this.calfId,
      this.notes,
      @JsonKey(name: 'created_at') this.createdAt})
      : super._();

  factory _$BreedingRecordImpl.fromJson(Map<String, dynamic> json) =>
      _$$BreedingRecordImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'cattle_id')
  final String cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  final String? cattleName;
  @override
  @JsonKey(name: 'event_type')
  final BreedingEventType eventType;
  @override
  final String date;
  @override
  @JsonKey(name: 'bull_id')
  final String? bullId;
  @override
  @JsonKey(name: 'ai_tech_id')
  final String? aiTechId;
  @override
  @JsonKey(name: 'ai_tech_name')
  final String? aiTechName;
  @override
  final String? result;
  @override
  @JsonKey(name: 'calf_id')
  final String? calfId;
  @override
  final String? notes;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;

  @override
  String toString() {
    return 'BreedingRecord(id: $id, cattleId: $cattleId, cattleName: $cattleName, eventType: $eventType, date: $date, bullId: $bullId, aiTechId: $aiTechId, aiTechName: $aiTechName, result: $result, calfId: $calfId, notes: $notes, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BreedingRecordImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.cattleId, cattleId) ||
                other.cattleId == cattleId) &&
            (identical(other.cattleName, cattleName) ||
                other.cattleName == cattleName) &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.bullId, bullId) || other.bullId == bullId) &&
            (identical(other.aiTechId, aiTechId) ||
                other.aiTechId == aiTechId) &&
            (identical(other.aiTechName, aiTechName) ||
                other.aiTechName == aiTechName) &&
            (identical(other.result, result) || other.result == result) &&
            (identical(other.calfId, calfId) || other.calfId == calfId) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, cattleId, cattleName,
      eventType, date, bullId, aiTechId, aiTechName, result, calfId, notes, createdAt);

  /// Create a copy of BreedingRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BreedingRecordImplCopyWith<_$BreedingRecordImpl> get copyWith =>
      __$$BreedingRecordImplCopyWithImpl<_$BreedingRecordImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$BreedingRecordImplToJson(
      this,
    );
  }
}

abstract class _BreedingRecord extends BreedingRecord {
  const factory _BreedingRecord(
      {required final String id,
      @JsonKey(name: 'cattle_id') required final String cattleId,
      @JsonKey(name: 'cattle_name') final String? cattleName,
      @JsonKey(name: 'event_type') required final BreedingEventType eventType,
      required final String date,
      @JsonKey(name: 'bull_id') final String? bullId,
      @JsonKey(name: 'ai_tech_id') final String? aiTechId,
      @JsonKey(name: 'ai_tech_name') final String? aiTechName,
      final String? result,
      @JsonKey(name: 'calf_id') final String? calfId,
      final String? notes,
      @JsonKey(name: 'created_at') final String? createdAt}) = _$BreedingRecordImpl;
  const _BreedingRecord._() : super._();

  factory _BreedingRecord.fromJson(Map<String, dynamic> json) =
      _$BreedingRecordImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'cattle_id')
  String get cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  String? get cattleName;
  @override
  @JsonKey(name: 'event_type')
  BreedingEventType get eventType;
  @override
  String get date;
  @override
  @JsonKey(name: 'bull_id')
  String? get bullId;
  @override
  @JsonKey(name: 'ai_tech_id')
  String? get aiTechId;
  @override
  @JsonKey(name: 'ai_tech_name')
  String? get aiTechName;
  @override
  String? get result;
  @override
  @JsonKey(name: 'calf_id')
  String? get calfId;
  @override
  String? get notes;
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;

  /// Create a copy of BreedingRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BreedingRecordImplCopyWith<_$BreedingRecordImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AddBreedingEventRequest _$AddBreedingEventRequestFromJson(
    Map<String, dynamic> json) {
  return _AddBreedingEventRequest.fromJson(json);
}

/// @nodoc
mixin _$AddBreedingEventRequest {
  @JsonKey(name: 'cattle_id')
  String get cattleId => throw _privateConstructorUsedError;
  @JsonKey(name: 'event_type')
  String get eventType => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'bull_id')
  String? get bullId => throw _privateConstructorUsedError;
  @JsonKey(name: 'ai_tech_id')
  String? get aiTechId => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  /// Serializes this AddBreedingEventRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AddBreedingEventRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AddBreedingEventRequestCopyWith<AddBreedingEventRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AddBreedingEventRequestCopyWith<$Res> {
  factory $AddBreedingEventRequestCopyWith(AddBreedingEventRequest value,
          $Res Function(AddBreedingEventRequest) then) =
      _$AddBreedingEventRequestCopyWithImpl<$Res, AddBreedingEventRequest>;
  @useResult
  $Res call(
      {@JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'event_type') String eventType,
      String date,
      @JsonKey(name: 'bull_id') String? bullId,
      @JsonKey(name: 'ai_tech_id') String? aiTechId,
      String? notes});
}

/// @nodoc
class _$AddBreedingEventRequestCopyWithImpl<$Res,
        $Val extends AddBreedingEventRequest>
    implements $AddBreedingEventRequestCopyWith<$Res> {
  _$AddBreedingEventRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AddBreedingEventRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cattleId = null,
    Object? eventType = null,
    Object? date = null,
    Object? bullId = freezed,
    Object? aiTechId = freezed,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      cattleId: null == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String,
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      bullId: freezed == bullId
          ? _value.bullId
          : bullId // ignore: cast_nullable_to_non_nullable
              as String?,
      aiTechId: freezed == aiTechId
          ? _value.aiTechId
          : aiTechId // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AddBreedingEventRequestImplCopyWith<$Res>
    implements $AddBreedingEventRequestCopyWith<$Res> {
  factory _$$AddBreedingEventRequestImplCopyWith(
          _$AddBreedingEventRequestImpl value,
          $Res Function(_$AddBreedingEventRequestImpl) then) =
      __$$AddBreedingEventRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'event_type') String eventType,
      String date,
      @JsonKey(name: 'bull_id') String? bullId,
      @JsonKey(name: 'ai_tech_id') String? aiTechId,
      String? notes});
}

/// @nodoc
class __$$AddBreedingEventRequestImplCopyWithImpl<$Res>
    extends _$AddBreedingEventRequestCopyWithImpl<$Res,
        _$AddBreedingEventRequestImpl>
    implements _$$AddBreedingEventRequestImplCopyWith<$Res> {
  __$$AddBreedingEventRequestImplCopyWithImpl(
      _$AddBreedingEventRequestImpl _value,
      $Res Function(_$AddBreedingEventRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of AddBreedingEventRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cattleId = null,
    Object? eventType = null,
    Object? date = null,
    Object? bullId = freezed,
    Object? aiTechId = freezed,
    Object? notes = freezed,
  }) {
    return _then(_$AddBreedingEventRequestImpl(
      cattleId: null == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String,
      eventType: null == eventType
          ? _value.eventType
          : eventType // ignore: cast_nullable_to_non_nullable
              as String,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      bullId: freezed == bullId
          ? _value.bullId
          : bullId // ignore: cast_nullable_to_non_nullable
              as String?,
      aiTechId: freezed == aiTechId
          ? _value.aiTechId
          : aiTechId // ignore: cast_nullable_to_non_nullable
              as String?,
      notes: freezed == notes
          ? _value.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AddBreedingEventRequestImpl implements _AddBreedingEventRequest {
  const _$AddBreedingEventRequestImpl(
      {@JsonKey(name: 'cattle_id') required this.cattleId,
      @JsonKey(name: 'event_type') required this.eventType,
      required this.date,
      @JsonKey(name: 'bull_id') this.bullId,
      @JsonKey(name: 'ai_tech_id') this.aiTechId,
      this.notes});

  factory _$AddBreedingEventRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$AddBreedingEventRequestImplFromJson(json);

  @override
  @JsonKey(name: 'cattle_id')
  final String cattleId;
  @override
  @JsonKey(name: 'event_type')
  final String eventType;
  @override
  final String date;
  @override
  @JsonKey(name: 'bull_id')
  final String? bullId;
  @override
  @JsonKey(name: 'ai_tech_id')
  final String? aiTechId;
  @override
  final String? notes;

  @override
  String toString() {
    return 'AddBreedingEventRequest(cattleId: $cattleId, eventType: $eventType, date: $date, bullId: $bullId, aiTechId: $aiTechId, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AddBreedingEventRequestImpl &&
            (identical(other.cattleId, cattleId) ||
                other.cattleId == cattleId) &&
            (identical(other.eventType, eventType) ||
                other.eventType == eventType) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.bullId, bullId) || other.bullId == bullId) &&
            (identical(other.aiTechId, aiTechId) ||
                other.aiTechId == aiTechId) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, cattleId, eventType, date, bullId, aiTechId, notes);

  /// Create a copy of AddBreedingEventRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AddBreedingEventRequestImplCopyWith<_$AddBreedingEventRequestImpl>
      get copyWith => __$$AddBreedingEventRequestImplCopyWithImpl<
          _$AddBreedingEventRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AddBreedingEventRequestImplToJson(
      this,
    );
  }
}

abstract class _AddBreedingEventRequest implements AddBreedingEventRequest {
  const factory _AddBreedingEventRequest(
      {@JsonKey(name: 'cattle_id') required final String cattleId,
      @JsonKey(name: 'event_type') required final String eventType,
      required final String date,
      @JsonKey(name: 'bull_id') final String? bullId,
      @JsonKey(name: 'ai_tech_id') final String? aiTechId,
      final String? notes}) = _$AddBreedingEventRequestImpl;

  factory _AddBreedingEventRequest.fromJson(Map<String, dynamic> json) =
      _$AddBreedingEventRequestImpl.fromJson;

  @override
  @JsonKey(name: 'cattle_id')
  String get cattleId;
  @override
  @JsonKey(name: 'event_type')
  String get eventType;
  @override
  String get date;
  @override
  @JsonKey(name: 'bull_id')
  String? get bullId;
  @override
  @JsonKey(name: 'ai_tech_id')
  String? get aiTechId;
  @override
  String? get notes;

  /// Create a copy of AddBreedingEventRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AddBreedingEventRequestImplCopyWith<_$AddBreedingEventRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}
