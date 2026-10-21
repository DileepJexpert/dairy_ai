import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/collection_models.dart';
import '../providers/collection_provider.dart';

/// Comprehensive Farmer Milk Collection Passbook & Rate Calculator Screen.
/// Provides daily Dugdha Parchi slips, 10-day settlement progress, and live Fat/SNF calculations.
class FarmerPassbookScreen extends ConsumerStatefulWidget {
  const FarmerPassbookScreen({super.key});

  @override
  ConsumerState<FarmerPassbookScreen> createState() =>
      _FarmerPassbookScreenState();
}

class _FarmerPassbookScreenState extends ConsumerState<FarmerPassbookScreen> {
  // Calculator state
  String _calcMilkType = 'cow'; // 'cow' or 'buffalo'
  double _calcLitres = 35.0;
  double _calcFat = 4.4;
  double _calcSnf = 8.7;

  // Filter state
  String _selectedFilter = 'all'; // 'all', 'morning', 'evening'

  // Cooperative rate calculation formula (Fat * 6.5 + SNF * 2.2 + Grade bonus)
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

  Widget _slipRow(String label, String value,
      {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
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
    final user = ref.watch(currentUserProvider);

    final calcResult = _calculateRate(_calcFat, _calcSnf, _calcLitres);

    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: const Text('दूध पासबुक व पर्ची (Dugdha Passbook)'),
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
          TextButton.icon(
            onPressed: () => _showAddPourDialog(context),
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            label: const Text('Add Pour',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
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
                    // ---- 1. 10-DAY SETTLEMENT SUMMARY CARD ----
                    _buildSettlementCard(passbook.summary, passbook.farmerName),
                    const SizedBox(height: 20),

                    // ---- 2. INTERACTIVE MILK RATE CALCULATOR ----
                    _buildRateCalculatorCard(calcResult),
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
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text('No milk collection records found.'),
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

  Widget _buildSettlementCard(
      FarmerPassbookSummary summary, String farmerName) {
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
                child: const Text('10-Day Dugdhadan Cycle',
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

          // 3-Metric Row
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
          const SizedBox(height: 14),

          // Payout status note
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, color: Colors.amberAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Direct Bank / UPI Settlement scheduled on 01 Nov 2026. Zero deductions applied.',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
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

  Widget _buildRateCalculatorCard(Map<String, dynamic> result) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_outlined,
                      color: Color(0xff064e3b), size: 20),
                  SizedBox(width: 8),
                  Text('Interactive Milk Rate Calculator',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff064e3b))),
                ],
              ),
              // Milk Type Toggle
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
                      _calcFat = 4.4;
                      _calcSnf = 8.7;
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

          // 3 Controls: Litres, Fat, SNF
          Row(
            children: [
              // Litres Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Volume: ${_calcLitres.toStringAsFixed(1)} L',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Slider(
                      value: _calcLitres,
                      min: 5,
                      max: 60,
                      divisions: 55,
                      activeColor: const Color(0xff064e3b),
                      onChanged: (v) => setState(() => _calcLitres = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Fat Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fat: ${_calcFat.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Slider(
                      value: _calcFat,
                      min: 3.0,
                      max: 9.0,
                      divisions: 60,
                      activeColor: Colors.amber.shade800,
                      onChanged: (v) => setState(() => _calcFat = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // SNF Slider
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SNF: ${_calcSnf.toStringAsFixed(1)}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    Slider(
                      value: _calcSnf,
                      min: 7.5,
                      max: 10.0,
                      divisions: 25,
                      activeColor: Colors.blue,
                      onChanged: (v) => setState(() => _calcSnf = v),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Result Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffbbf7d0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Rate',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                    Text(
                      '₹${result['rate']} / L',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff064e3b)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Grade & Incentive',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                    Row(
                      children: [
                        Text('Grade ${result['grade']}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff047857))),
                        if (result['bonus'] > 0)
                          Text(' (+₹${result['bonus']})',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.green)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Estimated Payout',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                    Text(
                      '₹${result['total']}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xff064e3b)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
