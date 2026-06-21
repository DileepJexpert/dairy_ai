// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DashboardStats _$DashboardStatsFromJson(Map<String, dynamic> json) {
  return _DashboardStats.fromJson(json);
}

/// @nodoc
mixin _$DashboardStats {
  @JsonKey(name: 'farmer_name')
  String get farmerName => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_cattle')
  int get totalCattle => throw _privateConstructorUsedError;
  @JsonKey(name: 'active_cattle')
  int get activeCattle => throw _privateConstructorUsedError;
  @JsonKey(name: 'today_milk_litres')
  double get todayMilkLitres => throw _privateConstructorUsedError;
  @JsonKey(name: 'pending_health_alerts')
  int get pendingHealthAlerts => throw _privateConstructorUsedError;
  @JsonKey(name: 'upcoming_vaccinations')
  int get upcomingVaccinations => throw _privateConstructorUsedError;
  @JsonKey(name: 'recent_activities')
  List<RecentActivity> get recentActivities =>
      throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $DashboardStatsCopyWith<DashboardStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DashboardStatsCopyWith<$Res> {
  factory $DashboardStatsCopyWith(
          DashboardStats value, $Res Function(DashboardStats) then) =
      _$DashboardStatsCopyWithImpl<$Res, DashboardStats>;
  @useResult
  $Res call(
      {@JsonKey(name: 'farmer_name') String farmerName,
      @JsonKey(name: 'total_cattle') int totalCattle,
      @JsonKey(name: 'active_cattle') int activeCattle,
      @JsonKey(name: 'today_milk_litres') double todayMilkLitres,
      @JsonKey(name: 'pending_health_alerts') int pendingHealthAlerts,
      @JsonKey(name: 'upcoming_vaccinations') int upcomingVaccinations,
      @JsonKey(name: 'recent_activities')
      List<RecentActivity> recentActivities});
}

/// @nodoc
class _$DashboardStatsCopyWithImpl<$Res, $Val extends DashboardStats>
    implements $DashboardStatsCopyWith<$Res> {
  _$DashboardStatsCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? farmerName = null,
    Object? totalCattle = null,
    Object? activeCattle = null,
    Object? todayMilkLitres = null,
    Object? pendingHealthAlerts = null,
    Object? upcomingVaccinations = null,
    Object? recentActivities = null,
  }) {
    return _then(_value.copyWith(
      farmerName:
          null == farmerName ? _value.farmerName : farmerName as String,
      totalCattle:
          null == totalCattle ? _value.totalCattle : totalCattle as int,
      activeCattle:
          null == activeCattle ? _value.activeCattle : activeCattle as int,
      todayMilkLitres: null == todayMilkLitres
          ? _value.todayMilkLitres
          : todayMilkLitres as double,
      pendingHealthAlerts: null == pendingHealthAlerts
          ? _value.pendingHealthAlerts
          : pendingHealthAlerts as int,
      upcomingVaccinations: null == upcomingVaccinations
          ? _value.upcomingVaccinations
          : upcomingVaccinations as int,
      recentActivities: null == recentActivities
          ? _value.recentActivities
          : recentActivities as List<RecentActivity>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DashboardStatsImplCopyWith<$Res>
    implements $DashboardStatsCopyWith<$Res> {
  factory _$$DashboardStatsImplCopyWith(_$DashboardStatsImpl value,
          $Res Function(_$DashboardStatsImpl) then) =
      __$$DashboardStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'farmer_name') String farmerName,
      @JsonKey(name: 'total_cattle') int totalCattle,
      @JsonKey(name: 'active_cattle') int activeCattle,
      @JsonKey(name: 'today_milk_litres') double todayMilkLitres,
      @JsonKey(name: 'pending_health_alerts') int pendingHealthAlerts,
      @JsonKey(name: 'upcoming_vaccinations') int upcomingVaccinations,
      @JsonKey(name: 'recent_activities')
      List<RecentActivity> recentActivities});
}

