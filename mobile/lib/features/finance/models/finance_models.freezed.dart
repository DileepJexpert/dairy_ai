// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'finance_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Transaction _$TransactionFromJson(Map<String, dynamic> json) {
  return _Transaction.fromJson(json);
}

/// @nodoc
mixin _$Transaction {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'farmer_id')
  String get farmerId => throw _privateConstructorUsedError;
  TransactionType get type => throw _privateConstructorUsedError;
  TransactionCategory get category => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_id')
  String? get cattleId => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_name')
  String? get cattleName => throw _privateConstructorUsedError;
  @JsonKey(name: 'created_at')
  String? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Transaction to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TransactionCopyWith<Transaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TransactionCopyWith<$Res> {
  factory $TransactionCopyWith(
          Transaction value, $Res Function(Transaction) then) =
      _$TransactionCopyWithImpl<$Res, Transaction>;
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'farmer_id') String farmerId,
      TransactionType type,
      TransactionCategory category,
      double amount,
      String? description,
      String date,
      @JsonKey(name: 'cattle_id') String? cattleId,
      @JsonKey(name: 'cattle_name') String? cattleName,
      @JsonKey(name: 'created_at') String? createdAt});
}

/// @nodoc
class _$TransactionCopyWithImpl<$Res, $Val extends Transaction>
    implements $TransactionCopyWith<$Res> {
  _$TransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? farmerId = null,
    Object? type = null,
    Object? category = null,
    Object? amount = null,
    Object? description = freezed,
    Object? date = null,
    Object? cattleId = freezed,
    Object? cattleName = freezed,
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
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TransactionType,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as TransactionCategory,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      cattleId: freezed == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String?,
      cattleName: freezed == cattleName
          ? _value.cattleName
          : cattleName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TransactionImplCopyWith<$Res>
    implements $TransactionCopyWith<$Res> {
  factory _$$TransactionImplCopyWith(
          _$TransactionImpl value, $Res Function(_$TransactionImpl) then) =
      __$$TransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      @JsonKey(name: 'farmer_id') String farmerId,
      TransactionType type,
      TransactionCategory category,
      double amount,
      String? description,
      String date,
      @JsonKey(name: 'cattle_id') String? cattleId,
      @JsonKey(name: 'cattle_name') String? cattleName,
      @JsonKey(name: 'created_at') String? createdAt});
}

/// @nodoc
class __$$TransactionImplCopyWithImpl<$Res>
    extends _$TransactionCopyWithImpl<$Res, _$TransactionImpl>
    implements _$$TransactionImplCopyWith<$Res> {
  __$$TransactionImplCopyWithImpl(
      _$TransactionImpl _value, $Res Function(_$TransactionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? farmerId = null,
    Object? type = null,
    Object? category = null,
    Object? amount = null,
    Object? description = freezed,
    Object? date = null,
    Object? cattleId = freezed,
    Object? cattleName = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$TransactionImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      farmerId: null == farmerId
          ? _value.farmerId
          : farmerId // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as TransactionType,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as TransactionCategory,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      cattleId: freezed == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String?,
      cattleName: freezed == cattleName
          ? _value.cattleName
          : cattleName // ignore: cast_nullable_to_non_nullable
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
class _$TransactionImpl extends _Transaction {
  const _$TransactionImpl(
      {required this.id,
      @JsonKey(name: 'farmer_id') required this.farmerId,
      required this.type,
      required this.category,
      required this.amount,
      this.description,
      required this.date,
      @JsonKey(name: 'cattle_id') this.cattleId,
      @JsonKey(name: 'cattle_name') this.cattleName,
      @JsonKey(name: 'created_at') this.createdAt})
      : super._();

  factory _$TransactionImpl.fromJson(Map<String, dynamic> json) =>
      _$$TransactionImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'farmer_id')
  final String farmerId;
  @override
  final TransactionType type;
  @override
  final TransactionCategory category;
  @override
  final double amount;
  @override
  final String? description;
  @override
  final String date;
  @override
  @JsonKey(name: 'cattle_id')
  final String? cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  final String? cattleName;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;

  @override
  String toString() {
    return 'Transaction(id: $id, farmerId: $farmerId, type: $type, category: $category, amount: $amount, description: $description, date: $date, cattleId: $cattleId, cattleName: $cattleName, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.farmerId, farmerId) ||
                other.farmerId == farmerId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.cattleId, cattleId) ||
                other.cattleId == cattleId) &&
            (identical(other.cattleName, cattleName) ||
                other.cattleName == cattleName) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, farmerId, type, category,
      amount, description, date, cattleId, cattleName, createdAt);

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      __$$TransactionImplCopyWithImpl<_$TransactionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TransactionImplToJson(
      this,
    );
  }
}

