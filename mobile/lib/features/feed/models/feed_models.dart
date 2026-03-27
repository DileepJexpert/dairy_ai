import 'package:freezed_annotation/freezed_annotation.dart';

part 'feed_models.freezed.dart';
part 'feed_models.g.dart';

@freezed
class FeedIngredient with _$FeedIngredient {
  const factory FeedIngredient({
    required String name,
    @JsonKey(name: 'quantity_kg') required double quantityKg,
    @JsonKey(name: 'cost_per_kg') required double costPerKg,
    @JsonKey(name: 'total_cost') required double totalCost,
    String? category,
  }) = _FeedIngredient;

  factory FeedIngredient.fromJson(Map<String, dynamic> json) =>
      _$FeedIngredientFromJson(json);
}

@freezed
class FeedPlan with _$FeedPlan {
  const factory FeedPlan({
    required String id,
    @JsonKey(name: 'cattle_id') required String cattleId,
    @JsonKey(name: 'cattle_name') String? cattleName,
    required List<FeedIngredient> ingredients,
    @JsonKey(name: 'cost_per_day') required double costPerDay,
    @JsonKey(name: 'total_dm_kg') double? totalDmKg,
    @JsonKey(name: 'total_cp_pct') double? totalCpPct,
    @JsonKey(name: 'is_ai_generated') @Default(false) bool isAiGenerated,
    @JsonKey(name: 'savings_vs_current') double? savingsVsCurrent,
    @JsonKey(name: 'created_at') required String createdAt,
    String? notes,
  }) = _FeedPlan;

  factory FeedPlan.fromJson(Map<String, dynamic> json) =>
      _$FeedPlanFromJson(json);
}

/// Lightweight cattle reference used in cattle selection dropdowns.
@freezed
class CattleRef with _$CattleRef {
  const factory CattleRef({
    required String id,
    @JsonKey(name: 'tag_id') required String tagId,
    required String name,
    required String breed,
  }) = _CattleRef;

  factory CattleRef.fromJson(Map<String, dynamic> json) =>
      _$CattleRefFromJson(json);
}
