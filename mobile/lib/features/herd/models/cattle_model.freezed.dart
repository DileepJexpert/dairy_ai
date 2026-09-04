// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cattle_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Cattle _$CattleFromJson(Map<String, dynamic> json) {
  return _Cattle.fromJson(json);
}

/// @nodoc
mixin _$Cattle {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'farmer_id')
  String get farmerId => throw _privateConstructorUsedError;
  @JsonKey(name: 'tag_id')
  String get tagId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get breed => throw _privateConstructorUsedError;
  CattleSex get sex => throw _privateConstructorUsedError;
  DateTime? get dob => throw _privateConstructorUsedError;
  @JsonKey(name: 'photo_url')
  String? get photoUrl => throw _privateConstructorUsedError;
  CattleStatus get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Cattle to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Cattle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CattleCopyWith<Cattle> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CattleCopyWith<$Res> {
  factory $CattleCopyWith(Cattle value, $Res Function(Cattle) then) =
      _$CattleCopyWithImpl<$Res, Cattle>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'farmer_id') String farmerId,
      @JsonKey(name: 'tag_id') String tagId,
      String name,
      String breed,
      CattleSex sex,
      DateTime? dob,
      @JsonKey(name: 'photo_url') String? photoUrl,
      CattleStatus status,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class _$CattleCopyWithImpl<$Res, $Val extends Cattle>
    implements $CattleCopyWith<$Res> {
  _$CattleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Cattle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? farmerId = null,
    Object? tagId = null,
    Object? name = null,
    Object? breed = null,
    Object? sex = null,
    Object? dob = freezed,
    Object? photoUrl = freezed,
    Object? status = null,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      farmerId: null == farmerId
          ? _value.farmerId
          : farmerId // ignore: cast_nullable_to_non_nullable
              as String,
      tagId: null == tagId
          ? _value.tagId
          : tagId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      breed: null == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String,
      sex: null == sex
          ? _value.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as CattleSex,
      dob: freezed == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as CattleStatus,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CattleImplCopyWith<$Res> implements $CattleCopyWith<$Res> {
  factory _$$CattleImplCopyWith(
          _$CattleImpl value, $Res Function(_$CattleImpl) then) =
      __$$CattleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'farmer_id') String farmerId,
      @JsonKey(name: 'tag_id') String tagId,
      String name,
      String breed,
      CattleSex sex,
      DateTime? dob,
      @JsonKey(name: 'photo_url') String? photoUrl,
      CattleStatus status,
      @JsonKey(name: 'created_at') DateTime? createdAt});
}

/// @nodoc
class __$$CattleImplCopyWithImpl<$Res>
    extends _$CattleCopyWithImpl<$Res, _$CattleImpl>
    implements _$$CattleImplCopyWith<$Res> {
  __$$CattleImplCopyWithImpl(
      _$CattleImpl _value, $Res Function(_$CattleImpl) _then)
      : super(_value, _then);

  /// Create a copy of Cattle
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? farmerId = null,
    Object? tagId = null,
    Object? name = null,
    Object? breed = null,
    Object? sex = null,
    Object? dob = freezed,
    Object? photoUrl = freezed,
    Object? status = null,
    Object? createdAt = freezed,
  }) {
    return _then(_$CattleImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      farmerId: null == farmerId
          ? _value.farmerId
          : farmerId // ignore: cast_nullable_to_non_nullable
              as String,
      tagId: null == tagId
          ? _value.tagId
          : tagId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      breed: null == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String,
      sex: null == sex
          ? _value.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as CattleSex,
      dob: freezed == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as CattleStatus,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CattleImpl extends _Cattle {
  const _$CattleImpl(
      {required this.id,
      @JsonKey(name: 'farmer_id') required this.farmerId,
      @JsonKey(name: 'tag_id') required this.tagId,
      required this.name,
      required this.breed,
      required this.sex,
      this.dob,
      @JsonKey(name: 'photo_url') this.photoUrl,
      this.status = CattleStatus.active,
      @JsonKey(name: 'created_at') this.createdAt})
      : super._();

  factory _$CattleImpl.fromJson(Map<String, dynamic> json) =>
      _$$CattleImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'farmer_id')
  final String farmerId;
  @override
  @JsonKey(name: 'tag_id')
  final String tagId;
  @override
  final String name;
  @override
  final String breed;
  @override
  final CattleSex sex;
  @override
  final DateTime? dob;
  @override
  @JsonKey(name: 'photo_url')
  final String? photoUrl;
  @override
  @JsonKey()
  final CattleStatus status;
  @override
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  @override
  String toString() {
    return 'Cattle(id: $id, farmerId: $farmerId, tagId: $tagId, name: $name, breed: $breed, sex: $sex, dob: $dob, photoUrl: $photoUrl, status: $status, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CattleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.farmerId, farmerId) ||
                other.farmerId == farmerId) &&
            (identical(other.tagId, tagId) || other.tagId == tagId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.breed, breed) || other.breed == breed) &&
            (identical(other.sex, sex) || other.sex == sex) &&
            (identical(other.dob, dob) || other.dob == dob) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, farmerId, tagId, name, breed,
      sex, dob, photoUrl, status, createdAt);

  /// Create a copy of Cattle
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CattleImplCopyWith<_$CattleImpl> get copyWith =>
      __$$CattleImplCopyWithImpl<_$CattleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CattleImplToJson(
      this,
    );
  }
}