abstract class _Transaction extends Transaction {
  const factory _Transaction(
          {required final String id,
          @JsonKey(name: 'farmer_id') required final String farmerId,
          required final TransactionType type,
          required final TransactionCategory category,
          required final double amount,
          final String? description,
          required final String date,
          @JsonKey(name: 'cattle_id') final String? cattleId,
          @JsonKey(name: 'cattle_name') final String? cattleName,
          @JsonKey(name: 'created_at') final String? createdAt}) =
      _$TransactionImpl;
  const _Transaction._() : super._();

  factory _Transaction.fromJson(Map<String, dynamic> json) =
      _$TransactionImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'farmer_id')
  String get farmerId;
  @override
  TransactionType get type;
  @override
  TransactionCategory get category;
  @override
  double get amount;
  @override
  String? get description;
  @override
  String get date;
  @override
  @JsonKey(name: 'cattle_id')
  String? get cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  String? get cattleName;
  @override
  @JsonKey(name: 'created_at')
  String? get createdAt;

  /// Create a copy of Transaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TransactionImplCopyWith<_$TransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CategoryBreakdown _$CategoryBreakdownFromJson(Map<String, dynamic> json) {
  return _CategoryBreakdown.fromJson(json);
}

/// @nodoc
mixin _$CategoryBreakdown {
  TransactionCategory get category => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  double get percentage => throw _privateConstructorUsedError;

  /// Serializes this CategoryBreakdown to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CategoryBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CategoryBreakdownCopyWith<CategoryBreakdown> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CategoryBreakdownCopyWith<$Res> {
  factory $CategoryBreakdownCopyWith(
          CategoryBreakdown value, $Res Function(CategoryBreakdown) then) =
      _$CategoryBreakdownCopyWithImpl<$Res, CategoryBreakdown>;
  @useResult
  $Res call({TransactionCategory category, double amount, double percentage});
}

/// @nodoc
class _$CategoryBreakdownCopyWithImpl<$Res, $Val extends CategoryBreakdown>
    implements $CategoryBreakdownCopyWith<$Res> {
  _$CategoryBreakdownCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CategoryBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? amount = null,
    Object? percentage = null,
  }) {
    return _then(_value.copyWith(
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as TransactionCategory,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      percentage: null == percentage
          ? _value.percentage
          : percentage // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CategoryBreakdownImplCopyWith<$Res>
    implements $CategoryBreakdownCopyWith<$Res> {
  factory _$$CategoryBreakdownImplCopyWith(_$CategoryBreakdownImpl value,
          $Res Function(_$CategoryBreakdownImpl) then) =
      __$$CategoryBreakdownImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({TransactionCategory category, double amount, double percentage});
}

/// @nodoc
class __$$CategoryBreakdownImplCopyWithImpl<$Res>
    extends _$CategoryBreakdownCopyWithImpl<$Res, _$CategoryBreakdownImpl>
    implements _$$CategoryBreakdownImplCopyWith<$Res> {
  __$$CategoryBreakdownImplCopyWithImpl(_$CategoryBreakdownImpl _value,
      $Res Function(_$CategoryBreakdownImpl) _then)
      : super(_value, _then);

  /// Create a copy of CategoryBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? amount = null,
    Object? percentage = null,
  }) {
    return _then(_$CategoryBreakdownImpl(
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as TransactionCategory,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      percentage: null == percentage
          ? _value.percentage
          : percentage // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CategoryBreakdownImpl implements _CategoryBreakdown {
  const _$CategoryBreakdownImpl(
      {required this.category, required this.amount, required this.percentage});

  factory _$CategoryBreakdownImpl.fromJson(Map<String, dynamic> json) =>
      _$$CategoryBreakdownImplFromJson(json);

  @override
  final TransactionCategory category;
  @override
  final double amount;
  @override
  final double percentage;

  @override
  String toString() {
    return 'CategoryBreakdown(category: $category, amount: $amount, percentage: $percentage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CategoryBreakdownImpl &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.percentage, percentage) ||
                other.percentage == percentage));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, category, amount, percentage);

  /// Create a copy of CategoryBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CategoryBreakdownImplCopyWith<_$CategoryBreakdownImpl> get copyWith =>
      __$$CategoryBreakdownImplCopyWithImpl<_$CategoryBreakdownImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CategoryBreakdownImplToJson(
      this,
    );
  }
}

abstract class _CategoryBreakdown implements CategoryBreakdown {
  const factory _CategoryBreakdown(
      {required final TransactionCategory category,
      required final double amount,
      required final double percentage}) = _$CategoryBreakdownImpl;

  factory _CategoryBreakdown.fromJson(Map<String, dynamic> json) =
      _$CategoryBreakdownImpl.fromJson;

  @override
  TransactionCategory get category;
  @override
  double get amount;
  @override
  double get percentage;

  /// Create a copy of CategoryBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CategoryBreakdownImplCopyWith<_$CategoryBreakdownImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FinanceSummary _$FinanceSummaryFromJson(Map<String, dynamic> json) {
  return _FinanceSummary.fromJson(json);
}

/// @nodoc
mixin _$FinanceSummary {
  @JsonKey(name: 'total_income')
  double get totalIncome => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_expense')
  double get totalExpense => throw _privateConstructorUsedError;
  @JsonKey(name: 'net_profit')
  double get netProfit => throw _privateConstructorUsedError;
  String get month => throw _privateConstructorUsedError;
  @JsonKey(name: 'income_breakdown')
  List<CategoryBreakdown> get incomeBreakdown =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'expense_breakdown')
  List<CategoryBreakdown> get expenseBreakdown =>
      throw _privateConstructorUsedError;

  /// Serializes this FinanceSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FinanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FinanceSummaryCopyWith<FinanceSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FinanceSummaryCopyWith<$Res> {
  factory $FinanceSummaryCopyWith(
          FinanceSummary value, $Res Function(FinanceSummary) then) =
      _$FinanceSummaryCopyWithImpl<$Res, FinanceSummary>;
  @useResult
  $Res call(
      {@JsonKey(name: 'total_income') double totalIncome,
      @JsonKey(name: 'total_expense') double totalExpense,
      @JsonKey(name: 'net_profit') double netProfit,
      String month,
      @JsonKey(name: 'income_breakdown')
      List<CategoryBreakdown> incomeBreakdown,
      @JsonKey(name: 'expense_breakdown')
      List<CategoryBreakdown> expenseBreakdown});
}

