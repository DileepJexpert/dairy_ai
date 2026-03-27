import 'package:flutter/foundation.dart';

/// Milk collection session.
enum MilkSession { morning, evening, night }

/// Buyer type for milk sales.
enum BuyerType { cooperative, private_buyer, self_use }

/// A single milk collection record.
@immutable
class MilkRecord {
  final int? id;
  final int cattleId;
  final String? cattleName;
  final String? cattleTagId;
  final DateTime date;
  final MilkSession session;
  final double quantityLitres;
  final double? fatPct;
  final double? snfPct;
  final BuyerType buyerType;
  final String? buyerName;
  final double? pricePerLitre;

  const MilkRecord({
    this.id,
    required this.cattleId,
    this.cattleName,
    this.cattleTagId,
    required this.date,
    required this.session,
    required this.quantityLitres,
    this.fatPct,
    this.snfPct,
    required this.buyerType,
    this.buyerName,
    this.pricePerLitre,
  });

  double get revenue =>
      (pricePerLitre ?? 0) * quantityLitres;

  factory MilkRecord.fromJson(Map<String, dynamic> json) {
    return MilkRecord(
      id: json['id'] as int?,
      cattleId: json['cattle_id'] as int,
      cattleName: json['cattle_name'] as String?,
      cattleTagId: json['cattle_tag_id'] as String?,
      date: DateTime.parse(json['date'] as String),
      session: MilkSession.values.firstWhere(
        (e) => e.name == json['session'],
        orElse: () => MilkSession.morning,
      ),
      quantityLitres: (json['quantity_litres'] as num).toDouble(),
      fatPct: (json['fat_pct'] as num?)?.toDouble(),
      snfPct: (json['snf_pct'] as num?)?.toDouble(),
      buyerType: _parseBuyerType(json['buyer'] as String?),
      buyerName: json['buyer_name'] as String?,
      pricePerLitre: (json['price_per_litre'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cattle_id': cattleId,
        'date': date.toIso8601String().split('T').first,
        'session': session.name,
        'quantity_litres': quantityLitres,
        if (fatPct != null) 'fat_pct': fatPct,
        if (snfPct != null) 'snf_pct': snfPct,
        'buyer': _buyerTypeToString(buyerType),
        if (buyerName != null) 'buyer_name': buyerName,
        if (pricePerLitre != null) 'price_per_litre': pricePerLitre,
      };

  static BuyerType _parseBuyerType(String? value) {
    switch (value) {
      case 'cooperative':
        return BuyerType.cooperative;
      case 'private':
        return BuyerType.private_buyer;
      case 'self':
        return BuyerType.self_use;
      default:
        return BuyerType.cooperative;
    }
  }

  static String _buyerTypeToString(BuyerType type) {
    switch (type) {
      case BuyerType.cooperative:
        return 'cooperative';
      case BuyerType.private_buyer:
        return 'private';
      case BuyerType.self_use:
        return 'self';
    }
  }
}

/// Aggregated milk summary for analytics.
@immutable
class MilkSummary {
  final double totalLitres;
  final double totalRevenue;
  final double avgFatPct;
  final double avgSnfPct;
  final int totalRecords;
  final List<DailyMilkEntry> dailyEntries;
  final List<CattleMilkBreakdown> cattleBreakdown;

  const MilkSummary({
    required this.totalLitres,
    required this.totalRevenue,
    required this.avgFatPct,
    required this.avgSnfPct,
    required this.totalRecords,
    required this.dailyEntries,
    required this.cattleBreakdown,
  });

  factory MilkSummary.fromJson(Map<String, dynamic> json) {
    return MilkSummary(
      totalLitres: (json['total_litres'] as num?)?.toDouble() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      avgFatPct: (json['avg_fat_pct'] as num?)?.toDouble() ?? 0,
      avgSnfPct: (json['avg_snf_pct'] as num?)?.toDouble() ?? 0,
      totalRecords: json['total_records'] as int? ?? 0,
      dailyEntries: (json['daily_entries'] as List<dynamic>?)
              ?.map((e) =>
                  DailyMilkEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      cattleBreakdown: (json['cattle_breakdown'] as List<dynamic>?)
              ?.map((e) =>
                  CattleMilkBreakdown.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  factory MilkSummary.empty() => const MilkSummary(
        totalLitres: 0,
        totalRevenue: 0,
        avgFatPct: 0,
        avgSnfPct: 0,
        totalRecords: 0,
        dailyEntries: [],
        cattleBreakdown: [],
      );
}

/// One day of milk production data.
@immutable
class DailyMilkEntry {
  final DateTime date;
  final double litres;
  final double revenue;

  const DailyMilkEntry({
    required this.date,
    required this.litres,
    required this.revenue,
  });

  factory DailyMilkEntry.fromJson(Map<String, dynamic> json) {
    return DailyMilkEntry(
      date: DateTime.parse(json['date'] as String),
      litres: (json['litres'] as num).toDouble(),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Per-cattle breakdown in summary.
@immutable
class CattleMilkBreakdown {
  final int cattleId;
  final String cattleName;
  final String? cattleTagId;
  final double totalLitres;
  final double totalRevenue;
  final double avgDaily;

  const CattleMilkBreakdown({
    required this.cattleId,
    required this.cattleName,
    this.cattleTagId,
    required this.totalLitres,
    required this.totalRevenue,
    required this.avgDaily,
  });

  factory CattleMilkBreakdown.fromJson(Map<String, dynamic> json) {
    return CattleMilkBreakdown(
      cattleId: json['cattle_id'] as int,
      cattleName: json['cattle_name'] as String? ?? 'Unknown',
      cattleTagId: json['cattle_tag_id'] as String?,
      totalLitres: (json['total_litres'] as num).toDouble(),
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      avgDaily: (json['avg_daily'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// District-wise milk price entry.
@immutable
class MilkPrice {
  final int id;
  final String district;
  final String buyerName;
  final double pricePerLitre;
  final double? fatPct;
  final DateTime date;

  const MilkPrice({
    required this.id,
    required this.district,
    required this.buyerName,
    required this.pricePerLitre,
    this.fatPct,
    required this.date,
  });

  factory MilkPrice.fromJson(Map<String, dynamic> json) {
    return MilkPrice(
      id: json['id'] as int,
      district: json['district'] as String,
      buyerName: json['buyer_name'] as String,
      pricePerLitre: (json['price_per_litre'] as num).toDouble(),
      fatPct: (json['fat_pct'] as num?)?.toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }
}
