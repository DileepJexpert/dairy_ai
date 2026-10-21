// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/foundation.dart';

@immutable
class ScorePillar {
  final String id;
  final String title;
  final int score;
  final int max;
  final String status;
  final String tips;

  const ScorePillar({
    required this.id,
    required this.title,
    required this.score,
    required this.max,
    required this.status,
    required this.tips,
  });

  factory ScorePillar.fromJson(Map<String, dynamic> json) {
    return ScorePillar(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 100,
      status: json['status'] as String? ?? 'अच्छा',
      tips: json['tips'] as String? ?? '',
    );
  }
}

@immutable
class PreApprovedOffer {
  final String id;
  final String title;
  final double maxAmount;
  final double interestRatePct;
  final int tenureMonths;
  final bool collateralRequired;
  final String subsidyBadge;
  final double monthlyEmiEst;
  final double dailyEscrowEst;
  final String tagline;

  const PreApprovedOffer({
    required this.id,
    required this.title,
    required this.maxAmount,
    required this.interestRatePct,
    required this.tenureMonths,
    required this.collateralRequired,
    required this.subsidyBadge,
    required this.monthlyEmiEst,
    required this.dailyEscrowEst,
    required this.tagline,
  });

  factory PreApprovedOffer.fromJson(Map<String, dynamic> json) {
    return PreApprovedOffer(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      maxAmount: (json['max_amount'] as num?)?.toDouble() ?? 0.0,
      interestRatePct: (json['interest_rate_pct'] as num?)?.toDouble() ?? 7.0,
      tenureMonths: (json['tenure_months'] as num?)?.toInt() ?? 12,
      collateralRequired: json['collateral_required'] as bool? ?? false,
      subsidyBadge: json['subsidy_badge'] as String? ?? '',
      monthlyEmiEst: (json['monthly_emi_est'] as num?)?.toDouble() ?? 0.0,
      dailyEscrowEst: (json['daily_escrow_est'] as num?)?.toDouble() ?? 0.0,
      tagline: json['tagline'] as String? ?? '',
    );
  }
}

@immutable
class PashuCreditScore {
  final String farmerId;
  final String farmerName;
  final String village;
  final String district;
  final int totalCattle;
  final int score;
  final int maxScore;
  final String grade;
  final String ratingText;
  final String ratingColor;
  final List<ScorePillar> pillars;
  final List<PreApprovedOffer> preApprovedOffers;
  final double monthlyRevenueEst;
  final String debtServiceRatio;
  final String repaymentModel;

  const PashuCreditScore({
    required this.farmerId,
    required this.farmerName,
    required this.village,
    required this.district,
    required this.totalCattle,
    required this.score,
    required this.maxScore,
    required this.grade,
    required this.ratingText,
    required this.ratingColor,
    required this.pillars,
    required this.preApprovedOffers,
    required this.monthlyRevenueEst,
    required this.debtServiceRatio,
    required this.repaymentModel,
  });

