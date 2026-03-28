// ---------------------------------------------------------------------------
// Payment, Loan, Insurance & Subsidy models — plain Dart classes with
// factory fromJson constructors (no freezed).
// ---------------------------------------------------------------------------

class PaymentCycle {
  final String id;
  final String cycleType;
  final String periodStart;
  final String periodEnd;
  final String status;
  final double? netPayout;
  final double? totalLitres;
  final double? totalAmount;
  final double? totalDeductions;
  final double? totalBonuses;
  final int? farmersCount;

  const PaymentCycle({
    required this.id,
    required this.cycleType,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.netPayout,
    this.totalLitres,
    this.totalAmount,
    this.totalDeductions,
    this.totalBonuses,
    this.farmersCount,
  });

  factory PaymentCycle.fromJson(Map<String, dynamic> json) {
    return PaymentCycle(
      id: json['id']?.toString() ?? '',
      cycleType: json['cycle_type']?.toString() ?? '',
      periodStart: json['period_start']?.toString() ?? '',
      periodEnd: json['period_end']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      netPayout: (json['net_payout'] as num?)?.toDouble(),
      totalLitres: (json['total_litres'] as num?)?.toDouble(),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      totalDeductions: (json['total_deductions'] as num?)?.toDouble(),
      totalBonuses: (json['total_bonuses'] as num?)?.toDouble(),
      farmersCount: (json['farmers_count'] as num?)?.toInt(),
    );
  }
}

class FarmerPayment {
  final String id;
  final String farmerId;
  final double totalLitres;
  final double avgFatPct;
  final double avgSnfPct;
  final double baseAmount;
  final double qualityBonus;
  final double loanDeduction;
  final double netAmount;
  final String? status;

  const FarmerPayment({
    required this.id,
    required this.farmerId,
    required this.totalLitres,
    required this.avgFatPct,
    required this.avgSnfPct,
    required this.baseAmount,
    required this.qualityBonus,
    required this.loanDeduction,
    required this.netAmount,
    this.status,
  });

  factory FarmerPayment.fromJson(Map<String, dynamic> json) {
    return FarmerPayment(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmer_id']?.toString() ?? '',
      totalLitres: (json['total_litres'] as num?)?.toDouble() ?? 0.0,
      avgFatPct: (json['avg_fat_pct'] as num?)?.toDouble() ?? 0.0,
      avgSnfPct: (json['avg_snf_pct'] as num?)?.toDouble() ?? 0.0,
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0.0,
      qualityBonus: (json['quality_bonus'] as num?)?.toDouble() ?? 0.0,
      loanDeduction: (json['loan_deduction'] as num?)?.toDouble() ?? 0.0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString(),
    );
  }
}

class Loan {
  final String id;
  final String farmerId;
  final String loanType;
  final String status;
  final double principalAmount;
  final double outstandingAmount;
  final double emiAmount;
  final double? interestRatePct;
  final int? tenureMonths;

  const Loan({
    required this.id,
    required this.farmerId,
    required this.loanType,
    required this.status,
    required this.principalAmount,
    required this.outstandingAmount,
    required this.emiAmount,
    this.interestRatePct,
    this.tenureMonths,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmer_id']?.toString() ?? '',
      loanType: json['loan_type']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      principalAmount: (json['principal_amount'] as num?)?.toDouble() ?? 0.0,
      outstandingAmount:
          (json['outstanding_amount'] as num?)?.toDouble() ?? 0.0,
      emiAmount: (json['emi_amount'] as num?)?.toDouble() ?? 0.0,
      interestRatePct: (json['interest_rate_pct'] as num?)?.toDouble(),
      tenureMonths: (json['tenure_months'] as num?)?.toInt(),
    );
  }

  String get loanTypeLabel {
    switch (loanType) {
      case 'cattle_purchase':
        return 'Cattle Purchase';
      case 'feed_advance':
        return 'Feed Advance';
      case 'equipment':
        return 'Equipment';
      case 'emergency':
        return 'Emergency';
      case 'dairy_infra':
        return 'Dairy Infrastructure';
      default:
        return loanType;
    }
  }
}