abstract class _Cattle extends Cattle {
  const factory _Cattle(
      {required final String id,
      @JsonKey(name: 'farmer_id') required final String farmerId,
      @JsonKey(name: 'tag_id') required final String tagId,
      required final String name,
      required final String breed,
      required final CattleSex sex,
      final DateTime? dob,
      @JsonKey(name: 'photo_url') final String? photoUrl,
      final CattleStatus status,
      @JsonKey(name: 'created_at') final DateTime? createdAt}) = _$CattleImpl;
  const _Cattle._() : super._();

  factory _Cattle.fromJson(Map<String, dynamic> json) = _$CattleImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'farmer_id')
  String get farmerId;
  @override
  @JsonKey(name: 'tag_id')
  String get tagId;
  @override
  String get name;
  @override
  String get breed;
  @override
  CattleSex get sex;
  @override
  DateTime? get dob;
  @override
  @JsonKey(name: 'photo_url')
  String? get photoUrl;
  @override
  CattleStatus get status;
  @override
  @JsonKey(name: 'created_at')
  DateTime? get createdAt;

  /// Create a copy of Cattle
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CattleImplCopyWith<_$CattleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CreateCattleRequest _$CreateCattleRequestFromJson(Map<String, dynamic> json) {
  return _CreateCattleRequest.fromJson(json);
}

/// @nodoc
mixin _$CreateCattleRequest {
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'tag_id')
  String get tagId => throw _privateConstructorUsedError;
  String get breed => throw _privateConstructorUsedError;
  CattleSex get sex => throw _privateConstructorUsedError;
  DateTime get dob => throw _privateConstructorUsedError;
  @JsonKey(name: 'photo_url')
  String? get photoUrl => throw _privateConstructorUsedError;

  /// Serializes this CreateCattleRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CreateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CreateCattleRequestCopyWith<CreateCattleRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CreateCattleRequestCopyWith<$Res> {
  factory $CreateCattleRequestCopyWith(
          CreateCattleRequest value, $Res Function(CreateCattleRequest) then) =
      _$CreateCattleRequestCopyWithImpl<$Res, CreateCattleRequest>;
  @useResult
  $Res call(
      {String name,
      @JsonKey(name: 'tag_id') String tagId,
      String breed,
      CattleSex sex,
      DateTime dob,
      @JsonKey(name: 'photo_url') String? photoUrl});
}

/// @nodoc
class _$CreateCattleRequestCopyWithImpl<$Res, $Val extends CreateCattleRequest>
    implements $CreateCattleRequestCopyWith<$Res> {
  _$CreateCattleRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CreateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? tagId = null,
    Object? breed = null,
    Object? sex = null,
    Object? dob = null,
    Object? photoUrl = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      tagId: null == tagId
          ? _value.tagId
          : tagId // ignore: cast_nullable_to_non_nullable
              as String,
      breed: null == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String,
      sex: null == sex
          ? _value.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as CattleSex,
      dob: null == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as DateTime,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CreateCattleRequestImplCopyWith<$Res>
    implements $CreateCattleRequestCopyWith<$Res> {
  factory _$$CreateCattleRequestImplCopyWith(_$CreateCattleRequestImpl value,
          $Res Function(_$CreateCattleRequestImpl) then) =
      __$$CreateCattleRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      @JsonKey(name: 'tag_id') String tagId,
      String breed,
      CattleSex sex,
      DateTime dob,
      @JsonKey(name: 'photo_url') String? photoUrl});
}