/// @nodoc
class _$FinanceSummaryCopyWithImpl<$Res, $Val extends FinanceSummary>
    implements $FinanceSummaryCopyWith<$Res> {
  _$FinanceSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FinanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalIncome = null,
    Object? totalExpense = null,
    Object? netProfit = null,
    Object? month = null,
    Object? incomeBreakdown = null,
    Object? expenseBreakdown = null,
  }) {
    return _then(_value.copyWith(
      totalIncome: null == totalIncome
          ? _value.totalIncome
          : totalIncome // ignore: cast_nullable_to_non_nullable
              as double,
      totalExpense: null == totalExpense
          ? _value.totalExpense
          : totalExpense // ignore: cast_nullable_to_non_nullable
              as double,
      netProfit: null == netProfit
          ? _value.netProfit
          : netProfit // ignore: cast_nullable_to_non_nullable
              as double,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      incomeBreakdown: null == incomeBreakdown
          ? _value.incomeBreakdown
          : incomeBreakdown // ignore: cast_nullable_to_non_nullable
              as List<CategoryBreakdown>,
      expenseBreakdown: null == expenseBreakdown
          ? _value.expenseBreakdown
          : expenseBreakdown // ignore: cast_nullable_to_non_nullable
              as List<CategoryBreakdown>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FinanceSummaryImplCopyWith<$Res>
    implements $FinanceSummaryCopyWith<$Res> {
  factory _$$FinanceSummaryImplCopyWith(_$FinanceSummaryImpl value,
          $Res Function(_$FinanceSummaryImpl) then) =
      __$$FinanceSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'total_income') double totalIncome,
      @JsonKey(name: 'total_expense') double totalExpense,
      @JsonKey(name: 'net_profit') double netProfit,
      String month,
      @JsonKey(name: 'income_breakdown')
      List<CategoryBreakdown> incomeBreakdown,
      @JsonKey(name: 'expense_breakdown')
      List<CategoryBreakdown> expenseBreakdown});
}