/// @nodoc
class __$$DashboardStatsImplCopyWithImpl<$Res>
    extends _$DashboardStatsCopyWithImpl<$Res, _$DashboardStatsImpl>
    implements _$$DashboardStatsImplCopyWith<$Res> {
  __$$DashboardStatsImplCopyWithImpl(
      _$DashboardStatsImpl _value, $Res Function(_$DashboardStatsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? farmerName = null,
    Object? totalCattle = null,
    Object? activeCattle = null,
    Object? todayMilkLitres = null,
    Object? pendingHealthAlerts = null,
    Object? upcomingVaccinations = null,
    Object? recentActivities = null,
  }) {
    return _then(_$DashboardStatsImpl(
      farmerName:
          null == farmerName ? _value.farmerName : farmerName as String,
      totalCattle:
          null == totalCattle ? _value.totalCattle : totalCattle as int,
      activeCattle:
          null == activeCattle ? _value.activeCattle : activeCattle as int,
      todayMilkLitres: null == todayMilkLitres
          ? _value.todayMilkLitres
          : todayMilkLitres as double,
      pendingHealthAlerts: null == pendingHealthAlerts
          ? _value.pendingHealthAlerts
          : pendingHealthAlerts as int,
      upcomingVaccinations: null == upcomingVaccinations
          ? _value.upcomingVaccinations
          : upcomingVaccinations as int,
      recentActivities: null == recentActivities
          ? _value._recentActivities
          : recentActivities as List<RecentActivity>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DashboardStatsImpl implements _DashboardStats {
  const _$DashboardStatsImpl(
      {@JsonKey(name: 'farmer_name') required this.farmerName,
      @JsonKey(name: 'total_cattle') required this.totalCattle,
      @JsonKey(name: 'active_cattle') required this.activeCattle,
      @JsonKey(name: 'today_milk_litres') required this.todayMilkLitres,
      @JsonKey(name: 'pending_health_alerts') required this.pendingHealthAlerts,
      @JsonKey(name: 'upcoming_vaccinations')
      required this.upcomingVaccinations,
      @JsonKey(name: 'recent_activities')
      final List<RecentActivity> recentActivities = const []})
      : _recentActivities = recentActivities;

  factory _$DashboardStatsImpl.fromJson(Map<String, dynamic> json) =>
      _$$DashboardStatsImplFromJson(json);

  @override
  @JsonKey(name: 'farmer_name')
  final String farmerName;
  @override
  @JsonKey(name: 'total_cattle')
  final int totalCattle;
  @override
  @JsonKey(name: 'active_cattle')
  final int activeCattle;
  @override
  @JsonKey(name: 'today_milk_litres')
  final double todayMilkLitres;
  @override
  @JsonKey(name: 'pending_health_alerts')
  final int pendingHealthAlerts;
  @override
  @JsonKey(name: 'upcoming_vaccinations')
  final int upcomingVaccinations;
  final List<RecentActivity> _recentActivities;
  @override
  @JsonKey(name: 'recent_activities')
  List<RecentActivity> get recentActivities {
    if (_recentActivities is EqualUnmodifiableListView)
      return _recentActivities;
    return EqualUnmodifiableListView(_recentActivities);
  }

  @override
  String toString() {
    return 'DashboardStats(farmerName: $farmerName, totalCattle: $totalCattle, activeCattle: $activeCattle, todayMilkLitres: $todayMilkLitres, pendingHealthAlerts: $pendingHealthAlerts, upcomingVaccinations: $upcomingVaccinations, recentActivities: $recentActivities)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DashboardStatsImpl &&
            (identical(other.farmerName, farmerName) ||
                other.farmerName == farmerName) &&
            (identical(other.totalCattle, totalCattle) ||
                other.totalCattle == totalCattle) &&
            (identical(other.activeCattle, activeCattle) ||
                other.activeCattle == activeCattle) &&
            (identical(other.todayMilkLitres, todayMilkLitres) ||
                other.todayMilkLitres == todayMilkLitres) &&
            (identical(other.pendingHealthAlerts, pendingHealthAlerts) ||
                other.pendingHealthAlerts == pendingHealthAlerts) &&
            (identical(other.upcomingVaccinations, upcomingVaccinations) ||
                other.upcomingVaccinations == upcomingVaccinations) &&
            const DeepCollectionEquality()
                .equals(other._recentActivities, _recentActivities));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      farmerName,
      totalCattle,
      activeCattle,
      todayMilkLitres,
      pendingHealthAlerts,
      upcomingVaccinations,
      const DeepCollectionEquality().hash(_recentActivities));

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$DashboardStatsImplCopyWith<_$DashboardStatsImpl> get copyWith =>
      __$$DashboardStatsImplCopyWithImpl<_$DashboardStatsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DashboardStatsImplToJson(this);
  }
}

abstract class _DashboardStats implements DashboardStats {
  const factory _DashboardStats(
      {@JsonKey(name: 'farmer_name') required final String farmerName,
      @JsonKey(name: 'total_cattle') required final int totalCattle,
      @JsonKey(name: 'active_cattle') required final int activeCattle,
      @JsonKey(name: 'today_milk_litres') required final double todayMilkLitres,
      @JsonKey(name: 'pending_health_alerts')
      required final int pendingHealthAlerts,
      @JsonKey(name: 'upcoming_vaccinations')
      required final int upcomingVaccinations,
      @JsonKey(name: 'recent_activities')
      final List<RecentActivity> recentActivities}) = _$DashboardStatsImpl;

  factory _DashboardStats.fromJson(Map<String, dynamic> json) =
      _$DashboardStatsImpl.fromJson;

  @override
  @JsonKey(name: 'farmer_name')
  String get farmerName;
  @override
  @JsonKey(name: 'total_cattle')
  int get totalCattle;
  @override
  @JsonKey(name: 'active_cattle')
  int get activeCattle;
  @override
  @JsonKey(name: 'today_milk_litres')
  double get todayMilkLitres;
  @override
  @JsonKey(name: 'pending_health_alerts')
  int get pendingHealthAlerts;
  @override
  @JsonKey(name: 'upcoming_vaccinations')
  int get upcomingVaccinations;
  @override
  @JsonKey(name: 'recent_activities')
  List<RecentActivity> get recentActivities;
  @override
  @JsonKey(ignore: true)
  _$$DashboardStatsImplCopyWith<_$DashboardStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RecentActivity _$RecentActivityFromJson(Map<String, dynamic> json) {
  return _RecentActivity.fromJson(json);
}

/// @nodoc
mixin _$RecentActivity {
  String get id => throw _privateConstructorUsedError;
  String get type => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String get createdAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_name')
  String? get cattleName => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_tag')
  String? get cattleTag => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $RecentActivityCopyWith<RecentActivity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RecentActivityCopyWith<$Res> {
  factory $RecentActivityCopyWith(
          RecentActivity value, $Res Function(RecentActivity) then) =
      _$RecentActivityCopyWithImpl<$Res, RecentActivity>;
  @useResult
  $Res call(
      {String id,
      String type,
      String title,
      String description,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'cattle_name') String? cattleName,
      @JsonKey(name: 'cattle_tag') String? cattleTag});
}

/// @nodoc
class _$RecentActivityCopyWithImpl<$Res, $Val extends RecentActivity>
    implements $RecentActivityCopyWith<$Res> {
  _$RecentActivityCopyWithImpl(this._value, this._then);

  final $Val _value;
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? description = null,
    Object? createdAt = null,
    Object? cattleName = freezed,
    Object? cattleTag = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id ? _value.id : id as String,
      type: null == type ? _value.type : type as String,
      title: null == title ? _value.title : title as String,
      description:
          null == description ? _value.description : description as String,
      createdAt: null == createdAt ? _value.createdAt : createdAt as String,
      cattleName:
          freezed == cattleName ? _value.cattleName : cattleName as String?,
      cattleTag:
          freezed == cattleTag ? _value.cattleTag : cattleTag as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RecentActivityImplCopyWith<$Res>
    implements $RecentActivityCopyWith<$Res> {
  factory _$$RecentActivityImplCopyWith(_$RecentActivityImpl value,
          $Res Function(_$RecentActivityImpl) then) =
      __$$RecentActivityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String type,
      String title,
      String description,
      @JsonKey(name: 'created_at') String createdAt,
      @JsonKey(name: 'cattle_name') String? cattleName,
      @JsonKey(name: 'cattle_tag') String? cattleTag});
}

/// @nodoc
class __$$RecentActivityImplCopyWithImpl<$Res>
    extends _$RecentActivityCopyWithImpl<$Res, _$RecentActivityImpl>
    implements _$$RecentActivityImplCopyWith<$Res> {
  __$$RecentActivityImplCopyWithImpl(
      _$RecentActivityImpl _value, $Res Function(_$RecentActivityImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? description = null,
    Object? createdAt = null,
    Object? cattleName = freezed,
    Object? cattleTag = freezed,
  }) {
    return _then(_$RecentActivityImpl(
      id: null == id ? _value.id : id as String,
      type: null == type ? _value.type : type as String,
      title: null == title ? _value.title : title as String,
      description:
          null == description ? _value.description : description as String,
      createdAt: null == createdAt ? _value.createdAt : createdAt as String,
      cattleName:
          freezed == cattleName ? _value.cattleName : cattleName as String?,
      cattleTag:
          freezed == cattleTag ? _value.cattleTag : cattleTag as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$RecentActivityImpl implements _RecentActivity {
  const _$RecentActivityImpl(
      {required this.id,
      required this.type,
      required this.title,
      required this.description,
      @JsonKey(name: 'created_at') required this.createdAt,
      @JsonKey(name: 'cattle_name') this.cattleName,
      @JsonKey(name: 'cattle_tag') this.cattleTag});

  factory _$RecentActivityImpl.fromJson(Map<String, dynamic> json) =>
      _$$RecentActivityImplFromJson(json);

  @override
  final String id;
  @override
  final String type;
  @override
  final String title;
  @override
  final String description;
  @override
  @JsonKey(name: 'created_at')
  final String createdAt;
  @override
  @JsonKey(name: 'cattle_name')
  final String? cattleName;
  @override
  @JsonKey(name: 'cattle_tag')
  final String? cattleTag;

  @override
  String toString() {
    return 'RecentActivity(id: $id, type: $type, title: $title, description: $description, createdAt: $createdAt, cattleName: $cattleName, cattleTag: $cattleTag)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RecentActivityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.cattleName, cattleName) ||
                other.cattleName == cattleName) &&
            (identical(other.cattleTag, cattleTag) ||
                other.cattleTag == cattleTag));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType, id, type, title, description, createdAt, cattleName, cattleTag);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$RecentActivityImplCopyWith<_$RecentActivityImpl> get copyWith =>
      __$$RecentActivityImplCopyWithImpl<_$RecentActivityImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$RecentActivityImplToJson(this);
  }
}

abstract class _RecentActivity implements RecentActivity {
  const factory _RecentActivity(
      {required final String id,
      required final String type,
      required final String title,
      required final String description,
      @JsonKey(name: 'created_at') required final String createdAt,
      @JsonKey(name: 'cattle_name') final String? cattleName,
      @JsonKey(name: 'cattle_tag') final String? cattleTag}) = _$RecentActivityImpl;

  factory _RecentActivity.fromJson(Map<String, dynamic> json) =
      _$RecentActivityImpl.fromJson;

  @override
  String get id;
  @override
  String get type;
  @override
  String get title;
  @override
  String get description;
  @override
  @JsonKey(name: 'created_at')
  String get createdAt;
  @override
  @JsonKey(name: 'cattle_name')
  String? get cattleName;
  @override
  @JsonKey(name: 'cattle_tag')
  String? get cattleTag;
  @override
  @JsonKey(ignore: true)
  _$$RecentActivityImplCopyWith<_$RecentActivityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
