// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feed_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FeedIngredient _$FeedIngredientFromJson(Map<String, dynamic> json) {
  return _FeedIngredient.fromJson(json);
}

/// @nodoc
mixin _$FeedIngredient {
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'quantity_kg')
  double get quantityKg => throw _privateConstructorUsedError;
  @JsonKey(name: 'cost_per_kg')
  double get costPerKg => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_cost')
  double get totalCost => throw _privateConstructorUsedError;
  String? get category => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FeedIngredientCopyWith<FeedIngredient> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedIngredientCopyWith<$Res> {
  factory $FeedIngredientCopyWith(
          FeedIngredient value, $Res Function(FeedIngredient) then) =
      _$FeedIngredientCopyWithImpl<$Res, FeedIngredient>;
  @useResult
  $Res call(
      {String name,
      @JsonKey(name: 'quantity_kg') double quantityKg,
      @JsonKey(name: 'cost_per_kg') double costPerKg,
      @JsonKey(name: 'total_cost') double totalCost,
      String? category});
}

/// @nodoc
class _$FeedIngredientCopyWithImpl<$Res, $Val extends FeedIngredient>
    implements $FeedIngredientCopyWith<$Res> {
  _$FeedIngredientCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? quantityKg = null,
    Object? costPerKg = null,
    Object? totalCost = null,
    Object? category = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name ? _value.name : name as String,
      quantityKg:
          null == quantityKg ? _value.quantityKg : quantityKg as double,
      costPerKg: null == costPerKg ? _value.costPerKg : costPerKg as double,
      totalCost: null == totalCost ? _value.totalCost : totalCost as double,
      category: freezed == category ? _value.category : category as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FeedIngredientImplCopyWith<$Res>
    implements $FeedIngredientCopyWith<$Res> {
  factory _$$FeedIngredientImplCopyWith(_$FeedIngredientImpl value,
          $Res Function(_$FeedIngredientImpl) then) =
      __$$FeedIngredientImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      @JsonKey(name: 'quantity_kg') double quantityKg,
      @JsonKey(name: 'cost_per_kg') double costPerKg,
      @JsonKey(name: 'total_cost') double totalCost,
      String? category});
}