/// @nodoc
class __$$FinanceSummaryImplCopyWithImpl<$Res>
    extends _$FinanceSummaryCopyWithImpl<$Res, _$FinanceSummaryImpl>
    implements _$$FinanceSummaryImplCopyWith<$Res> {
  __$$FinanceSummaryImplCopyWithImpl(
      _$FinanceSummaryImpl _value, $Res Function(_$FinanceSummaryImpl) _then)
      : super(_value, _then);

  /// Create a copy of FinanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalIncome = null,
    Object? totalExpense = null,
    Object? netProfit = null,
    Object? month = null,
    Object? incomeBreakdown = null,
    Object? expenseBreakdown = null,
  }) {
    return _then(_$FinanceSummaryImpl(
      totalIncome: null == totalIncome
          ? _value.totalIncome
          : totalIncome // ignore: cast_nullable_to_non_nullable
              as double,
      totalExpense: null == totalExpense
          ? _value.totalExpense
          : totalExpense // ignore: cast_nullable_to_non_nullable
              as double,
      netProfit: null == netProfit
          ? _value.netProfit
          : netProfit // ignore: cast_nullable_to_non_nullable
              as double,
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      incomeBreakdown: null == incomeBreakdown
          ? _value._incomeBreakdown
          : incomeBreakdown // ignore: cast_nullable_to_non_nullable
              as List<CategoryBreakdown>,
      expenseBreakdown: null == expenseBreakdown
          ? _value._expenseBreakdown
          : expenseBreakdown // ignore: cast_nullable_to_non_nullable
              as List<CategoryBreakdown>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FinanceSummaryImpl extends _FinanceSummary {
  const _$FinanceSummaryImpl(
      {@JsonKey(name: 'total_income') required this.totalIncome,
      @JsonKey(name: 'total_expense') required this.totalExpense,
      @JsonKey(name: 'net_profit') required this.netProfit,
      required this.month,
      @JsonKey(name: 'income_breakdown')
      final List<CategoryBreakdown> incomeBreakdown = const [],
      @JsonKey(name: 'expense_breakdown')
      final List<CategoryBreakdown> expenseBreakdown = const []})
      : _incomeBreakdown = incomeBreakdown,
        _expenseBreakdown = expenseBreakdown,
        super._();

  factory _$FinanceSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$FinanceSummaryImplFromJson(json);

  @override
  @JsonKey(name: 'total_income')
  final double totalIncome;
  @override
  @JsonKey(name: 'total_expense')
  final double totalExpense;
  @override
  @JsonKey(name: 'net_profit')
  final double netProfit;
  @override
  final String month;
  final List<CategoryBreakdown> _incomeBreakdown;
  @override
  @JsonKey(name: 'income_breakdown')
  List<CategoryBreakdown> get incomeBreakdown {
    if (_incomeBreakdown is EqualUnmodifiableListView) return _incomeBreakdown;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_incomeBreakdown);
  }

  final List<CategoryBreakdown> _expenseBreakdown;
  @override
  @JsonKey(name: 'expense_breakdown')
  List<CategoryBreakdown> get expenseBreakdown {
    if (_expenseBreakdown is EqualUnmodifiableListView)
      return _expenseBreakdown;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_expenseBreakdown);
  }

  @override
  String toString() {
    return 'FinanceSummary(totalIncome: $totalIncome, totalExpense: $totalExpense, netProfit: $netProfit, month: $month, incomeBreakdown: $incomeBreakdown, expenseBreakdown: $expenseBreakdown)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FinanceSummaryImpl &&
            (identical(other.totalIncome, totalIncome) ||
                other.totalIncome == totalIncome) &&
            (identical(other.totalExpense, totalExpense) ||
                other.totalExpense == totalExpense) &&
            (identical(other.netProfit, netProfit) ||
                other.netProfit == netProfit) &&
            (identical(other.month, month) || other.month == month) &&
            const DeepCollectionEquality()
                .equals(other._incomeBreakdown, _incomeBreakdown) &&
            const DeepCollectionEquality()
                .equals(other._expenseBreakdown, _expenseBreakdown));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalIncome,
      totalExpense,
      netProfit,
      month,
      const DeepCollectionEquality().hash(_incomeBreakdown),
      const DeepCollectionEquality().hash(_expenseBreakdown));

  /// Create a copy of FinanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FinanceSummaryImplCopyWith<_$FinanceSummaryImpl> get copyWith =>
      __$$FinanceSummaryImplCopyWithImpl<_$FinanceSummaryImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FinanceSummaryImplToJson(
      this,
    );
  }
}

