import 'package:freezed_annotation/freezed_annotation.dart';

part 'finance_models.freezed.dart';
part 'finance_models.g.dart';

enum TransactionType {
  @JsonValue('income')
  income,
  @JsonValue('expense')
  expense,
}

enum TransactionCategory {
  @JsonValue('milk_sales')
  milkSales,
  @JsonValue('feed_cost')
  feedCost,
  @JsonValue('vet_fees')
  vetFees,
  @JsonValue('medicine')
  medicine,
  @JsonValue('cattle_purchase')
  cattlePurchase,
  @JsonValue('cattle_sale')
  cattleSale,
  @JsonValue('equipment')
  equipment,
  @JsonValue('labour')
  labour,
  @JsonValue('other')
  other,
}

@freezed
class Transaction with _$Transaction {
  const Transaction._();

  const factory Transaction({
    required String id,
    @JsonKey(name: 'farmer_id') required String farmerId,
    required TransactionType type,
    required TransactionCategory category,
    required double amount,
    String? description,
    required String date,
    @JsonKey(name: 'cattle_id') String? cattleId,
    @JsonKey(name: 'cattle_name') String? cattleName,
    @JsonKey(name: 'created_at') String? createdAt,
  }) = _Transaction;

  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  String get categoryLabel {
    switch (category) {
      case TransactionCategory.milkSales:
        return 'Milk Sales';
      case TransactionCategory.feedCost:
        return 'Feed Cost';
      case TransactionCategory.vetFees:
        return 'Vet Fees';
      case TransactionCategory.medicine:
        return 'Medicine';
      case TransactionCategory.cattlePurchase:
        return 'Cattle Purchase';
      case TransactionCategory.cattleSale:
        return 'Cattle Sale';
      case TransactionCategory.equipment:
        return 'Equipment';
      case TransactionCategory.labour:
        return 'Labour';
      case TransactionCategory.other:
        return 'Other';
    }
  }
}

@freezed
class CategoryBreakdown with _$CategoryBreakdown {
  const factory CategoryBreakdown({
    required TransactionCategory category,
    required double amount,
    required double percentage,
  }) = _CategoryBreakdown;

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) =>
      _$CategoryBreakdownFromJson(json);
}

@freezed
class FinanceSummary with _$FinanceSummary {
  const FinanceSummary._();

  const factory FinanceSummary({
    @JsonKey(name: 'total_income') required double totalIncome,
    @JsonKey(name: 'total_expense') required double totalExpense,
    @JsonKey(name: 'net_profit') required double netProfit,
    required String month,
    @JsonKey(name: 'income_breakdown') @Default([]) List<CategoryBreakdown> incomeBreakdown,
    @JsonKey(name: 'expense_breakdown') @Default([]) List<CategoryBreakdown> expenseBreakdown,
  }) = _FinanceSummary;

  factory FinanceSummary.fromJson(Map<String, dynamic> json) =>
      _$FinanceSummaryFromJson(json);

  bool get isProfitable => netProfit >= 0;
}

@freezed
class AddTransactionRequest with _$AddTransactionRequest {
  const factory AddTransactionRequest({
    required String type,
    required String category,
    required double amount,
    String? description,
    required String date,
    @JsonKey(name: 'cattle_id') String? cattleId,
  }) = _AddTransactionRequest;

  factory AddTransactionRequest.fromJson(Map<String, dynamic> json) =>
      _$AddTransactionRequestFromJson(json);
}

@freezed
class MonthlyReport with _$MonthlyReport {
  const factory MonthlyReport({
    required String month,
    required double income,
    required double expense,
    required double profit,
  }) = _MonthlyReport;

  factory MonthlyReport.fromJson(Map<String, dynamic> json) =>
      _$MonthlyReportFromJson(json);
}

@freezed
class CattleCostAnalysis with _$CattleCostAnalysis {
  const factory CattleCostAnalysis({
    @JsonKey(name: 'cattle_id') required String cattleId,
    @JsonKey(name: 'cattle_name') required String cattleName,
    @JsonKey(name: 'total_income') required double totalIncome,
    @JsonKey(name: 'total_expense') required double totalExpense,
    @JsonKey(name: 'net_profit') required double netProfit,
  }) = _CattleCostAnalysis;

  factory CattleCostAnalysis.fromJson(Map<String, dynamic> json) =>
      _$CattleCostAnalysisFromJson(json);
}