/// @nodoc
class __$$FeedIngredientImplCopyWithImpl<$Res>
    extends _$FeedIngredientCopyWithImpl<$Res, _$FeedIngredientImpl>
    implements _$$FeedIngredientImplCopyWith<$Res> {
  __$$FeedIngredientImplCopyWithImpl(
      _$FeedIngredientImpl _value, $Res Function(_$FeedIngredientImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? quantityKg = null,
    Object? costPerKg = null,
    Object? totalCost = null,
    Object? category = freezed,
  }) {
    return _then(_$FeedIngredientImpl(
      name: null == name ? _value.name : name as String,
      quantityKg:
          null == quantityKg ? _value.quantityKg : quantityKg as double,
      costPerKg: null == costPerKg ? _value.costPerKg : costPerKg as double,
      totalCost: null == totalCost ? _value.totalCost : totalCost as double,
      category: freezed == category ? _value.category : category as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedIngredientImpl implements _FeedIngredient {
  const _$FeedIngredientImpl(
      {required this.name,
      @JsonKey(name: 'quantity_kg') required this.quantityKg,
      @JsonKey(name: 'cost_per_kg') required this.costPerKg,
      @JsonKey(name: 'total_cost') required this.totalCost,
      this.category});

  factory _$FeedIngredientImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedIngredientImplFromJson(json);

  @override
  final String name;
  @override
  @JsonKey(name: 'quantity_kg')
  final double quantityKg;
  @override
  @JsonKey(name: 'cost_per_kg')
  final double costPerKg;
  @override
  @JsonKey(name: 'total_cost')
  final double totalCost;
  @override
  final String? category;

  @override
  String toString() {
    return 'FeedIngredient(name: $name, quantityKg: $quantityKg, costPerKg: $costPerKg, totalCost: $totalCost, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedIngredientImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.quantityKg, quantityKg) ||
                other.quantityKg == quantityKg) &&
            (identical(other.costPerKg, costPerKg) ||
                other.costPerKg == costPerKg) &&
            (identical(other.totalCost, totalCost) ||
                other.totalCost == totalCost) &&
            (identical(other.category, category) ||
                other.category == category));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, name, quantityKg, costPerKg, totalCost, category);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedIngredientImplCopyWith<_$FeedIngredientImpl> get copyWith =>
      __$$FeedIngredientImplCopyWithImpl<_$FeedIngredientImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedIngredientImplToJson(this);
  }
}

abstract class _FeedIngredient implements FeedIngredient {
  const factory _FeedIngredient(
      {required final String name,
      @JsonKey(name: 'quantity_kg') required final double quantityKg,
      @JsonKey(name: 'cost_per_kg') required final double costPerKg,
      @JsonKey(name: 'total_cost') required final double totalCost,
      final String? category}) = _$FeedIngredientImpl;

  factory _FeedIngredient.fromJson(Map<String, dynamic> json) =
      _$FeedIngredientImpl.fromJson;

  @override
  String get name;
  @override
  @JsonKey(name: 'quantity_kg')
  double get quantityKg;
  @override
  @JsonKey(name: 'cost_per_kg')
  double get costPerKg;
  @override
  @JsonKey(name: 'total_cost')
  double get totalCost;
  @override
  String? get category;
  @override
  @JsonKey(ignore: true)
  _$$FeedIngredientImplCopyWith<_$FeedIngredientImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeedPlan _$FeedPlanFromJson(Map<String, dynamic> json) {
  return _FeedPlan.fromJson(json);
}

/// @nodoc
mixin _$FeedPlan {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_id')
  String get cattleId => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_name')
  String? get cattleName => throw _privateConstructorUsedError;
  List<FeedIngredient> get ingredients => throw _privateConstructorUsedError;
  @JsonKey(name: 'cost_per_day')
  double get costPerDay => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_dm_kg')
  double? get totalDmKg => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_cp_pct')
  double? get totalCpPct => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_ai_generated')
  bool get isAiGenerated => throw _privateConstructorUsedError;
  @JsonKey(name: 'savings_vs_current')
  double? get savingsVsCurrent => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  String? get notes => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FeedPlanCopyWith<FeedPlan> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedPlanCopyWith<$Res> {
  factory $FeedPlanCopyWith(FeedPlan value, $Res Function(FeedPlan) then) =
      _$FeedPlanCopyWithImpl<$Res, FeedPlan>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'cattle_name') String? cattleName,
      List<FeedIngredient> ingredients,
      @JsonKey(name: 'cost_per_day') double costPerDay,
      @JsonKey(name: 'total_dm_kg') double? totalDmKg,
      @JsonKey(name: 'total_cp_pct') double? totalCpPct,
      @JsonKey(name: 'is_ai_generated') bool isAiGenerated,
      @JsonKey(name: 'savings_vs_current') double? savingsVsCurrent,
      @JsonKey(name: 'created_at') String createdAt,
      String? notes});
}