abstract class _FinanceSummary extends FinanceSummary {
  const factory _FinanceSummary(
      {@JsonKey(name: 'total_income') required final double totalIncome,
      @JsonKey(name: 'total_expense') required final double totalExpense,
      @JsonKey(name: 'net_profit') required final double netProfit,
      required final String month,
      @JsonKey(name: 'income_breakdown')
      final List<CategoryBreakdown> incomeBreakdown,
      @JsonKey(name: 'expense_breakdown')
      final List<CategoryBreakdown> expenseBreakdown}) = _$FinanceSummaryImpl;
  const _FinanceSummary._() : super._();

  factory _FinanceSummary.fromJson(Map<String, dynamic> json) =
      _$FinanceSummaryImpl.fromJson;

  @override
  @JsonKey(name: 'total_income')
  double get totalIncome;
  @override
  @JsonKey(name: 'total_expense')
  double get totalExpense;
  @override
  @JsonKey(name: 'net_profit')
  double get netProfit;
  @override
  String get month;
  @override
  @JsonKey(name: 'income_breakdown')
  List<CategoryBreakdown> get incomeBreakdown;
  @override
  @JsonKey(name: 'expense_breakdown')
  List<CategoryBreakdown> get expenseBreakdown;

  /// Create a copy of FinanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FinanceSummaryImplCopyWith<_$FinanceSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AddTransactionRequest _$AddTransactionRequestFromJson(
    Map<String, dynamic> json) {
  return _AddTransactionRequest.fromJson(json);
}

/// @nodoc
mixin _$AddTransactionRequest {
  String get type => throw _privateConstructorUsedError;
  String get category => throw _privateConstructorUsedError;
  double get amount => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get date => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_id')
  String? get cattleId => throw _privateConstructorUsedError;

  /// Serializes this AddTransactionRequest to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AddTransactionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AddTransactionRequestCopyWith<AddTransactionRequest> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AddTransactionRequestCopyWith<$Res> {
  factory $AddTransactionRequestCopyWith(AddTransactionRequest value,
          $Res Function(AddTransactionRequest) then) =
      _$AddTransactionRequestCopyWithImpl<$Res, AddTransactionRequest>;
  @useResult
  $Res call(
      {String type,
      String category,
      double amount,
      String? description,
      String date,
      @JsonKey(name: 'cattle_id') String? cattleId});
}

/// @nodoc
class _$AddTransactionRequestCopyWithImpl<$Res,
        $Val extends AddTransactionRequest>
    implements $AddTransactionRequestCopyWith<$Res> {
  _$AddTransactionRequestCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AddTransactionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? category = null,
    Object? amount = null,
    Object? description = freezed,
    Object? date = null,
    Object? cattleId = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      cattleId: freezed == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AddTransactionRequestImplCopyWith<$Res>
    implements $AddTransactionRequestCopyWith<$Res> {
  factory _$$AddTransactionRequestImplCopyWith(
          _$AddTransactionRequestImpl value,
          $Res Function(_$AddTransactionRequestImpl) then) =
      __$$AddTransactionRequestImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String type,
      String category,
      double amount,
      String? description,
      String date,
      @JsonKey(name: 'cattle_id') String? cattleId});
}

