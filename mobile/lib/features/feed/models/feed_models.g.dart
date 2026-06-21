// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeedIngredientImpl _$$FeedIngredientImplFromJson(
        Map<String, dynamic> json) =>
    _$FeedIngredientImpl(
      name: json['name'] as String,
      quantityKg: (json['quantity_kg'] as num).toDouble(),
      costPerKg: (json['cost_per_kg'] as num).toDouble(),
      totalCost: (json['total_cost'] as num).toDouble(),
      category: json['category'] as String?,
    );

Map<String, dynamic> _$$FeedIngredientImplToJson(
        _$FeedIngredientImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'quantity_kg': instance.quantityKg,
      'cost_per_kg': instance.costPerKg,
      'total_cost': instance.totalCost,
      'category': instance.category,
    };

_$FeedPlanImpl _$$FeedPlanImplFromJson(Map<String, dynamic> json) =>
    _$FeedPlanImpl(
      id: json['id'] as String,
      cattleId: json['cattle_id'] as String,
      cattleName: json['cattle_name'] as String?,
      ingredients: (json['ingredients'] as List<dynamic>)
          .map((e) => FeedIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      costPerDay: (json['cost_per_day'] as num).toDouble(),
      totalDmKg: (json['total_dm_kg'] as num?)?.toDouble(),
      totalCpPct: (json['total_cp_pct'] as num?)?.toDouble(),
      isAiGenerated: json['is_ai_generated'] as bool? ?? false,
      savingsVsCurrent: (json['savings_vs_current'] as num?)?.toDouble(),
      createdAt: json['created_at'] as String,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$$FeedPlanImplToJson(_$FeedPlanImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'cattle_id': instance.cattleId,
      'cattle_name': instance.cattleName,
      'ingredients': instance.ingredients.map((e) => e.toJson()).toList(),
      'cost_per_day': instance.costPerDay,
      'total_dm_kg': instance.totalDmKg,
      'total_cp_pct': instance.totalCpPct,
      'is_ai_generated': instance.isAiGenerated,
      'savings_vs_current': instance.savingsVsCurrent,
      'created_at': instance.createdAt,
      'notes': instance.notes,
    };

_$CattleRefImpl _$$CattleRefImplFromJson(Map<String, dynamic> json) =>
    _$CattleRefImpl(
      id: json['id'] as String,
      tagId: json['tag_id'] as String,
      name: json['name'] as String,
      breed: json['breed'] as String,
    );

Map<String, dynamic> _$$CattleRefImplToJson(_$CattleRefImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tag_id': instance.tagId,
      'name': instance.name,
      'breed': instance.breed,
    };