/// @nodoc
class _$FeedPlanCopyWithImpl<$Res, $Val extends FeedPlan>
    implements $FeedPlanCopyWith<$Res> {
  _$FeedPlanCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cattleId = null,
    Object? cattleName = freezed,
    Object? ingredients = null,
    Object? costPerDay = null,
    Object? totalDmKg = freezed,
    Object? totalCpPct = freezed,
    Object? isAiGenerated = null,
    Object? savingsVsCurrent = freezed,
    Object? createdAt = null,
    Object? notes = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id ? _value.id : id as String,
      cattleId: null == cattleId ? _value.cattleId : cattleId as String,
      cattleName:
          freezed == cattleName ? _value.cattleName : cattleName as String?,
      ingredients: null == ingredients
          ? _value.ingredients
          : ingredients as List<FeedIngredient>,
      costPerDay:
          null == costPerDay ? _value.costPerDay : costPerDay as double,
      totalDmKg:
          freezed == totalDmKg ? _value.totalDmKg : totalDmKg as double?,
      totalCpPct:
          freezed == totalCpPct ? _value.totalCpPct : totalCpPct as double?,
      isAiGenerated: null == isAiGenerated
          ? _value.isAiGenerated
          : isAiGenerated as bool,
      savingsVsCurrent: freezed == savingsVsCurrent
          ? _value.savingsVsCurrent
          : savingsVsCurrent as double?,
      createdAt: null == createdAt ? _value.createdAt : createdAt as String,
      notes: freezed == notes ? _value.notes : notes as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FeedPlanImplCopyWith<$Res>
    implements $FeedPlanCopyWith<$Res> {
  factory _$$FeedPlanImplCopyWith(
          _$FeedPlanImpl value, $Res Function(_$FeedPlanImpl) then) =
      __$$FeedPlanImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'cattle_name') String? cattleName,
      List<FeedIngredient> ingredients,
      @JsonKey(name: 'cost_per_day') double costPerDay,
      @JsonKey(name: 'total_dm_kg') double? totalDmKg,
      @JsonKey(name: 'total_cp_pct') double? totalCpPct,
      @JsonKey(name: 'is_ai_generated') bool isAiGenerated,
      @JsonKey(name: 'savings_vs_current') double? savingsVsCurrent,
      @JsonKey(name: 'created_at') String createdAt,
      String? notes});
}

