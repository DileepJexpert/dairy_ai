import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';
import 'package:dairy_ai/shared/widgets/farmer_responsive.dart';
import '../models/collection_models.dart';
import '../providers/collection_provider.dart';

/// Model representing a buyer's calculated rate and payout.
class BuyerComparisonModel {
  final String buyerName;
  final String formulaType;
  final Color brandColor;
  final double ratePerLitre;
  final double dailyPayout;
  final double monthlyRevenue;
  final String badge;
  final bool isPremiumDirect;

  const BuyerComparisonModel({
    required this.buyerName,
    required this.formulaType,
    required this.brandColor,
    required this.ratePerLitre,
    required this.dailyPayout,
    required this.monthlyRevenue,
    required this.badge,
    this.isPremiumDirect = false,
  });
}

/// Comprehensive Farmer Milk Collection Passbook, Dynamic Rate Chart & KCC Statement Screen.
/// Provides:
/// 1. Dynamic multi-dairy rate comparison (Amul, Mother Dairy, State Fed, BMC TS, Milterra A2).
/// 2. Interactive 2D Fat x SNF rate matrix chart.
/// 3. 10/15-day settlement cycle progress & official Kisan Credit Card (KCC) dossier.
/// 4. 1-Click WhatsApp passbook share and thermal Dugdha Parchi slips.
class FarmerPassbookScreen extends ConsumerStatefulWidget {
  const FarmerPassbookScreen({super.key});

  @override
  ConsumerState<FarmerPassbookScreen> createState() =>
      _FarmerPassbookScreenState();
}

class _FarmerPassbookScreenState extends ConsumerState<FarmerPassbookScreen> {
  // Calculator state
  String _calcMilkType = 'cow'; // 'cow' or 'buffalo'
  double _calcLitres = 25.0;
  double _calcFat = 4.2;
  double _calcSnf = 8.6;
  bool _showRateMatrix = false;

  // Filter state
  String _selectedFilter = 'all'; // 'all', 'morning', 'evening'

