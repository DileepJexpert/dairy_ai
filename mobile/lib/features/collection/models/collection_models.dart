/// Data models for the Milk Collection Center feature.
///
/// Plain Dart classes with `factory fromJson` constructors — no freezed.

class CollectionCenter {
  final String id;
  final String name;
  final String code;
  final String? cooperativeId;
  final String? address;
  final String? village;
  final String? district;
  final String? state;
  final String? pincode;
  final double? lat;
  final double? lng;
  final double capacityLitres;
  final double currentStockLitres;
  final double chillingTempCelsius;
  final bool hasFatAnalyzer;
  final bool hasSnfAnalyzer;
  final String? managerName;
  final String? managerPhone;
  final String status; // active, inactive, maintenance

  const CollectionCenter({
    required this.id,
    required this.name,
    required this.code,
    this.cooperativeId,
    this.address,
    this.village,
    this.district,
    this.state,
    this.pincode,
    this.lat,
    this.lng,
    required this.capacityLitres,
    required this.currentStockLitres,
    required this.chillingTempCelsius,
    this.hasFatAnalyzer = false,
    this.hasSnfAnalyzer = false,
    this.managerName,
    this.managerPhone,
    required this.status,
  });

  factory CollectionCenter.fromJson(Map<String, dynamic> json) {
    return CollectionCenter(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      cooperativeId: json['cooperative_id'] as String?,
      address: json['address'] as String?,
      village: json['village'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      capacityLitres: (json['capacity_litres'] as num).toDouble(),
      currentStockLitres: (json['current_stock_litres'] as num).toDouble(),
      chillingTempCelsius: (json['chilling_temp_celsius'] as num).toDouble(),
      hasFatAnalyzer: json['has_fat_analyzer'] as bool? ?? false,
      hasSnfAnalyzer: json['has_snf_analyzer'] as bool? ?? false,
      managerName: json['manager_name'] as String?,
      managerPhone: json['manager_phone'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        if (cooperativeId != null) 'cooperative_id': cooperativeId,
        if (address != null) 'address': address,
        if (village != null) 'village': village,
        if (district != null) 'district': district,
        if (state != null) 'state': state,
        if (pincode != null) 'pincode': pincode,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'capacity_litres': capacityLitres,
        'current_stock_litres': currentStockLitres,
        'chilling_temp_celsius': chillingTempCelsius,
        'has_fat_analyzer': hasFatAnalyzer,
        'has_snf_analyzer': hasSnfAnalyzer,
        if (managerName != null) 'manager_name': managerName,
        if (managerPhone != null) 'manager_phone': managerPhone,
        'status': status,
      };

  /// Stock percentage (0.0 – 1.0).
  double get stockRatio =>
      capacityLitres > 0 ? currentStockLitres / capacityLitres : 0;

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'maintenance':
        return 'Maintenance';
      default:
        return status;
    }
  }
}

class MilkCollectionRecord {
  final String id;
  final String centerId;
  final String farmerId;
  final String date;
  final String shift; // morning, evening
  final double quantityLitres;
  final double? fatPct;
  final double? snfPct;
  final double? temperatureCelsius;
  final String? milkGrade; // A, B, C, rejected
  final double ratePerLitre;
  final double totalAmount;
  final double qualityBonus;
  final double deductions;
  final double netAmount;
  final bool isRejected;
  final String? rejectionReason;
  final String? whatsappSlipText;
  final String? whatsappUrl;

  const MilkCollectionRecord({
    required this.id,
    required this.centerId,
    required this.farmerId,
    required this.date,
    required this.shift,
    required this.quantityLitres,
    this.fatPct,
    this.snfPct,
    this.temperatureCelsius,
    this.milkGrade,
    required this.ratePerLitre,
    required this.totalAmount,
    this.qualityBonus = 0,
    this.deductions = 0,
    required this.netAmount,
    this.isRejected = false,
    this.rejectionReason,
    this.whatsappSlipText,
    this.whatsappUrl,
  });