/// @nodoc
class __$$FeedPlanImplCopyWithImpl<$Res>
    extends _$FeedPlanCopyWithImpl<$Res, _$FeedPlanImpl>
    implements _$$FeedPlanImplCopyWith<$Res> {
  __$$FeedPlanImplCopyWithImpl(
      _$FeedPlanImpl _value, $Res Function(_$FeedPlanImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? cattleId = null,
    Object? cattleName = freezed,
    Object? ingredients = null,
    Object? costPerDay = null,
    Object? totalDmKg = freezed,
    Object? totalCpPct = freezed,
    Object? isAiGenerated = null,
    Object? savingsVsCurrent = freezed,
    Object? createdAt = null,
    Object? notes = freezed,
  }) {
    return _then(_$FeedPlanImpl(
      id: null == id ? _value.id : id as String,
      cattleId: null == cattleId ? _value.cattleId : cattleId as String,
      cattleName:
          freezed == cattleName ? _value.cattleName : cattleName as String?,
      ingredients: null == ingredients
          ? _value._ingredients
          : ingredients as List<FeedIngredient>,
      costPerDay:
          null == costPerDay ? _value.costPerDay : costPerDay as double,
      totalDmKg:
          freezed == totalDmKg ? _value.totalDmKg : totalDmKg as double?,
      totalCpPct:
          freezed == totalCpPct ? _value.totalCpPct : totalCpPct as double?,
      isAiGenerated: null == isAiGenerated
          ? _value.isAiGenerated
          : isAiGenerated as bool,
      savingsVsCurrent: freezed == savingsVsCurrent
          ? _value.savingsVsCurrent
          : savingsVsCurrent as double?,
      createdAt: null == createdAt ? _value.createdAt : createdAt as String,
      notes: freezed == notes ? _value.notes : notes as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedPlanImpl implements _FeedPlan {
  const _$FeedPlanImpl(
      {required this.id,
      @JsonKey(name: 'cattle_id') required this.cattleId,
      @JsonKey(name: 'cattle_name') this.cattleName,
      required final List<FeedIngredient> ingredients,
      @JsonKey(name: 'cost_per_day') required this.costPerDay,
      @JsonKey(name: 'total_dm_kg') this.totalDmKg,
      @JsonKey(name: 'total_cp_pct') this.totalCpPct,
      @JsonKey(name: 'is_ai_generated') this.isAiGenerated = false,
      @JsonKey(name: 'savings_vs_current') this.savingsVsCurrent,
      @JsonKey(name: 'created_at') required this.createdAt,
      this.notes})
      : _ingredients = ingredients;

  factory _$FeedPlanImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedPlanImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'cattle_id')
  final String cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  final String? cattleName;
  final List<FeedIngredient> _ingredients;
  @override
  List<FeedIngredient> get ingredients {
    if (_ingredients is EqualUnmodifiableListView) return _ingredients;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ingredients);
  }

  @override
  @JsonKey(name: 'cost_per_day')
  final double costPerDay;
  @override
  @JsonKey(name: 'total_dm_kg')
  final double? totalDmKg;
  @override
  @JsonKey(name: 'total_cp_pct')
  final double? totalCpPct;
  @override
  @JsonKey(name: 'is_ai_generated')
  final bool isAiGenerated;
  @override
  @JsonKey(name: 'savings_vs_current')
  final double? savingsVsCurrent;
  @override
  @JsonKey(name: 'created_at')
  final String createdAt;
  @override
  final String? notes;

  @override
  String toString() {
    return 'FeedPlan(id: $id, cattleId: $cattleId, cattleName: $cattleName, ingredients: $ingredients, costPerDay: $costPerDay, totalDmKg: $totalDmKg, totalCpPct: $totalCpPct, isAiGenerated: $isAiGenerated, savingsVsCurrent: $savingsVsCurrent, createdAt: $createdAt, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedPlanImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.cattleId, cattleId) ||
                other.cattleId == cattleId) &&
            (identical(other.cattleName, cattleName) ||
                other.cattleName == cattleName) &&
            const DeepCollectionEquality()
                .equals(other._ingredients, _ingredients) &&
            (identical(other.costPerDay, costPerDay) ||
                other.costPerDay == costPerDay) &&
            (identical(other.totalDmKg, totalDmKg) ||
                other.totalDmKg == totalDmKg) &&
            (identical(other.totalCpPct, totalCpPct) ||
                other.totalCpPct == totalCpPct) &&
            (identical(other.isAiGenerated, isAiGenerated) ||
                other.isAiGenerated == isAiGenerated) &&
            (identical(other.savingsVsCurrent, savingsVsCurrent) ||
                other.savingsVsCurrent == savingsVsCurrent) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      cattleId,
      cattleName,
      const DeepCollectionEquality().hash(_ingredients),
      costPerDay,
      totalDmKg,
      totalCpPct,
      isAiGenerated,
      savingsVsCurrent,
      createdAt,
      notes);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedPlanImplCopyWith<_$FeedPlanImpl> get copyWith =>
      __$$FeedPlanImplCopyWithImpl<_$FeedPlanImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedPlanImplToJson(this);
  }
}

abstract class _FeedPlan implements FeedPlan {
  const factory _FeedPlan(
      {required final String id,
      @JsonKey(name: 'cattle_id') required final String cattleId,
      @JsonKey(name: 'cattle_name') final String? cattleName,
      required final List<FeedIngredient> ingredients,
      @JsonKey(name: 'cost_per_day') required final double costPerDay,
      @JsonKey(name: 'total_dm_kg') final double? totalDmKg,
      @JsonKey(name: 'total_cp_pct') final double? totalCpPct,
      @JsonKey(name: 'is_ai_generated') final bool isAiGenerated,
      @JsonKey(name: 'savings_vs_current') final double? savingsVsCurrent,
      @JsonKey(name: 'created_at') required final String createdAt,
      final String? notes}) = _$FeedPlanImpl;