/// @nodoc
class __$$CreateCattleRequestImplCopyWithImpl<$Res>
    extends _$CreateCattleRequestCopyWithImpl<$Res, _$CreateCattleRequestImpl>
    implements _$$CreateCattleRequestImplCopyWith<$Res> {
  __$$CreateCattleRequestImplCopyWithImpl(_$CreateCattleRequestImpl _value,
      $Res Function(_$CreateCattleRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of CreateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? tagId = null,
    Object? breed = null,
    Object? sex = null,
    Object? dob = null,
    Object? photoUrl = freezed,
  }) {
    return _then(_$CreateCattleRequestImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      tagId: null == tagId
          ? _value.tagId
          : tagId // ignore: cast_nullable_to_non_nullable
              as String,
      breed: null == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String,
      sex: null == sex
          ? _value.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as CattleSex,
      dob: null == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as DateTime,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CreateCattleRequestImpl implements _CreateCattleRequest {
  const _$CreateCattleRequestImpl(
      {required this.name,
      @JsonKey(name: 'tag_id') required this.tagId,
      required this.breed,
      required this.sex,
      required this.dob,
      @JsonKey(name: 'photo_url') this.photoUrl});

  factory _$CreateCattleRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$CreateCattleRequestImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey(name: 'tag_id')
  final String tagId;
  @override
  final String breed;
  @override
  final CattleSex sex;
  @override
  final DateTime dob;
  @override
  @JsonKey(name: 'photo_url')
  final String? photoUrl;

  @override
  String toString() {
    return 'CreateCattleRequest(name: $name, tagId: $tagId, breed: $breed, sex: $sex, dob: $dob, photoUrl: $photoUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CreateCattleRequestImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.tagId, tagId) || other.tagId == tagId) &&
            (identical(other.breed, breed) || other.breed == breed) &&
            (identical(other.sex, sex) || other.sex == sex) &&
            (identical(other.dob, dob) || other.dob == dob) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, tagId, breed, sex, dob, photoUrl);

  /// Create a copy of CreateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CreateCattleRequestImplCopyWith<_$CreateCattleRequestImpl> get copyWith =>
      __$$CreateCattleRequestImplCopyWithImpl<_$CreateCattleRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CreateCattleRequestImplToJson(
      this,
    );
  }
}

abstract class _CreateCattleRequest implements CreateCattleRequest {
  const factory _CreateCattleRequest(
          {required final String name,
          @JsonKey(name: 'tag_id') required final String tagId,
          required final String breed,
          required final CattleSex sex,
          required final DateTime dob,
          @JsonKey(name: 'photo_url') final String? photoUrl}) =
      _$CreateCattleRequestImpl;

  factory _CreateCattleRequest.fromJson(Map<String, dynamic> json) =
      _$CreateCattleRequestImpl.fromJson;

  @override
  String get name;
  @override
  @JsonKey(name: 'tag_id')
  String get tagId;
  @override
  String get breed;
  @override
  CattleSex get sex;
  @override
  DateTime get dob;
  @override
  @JsonKey(name: 'photo_url')
  String? get photoUrl;

  /// Create a copy of CreateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CreateCattleRequestImplCopyWith<_$CreateCattleRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

UpdateCattleRequest _$UpdateCattleRequestFromJson(Map<String, dynamic> json) {
  return _UpdateCattleRequest.fromJson(json);
}

/// @nodoc
mixin _$UpdateCattleRequest {
  String? get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'tag_id')
  String? get tagId => throw _privateConstructorUsedError;
  String? get breed => throw _privateConstructorUsedError;
  CattleSex? get sex => throw _privateConstructorUsedError;
  DateTime? get dob => throw _privateConstructorUsedError;
  @JsonKey(name: 'photo_url')
  String? get photoUrl => throw _privateConstructorUsedError;
  CattleStatus? get status => throw _privateConstructorUsedError;

  /// Serializes this UpdateCattleRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UpdateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UpdateCattleRequestCopyWith<UpdateCattleRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UpdateCattleRequestCopyWith<$Res> {
  factory $UpdateCattleRequestCopyWith(
          UpdateCattleRequest value, $Res Function(UpdateCattleRequest) then) =
      _$UpdateCattleRequestCopyWithImpl<$Res, UpdateCattleRequest>;
  @useResult
  $Res call(
      {String? name,
      @JsonKey(name: 'tag_id') String? tagId,
      String? breed,
      CattleSex? sex,
      DateTime? dob,
      @JsonKey(name: 'photo_url') String? photoUrl,
      CattleStatus? status});
}

/// @nodoc
class _$UpdateCattleRequestCopyWithImpl<$Res, $Val extends UpdateCattleRequest>
    implements $UpdateCattleRequestCopyWith<$Res> {
  _$UpdateCattleRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UpdateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? tagId = freezed,
    Object? breed = freezed,
    Object? sex = freezed,
    Object? dob = freezed,
    Object? photoUrl = freezed,
    Object? status = freezed,
  }) {
    return _then(_value.copyWith(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      tagId: freezed == tagId
          ? _value.tagId
          : tagId // ignore: cast_nullable_to_non_nullable
              as String?,
      breed: freezed == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String?,
      sex: freezed == sex
          ? _value.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as CattleSex?,
      dob: freezed == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as CattleStatus?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UpdateCattleRequestImplCopyWith<$Res>
    implements $UpdateCattleRequestCopyWith<$Res> {
  factory _$$UpdateCattleRequestImplCopyWith(_$UpdateCattleRequestImpl value,
          $Res Function(_$UpdateCattleRequestImpl) then) =
      __$$UpdateCattleRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String? name,
      @JsonKey(name: 'tag_id') String? tagId,
      String? breed,
      CattleSex? sex,
      DateTime? dob,
      @JsonKey(name: 'photo_url') String? photoUrl,
      CattleStatus? status});
}

/// @nodoc
class __$$UpdateCattleRequestImplCopyWithImpl<$Res>
    extends _$UpdateCattleRequestCopyWithImpl<$Res, _$UpdateCattleRequestImpl>
    implements _$$UpdateCattleRequestImplCopyWith<$Res> {
  __$$UpdateCattleRequestImplCopyWithImpl(_$UpdateCattleRequestImpl _value,
      $Res Function(_$UpdateCattleRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of UpdateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? tagId = freezed,
    Object? breed = freezed,
    Object? sex = freezed,
    Object? dob = freezed,
    Object? photoUrl = freezed,
    Object? status = freezed,
  }) {
    return _then(_$UpdateCattleRequestImpl(
      name: freezed == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      tagId: freezed == tagId
          ? _value.tagId
          : tagId // ignore: cast_nullable_to_non_nullable
              as String?,
      breed: freezed == breed
          ? _value.breed
          : breed // ignore: cast_nullable_to_non_nullable
              as String?,
      sex: freezed == sex
          ? _value.sex
          : sex // ignore: cast_nullable_to_non_nullable
              as CattleSex?,
      dob: freezed == dob
          ? _value.dob
          : dob // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      photoUrl: freezed == photoUrl
          ? _value.photoUrl
          : photoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as CattleStatus?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UpdateCattleRequestImpl implements _UpdateCattleRequest {
  const _$UpdateCattleRequestImpl(
      {this.name,
      @JsonKey(name: 'tag_id') this.tagId,
      this.breed,
      this.sex,
      this.dob,
      @JsonKey(name: 'photo_url') this.photoUrl,
      this.status});

  factory _$UpdateCattleRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$UpdateCattleRequestImplFromJson(json);

  @override
  final String? name;
  @override
  @JsonKey(name: 'tag_id')
  final String? tagId;
  @override
  final String? breed;
  @override
  final CattleSex? sex;
  @override
  final DateTime? dob;
  @override
  @JsonKey(name: 'photo_url')
  final String? photoUrl;
  @override
  final CattleStatus? status;

  @override
  String toString() {
    return 'UpdateCattleRequest(name: $name, tagId: $tagId, breed: $breed, sex: $sex, dob: $dob, photoUrl: $photoUrl, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UpdateCattleRequestImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.tagId, tagId) || other.tagId == tagId) &&
            (identical(other.breed, breed) || other.breed == breed) &&
            (identical(other.sex, sex) || other.sex == sex) &&
            (identical(other.dob, dob) || other.dob == dob) &&
            (identical(other.photoUrl, photoUrl) ||
                other.photoUrl == photoUrl) &&
            (identical(other.status, status) || other.status == status));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, tagId, breed, sex, dob, photoUrl, status);

  /// Create a copy of UpdateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UpdateCattleRequestImplCopyWith<_$UpdateCattleRequestImpl> get copyWith =>
      __$$UpdateCattleRequestImplCopyWithImpl<_$UpdateCattleRequestImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UpdateCattleRequestImplToJson(
      this,
    );
  }
}

abstract class _UpdateCattleRequest implements UpdateCattleRequest {
  const factory _UpdateCattleRequest(
      {final String? name,
      @JsonKey(name: 'tag_id') final String? tagId,
      final String? breed,
      final CattleSex? sex,
      final DateTime? dob,
      @JsonKey(name: 'photo_url') final String? photoUrl,
      final CattleStatus? status}) = _$UpdateCattleRequestImpl;

  factory _UpdateCattleRequest.fromJson(Map<String, dynamic> json) =
      _$UpdateCattleRequestImpl.fromJson;

  @override
  String? get name;
  @override
  @JsonKey(name: 'tag_id')
  String? get tagId;
  @override
  String? get breed;
  @override
  CattleSex? get sex;
  @override
  DateTime? get dob;
  @override
  @JsonKey(name: 'photo_url')
  String? get photoUrl;
  @override
  CattleStatus? get status;

  /// Create a copy of UpdateCattleRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UpdateCattleRequestImplCopyWith<_$UpdateCattleRequestImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