/// @nodoc
class __$$AddTransactionRequestImplCopyWithImpl<$Res>
    extends _$AddTransactionRequestCopyWithImpl<$Res,
        _$AddTransactionRequestImpl>
    implements _$$AddTransactionRequestImplCopyWith<$Res> {
  __$$AddTransactionRequestImplCopyWithImpl(_$AddTransactionRequestImpl _value,
      $Res Function(_$AddTransactionRequestImpl) _then)
      : super(_value, _then);

  /// Create a copy of AddTransactionRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? category = null,
    Object? amount = null,
    Object? description = freezed,
    Object? date = null,
    Object? cattleId = freezed,
  }) {
    return _then(_$AddTransactionRequestImpl(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      date: null == date
          ? _value.date
          : date // ignore: cast_nullable_to_non_nullable
              as String,
      cattleId: freezed == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AddTransactionRequestImpl implements _AddTransactionRequest {
  const _$AddTransactionRequestImpl(
      {required this.type,
      required this.category,
      required this.amount,
      this.description,
      required this.date,
      @JsonKey(name: 'cattle_id') this.cattleId});

  factory _$AddTransactionRequestImpl.fromJson(Map<String, dynamic> json) =>
      _$$AddTransactionRequestImplFromJson(json);

  @override
  final String type;
  @override
  final String category;
  @override
  final double amount;
  @override
  final String? description;
  @override
  final String date;
  @override
  @JsonKey(name: 'cattle_id')
  final String? cattleId;

  @override
  String toString() {
    return 'AddTransactionRequest(type: $type, category: $category, amount: $amount, description: $description, date: $date, cattleId: $cattleId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AddTransactionRequestImpl &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.cattleId, cattleId) ||
                other.cattleId == cattleId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, type, category, amount, description, date, cattleId);

  /// Create a copy of AddTransactionRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AddTransactionRequestImplCopyWith<_$AddTransactionRequestImpl>
      get copyWith => __$$AddTransactionRequestImplCopyWithImpl<
          _$AddTransactionRequestImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AddTransactionRequestImplToJson(
      this,
    );
  }
}

abstract class _AddTransactionRequest implements AddTransactionRequest {
  const factory _AddTransactionRequest(
          {required final String type,
          required final String category,
          required final double amount,
          final String? description,
          required final String date,
          @JsonKey(name: 'cattle_id') final String? cattleId}) =
      _$AddTransactionRequestImpl;

  factory _AddTransactionRequest.fromJson(Map<String, dynamic> json) =
      _$AddTransactionRequestImpl.fromJson;

  @override
  String get type;
  @override
  String get category;
  @override
  double get amount;
  @override
  String? get description;
  @override
  String get date;
  @override
  @JsonKey(name: 'cattle_id')
  String? get cattleId;

  /// Create a copy of AddTransactionRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AddTransactionRequestImplCopyWith<_$AddTransactionRequestImpl>
      get copyWith => throw _privateConstructorUsedError;
}

MonthlyReport _$MonthlyReportFromJson(Map<String, dynamic> json) {
  return _MonthlyReport.fromJson(json);
}

/// @nodoc
mixin _$MonthlyReport {
  String get month => throw _privateConstructorUsedError;
  double get income => throw _privateConstructorUsedError;
  double get expense => throw _privateConstructorUsedError;
  double get profit => throw _privateConstructorUsedError;

  /// Serializes this MonthlyReport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MonthlyReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MonthlyReportCopyWith<MonthlyReport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MonthlyReportCopyWith<$Res> {
  factory $MonthlyReportCopyWith(
          MonthlyReport value, $Res Function(MonthlyReport) then) =
      _$MonthlyReportCopyWithImpl<$Res, MonthlyReport>;
  @useResult
  $Res call({String month, double income, double expense, double profit});
}

/// @nodoc
class _$MonthlyReportCopyWithImpl<$Res, $Val extends MonthlyReport>
    implements $MonthlyReportCopyWith<$Res> {
  _$MonthlyReportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MonthlyReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? month = null,
    Object? income = null,
    Object? expense = null,
    Object? profit = null,
  }) {
    return _then(_value.copyWith(
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      income: null == income
          ? _value.income
          : income // ignore: cast_nullable_to_non_nullable
              as double,
      expense: null == expense
          ? _value.expense
          : expense // ignore: cast_nullable_to_non_nullable
              as double,
      profit: null == profit
          ? _value.profit
          : profit // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MonthlyReportImplCopyWith<$Res>
    implements $MonthlyReportCopyWith<$Res> {
  factory _$$MonthlyReportImplCopyWith(
          _$MonthlyReportImpl value, $Res Function(_$MonthlyReportImpl) then) =
      __$$MonthlyReportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String month, double income, double expense, double profit});
}

/// @nodoc
class __$$MonthlyReportImplCopyWithImpl<$Res>
    extends _$MonthlyReportCopyWithImpl<$Res, _$MonthlyReportImpl>
    implements _$$MonthlyReportImplCopyWith<$Res> {
  __$$MonthlyReportImplCopyWithImpl(
      _$MonthlyReportImpl _value, $Res Function(_$MonthlyReportImpl) _then)
      : super(_value, _then);

  /// Create a copy of MonthlyReport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? month = null,
    Object? income = null,
    Object? expense = null,
    Object? profit = null,
  }) {
    return _then(_$MonthlyReportImpl(
      month: null == month
          ? _value.month
          : month // ignore: cast_nullable_to_non_nullable
              as String,
      income: null == income
          ? _value.income
          : income // ignore: cast_nullable_to_non_nullable
              as double,
      expense: null == expense
          ? _value.expense
          : expense // ignore: cast_nullable_to_non_nullable
              as double,
      profit: null == profit
          ? _value.profit
          : profit // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MonthlyReportImpl implements _MonthlyReport {
  const _$MonthlyReportImpl(
      {required this.month,
      required this.income,
      required this.expense,
      required this.profit});

  factory _$MonthlyReportImpl.fromJson(Map<String, dynamic> json) =>
      _$$MonthlyReportImplFromJson(json);

  @override
  final String month;
  @override
  final double income;
  @override
  final double expense;
  @override
  final double profit;

  @override
  String toString() {
    return 'MonthlyReport(month: $month, income: $income, expense: $expense, profit: $profit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MonthlyReportImpl &&
            (identical(other.month, month) || other.month == month) &&
            (identical(other.income, income) || other.income == income) &&
            (identical(other.expense, expense) || other.expense == expense) &&
            (identical(other.profit, profit) || other.profit == profit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, month, income, expense, profit);

  /// Create a copy of MonthlyReport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MonthlyReportImplCopyWith<_$MonthlyReportImpl> get copyWith =>
      __$$MonthlyReportImplCopyWithImpl<_$MonthlyReportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MonthlyReportImplToJson(
      this,
    );
  }
}

abstract class _MonthlyReport implements MonthlyReport {
  const factory _MonthlyReport(
      {required final String month,
      required final double income,
      required final double expense,
      required final double profit}) = _$MonthlyReportImpl;

  factory _MonthlyReport.fromJson(Map<String, dynamic> json) =
      _$MonthlyReportImpl.fromJson;

  @override
  String get month;
  @override
  double get income;
  @override
  double get expense;
  @override
  double get profit;

  /// Create a copy of MonthlyReport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MonthlyReportImplCopyWith<_$MonthlyReportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CattleCostAnalysis _$CattleCostAnalysisFromJson(Map<String, dynamic> json) {
  return _CattleCostAnalysis.fromJson(json);
}

/// @nodoc
mixin _$CattleCostAnalysis {
  @JsonKey(name: 'cattle_id')
  String get cattleId => throw _privateConstructorUsedError;
  @JsonKey(name: 'cattle_name')
  String get cattleName => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_income')
  double get totalIncome => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_expense')
  double get totalExpense => throw _privateConstructorUsedError;
  @JsonKey(name: 'net_profit')
  double get netProfit => throw _privateConstructorUsedError;

  /// Serializes this CattleCostAnalysis to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CattleCostAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CattleCostAnalysisCopyWith<CattleCostAnalysis> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CattleCostAnalysisCopyWith<$Res> {
  factory $CattleCostAnalysisCopyWith(
          CattleCostAnalysis value, $Res Function(CattleCostAnalysis) then) =
      _$CattleCostAnalysisCopyWithImpl<$Res, CattleCostAnalysis>;
  @useResult
  $Res call(
      {@JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'cattle_name') String cattleName,
      @JsonKey(name: 'total_income') double totalIncome,
      @JsonKey(name: 'total_expense') double totalExpense,
      @JsonKey(name: 'net_profit') double netProfit});
}

/// @nodoc
class _$CattleCostAnalysisCopyWithImpl<$Res, $Val extends CattleCostAnalysis>
    implements $CattleCostAnalysisCopyWith<$Res> {
  _$CattleCostAnalysisCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CattleCostAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cattleId = null,
    Object? cattleName = null,
    Object? totalIncome = null,
    Object? totalExpense = null,
    Object? netProfit = null,
  }) {
    return _then(_value.copyWith(
      cattleId: null == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String,
      cattleName: null == cattleName
          ? _value.cattleName
          : cattleName // ignore: cast_nullable_to_non_nullable
              as String,
      totalIncome: null == totalIncome
          ? _value.totalIncome
          : totalIncome // ignore: cast_nullable_to_non_nullable
              as double,
      totalExpense: null == totalExpense
          ? _value.totalExpense
          : totalExpense // ignore: cast_nullable_to_non_nullable
              as double,
      netProfit: null == netProfit
          ? _value.netProfit
          : netProfit // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CattleCostAnalysisImplCopyWith<$Res>
    implements $CattleCostAnalysisCopyWith<$Res> {
  factory _$$CattleCostAnalysisImplCopyWith(_$CattleCostAnalysisImpl value,
          $Res Function(_$CattleCostAnalysisImpl) then) =
      __$$CattleCostAnalysisImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'cattle_id') String cattleId,
      @JsonKey(name: 'cattle_name') String cattleName,
      @JsonKey(name: 'total_income') double totalIncome,
      @JsonKey(name: 'total_expense') double totalExpense,
      @JsonKey(name: 'net_profit') double netProfit});
}

/// @nodoc
class __$$CattleCostAnalysisImplCopyWithImpl<$Res>
    extends _$CattleCostAnalysisCopyWithImpl<$Res, _$CattleCostAnalysisImpl>
    implements _$$CattleCostAnalysisImplCopyWith<$Res> {
  __$$CattleCostAnalysisImplCopyWithImpl(_$CattleCostAnalysisImpl _value,
      $Res Function(_$CattleCostAnalysisImpl) _then)
      : super(_value, _then);

  /// Create a copy of CattleCostAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cattleId = null,
    Object? cattleName = null,
    Object? totalIncome = null,
    Object? totalExpense = null,
    Object? netProfit = null,
  }) {
    return _then(_$CattleCostAnalysisImpl(
      cattleId: null == cattleId
          ? _value.cattleId
          : cattleId // ignore: cast_nullable_to_non_nullable
              as String,
      cattleName: null == cattleName
          ? _value.cattleName
          : cattleName // ignore: cast_nullable_to_non_nullable
              as String,
      totalIncome: null == totalIncome
          ? _value.totalIncome
          : totalIncome // ignore: cast_nullable_to_non_nullable
              as double,
      totalExpense: null == totalExpense
          ? _value.totalExpense
          : totalExpense // ignore: cast_nullable_to_non_nullable
              as double,
      netProfit: null == netProfit
          ? _value.netProfit
          : netProfit // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CattleCostAnalysisImpl implements _CattleCostAnalysis {
  const _$CattleCostAnalysisImpl(
      {@JsonKey(name: 'cattle_id') required this.cattleId,
      @JsonKey(name: 'cattle_name') required this.cattleName,
      @JsonKey(name: 'total_income') required this.totalIncome,
      @JsonKey(name: 'total_expense') required this.totalExpense,
      @JsonKey(name: 'net_profit') required this.netProfit});

  factory _$CattleCostAnalysisImpl.fromJson(Map<String, dynamic> json) =>
      _$$CattleCostAnalysisImplFromJson(json);

  @override
  @JsonKey(name: 'cattle_id')
  final String cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  final String cattleName;
  @override
  @JsonKey(name: 'total_income')
  final double totalIncome;
  @override
  @JsonKey(name: 'total_expense')
  final double totalExpense;
  @override
  @JsonKey(name: 'net_profit')
  final double netProfit;

  @override
  String toString() {
    return 'CattleCostAnalysis(cattleId: $cattleId, cattleName: $cattleName, totalIncome: $totalIncome, totalExpense: $totalExpense, netProfit: $netProfit)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CattleCostAnalysisImpl &&
            (identical(other.cattleId, cattleId) ||
                other.cattleId == cattleId) &&
            (identical(other.cattleName, cattleName) ||
                other.cattleName == cattleName) &&
            (identical(other.totalIncome, totalIncome) ||
                other.totalIncome == totalIncome) &&
            (identical(other.totalExpense, totalExpense) ||
                other.totalExpense == totalExpense) &&
            (identical(other.netProfit, netProfit) ||
                other.netProfit == netProfit));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, cattleId, cattleName, totalIncome, totalExpense, netProfit);

  /// Create a copy of CattleCostAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CattleCostAnalysisImplCopyWith<_$CattleCostAnalysisImpl> get copyWith =>
      __$$CattleCostAnalysisImplCopyWithImpl<_$CattleCostAnalysisImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CattleCostAnalysisImplToJson(
      this,
    );
  }
}

abstract class _CattleCostAnalysis implements CattleCostAnalysis {
  const factory _CattleCostAnalysis(
          {@JsonKey(name: 'cattle_id') required final String cattleId,
          @JsonKey(name: 'cattle_name') required final String cattleName,
          @JsonKey(name: 'total_income') required final double totalIncome,
          @JsonKey(name: 'total_expense') required final double totalExpense,
          @JsonKey(name: 'net_profit') required final double netProfit}) =
      _$CattleCostAnalysisImpl;

  factory _CattleCostAnalysis.fromJson(Map<String, dynamic> json) =
      _$CattleCostAnalysisImpl.fromJson;

  @override
  @JsonKey(name: 'cattle_id')
  String get cattleId;
  @override
  @JsonKey(name: 'cattle_name')
  String get cattleName;
  @override
  @JsonKey(name: 'total_income')
  double get totalIncome;
  @override
  @JsonKey(name: 'total_expense')
  double get totalExpense;
  @override
  @JsonKey(name: 'net_profit')
  double get netProfit;

  /// Create a copy of CattleCostAnalysis
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CattleCostAnalysisImplCopyWith<_$CattleCostAnalysisImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