  factory _FeedPlan.fromJson(Map<String, dynamic> json) =
      _$FeedPlanImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'cattle_id')
  String get cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  String? get cattleName;
  @override
  List<FeedIngredient> get ingredients;
  @override
  @JsonKey(name: 'cost_per_day')
  double get costPerDay;
  @override
  @JsonKey(name: 'total_dm_kg')
  double? get totalDmKg;
  @override
  @JsonKey(name: 'total_cp_pct')
  double? get totalCpPct;
  @override
  @JsonKey(name: 'is_ai_generated')
  bool get isAiGenerated;
  @override
  @JsonKey(name: 'savings_vs_current')
  double? get savingsVsCurrent;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  String? get notes;
  @override
  @JsonKey(ignore: true)
  _$$FeedPlanImplCopyWith<_$FeedPlanImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CattleRef _$CattleRefFromJson(Map<String, dynamic> json) {
  return _CattleRef.fromJson(json);
}

/// @nodoc
mixin _$CattleRef {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'tag_id')
  String get tagId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get breed => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CattleRefCopyWith<CattleRef> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CattleRefCopyWith<$Res> {
  factory $CattleRefCopyWith(CattleRef value, $Res Function(CattleRef) then) =
      _$CattleRefCopyWithImpl<$Res, CattleRef>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tag_id') String tagId,
      String name,
      String breed});
}

/// @nodoc
class _$CattleRefCopyWithImpl<$Res, $Val extends CattleRef>
    implements $CattleRefCopyWith<$Res> {
  _$CattleRefCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tagId = null,
    Object? name = null,
    Object? breed = null,
  }) {
    return _then(_value.copyWith(
      id: null == id ? _value.id : id as String,
      tagId: null == tagId ? _value.tagId : tagId as String,
      name: null == name ? _value.name : name as String,
      breed: null == breed ? _value.breed : breed as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CattleRefImplCopyWith<$Res>
    implements $CattleRefCopyWith<$Res> {
  factory _$$CattleRefImplCopyWith(
          _$CattleRefImpl value, $Res Function(_$CattleRefImpl) then) =
      __$$CattleRefImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'tag_id') String tagId,
      String name,
      String breed});
}

/// @nodoc
class __$$CattleRefImplCopyWithImpl<$Res>
    extends _$CattleRefCopyWithImpl<$Res, _$CattleRefImpl>
    implements _$$CattleRefImplCopyWith<$Res> {
  __$$CattleRefImplCopyWithImpl(
      _$CattleRefImpl _value, $Res Function(_$CattleRefImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tagId = null,
    Object? name = null,
    Object? breed = null,
  }) {
    return _then(_$CattleRefImpl(
      id: null == id ? _value.id : id as String,
      tagId: null == tagId ? _value.tagId : tagId as String,
      name: null == name ? _value.name : name as String,
      breed: null == breed ? _value.breed : breed as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CattleRefImpl implements _CattleRef {
  const _$CattleRefImpl(
      {required this.id,
      @JsonKey(name: 'tag_id') required this.tagId,
      required this.name,
      required this.breed});

  factory _$CattleRefImpl.fromJson(Map<String, dynamic> json) =>
      _$$CattleRefImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'tag_id')
  final String tagId;
  @override
  final String name;
  @override
  final String breed;

  @override
  String toString() {
    return 'CattleRef(id: $id, tagId: $tagId, name: $name, breed: $breed)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CattleRefImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tagId, tagId) || other.tagId == tagId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.breed, breed) || other.breed == breed));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, id, tagId, name, breed);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$CattleRefImplCopyWith<_$CattleRefImpl> get copyWith =>
      __$$CattleRefImplCopyWithImpl<_$CattleRefImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CattleRefImplToJson(this);
  }
}

abstract class _CattleRef implements CattleRef {
  const factory _CattleRef(
      {required final String id,
      @JsonKey(name: 'tag_id') required final String tagId,
      required final String name,
      required final String breed}) = _$CattleRefImpl;

  factory _CattleRef.fromJson(Map<String, dynamic> json) =
      _$CattleRefImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'tag_id')
  String get tagId;
  @override
  String get name;
  @override
  String get breed;
  @override
  @JsonKey(ignore: true)
  _$$CattleRefImplCopyWith<_$CattleRefImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