  factory MilkCollectionRecord.fromJson(Map<String, dynamic> json) {
    final whatsappSlipObj = json['whatsapp_slip'] is Map ? json['whatsapp_slip'] as Map<String, dynamic> : null;
    return MilkCollectionRecord(
      id: json['id'] as String,
      centerId: json['center_id'] as String,
      farmerId: json['farmer_id'] as String,
      date: json['date'] as String,
      shift: json['shift'] as String,
      quantityLitres: (json['quantity_litres'] as num).toDouble(),
      fatPct: (json['fat_pct'] as num?)?.toDouble(),
      snfPct: (json['snf_pct'] as num?)?.toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num?)?.toDouble(),
      milkGrade: json['milk_grade'] as String?,
      ratePerLitre: (json['rate_per_litre'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      qualityBonus: (json['quality_bonus'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      netAmount: (json['net_amount'] as num).toDouble(),
      isRejected: json['is_rejected'] as bool? ?? false,
      rejectionReason: json['rejection_reason'] as String?,
      whatsappSlipText: whatsappSlipObj?['text']?.toString() ?? json['whatsapp_slip_text'] as String?,
      whatsappUrl: whatsappSlipObj?['url']?.toString(),
    );
  }

  String generateDefaultWhatsAppSlip({String? farmerName}) {
    if (whatsappSlipText != null && whatsappSlipText!.isNotEmpty) {
      return whatsappSlipText!;
    }
    final name = farmerName ?? 'Ramesh';
    final shiftTitle = shift == 'morning' ? 'Morning' : 'Evening';
    return 'Namaste $name ji! $shiftTitle collection: $quantityLitres Litres | Fat: ${fatPct ?? 4.4}% | SNF: ${snfPct ?? 8.6}% | Payout: \u20B9${netAmount.toStringAsFixed(2)} credited to Milterra Wallet.';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'center_id': centerId,
        'farmer_id': farmerId,
        'date': date,
        'shift': shift,
        'quantity_litres': quantityLitres,
        if (fatPct != null) 'fat_pct': fatPct,
        if (snfPct != null) 'snf_pct': snfPct,
        if (temperatureCelsius != null)
          'temperature_celsius': temperatureCelsius,
        if (milkGrade != null) 'milk_grade': milkGrade,
        'rate_per_litre': ratePerLitre,
        'total_amount': totalAmount,
        'quality_bonus': qualityBonus,
        'deductions': deductions,
        'net_amount': netAmount,
        'is_rejected': isRejected,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      };
}

class ColdChainReading {
  final String id;
  final double temperatureCelsius;
  final bool isAlert;
  final String recordedAt;

  const ColdChainReading({
    required this.id,
    required this.temperatureCelsius,
    this.isAlert = false,
    required this.recordedAt,
  });

  factory ColdChainReading.fromJson(Map<String, dynamic> json) {
    return ColdChainReading(
      id: json['id'] as String,
      temperatureCelsius: (json['temperature_celsius'] as num).toDouble(),
      isAlert: json['is_alert'] as bool? ?? false,
      recordedAt: json['recorded_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'temperature_celsius': temperatureCelsius,
        'is_alert': isAlert,
        'recorded_at': recordedAt,
      };
}

class ColdChainAlert {
  final String id;
  final String? centerId;
  final double temperatureCelsius;
  final String severity; // info, warning, critical
  final String status; // active, acknowledged, resolved
  final String? message;
  final String createdAt;

  const ColdChainAlert({
    required this.id,
    this.centerId,
    required this.temperatureCelsius,
    required this.severity,
    required this.status,
    this.message,
    required this.createdAt,
  });

  factory ColdChainAlert.fromJson(Map<String, dynamic> json) {
    return ColdChainAlert(
      id: json['id'] as String,
      centerId: json['center_id'] as String?,
      temperatureCelsius: (json['temperature_celsius'] as num).toDouble(),
      severity: json['severity'] as String? ?? 'info',
      status: json['status'] as String? ?? 'active',
      message: json['message'] as String?,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (centerId != null) 'center_id': centerId,
        'temperature_celsius': temperatureCelsius,
        'severity': severity,
        'status': status,
        if (message != null) 'message': message,
        'created_at': createdAt,
      };
}

class CenterDashboard {
  final Map<String, dynamic> center;
  final Map<String, dynamic> today;
  final Map<String, dynamic> alerts;

  const CenterDashboard({
    required this.center,
    required this.today,
    required this.alerts,
  });

  factory CenterDashboard.fromJson(Map<String, dynamic> json) {
    return CenterDashboard(
      center: json['center'] as Map<String, dynamic>? ?? {},
      today: json['today'] as Map<String, dynamic>? ?? {},
      alerts: json['alerts'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'center': center,
        'today': today,
        'alerts': alerts,
      };
}

class FarmerPassbookSummary {
  final int totalEntries;
  final double totalLitres;
  final double totalNetPayout;
  final double averageFatPct;
  final double averageSnfPct;
  final String currentCycleName;
  final int cycleDaysRemaining;
  final double cycleEstimatedPayout;

  const FarmerPassbookSummary({
    required this.totalEntries,
    required this.totalLitres,
    required this.totalNetPayout,
    required this.averageFatPct,
    required this.averageSnfPct,
    this.currentCycleName = 'Cycle 3 (21 Oct – 31 Oct)',
    this.cycleDaysRemaining = 10,
    this.cycleEstimatedPayout = 0,
  });

  factory FarmerPassbookSummary.fromJson(Map<String, dynamic> json) {
    return FarmerPassbookSummary(
      totalEntries: (json['total_entries'] as num?)?.toInt() ?? 0,
      totalLitres: (json['total_litres'] as num?)?.toDouble() ?? 0.0,
      totalNetPayout: (json['total_net_payout'] as num?)?.toDouble() ?? 0.0,
      averageFatPct: (json['average_fat_pct'] as num?)?.toDouble() ?? 0.0,
      averageSnfPct: (json['average_snf_pct'] as num?)?.toDouble() ?? 0.0,
      currentCycleName: json['cycle_name'] as String? ?? 'Cycle 3 (21 Oct – 31 Oct)',
      cycleDaysRemaining: (json['cycle_days_remaining'] as num?)?.toInt() ?? 10,
      cycleEstimatedPayout: (json['cycle_estimated_payout'] as num?)?.toDouble() ??
          (json['total_net_payout'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

class FarmerPassbookData {
  final String farmerName;
  final String? farmerId;
  final String? village;
  final FarmerPassbookSummary summary;
  final List<MilkCollectionRecord> entries;

  const FarmerPassbookData({
    required this.farmerName,
    this.farmerId,
    this.village,
    required this.summary,
    required this.entries,
  });
}