  // Cooperative multi-buyer pricing engine
  List<BuyerComparisonModel> _getBuyerComparisons(
      double fat, double snf, double litres) {
    final isCow = _calcMilkType == 'cow';
    final List<BuyerComparisonModel> list = [];

    // 1. Amul (GCMMF Two-Axis Model)
    // Cow: Base 36.50 @ 3.5/8.5. Buffalo: Base 58.50 @ 6.0/9.0
    double amulRate;
    if (isCow) {
      amulRate = 36.50 + ((fat - 3.5) * 3.8) + ((snf - 8.5) * 2.6);
      if (fat >= 4.2 && snf >= 8.6) amulRate += 1.20; // Grade A incentive
    } else {
      amulRate = 58.50 + ((fat - 6.0) * 6.4) + ((snf - 9.0) * 3.2);
      if (fat >= 7.0 && snf >= 9.0) amulRate += 2.00;
    }
    amulRate = math.max(0.0, amulRate);

    // 2. Mother Dairy (Metro Cooperative Model)
    double motherDairyRate;
    if (isCow) {
      motherDairyRate = 36.00 + ((fat - 3.5) * 3.6) + ((snf - 8.5) * 2.4);
      if (fat >= 4.0) motherDairyRate += 1.00;
    } else {
      motherDairyRate = 57.80 + ((fat - 6.0) * 6.0) + ((snf - 9.0) * 3.0);
    }
    motherDairyRate = math.max(0.0, motherDairyRate);

    // 3. State Dairy Federation (Parag / Saras / Gokul)
    double stateFedRate;
    if (isCow) {
      stateFedRate = 34.80 + ((fat - 3.5) * 3.4) + ((snf - 8.5) * 2.2);
    } else {
      stateFedRate = 55.50 + ((fat - 6.0) * 5.6) + ((snf - 9.0) * 2.8);
    }
    stateFedRate = math.max(0.0, stateFedRate);

    // 4. Local BMC Center (Total Solids - TS Model: TS = Fat + SNF)
    final ts = fat + snf;
    final tsMultiplier = isCow ? 3.22 : 3.85;
    final double bmcRate = math.max(0.0, ts * tsMultiplier);

    // 5. Milterra A2 Vedic Direct (Premium Retail Quality Model)
    double milterraRate;
    if (isCow) {
      milterraRate = 55.00;
      if (fat >= 4.2 && snf >= 8.6) milterraRate = 62.00;
      if (fat >= 4.5 && snf >= 8.8) milterraRate = 68.00;
    } else {
      milterraRate = 72.00;
      if (fat >= 6.8 && snf >= 9.0) milterraRate = 78.00;
      if (fat >= 7.5) milterraRate = 85.00;
    }

    list.add(BuyerComparisonModel(
      buyerName: 'अमूल (Amul / GCMMF)',
      formulaType: 'द्वि-अक्षीय सूत्र (Two-Axis Fat + SNF)',
      brandColor: const Color(0xff1e40af),
      ratePerLitre: amulRate,
      dailyPayout: amulRate * litres,
      monthlyRevenue: amulRate * litres * 30,
      badge: 'राष्ट्रीय सहकारी संघ',
    ));

    list.add(BuyerComparisonModel(
      buyerName: 'मदर डेयरी (Mother Dairy)',
      formulaType: 'मेट्रो मानक + फैट इंसेंटिव',
      brandColor: const Color(0xff0284c7),
      ratePerLitre: motherDairyRate,
      dailyPayout: motherDairyRate * litres,
      monthlyRevenue: motherDairyRate * litres * 30,
      badge: 'NDDB समर्थित',
    ));

    list.add(BuyerComparisonModel(
      buyerName: 'राज्य संघ (Parag/Saras/Gokul)',
      formulaType: 'राज्य सहकारी दर तालिका',
      brandColor: const Color(0xffd97706),
      ratePerLitre: stateFedRate,
      dailyPayout: stateFedRate * litres,
      monthlyRevenue: stateFedRate * litres * 30,
      badge: 'सरकारी न्यूनतम समर्थन',
    ));

    list.add(BuyerComparisonModel(
      buyerName: 'लोकल BMC (Total Solids - TS)',
      formulaType: 'कुल ठोस पदार्थ सूत्र (TS = Fat + SNF)',
      brandColor: const Color(0xff64748b),
      ratePerLitre: bmcRate,
      dailyPayout: bmcRate * litres,
      monthlyRevenue: bmcRate * litres * 30,
      badge: 'निजी चिलिंग सेंटर',
    ));

    list.add(BuyerComparisonModel(
      buyerName: 'मिल्टेरा फार्म डायरेक्ट (A2 Premium)',
      formulaType: 'गुणवत्ता-प्रमाणित शुद्ध खुदरा खरीद',
      brandColor: const Color(0xff064e3b),
      ratePerLitre: milterraRate,
      dailyPayout: milterraRate * litres,
      monthlyRevenue: milterraRate * litres * 30,
      badge: '⭐️ सर्वाधिक किसान लाभ',
      isPremiumDirect: true,
    ));

    return list;
  }

  // Cooperative rate calculation for passbook additions
  Map<String, dynamic> _calculateRate(double fat, double snf, double litres) {
    if (fat < 3.0 || snf < 7.5) {
      return {
        'rate': 0.0,
        'bonus': 0.0,
        'total': 0.0,
        'grade': 'Rejected',
        'isRejected': true,
      };
    }
    double baseRate = (fat * 6.5) + (snf * 2.2);
    String grade = 'B';
    double bonus = 0.0;
    if (fat >= 4.5 && snf >= 8.5) {
      grade = 'A';
      bonus = litres * 2.0;
    } else if (fat < 3.8 || snf < 8.2) {
      grade = 'C';
      bonus = -1.0 * litres;
    }
    double total = (litres * baseRate) + bonus;
    return {
      'rate': double.parse(baseRate.toStringAsFixed(2)),
      'bonus': double.parse(bonus.toStringAsFixed(2)),
      'total': double.parse(total.toStringAsFixed(2)),
      'grade': grade,
      'isRejected': false,
    };
  }

