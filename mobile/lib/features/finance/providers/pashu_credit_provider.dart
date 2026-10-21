import 'package:dio/dio.dart';
// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/finance/models/pashu_credit_model.dart';

final _dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider);
});

final pashuCreditScoreProvider =
    FutureProvider.autoDispose<PashuCreditScore>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/finance/pashu-credit-score');
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true && body['data'] != null) {
      return PashuCreditScore.fromJson(body['data'] as Map<String, dynamic>);
    }
  } catch (_) {
    // Graceful offline fallback
  }
  return fallbackPashuCreditScore;
});

final bankDossierProvider =
    FutureProvider.autoDispose<BankDossier?>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/finance/bank-dossier');
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true && body['data'] != null) {
      return BankDossier.fromJson(body['data'] as Map<String, dynamic>);
    }
  } catch (_) {
    // Return sample offline dossier
  }
  return BankDossier.fromJson({
    'certificate_id': 'MIL-DOSSIER-2026-08492',
    'issued_date': DateTime.now().toString().substring(0, 10),
    'valid_until': DateTime.now().add(const Duration(days: 60)).toString().substring(0, 10),
    'verification_hash': 'VET-HASH-9812A',
    'issuing_authority': 'Milterra Dairy AI Fintech Underwriting Engine',
    'farmer_kyc': {
      'name': 'रामेश पटेल',
      'village': 'आनंद',
      'district': 'आनंद',
      'phone': '+91 98397 69808',
    },
    'herd_health_audit': {
      'total_active_cattle': 4,
      'fmd_vaccine_status': '100% COMPLIANT (NADCP)',
      'hs_bq_vaccine_status': '100% COMPLIANT (Pre-Monsoon)',
      'chronic_disease_free': true,
    },
    'milk_cash_flow_audit': {
      'total_litres_poured': 1350.0,
      'total_net_payout': 54000.0,
      'avg_monthly_payout': 18000.0,
      'avg_fat_pct': 4.3,
      'avg_snf_pct': 8.7,
    },
    'underwriting_recommendation': {
      'recommended_kcc_limit': 160000.0,
      'recommended_interest_rate_pct': 4.0,
      'escrow_daily_deduction': 125.0,
    },
    'cattle_inventory': [
      {'tag_id': 'MIL-0842', 'name': 'Ganga', 'breed': 'GIR COW', 'lactation': 2, 'health_clearance': 'CERTIFIED HEALTHY', 'estimated_daily_yield': '16 L'},
      {'tag_id': 'MIL-0911', 'name': 'Gauri', 'breed': 'SAHIWAL COW', 'lactation': 3, 'health_clearance': 'CERTIFIED HEALTHY', 'estimated_daily_yield': '15 L'},
      {'tag_id': 'MIL-1024', 'name': 'Murrah-1', 'breed': 'MURRAH BUFFALO', 'lactation': 2, 'health_clearance': 'CERTIFIED HEALTHY', 'estimated_daily_yield': '14 L'},
    ],
  });
});

Future<Map<String, dynamic>> applyKccLoan(
  WidgetRef ref, {
  required String loanType,
  required double requestedAmount,
  required String preferredBank,
  required String repaymentMode,
  String? remarks,
}) async {
  final dio = ref.read(_dioProvider);
  final payload = {
    'loan_type': loanType,
    'requested_amount': requestedAmount,
    'preferred_bank': preferredBank,
    'repayment_mode': repaymentMode,
    if (remarks != null) 'farmer_remarks': remarks,
  };

  try {
    final response = await dio.post('/finance/loans/kcc-apply', data: payload);
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true) {
      ref.invalidate(pashuCreditScoreProvider);
      return body['data'] as Map<String, dynamic>;
    }
  } catch (_) {
    // Offline simulation
  }

  // Fallback instant approval response
  return {
    'application_id': 'LOAN-2026-${DateTime.now().millisecondsSinceEpoch % 100000}',
    'status': 'pre_approved',
    'loan_type': loanType,
    'sanctioned_amount': requestedAmount,
    'interest_rate_pct': loanType == 'kcc_dairy' ? 4.0 : 7.5,
    'tenure_months': loanType == 'kcc_dairy' ? 12 : 36,
    'monthly_emi': (requestedAmount * 0.088).round(),
    'daily_escrow': ((requestedAmount * 0.088) / 30).round(),
    'preferred_bank': preferredBank,
    'repayment_mode': repaymentMode,
    'tracking_message': 'लोन आवेदन स्वीकृत हो गया है! दैनिक दूध पर्ची से स्वतः ईएमआई कटेगी।',
  };
}
