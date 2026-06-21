// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'finance_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

const _$TransactionTypeEnumMap = {
  TransactionType.income: 'income',
  TransactionType.expense: 'expense',
};

const _$TransactionCategoryEnumMap = {
  TransactionCategory.milkSales: 'milk_sales',
  TransactionCategory.feedCost: 'feed_cost',
  TransactionCategory.vetFees: 'vet_fees',
  TransactionCategory.medicine: 'medicine',
  TransactionCategory.cattlePurchase: 'cattle_purchase',
  TransactionCategory.cattleSale: 'cattle_sale',
  TransactionCategory.equipment: 'equipment',
  TransactionCategory.labour: 'labour',
  TransactionCategory.other: 'other',
};

_$TransactionImpl _$$TransactionImplFromJson(Map<String, dynamic> json) =>
    _$TransactionImpl(
      id: json['id'] as String,
      farmerId: json['farmer_id'] as String,
      type: $enumDecode(_$TransactionTypeEnumMap, json['type']),
      category: $enumDecode(_$TransactionCategoryEnumMap, json['category']),
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      date: json['date'] as String,
      cattleId: json['cattle_id'] as String?,
      cattleName: json['cattle_name'] as String?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$$TransactionImplToJson(_$TransactionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'farmer_id': instance.farmerId,
      'type': _$TransactionTypeEnumMap[instance.type]!,
      'category': _$TransactionCategoryEnumMap[instance.category]!,
      'amount': instance.amount,
      'description': instance.description,
      'date': instance.date,
      'cattle_id': instance.cattleId,
      'cattle_name': instance.cattleName,
      'created_at': instance.createdAt,
    };

_$CategoryBreakdownImpl _$$CategoryBreakdownImplFromJson(
        Map<String, dynamic> json) =>
    _$CategoryBreakdownImpl(
      category: $enumDecode(_$TransactionCategoryEnumMap, json['category']),
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );

Map<String, dynamic> _$$CategoryBreakdownImplToJson(
        _$CategoryBreakdownImpl instance) =>
    <String, dynamic>{
      'category': _$TransactionCategoryEnumMap[instance.category]!,
      'amount': instance.amount,
      'percentage': instance.percentage,
    };

_$FinanceSummaryImpl _$$FinanceSummaryImplFromJson(
        Map<String, dynamic> json) =>
    _$FinanceSummaryImpl(
      totalIncome: (json['total_income'] as num).toDouble(),
      totalExpense: (json['total_expense'] as num).toDouble(),
      netProfit: (json['net_profit'] as num).toDouble(),
      month: json['month'] as String,
      incomeBreakdown: (json['income_breakdown'] as List<dynamic>?)
              ?.map((e) =>
                  CategoryBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      expenseBreakdown: (json['expense_breakdown'] as List<dynamic>?)
              ?.map((e) =>
                  CategoryBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$FinanceSummaryImplToJson(
        _$FinanceSummaryImpl instance) =>
    <String, dynamic>{
      'total_income': instance.totalIncome,
      'total_expense': instance.totalExpense,
      'net_profit': instance.netProfit,
      'month': instance.month,
      'income_breakdown':
          instance.incomeBreakdown.map((e) => e.toJson()).toList(),
      'expense_breakdown':
          instance.expenseBreakdown.map((e) => e.toJson()).toList(),
    };

_$AddTransactionRequestImpl _$$AddTransactionRequestImplFromJson(
        Map<String, dynamic> json) =>
    _$AddTransactionRequestImpl(
      type: json['type'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      date: json['date'] as String,
      cattleId: json['cattle_id'] as String?,
    );

Map<String, dynamic> _$$AddTransactionRequestImplToJson(
        _$AddTransactionRequestImpl instance) =>
    <String, dynamic>{
      'type': instance.type,
      'category': instance.category,
      'amount': instance.amount,
      'description': instance.description,
      'date': instance.date,
      'cattle_id': instance.cattleId,
    };

_$MonthlyReportImpl _$$MonthlyReportImplFromJson(
        Map<String, dynamic> json) =>
    _$MonthlyReportImpl(
      month: json['month'] as String,
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
      profit: (json['profit'] as num).toDouble(),
    );

Map<String, dynamic> _$$MonthlyReportImplToJson(
        _$MonthlyReportImpl instance) =>
    <String, dynamic>{
      'month': instance.month,
      'income': instance.income,
      'expense': instance.expense,
      'profit': instance.profit,
    };

_$CattleCostAnalysisImpl _$$CattleCostAnalysisImplFromJson(
        Map<String, dynamic> json) =>
    _$CattleCostAnalysisImpl(
      cattleId: json['cattle_id'] as String,
      cattleName: json['cattle_name'] as String,
      totalIncome: (json['total_income'] as num).toDouble(),
      totalExpense: (json['total_expense'] as num).toDouble(),
      netProfit: (json['net_profit'] as num).toDouble(),
    );

Map<String, dynamic> _$$CattleCostAnalysisImplToJson(
        _$CattleCostAnalysisImpl instance) =>
    <String, dynamic>{
      'cattle_id': instance.cattleId,
      'cattle_name': instance.cattleName,
      'total_income': instance.totalIncome,
      'total_expense': instance.totalExpense,
      'net_profit': instance.netProfit,
    };