  void _shareViaWhatsApp(MilkCollectionRecord record, String farmerName) async {
    final text = record.whatsappSlipText ??
        '🌾 *MILTERRA DUGDHA PARCHI*\n'
            '👤 Kisan: $farmerName\n'
            '📅 Date: ${record.date} (${record.shift.toUpperCase()})\n'
            '🥛 Milk: ${record.quantityLitres} L | Fat: ${record.fatPct}% | SNF: ${record.snfPct}\n'
            '💰 Rate: ₹${record.ratePerLitre.toStringAsFixed(2)}/L\n'
            '💵 Net Amount: ₹${record.netAmount.toStringAsFixed(2)}\n'
            '✅ Status: Credited to Milterra Wallet';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareCycleViaWhatsApp(FarmerPassbookSummary summary, String farmerName,
      String currentCycle) async {
    final text = '🌾 *MILTERRA KISAN PASSBOOK & MILK BILL*\n'
        '👤 किसान (Farmer): $farmerName\n'
        '📅 चक्र अवधि (Cycle): $currentCycle (10/15-दिवसीय दुग्ध संकलन)\n'
        '----------------------------------------\n'
        '🥛 कुल दूध संकलन (Total Milk): ${summary.totalLitres.toStringAsFixed(1)} Litres\n'
        '🧪 औसत गुणवत्ता (Avg Quality): फैट ${summary.averageFatPct}% | SNF ${summary.averageSnfPct}\n'
        '💵 सकल दूध आय (Gross Payout): ₹${summary.totalNetPayout.toStringAsFixed(2)}\n'
        '✂️ चारा/अग्रिम कटौती (Deductions): ₹0.00\n'
        '🏦 शुद्ध देय बैंक राशि (Net Bank Payout): ₹${summary.totalNetPayout.toStringAsFixed(2)}\n'
        '----------------------------------------\n'
        '✅ बैंक KCC ऋण व क्रेडिट स्कोर सत्यापन हेतु अधिकृत डिजिटल पासबुक\n'
        '📲 लाइव पासबुक लिंक: https://farmers.milterrafoods.com/#/passbook\n'
        '🌿 _Milterra Foods — समृद्ध किसान, शुद्ध डेयरी_';

    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSlipDialog(
      BuildContext context, MilkCollectionRecord record, String farmerName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe2e8f0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xff064e3b).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long,
                            color: Color(0xff064e3b), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MILTERRA DAIRY NETWORK',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 0.5)),
                          Text('BMC Collection Center Parchi',
                              style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Slip Details
              _slipRow('Kisan Name', farmerName),
              _slipRow('Slip ID', record.id),
              _slipRow('Date & Shift',
                  '${record.date} (${record.shift.toUpperCase()})'),
              _slipRow('Milk Quantity', '${record.quantityLitres} Litres',
                  isBold: true),
              _slipRow('Fat %', '${record.fatPct ?? 0.0}%'),
              _slipRow('SNF %', '${record.snfPct ?? 0.0}'),
              _slipRow('Quality Grade', 'Grade ${record.milkGrade ?? 'A'}',
                  color: const Color(0xff047857)),
              const Divider(height: 16),
              _slipRow('Rate per Litre',
                  '₹${record.ratePerLitre.toStringAsFixed(2)} / L'),
              if (record.qualityBonus > 0)
                _slipRow('Quality Incentive',
                    '+₹${record.qualityBonus.toStringAsFixed(2)}',
                    color: const Color(0xff047857)),
              const Divider(height: 16),
              _slipRow(
                'Total Net Payout',
                '₹${record.netAmount.toStringAsFixed(2)}',
                isBold: true,
                fontSize: 16,
                color: const Color(0xff064e3b),
              ),

              const SizedBox(height: 20),

              // Actions
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xff25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _shareViaWhatsApp(record, farmerName);
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share Slip on WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKccStatementDialog(
      BuildContext context, FarmerPassbookData passbook) {
    final summary = passbook.summary;
    final farmerName = passbook.farmerName;
    final entries = passbook.entries;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Certificate Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xff064e3b),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MILTERRA DAIRY COOPERATIVE NETWORK',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xff064e3b),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Kisan Credit Card (KCC) Milk Payout Dossier',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xff64748b),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xffecfdf5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xffa7f3d0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: Color(0xff047857)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'अधिकृत बैंक सत्यापन — SBI, PNB, BoB एवं KCC डेयरी ऋण हेतु मान्य डिजिटल आय प्रमाण पत्र',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xff064e3b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // Farmer Bio Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('किसान का नाम (Farmer)',
                            style:
                                TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(farmerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('ग्राम / केंद्र (Village)',
                            style:
                                TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          (passbook.village != null && passbook.village!.isNotEmpty)
                              ? passbook.village!
                              : 'आनंद ग्रामीण',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('सदस्यता आईडी (Member ID)',
                            style:
                                TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(passbook.farmerId ?? 'MIL-COOP-842',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        const Text('चक्र अवधि (Settlement Cycle)',
                            style:
                                TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(summary.currentCycleName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Summary Stat Badges
              Row(
                children: [
                  _kccStatTile(
                      'कुल दूध (Litres)',
                      '${summary.totalLitres.toStringAsFixed(1)} L',
                      const Color(0xff0284c7)),
                  const SizedBox(width: 8),
                  _kccStatTile(
                      'औसत गुणवत्ता',
                      'F: ${summary.averageFatPct}% | S: ${summary.averageSnfPct}',
                      const Color(0xffd97706)),
                  const SizedBox(width: 8),
                  _kccStatTile(
                      'कुल देय राशि',
                      '₹${summary.totalNetPayout.toStringAsFixed(2)}',
                      const Color(0xff064e3b)),
                ],
              ),
              const SizedBox(height: 14),

              const Text('दैनिक दुग्ध संकलन विवरण (Collection Ledger):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),

              // Scrollable Table of Pours
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Text(
                          'इस चक्र में कोई पर्ची उपलब्ध नहीं है।',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (ctx, i) {
                          final e = entries[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 6, horizontal: 8),
                            decoration: BoxDecoration(
                              color: i % 2 == 0
                                  ? Colors.grey.shade50
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${e.date} (${e.shift[0].toUpperCase()})',
                                    style: const TextStyle(fontSize: 11)),
                                Text('${e.quantityLitres.toStringAsFixed(1)} L',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    'F: ${e.fatPct ?? 0}% | S: ${e.snfPct ?? 0}',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.black54)),
                                Text('₹${e.netAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xff064e3b))),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const Divider(height: 16),

              // Footer Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff064e3b),
                        side: const BorderSide(color: Color(0xff064e3b)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text:
                                'MILTERRA KCC STATEMENT: Kisan $farmerName, Total ${summary.totalLitres}L, Payout ₹${summary.totalNetPayout}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('स्टेटमेंट कॉपी किया गया (Copied)')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('कॉपी करें (Copy)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff25D366),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _shareCycleViaWhatsApp(
                            summary, farmerName, summary.currentCycleName);
                      },
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('व्हाट्सएप शेयर',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kccStatTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _slipRow(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Text(value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? Colors.black87,
              )),
        ],
      ),
    );
  }

  void _showAddPourDialog(BuildContext context) {
    double litres = 30.0;
    double fat = 4.3;
    double snf = 8.6;
    String shift = 'morning';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final res = _calculateRate(fat, snf, litres);
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Today’s Milk Pour',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff064e3b))),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Text(
                  'Record morning or evening pour to calculate rate and update passbook.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Shift toggle
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wb_sunny_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Morning Pour'),
                          ],
                        ),
                        selected: shift == 'morning',
                        selectedColor: const Color(0xff047857),
                        labelStyle: TextStyle(
                            color: shift == 'morning'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold),
                        onSelected: (_) =>
                            setModalState(() => shift = 'morning'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.nightlight_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('Evening Pour'),
                          ],
                        ),
                        selected: shift == 'evening',
                        selectedColor: const Color(0xff047857),
                        labelStyle: TextStyle(
                            color: shift == 'evening'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold),
                        onSelected: (_) =>
                            setModalState(() => shift = 'evening'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Litres input
                Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text('Milk Quantity (L):',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 6,
                      child: Slider(
                        value: litres,
                        min: 5,
                        max: 60,
                        divisions: 55,
                        activeColor: const Color(0xff047857),
                        label: '${litres.toStringAsFixed(1)} L',
                        onChanged: (v) => setModalState(() => litres = v),
                      ),
                    ),
                    Text('${litres.toStringAsFixed(1)} L',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),

                // Fat input
                Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text('Fat % (चिकनाई):',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 6,
                      child: Slider(
                        value: fat,
                        min: 3.0,
                        max: 7.0,
                        divisions: 40,
                        activeColor: Colors.amber.shade800,
                        label: '${fat.toStringAsFixed(1)}%',
                        onChanged: (v) => setModalState(() => fat = v),
                      ),
                    ),
                    Text('${fat.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),

                // SNF input
                Row(
                  children: [
                    const Expanded(
                      flex: 4,
                      child: Text('SNF % (एस.एन.एफ):',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      flex: 6,
                      child: Slider(
                        value: snf,
                        min: 7.5,
                        max: 9.5,
                        divisions: 20,
                        activeColor: Colors.blue,
                        label: '${snf.toStringAsFixed(1)}%',
                        onChanged: (v) => setModalState(() => snf = v),
                      ),
                    ),
                    Text('${snf.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),

                // Live Preview Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0fdf4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffbbf7d0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Computed Rate',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black54)),
                          Text('₹${res['rate']}/L',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff064e3b))),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Grade',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black54)),
                          Text('Grade ${res['grade']}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff047857))),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Net Payout',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.black54)),
                          Text('₹${res['total']}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xff064e3b))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff064e3b),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xff064e3b),
                        content: Text(
                            'Recorded ${litres.toStringAsFixed(1)}L pour! Net payout ₹${res['total']} added to Passbook.'),
                      ),
                    );
                  },
                  child: const Text('Record & Generate Slip',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passbookAsync = ref.watch(farmerPassbookProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    final buyers = _getBuyerComparisons(_calcFat, _calcSnf, _calcLitres);

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: Text(
          FarmerBreakpoints.isMobile(context)
              ? 'दूध दर व पासबुक'
              : 'दूध दर सूची कैलकुलेटर व KCC पासबुक',
        ),
        backgroundColor: const Color(0xff064e3b),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Add Milk Pour',
            onPressed: () => _showAddPourDialog(context),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          ),
          const FarmerAuthAction(nextRoute: '/passbook', color: Colors.white),
          const SizedBox(width: 8),
        ],
      ),
      body: passbookAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading passbook: $err'),
        ),
        data: (passbook) {
          final entries = passbook.entries.where((e) {
            if (_selectedFilter == 'morning') return e.shift == 'morning';
            if (_selectedFilter == 'evening') return e.shift == 'evening';
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isAuthenticated) ...[
                      _buildGuestPassbookNotice(context),
                      const SizedBox(height: 16),
                    ],

                    // ---- 1. 10/15-DAY SETTLEMENT SUMMARY & KCC DOSSIER CARD ----
                    _buildSettlementCard(passbook),
                    const SizedBox(height: 20),

                    // ---- 2. DYNAMIC MILK RATE CALCULATOR & MULTI-BUYER COMPARISON ----
                    _buildDynamicRateCalculatorCard(buyers),
                    const SizedBox(height: 24),

                    // ---- 3. PASSBOOK COLLECTION LEDGER ----
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Milk Pours & Slips',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff064e3b)),
                        ),
                        // Filter chips
                        Row(
                          children: [
                            _filterChip('all', 'All'),
                            const SizedBox(width: 6),
                            _filterChip('morning', '☀️ Morning'),
                            const SizedBox(width: 6),
                            _filterChip('evening', '🌙 Evening'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (entries.isEmpty)
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xffe2e8f0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long_outlined,
                                  size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text(
                                'No milk collection records found for this cycle.',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap "Add Pour" or visit BMC center to record your daily collection.',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xff064e3b),
                                ),
                                onPressed: () => _showAddPourDialog(context),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Add Milk Pour'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final rec = entries[idx];
                          return _buildCollectionCard(rec, passbook.farmerName);
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuestPassbookNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffef3c7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xfffde68a)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xff92400e), size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'अतिथि मोड (Guest Mode)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xff92400e),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'दूध दर कैलकुलेटर, 2D दर तालिका व मल्टी-डेयरी तुलना पूर्णतः सक्रिय है। अपने पासबुक रिकॉर्ड सुरक्षित करने हेतु लॉगिन करें।',
                  style: TextStyle(fontSize: 11, color: Color(0xff78350f)),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff92400e),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            onPressed: () => context.push('/login?next=/passbook'),
            child: const Text('लॉगिन करें',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xff064e3b),
      labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontSize: 11,
          fontWeight: FontWeight.bold),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildSettlementCard(FarmerPassbookData passbook) {
    final summary = passbook.summary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff064e3b), Color(0xff047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1a000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    summary.currentCycleName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('10/15-Day Dugdha Cycle',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Total Net Milk Earnings (This Cycle)',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '₹${summary.totalNetPayout.toStringAsFixed(2)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 14),

          // 4-Metric Row
          Row(
            children: [
              _summaryMetric('Total Litres',
                  '${summary.totalLitres.toStringAsFixed(1)} L'),
              _summaryMetric('Avg. Fat', '${summary.averageFatPct}%'),
              _summaryMetric('Avg. SNF', '${summary.averageSnfPct}'),
              _summaryMetric(
                  'Days Left', '${summary.cycleDaysRemaining} Days'),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: WhatsApp Share & KCC Dossier Dialog
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _shareCycleViaWhatsApp(
                      summary, passbook.farmerName, summary.currentCycleName),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('व्हाट्सएप पर पासबुक भेजें',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showKccStatementDialog(context, passbook),
                  icon: const Icon(Icons.picture_as_pdf_outlined,
                      size: 16, color: Colors.white),
                  label: const Text('KCC बैंक डॉसियर',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDynamicRateCalculatorCard(List<BuyerComparisonModel> buyers) {
    final highestBuyer = buyers.reduce(
        (curr, next) => curr.ratePerLitre > next.ratePerLitre ? curr : next);
    final amulBuyer = buyers.firstWhere(
      (b) => b.buyerName.contains('Amul'),
      orElse: () => buyers.first,
    );
    final extraPerLitre = highestBuyer.ratePerLitre - amulBuyer.ratePerLitre;
    final monthlyExtra = extraPerLitre * _calcLitres * 30;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Milk Type Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_outlined,
                      color: Color(0xff064e3b), size: 22),
                  SizedBox(width: 8),
                  Text('Dynamic Milk Rate Calculator',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff064e3b))),
                ],
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Cow (गाय)'),
                    selected: _calcMilkType == 'cow',
                    selectedColor: const Color(0xff064e3b),
                    labelStyle: TextStyle(
                        fontSize: 11,
                        color: _calcMilkType == 'cow'
                            ? Colors.white
                            : Colors.black87),
                    onSelected: (_) => setState(() {
                      _calcMilkType = 'cow';
                      _calcFat = 4.2;
                      _calcSnf = 8.6;
                    }),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('Buffalo (भैंस)'),
                    selected: _calcMilkType == 'buffalo',
                    selectedColor: const Color(0xff064e3b),
                    labelStyle: TextStyle(
                        fontSize: 11,
                        color: _calcMilkType == 'buffalo'
                            ? Colors.white
                            : Colors.black87),
                    onSelected: (_) => setState(() {
                      _calcMilkType = 'buffalo';
                      _calcFat = 6.8;
                      _calcSnf = 9.0;
                    }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Controls: Litres, Fat %, SNF %
          Row(
            children: [
              // Litres Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('दैनिक दूध: ${_calcLitres.toStringAsFixed(0)} L',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Slider(
                      value: _calcLitres,
                      min: 5,
                      max: 100,
                      divisions: 95,
                      activeColor: const Color(0xff064e3b),
                      onChanged: (v) => setState(() => _calcLitres = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Fat Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('फैट (Fat): ${_calcFat.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Slider(
                      value: _calcFat,
                      min: 2.5,
                      max: 9.5,
                      divisions: 70,
                      activeColor: Colors.amber.shade800,
                      onChanged: (v) => setState(() => _calcFat = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // SNF Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('एस.एन.एफ (SNF): ${_calcSnf.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Slider(
                      value: _calcSnf,
                      min: 7.0,
                      max: 10.0,
                      divisions: 30,
                      activeColor: Colors.blue,
                      onChanged: (v) => setState(() => _calcSnf = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Best Price Insight Banner
          if (extraPerLitre > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xffecfdf5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xffa7f3d0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on,
                      color: Color(0xff047857), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '💡 इस गुणवत्ता पर ${highestBuyer.buyerName} सबसे अधिक ₹${highestBuyer.ratePerLitre.toStringAsFixed(2)}/L दे रहा है (+₹${extraPerLitre.toStringAsFixed(2)}/L अधिक — मासिक ₹${monthlyExtra.toStringAsFixed(0)} अतिरिक्त मुनाफा)!',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xff064e3b),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Multi-Buyer Cards
          const Text('विभिन्न डेयरी संघों की दर तुलना (Multi-Buyer Comparison):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),

          ...buyers.map((b) => _buildBuyerTile(b, highestBuyer.buyerName)),

          const SizedBox(height: 12),

          // 2D Rate Matrix Toggle
          InkWell(
            onTap: () => setState(() => _showRateMatrix = !_showRateMatrix),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xfff1f5f9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grid_on,
                          size: 18, color: Color(0xff064e3b)),
                      const SizedBox(width: 8),
                      Text(
                        _showRateMatrix
                            ? 'पूर्ण 2D दर तालिका छुपाएं (Hide Rate Grid)'
                            : 'पूर्ण 2D दर तालिका देखें (View Full Fat x SNF Rate Grid)',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff064e3b)),
                      ),
                    ],
                  ),
                  Icon(
                    _showRateMatrix
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xff064e3b),
                  ),
                ],
              ),
            ),
          ),

          if (_showRateMatrix) ...[
            const SizedBox(height: 12),
            _buildRateMatrixGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildBuyerTile(BuyerComparisonModel buyer, String highestName) {
    final isHighest = buyer.buyerName == highestName;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isHighest ? const Color(0xfff0fdf4) : const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighest
              ? const Color(0xff22c55e)
              : const Color(0xffe2e8f0),
          width: isHighest ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: buyer.brandColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        buyer.buyerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: buyer.brandColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          buyer.badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: buyer.brandColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    buyer.formulaType,
                    style:
                        const TextStyle(fontSize: 10.5, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${buyer.ratePerLitre.toStringAsFixed(2)} / L',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: isHighest
                      ? const Color(0xff064e3b)
                      : const Color(0xff1e293b),
                ),
              ),
              Text(
                'मासिक: ₹${buyer.monthlyRevenue.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateMatrixGrid() {
    final isCow = _calcMilkType == 'cow';
    final fats = isCow
        ? [3.2, 3.5, 3.8, 4.0, 4.2, 4.5, 4.8, 5.0]
        : [5.5, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5];
    final snfs = [8.0, 8.2, 8.4, 8.5, 8.6, 8.8, 9.0];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xffcbd5e1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 34,
          headingRowColor: WidgetStateProperty.all(const Color(0xff064e3b)),
          columns: [
            const DataColumn(
              label: Text('Fat %',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
            ),
            ...snfs.map(
              (s) => DataColumn(
                label: Text('$s SNF',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ),
          ],
          rows: fats.map((f) {
            final isCurrentFat = (f - _calcFat).abs() < 0.15;
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (isCurrentFat) {
                  return const Color(0xffecfdf5);
                }
                return null;
              }),
              cells: [
                DataCell(
                  Text('$f%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isCurrentFat
                            ? const Color(0xff064e3b)
                            : Colors.black87,
                      )),
                ),
                ...snfs.map((s) {
                  final isCurrentCell = isCurrentFat && (s - _calcSnf).abs() < 0.1;
                  double rate;
                  if (isCow) {
                    rate = 36.50 + ((f - 3.5) * 3.8) + ((s - 8.5) * 2.6);
                  } else {
                    rate = 58.50 + ((f - 6.0) * 6.4) + ((s - 9.0) * 3.2);
                  }
                  return DataCell(
                    InkWell(
                      onTap: () => setState(() {
                        _calcFat = f;
                        _calcSnf = s;
                      }),
                      child: Text(
                        '₹${rate.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isCurrentCell
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrentCell
                              ? const Color(0xff047857)
                              : Colors.black87,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCollectionCard(MilkCollectionRecord record, String farmerName) {
    final isMorning = record.shift == 'morning';
    final formattedDate = record.date;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xffe2e8f0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Shift Icon Circle
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMorning
                    ? Colors.amber.shade50
                    : Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMorning ? Icons.wb_sunny : Icons.nightlight_round,
                color: isMorning ? Colors.amber.shade800 : Colors.indigo,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isMorning ? 'Morning Pour' : 'Evening Pour',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xff047857).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Grade ${record.milkGrade ?? 'A'}',
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff047857)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formattedDate · Fat: ${record.fatPct}% · SNF: ${record.snfPct} · Rate: ₹${record.ratePerLitre.toStringAsFixed(2)}/L',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),

            // Payout and Action
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.quantityLitres.toStringAsFixed(1)} L',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '₹${record.netAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Color(0xff064e3b)),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Slip Button
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined,
                  color: Color(0xff064e3b)),
              tooltip: 'View Dugdha Parchi Slip',
              onPressed: () => _showSlipDialog(context, record, farmerName),
            ),

            // WhatsApp Share
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Color(0xff25D366)),
              tooltip: 'Share on WhatsApp',
              onPressed: () => _shareViaWhatsApp(record, farmerName),
            ),
          ],
        ),
      ),
    );
  }
}
