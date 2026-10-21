// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// 1. Thermal Slip Model
// ---------------------------------------------------------------------------
@immutable
class ThermalSlipData {
  final String slipId;
  final String date;
  final String shift;
  final String farmerName;
  final double quantityLitres;
  final double fatPct;
  final double snfPct;
  final double ratePerLitre;
  final double totalAmount;
  final String formattedText;
  final String escposHex;
  final String barcode;

  const ThermalSlipData({
    required this.slipId,
    required this.date,
    required this.shift,
    required this.farmerName,
    required this.quantityLitres,
    required this.fatPct,
    required this.snfPct,
    required this.ratePerLitre,
    required this.totalAmount,
    required this.formattedText,
    required this.escposHex,
    required this.barcode,
  });

  factory ThermalSlipData.fromJson(Map<String, dynamic> json) {
    return ThermalSlipData(
      slipId: json['slip_id'] as String? ?? 'SLIP-001',
      date: json['date'] as String? ?? '',
      shift: json['shift'] as String? ?? 'MORNING',
      farmerName: json['farmer_name'] as String? ?? 'किसान',
      quantityLitres: (json['quantity_litres'] as num?)?.toDouble() ?? 0.0,
      fatPct: (json['fat_pct'] as num?)?.toDouble() ?? 0.0,
      snfPct: (json['snf_pct'] as num?)?.toDouble() ?? 0.0,
      ratePerLitre: (json['rate_per_litre'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      formattedText: json['formatted_text'] as String? ?? '',
      escposHex: json['escpos_hex'] as String? ?? '',
      barcode: json['barcode_code128'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Smart Heat (Estrus) Detection Alert Model
// ---------------------------------------------------------------------------
@immutable
class SireRecommendation {
  final String sireId;
  final String name;
  final String organization;
  final String semenType;
  final double fatPotentialPct;
  final double strawPriceInr;
  final bool inStock;

  const SireRecommendation({
    required this.sireId,
    required this.name,
    required this.organization,
    required this.semenType,
    required this.fatPotentialPct,
    required this.strawPriceInr,
    required this.inStock,
  });

  factory SireRecommendation.fromJson(Map<String, dynamic> json) {
    return SireRecommendation(
      sireId: json['sire_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      semenType: json['semen_type'] as String? ?? 'Conventional',
      fatPotentialPct: (json['fat_potential_pct'] as num?)?.toDouble() ?? 5.0,
      strawPriceInr: (json['straw_price_inr'] as num?)?.toDouble() ?? 300.0,
      inStock: json['in_stock'] as bool? ?? true,
    );
  }
}

@immutable
class HeatAlert {
  final String cattleId;
  final String cattleName;
  final String breed;
  final String lactationStage;
  final String heatStatus;
  final double confidencePct;
  final int activitySpikePct;
  final int ruminationDropPct;
  final double hoursRemaining;
  final String ruleApplied;
  final List<SireRecommendation> sires;

  const HeatAlert({
    required this.cattleId,
    required this.cattleName,
    required this.breed,
    required this.lactationStage,
    required this.heatStatus,
    required this.confidencePct,
    required this.activitySpikePct,
    required this.ruminationDropPct,
    required this.hoursRemaining,
    required this.ruleApplied,
    required this.sires,
  });

  factory HeatAlert.fromJson(Map<String, dynamic> json) {
    final siresRaw = json['sire_recommendations'] as List<dynamic>? ?? [];
    return HeatAlert(
      cattleId: json['cattle_id'] as String? ?? '',
      cattleName: json['cattle_name'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      lactationStage: json['lactation_stage'] as String? ?? '',
      heatStatus: json['heat_status'] as String? ?? 'HEAT_DETECTED',
      confidencePct: (json['confidence_pct'] as num?)?.toDouble() ?? 90.0,
      activitySpikePct: (json['activity_spike_pct'] as num?)?.toInt() ?? 250,
      ruminationDropPct: (json['rumination_drop_pct'] as num?)?.toInt() ?? 20,
      hoursRemaining: (json['hours_remaining'] as num?)?.toDouble() ?? 8.0,
      ruleApplied: json['rule_applied'] as String? ?? 'AM-PM Rule',
      sires: siresRaw.map((e) => SireRecommendation.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Bulk Milk Cooler (BMC) Telemetry Model
// ---------------------------------------------------------------------------
@immutable
class BmcTelemetryData {
  final String centerId;
  final String centerName;
  final String managerName;
  final double capacityLitres;
  final double currentVolumeLitres;
  final double fillPct;
  final double currentTemperatureC;
  final double targetTemperatureC;
  final String status;
  final int agitatorRpm;
  final String powerSource;
  final double mbrtHours;

  const BmcTelemetryData({
    required this.centerId,
    required this.centerName,
    required this.managerName,
    required this.capacityLitres,
    required this.currentVolumeLitres,
    required this.fillPct,
    required this.currentTemperatureC,
    required this.targetTemperatureC,
    required this.status,
    required this.agitatorRpm,
    required this.powerSource,
    required this.mbrtHours,
  });

  factory BmcTelemetryData.fromJson(Map<String, dynamic> json) {
    return BmcTelemetryData(
      centerId: json['center_id'] as String? ?? 'BMC-01',
      centerName: json['center_name'] as String? ?? 'Chilling Center',
      managerName: json['manager_name'] as String? ?? '',
      capacityLitres: (json['capacity_litres'] as num?)?.toDouble() ?? 5000.0,
      currentVolumeLitres: (json['current_volume_litres'] as num?)?.toDouble() ?? 3840.0,
      fillPct: (json['fill_pct'] as num?)?.toDouble() ?? 75.0,
      currentTemperatureC: (json['current_temperature_c'] as num?)?.toDouble() ?? 3.8,
      targetTemperatureC: (json['target_temperature_c'] as num?)?.toDouble() ?? 4.0,
      status: json['status'] as String? ?? 'OPTIMAL_CHILLED',
      agitatorRpm: (json['agitator_rpm'] as num?)?.toInt() ?? 28,
      powerSource: json['power_source'] as String? ?? 'GRID',
      mbrtHours: (json['mbrt_hours'] as num?)?.toDouble() ?? 4.5,
    );
  }
}

// ---------------------------------------------------------------------------
// 4. GOBARdhan Biogas & Carbon Credits Model
// ---------------------------------------------------------------------------
@immutable
class GobardhanData {
  final double dailyDungKg;
  final double monthlyBiogasM3;
  final double monthlyLpgSavingsInr;
  final double bioSlurryLitres;
  final double bioSlurryValueInr;
  final double co2eMitigationTons;
  final double carbonCreditsEarned;
  final double carbonRevenueInr;
  final double withdrawableBalanceInr;
  final double totalMonthlyCircularIncomeInr;

  const GobardhanData({
    required this.dailyDungKg,
    required this.monthlyBiogasM3,
    required this.monthlyLpgSavingsInr,
    required this.bioSlurryLitres,
    required this.bioSlurryValueInr,
    required this.co2eMitigationTons,
    required this.carbonCreditsEarned,
    required this.carbonRevenueInr,
    required this.withdrawableBalanceInr,
    required this.totalMonthlyCircularIncomeInr,
  });

  factory GobardhanData.fromJson(Map<String, dynamic> json) {
    final carbon = json['carbon_mitigation'] as Map<String, dynamic>? ?? {};
    return GobardhanData(
      dailyDungKg: (json['daily_dung_output_kg'] as num?)?.toDouble() ?? 72.0,
      monthlyBiogasM3: (json['biogas_monthly_m3'] as num?)?.toDouble() ?? 108.0,
      monthlyLpgSavingsInr: (json['monthly_lpg_savings_inr'] as num?)?.toDouble() ?? 2520.0,
      bioSlurryLitres: (json['bio_slurry_monthly_litres'] as num?)?.toDouble() ?? 2160.0,
      bioSlurryValueInr: (json['bio_slurry_fertilizer_value_inr'] as num?)?.toDouble() ?? 3240.0,
      co2eMitigationTons: (carbon['methane_avoidance_mt_co2e'] as num?)?.toDouble() ?? 4.2,
      carbonCreditsEarned: (carbon['total_carbon_credits_earned'] as num?)?.toDouble() ?? 4.2,
      carbonRevenueInr: (carbon['total_carbon_revenue_inr'] as num?)?.toDouble() ?? 3780.0,
      withdrawableBalanceInr: (carbon['withdrawable_balance_inr'] as num?)?.toDouble() ?? 3780.0,
      totalMonthlyCircularIncomeInr: (json['total_monthly_circular_income_inr'] as num?)?.toDouble() ?? 9540.0,
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Group Feed & Silage Pool Model
// ---------------------------------------------------------------------------
@immutable
class GroupFeedPool {
  final String poolId;
  final String title;
  final String category;
  final String clusterLocation;
  final String deliveryHub;
  final double targetTons;
  final double bookedTons;
  final double minOrderKg;
  final double retailPricePerKg;
  final double groupPricePerKg;
  final double savingsPct;
  final int hoursRemaining;
  final int participatingFarmers;

  const GroupFeedPool({
    required this.poolId,
    required this.title,
    required this.category,
    required this.clusterLocation,
    required this.deliveryHub,
    required this.targetTons,
    required this.bookedTons,
    required this.minOrderKg,
    required this.retailPricePerKg,
    required this.groupPricePerKg,
    required this.savingsPct,
    required this.hoursRemaining,
    required this.participatingFarmers,
  });

  factory GroupFeedPool.fromJson(Map<String, dynamic> json) {
    return GroupFeedPool(
      poolId: json['pool_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'Feed',
      clusterLocation: json['cluster_location'] as String? ?? '',
      deliveryHub: json['delivery_hub'] as String? ?? '',
      targetTons: (json['target_metric_tons'] as num?)?.toDouble() ?? 50.0,
      bookedTons: (json['booked_metric_tons'] as num?)?.toDouble() ?? 38.0,
      minOrderKg: (json['min_order_kg'] as num?)?.toDouble() ?? 100.0,
      retailPricePerKg: (json['retail_price_per_kg'] as num?)?.toDouble() ?? 5.5,
      groupPricePerKg: (json['group_pool_price_per_kg'] as num?)?.toDouble() ?? 4.3,
      savingsPct: (json['savings_pct'] as num?)?.toDouble() ?? 20.0,
      hoursRemaining: (json['hours_remaining'] as num?)?.toInt() ?? 24,
      participatingFarmers: (json['total_participating_farmers'] as num?)?.toInt() ?? 20,
    );
  }
}