  factory PashuCreditScore.fromJson(Map<String, dynamic> json) {
    return PashuCreditScore(
      farmerId: json['farmer_id'] as String? ?? '',
      farmerName: json['farmer_name'] as String? ?? 'डेयरी किसान',
      village: json['village'] as String? ?? 'आनंद',
      district: json['district'] as String? ?? 'आनंद',
      totalCattle: (json['total_cattle'] as num?)?.toInt() ?? 4,
      score: (json['score'] as num?)?.toInt() ?? 835,
      maxScore: (json['max_score'] as num?)?.toInt() ?? 900,
      grade: json['grade'] as String? ?? 'A+',
      ratingText: json['rating_text'] as String? ?? 'उत्कृष्ट (Prime / Pre-Approved)',
      ratingColor: json['rating_color'] as String? ?? '#16a34a',
      pillars: (json['pillars'] as List<dynamic>?)
              ?.map((e) => ScorePillar.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      preApprovedOffers: (json['pre_approved_offers'] as List<dynamic>?)
              ?.map((e) => PreApprovedOffer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      monthlyRevenueEst: (json['monthly_revenue_est'] as num?)?.toDouble() ?? 54000.0,
      debtServiceRatio: json['debt_service_ratio'] as String? ?? '3.4x (अत्यधिक सुरक्षित)',
      repaymentModel: json['repayment_model'] as String? ?? 'दैनिक दूध पर्ची से ₹125/दिन कटौती',
    );
  }
}

@immutable
class BankDossierCattle {
  final String tagId;
  final String name;
  final String breed;
  final int lactation;
  final String healthClearance;
  final String estimatedDailyYield;

  const BankDossierCattle({
    required this.tagId,
    required this.name,
    required this.breed,
    required this.lactation,
    required this.healthClearance,
    required this.estimatedDailyYield,
  });

  factory BankDossierCattle.fromJson(Map<String, dynamic> json) {
    return BankDossierCattle(
      tagId: json['tag_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      breed: json['breed'] as String? ?? '',
      lactation: (json['lactation'] as num?)?.toInt() ?? 1,
      healthClearance: json['health_clearance'] as String? ?? 'प्रमाणित रोगमुक्त',
      estimatedDailyYield: json['estimated_daily_yield'] as String? ?? '14-16 L',
    );
  }
}

@immutable
class BankDossier {
  final String certificateId;
  final String issuedDate;
  final String validUntil;
  final String verificationHash;
  final String issuingAuthority;
  final String farmerName;
  final String village;
  final String district;
  final String phone;
  final int totalCattle;
  final String fmdVaccineStatus;
  final String hsBqVaccineStatus;
  final bool chronicDiseaseFree;
  final double totalLitres90d;
  final double totalRevenue90d;
  final double avgMonthlyRevenue;
  final double avgFat;
  final double avgSnf;
  final double recommendedKccLimit;
  final double recommendedInterestRate;
  final double escrowDailyDeduction;
  final List<BankDossierCattle> cattleList;

  const BankDossier({
    required this.certificateId,
    required this.issuedDate,
    required this.validUntil,
    required this.verificationHash,
    required this.issuingAuthority,
    required this.farmerName,
    required this.village,
    required this.district,
    required this.phone,
    required this.totalCattle,
    required this.fmdVaccineStatus,
    required this.hsBqVaccineStatus,
    required this.chronicDiseaseFree,
    required this.totalLitres90d,
    required this.totalRevenue90d,
    required this.avgMonthlyRevenue,
    required this.avgFat,
    required this.avgSnf,
    required this.recommendedKccLimit,
    required this.recommendedInterestRate,
    required this.escrowDailyDeduction,
    required this.cattleList,
  });

  factory BankDossier.fromJson(Map<String, dynamic> json) {
    final kyc = json['farmer_kyc'] as Map<String, dynamic>? ?? {};
    final audit = json['herd_health_audit'] as Map<String, dynamic>? ?? {};
    final milk = json['milk_cash_flow_audit'] as Map<String, dynamic>? ?? {};
    final rec = json['underwriting_recommendation'] as Map<String, dynamic>? ?? {};
    final inv = json['cattle_inventory'] as List<dynamic>? ?? [];

    return BankDossier(
      certificateId: json['certificate_id'] as String? ?? 'MIL-DOSSIER-2026-08492',
      issuedDate: json['issued_date'] as String? ?? '2026-10-22',
      validUntil: json['valid_until'] as String? ?? '2026-12-22',
      verificationHash: json['verification_hash'] as String? ?? 'VET-HASH-9812A',
      issuingAuthority: json['issuing_authority'] as String? ?? 'Milterra Fintech',
      farmerName: kyc['name'] as String? ?? 'रामेश पटेल',
      village: kyc['village'] as String? ?? 'आनंद',
      district: kyc['district'] as String? ?? 'आनंद',
      phone: kyc['phone'] as String? ?? '+91 98397 69808',
      totalCattle: (audit['total_active_cattle'] as num?)?.toInt() ?? 4,
      fmdVaccineStatus: audit['fmd_vaccine_status'] as String? ?? '100% COMPLIANT',
      hsBqVaccineStatus: audit['hs_bq_vaccine_status'] as String? ?? '100% COMPLIANT',
      chronicDiseaseFree: audit['chronic_disease_free'] as bool? ?? true,
      totalLitres90d: (milk['total_litres_poured'] as num?)?.toDouble() ?? 1350.0,
      totalRevenue90d: (milk['total_net_payout'] as num?)?.toDouble() ?? 54000.0,
      avgMonthlyRevenue: (milk['avg_monthly_payout'] as num?)?.toDouble() ?? 18000.0,
      avgFat: (milk['avg_fat_pct'] as num?)?.toDouble() ?? 4.3,
      avgSnf: (milk['avg_snf_pct'] as num?)?.toDouble() ?? 8.7,
      recommendedKccLimit: (rec['recommended_kcc_limit'] as num?)?.toDouble() ?? 160000.0,
      recommendedInterestRate: (rec['recommended_interest_rate_pct'] as num?)?.toDouble() ?? 4.0,
      escrowDailyDeduction: (rec['escrow_daily_deduction'] as num?)?.toDouble() ?? 125.0,
      cattleList: inv.map((e) => BankDossierCattle.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Fallback Offline Pashu Credit Score
final PashuCreditScore fallbackPashuCreditScore = PashuCreditScore(
  farmerId: 'farmer-offline-1',
  farmerName: 'रामेश पटेल',
  village: 'आनंद डेयरी क्षेत्र',
  district: 'आनंद',
  totalCattle: 4,
  score: 835,
  maxScore: 900,
  grade: 'A+',
  ratingText: 'उत्कृष्ट (Prime Borrower / 100% Pre-Approved)',
  ratingColor: '#16a34a',
  pillars: [
    ScorePillar(
      id: 'biosecurity',
      title: 'टीकाकरण व रोग रोकथाम (Vaccine & Prevention)',
      score: 205,
      max: 220,
      status: 'उत्कृष्ट',
      tips: 'FMD, HS व BQ टीकाकरण रिकॉर्ड अद्यतन हैं',
    ),
    ScorePillar(
      id: 'morbidity',
      title: 'रोगमुक्ति व त्वरित उपचार (Herd Health Stability)',
      score: 170,
      max: 180,
      status: 'उत्कृष्ट',
      tips: 'लक्षण दिखने पर 2 घंटे में प्राथमिक उपचार रिकॉर्ड किया गया',
    ),
    ScorePillar(
      id: 'milk_quality',
      title: 'दूध उत्पादन व गुणवत्ता निरंतरता (Milk Cash Flow)',
      score: 220,
      max: 240,
      status: 'उत्कृष्ट',
      tips: 'औसत फैट 4.3% व 90 दिन में 85 दिन नियमित दूध संकलन',
    ),
    ScorePillar(
      id: 'nutrition',
      title: 'संतुलित चारा व पोषण (Ration & Mineral Mix)',
      score: 80,
      max: 80,
      status: 'उत्कृष्ट',
      tips: 'दैनिक मिनरल मिक्सर व हरा चारा आहार में शामिल है',
    ),
    ScorePillar(
      id: 'financial',
      title: 'वित्तीय अनुशासन व आय (Financial Discipline)',
      score: 80,
      max: 80,
      status: 'उत्कृष्ट',
      tips: 'दूध भुगतान खाते में नियमित नकदी प्रवाह बना हुआ है',
    ),
  ],
  preApprovedOffers: [
    PreApprovedOffer(
      id: 'offer-kcc',
      title: 'पशुपालन किसान क्रेडिट कार्ड (KCC Animal Husbandry)',
      maxAmount: 160000,
      interestRatePct: 4.0,
      tenureMonths: 12,
      collateralRequired: false,
      subsidyBadge: '3% ब्याज छूट (Govt Subvention)',
      monthlyEmiEst: 13760,
      dailyEscrowEst: 458,
      tagline: 'बिना जमीन गिरवी रखे चारा, दवा व कार्यशील पूंजी हेतु 0% कोलैटरल लोन',
    ),
    PreApprovedOffer(
      id: 'offer-cattle-purchase',
      title: 'दुधारू पशु खरीद लोन (Dairy Cattle Purchase Loan)',
      maxAmount: 350000,
      interestRatePct: 7.5,
      tenureMonths: 36,
      collateralRequired: false,
      subsidyBadge: '80% LTV पशु बंधक पर',
      monthlyEmiEst: 10850,
      dailyEscrowEst: 360,
      tagline: '2 से 4 नई मुर्रा भैंस या गिर/साहीवाल गाय खरीदने हेतु दीर्घकालिक लोन',
    ),
    PreApprovedOffer(
      id: 'offer-insurance-subsidy',
      title: 'सत्यापित पशु बीमा प्रीमियम छूट (Cattle Insurance)',
      maxAmount: 0,
      interestRatePct: 2.2,
      tenureMonths: 12,
      collateralRequired: false,
      subsidyBadge: '50% प्रीमियम छूट',
      monthlyEmiEst: 0,
      dailyEscrowEst: 0,
      tagline: 'स्वस्थ पशु रिकॉर्ड पर 4.5% की जगह मात्र 2.2% वार्षिक प्रीमियम दर',
    ),
  ],
  monthlyRevenueEst: 54000.0,
  debtServiceRatio: '3.4x (अत्यधिक सुरक्षित रीपेमेंट क्षमता)',
  repaymentModel: 'दूध बिक्री से ₹125/दिन की स्वचालित माइक्रो-ईएमआई कटौती (Zero-Burden Daily Escrow)',
);
