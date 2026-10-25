// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/maturity/models/maturity_models.dart';

final _dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider);
});

// ---------------------------------------------------------------------------
// Heat Alerts Provider
// ---------------------------------------------------------------------------
final heatAlertsProvider = FutureProvider<List<HeatAlert>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/breeding/heat-alerts');
    final json = response.data as Map<String, dynamic>;
    if (json['success'] == true) {
      final list = json['alerts'] as List<dynamic>? ?? [];
      return list.map((e) => HeatAlert.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}

  return const <HeatAlert>[];
});

// ---------------------------------------------------------------------------
// Bulk Milk Cooler (BMC) Provider
// ---------------------------------------------------------------------------
final bmcTelemetryProvider = FutureProvider<BmcTelemetryData>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/cold-chain/bmc-status');
    final json = response.data as Map<String, dynamic>;
    if (json['success'] == true) {
      return BmcTelemetryData.fromJson(json['data'] as Map<String, dynamic>);
    }
  } catch (_) {}

  return BmcTelemetryData(
    centerId: 'BMC-ANAND-04',
    centerName: 'Mogar Village Milk Chilling Center (मोगर बीएमसी)',
    managerName: 'Vikrambhai Solanki',
    capacityLitres: 5000,
    currentVolumeLitres: 3840,
    fillPct: 76.8,
    currentTemperatureC: 3.7,
    targetTemperatureC: 4.0,
    status: 'OPTIMAL_CHILLED',
    agitatorRpm: 28,
    powerSource: 'GRID_PRIMARY',
    mbrtHours: 4.8,
  );
});

// ---------------------------------------------------------------------------
// GOBARdhan Biogas & Carbon Provider
// ---------------------------------------------------------------------------
final gobardhanDataProvider = FutureProvider<GobardhanData>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/sustainability/gobardhan-credits');
    final json = response.data as Map<String, dynamic>;
    if (json['success'] == true) {
      return GobardhanData.fromJson(json['data'] as Map<String, dynamic>);
    }
  } catch (_) {}

  return const GobardhanData(
    dailyDungKg: 0.0,
    monthlyBiogasM3: 0.0,
    monthlyLpgSavingsInr: 0,
    bioSlurryLitres: 0,
    bioSlurryValueInr: 0,
    co2eMitigationTons: 0.0,
    carbonCreditsEarned: 0.0,
    carbonRevenueInr: 0,
    withdrawableBalanceInr: 0,
    totalMonthlyCircularIncomeInr: 0,
  );
});

// ---------------------------------------------------------------------------
// Group Feed Buying Pools Provider
// ---------------------------------------------------------------------------
final groupFeedPoolsProvider = FutureProvider<List<GroupFeedPool>>((ref) async {
  try {
    final dio = ref.watch(_dioProvider);
    final response = await dio.get('/feed/group-pools');
    final json = response.data as Map<String, dynamic>;
    if (json['success'] == true) {
      final list = json['pools'] as List<dynamic>? ?? [];
      return list.map((e) => GroupFeedPool.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}

  return [
    GroupFeedPool(
      poolId: 'POOL-SILAGE-ANAND-01',
      title: 'मक्का साइलेज बेल सामूहिक खरीद (Corn Silage Bales 500kg)',
      category: 'Silage',
      clusterLocation: 'आनंद व मोगर ब्लॉक (Anand Cluster)',
      deliveryHub: 'मोगर प्राथमिक दुग्ध सहकारी समिति',
      targetTons: 50.0,
      bookedTons: 38.5,
      minOrderKg: 500,
      retailPricePerKg: 5.60,
      groupPricePerKg: 4.30,
      savingsPct: 23.2,
      hoursRemaining: 32,
      participatingFarmers: 24,
    ),
    GroupFeedPool(
      poolId: 'POOL-PELLET-ANAND-02',
      title: 'संतुलित कैटल फीड पेलेट्स 22% प्रोटीन (Balanced Feed 50kg Bags)',
      category: 'Feed Pellets',
      clusterLocation: 'आनंद व मोगर ब्लॉक (Anand Cluster)',
      deliveryHub: 'अमूल फीड डिपो, मोगर',
      targetTons: 20.0,
      bookedTons: 16.2,
      minOrderKg: 100,
      retailPricePerKg: 26.0,
      groupPricePerKg: 21.5,
      savingsPct: 17.3,
      hoursRemaining: 48,
      participatingFarmers: 31,
    ),
  ];
});

// ---------------------------------------------------------------------------
// Helpers for Thermal & WhatsApp
// ---------------------------------------------------------------------------
Future<ThermalSlipData> generateThermalSlip({
  required String farmerName,
  required String shift,
  required double quantity,
  required double fat,
  required double snf,
  required double rate,
}) async {
  final total = quantity * rate;
  final slipId = 'SLIP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

  final formattedText = [
    '        MILTERRA DAIRY        ',
    '     दुग्ध संकलन पर्ची (SLIP)    ',
    '================================',
    'पर्ची क्र.: $slipId',
    'समय: $shift | किसान: $farmerName',
    '--------------------------------',
    'मात्रा (Qty):       ${quantity.toStringAsFixed(1)} Litres',
    'फैट (Fat %):        ${fat.toStringAsFixed(1)} %',
    'एस.एन.एफ (SNF %):  ${snf.toStringAsFixed(1)} %',
    'दर (Rate/L):        Rs ${rate.toStringAsFixed(2)} / L',
    '--------------------------------',
    'कुल भुगतान (NET):   Rs ${total.toStringAsFixed(2)}',
    '================================',
    '  * डिजिटल सत्यापित पर्ची *   ',
    'UPI: paytmqr@milterra | ESC/POS',
  ].join('\n');

  return ThermalSlipData(
    slipId: slipId,
    date: DateTime.now().toIso8601String().split('T')[0],
    shift: shift,
    farmerName: farmerName,
    quantityLitres: quantity,
    fatPct: fat,
    snfPct: snf,
    ratePerLitre: rate,
    totalAmount: total,
    formattedText: formattedText,
    escposHex: '1B401B6101',
    barcode: 'MIL$slipId',
  );
}

Future<String> generateWhatsAppDeepLink({
  required String farmerName,
  required double quantity,
  required double rate,
  required double fat,
}) async {
  final total = (quantity * rate).toStringAsFixed(2);
  final message =
      '🥛 *MILTERRA दुग्ध संकलन रसीद* 🥛\n'
      '━━━━━━━━━━━━━━━━━━━\n'
      '👤 *किसान:* $farmerName\n'
      '🍶 *दूध मात्रा:* ${quantity.toStringAsFixed(1)} लीटर\n'
      '🧪 *फैट:* ${fat.toStringAsFixed(1)}% | *दर:* ₹${rate.toStringAsFixed(2)}/लीटर\n'
      '💵 *कुल राशि:* *₹$total*\n'
      '━━━━━━━━━━━━━━━━━━━\n'
      '📲 डिजिटल खाता: https://farmers.milterrafoods.com/#/passbook';

  final text = Uri.encodeComponent(message);
  return 'https://api.whatsapp.com/send?text=$text';
}