class CattleInsurance {
  final String id;
  final String farmerId;
  final String? cattleId;
  final String? policyNumber;
  final String? insurerName;
  final double sumInsured;
  final double premiumAmount;
  final double farmerPremium;
  final String? startDate;
  final String? endDate;
  final String? status;
  final double? claimAmount;
  final String? claimReason;

  const CattleInsurance({
    required this.id,
    required this.farmerId,
    this.cattleId,
    this.policyNumber,
    this.insurerName,
    required this.sumInsured,
    required this.premiumAmount,
    required this.farmerPremium,
    this.startDate,
    this.endDate,
    this.status,
    this.claimAmount,
    this.claimReason,
  });

  factory CattleInsurance.fromJson(Map<String, dynamic> json) {
    return CattleInsurance(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmer_id']?.toString() ?? '',
      cattleId: json['cattle_id']?.toString(),
      policyNumber: json['policy_number']?.toString(),
      insurerName: json['insurer_name']?.toString(),
      sumInsured: (json['sum_insured'] as num?)?.toDouble() ?? 0.0,
      premiumAmount: (json['premium_amount'] as num?)?.toDouble() ?? 0.0,
      farmerPremium: (json['farmer_premium'] as num?)?.toDouble() ?? 0.0,
      startDate: json['start_date']?.toString(),
      endDate: json['end_date']?.toString(),
      status: json['status']?.toString(),
      claimAmount: (json['claim_amount'] as num?)?.toDouble(),
      claimReason: json['claim_reason']?.toString(),
    );
  }
}

class SubsidyApplication {
  final String id;
  final String farmerId;
  final String scheme;
  final String schemeName;
  final String status;
  final double appliedAmount;
  final double? approvedAmount;
  final double? disbursedAmount;

  const SubsidyApplication({
    required this.id,
    required this.farmerId,
    required this.scheme,
    required this.schemeName,
    required this.status,
    required this.appliedAmount,
    this.approvedAmount,
    this.disbursedAmount,
  });

  factory SubsidyApplication.fromJson(Map<String, dynamic> json) {
    return SubsidyApplication(
      id: json['id']?.toString() ?? '',
      farmerId: json['farmer_id']?.toString() ?? '',
      scheme: json['scheme']?.toString() ?? '',
      schemeName: json['scheme_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'applied',
      appliedAmount: (json['applied_amount'] as num?)?.toDouble() ?? 0.0,
      approvedAmount: (json['approved_amount'] as num?)?.toDouble(),
      disbursedAmount: (json['disbursed_amount'] as num?)?.toDouble(),
    );
  }

  String get schemeLabel {
    switch (scheme) {
      case 'nabard_dairy':
        return 'NABARD Dairy';
      case 'ndp_ii':
        return 'NDP-II';
      case 'didf':
        return 'DIDF';
      case 'state_scheme':
        return 'State Scheme';
      default:
        return scheme;
    }
  }
}

class FarmerLedger {
  final String farmerId;
  final double totalEarnings;
  final double totalLoansOutstanding;
  final double totalSubsidiesReceived;
  final List<FarmerPayment> recentPayments;
  final List<Loan> loans;
  final List<CattleInsurance> insurancePolicies;

  const FarmerLedger({
    required this.farmerId,
    required this.totalEarnings,
    required this.totalLoansOutstanding,
    required this.totalSubsidiesReceived,
    required this.recentPayments,
    required this.loans,
    required this.insurancePolicies,
  });

  factory FarmerLedger.fromJson(Map<String, dynamic> json) {
    return FarmerLedger(
      farmerId: json['farmer_id']?.toString() ?? '',
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0.0,
      totalLoansOutstanding:
          (json['total_loans_outstanding'] as num?)?.toDouble() ?? 0.0,
      totalSubsidiesReceived:
          (json['total_subsidies_received'] as num?)?.toDouble() ?? 0.0,
      recentPayments: (json['recent_payments'] as List<dynamic>?)
              ?.map((e) => FarmerPayment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      loans: (json['loans'] as List<dynamic>?)
              ?.map((e) => Loan.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      insurancePolicies: (json['insurance_policies'] as List<dynamic>?)
              ?.map((e) => CattleInsurance.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
