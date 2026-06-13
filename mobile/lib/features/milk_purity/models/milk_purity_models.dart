class BrandSummary {
  final String id;
  final String name;
  final String slug;
  final String? parentCompany;
  final String variant;
  final double? overallScore;
  final String? band;
  final String? logoUrl;

  BrandSummary({
    required this.id,
    required this.name,
    required this.slug,
    this.parentCompany,
    required this.variant,
    this.overallScore,
    this.band,
    this.logoUrl,
  });

  factory BrandSummary.fromJson(Map<String, dynamic> json) {
    return BrandSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      parentCompany: json['parent_company'] as String?,
      variant: json['variant'] as String? ?? 'toned',
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      band: json['band'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class BrandScore {
  final BrandDetail brand;
  final ScoreDetail score;
  final List<LabReportSummary> labReports;
  final List<ViolationSummary> violations;

  BrandScore({
    required this.brand,
    required this.score,
    required this.labReports,
    required this.violations,
  });

  factory BrandScore.fromJson(Map<String, dynamic> json) {
    return BrandScore(
      brand: BrandDetail.fromJson(json['brand'] as Map<String, dynamic>),
      score: ScoreDetail.fromJson(json['score'] as Map<String, dynamic>),
      labReports: (json['lab_reports'] as List?)
              ?.map((e) =>
                  LabReportSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      violations: (json['violations'] as List?)
              ?.map((e) =>
                  ViolationSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BrandDetail {
  final String id;
  final String name;
  final String slug;
  final String? parentCompany;
  final String variant;
  final double? labelFatPct;
  final double? labelSnfPct;
  final String? fssaiLicenceNo;
  final String? logoUrl;

  BrandDetail({
    required this.id,
    required this.name,
    required this.slug,
    this.parentCompany,
    required this.variant,
    this.labelFatPct,
    this.labelSnfPct,
    this.fssaiLicenceNo,
    this.logoUrl,
  });

  factory BrandDetail.fromJson(Map<String, dynamic> json) {
    return BrandDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      parentCompany: json['parent_company'] as String?,
      variant: json['variant'] as String? ?? 'toned',
      labelFatPct: (json['label_fat_pct'] as num?)?.toDouble(),
      labelSnfPct: (json['label_snf_pct'] as num?)?.toDouble(),
      fssaiLicenceNo: json['fssai_licence_no'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class ScoreDetail {
  final double overallScore;
  final String band;
  final double fatAccuracyScore;
  final double snfComplianceScore;
  final double adulterationScore;
  final double bacterialScore;
  final double fssaiComplianceScore;
  final int dataSourcesCount;
  final bool hasLimitedData;

  ScoreDetail({
    required this.overallScore,
    required this.band,
    required this.fatAccuracyScore,
    required this.snfComplianceScore,
    required this.adulterationScore,
    required this.bacterialScore,
    required this.fssaiComplianceScore,
    required this.dataSourcesCount,
    required this.hasLimitedData,
  });

  factory ScoreDetail.fromJson(Map<String, dynamic> json) {
    return ScoreDetail(
      overallScore: (json['overall_score'] as num).toDouble(),
      band: json['band'] as String,
      fatAccuracyScore: (json['fat_accuracy_score'] as num).toDouble(),
      snfComplianceScore: (json['snf_compliance_score'] as num).toDouble(),
      adulterationScore: (json['adulteration_score'] as num).toDouble(),
      bacterialScore: (json['bacterial_score'] as num).toDouble(),
      fssaiComplianceScore:
          (json['fssai_compliance_score'] as num).toDouble(),
      dataSourcesCount: json['data_sources_count'] as int? ?? 0,
      hasLimitedData: json['has_limited_data'] as bool? ?? true,
    );
  }
}

class LabReportSummary {
  final String labName;
  final String reportDate;
  final double? actualFatPct;
  final double? actualSnfPct;
  final bool ureaDetected;
  final bool detergentDetected;

  LabReportSummary({
    required this.labName,
    required this.reportDate,
    this.actualFatPct,
    this.actualSnfPct,
    required this.ureaDetected,
    required this.detergentDetected,
  });

  factory LabReportSummary.fromJson(Map<String, dynamic> json) {
    return LabReportSummary(
      labName: json['lab_name'] as String,
      reportDate: json['report_date'] as String,
      actualFatPct: (json['actual_fat_pct'] as num?)?.toDouble(),
      actualSnfPct: (json['actual_snf_pct'] as num?)?.toDouble(),
      ureaDetected: json['urea_detected'] as bool? ?? false,
      detergentDetected: json['detergent_detected'] as bool? ?? false,
    );
  }
}

class ViolationSummary {
  final String violationDate;
  final String severity;
  final String violationType;
  final String? description;

  ViolationSummary({
    required this.violationDate,
    required this.severity,
    required this.violationType,
    this.description,
  });

  factory ViolationSummary.fromJson(Map<String, dynamic> json) {
    return ViolationSummary(
      violationDate: json['violation_date'] as String,
      severity: json['severity'] as String,
      violationType: json['violation_type'] as String,
      description: json['description'] as String?,
    );
  }
}

class CompareResult {
  final BrandScore brandA;
  final BrandScore brandB;

  CompareResult({required this.brandA, required this.brandB});

  factory CompareResult.fromJson(Map<String, dynamic> json) {
    return CompareResult(
      brandA: BrandScore.fromJson(json['brand_a'] as Map<String, dynamic>),
      brandB: BrandScore.fromJson(json['brand_b'] as Map<String, dynamic>),
    );
  }
}
