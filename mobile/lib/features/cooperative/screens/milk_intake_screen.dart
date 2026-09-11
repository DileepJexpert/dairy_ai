import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../marketplace/widgets/store_design.dart';
import '../../finance/providers/wallet_provider.dart';

class MilkIntakeScreen extends ConsumerStatefulWidget {
  const MilkIntakeScreen({super.key});

  @override
  ConsumerState<MilkIntakeScreen> createState() => _MilkIntakeScreenState();
}

class _MilkIntakeScreenState extends ConsumerState<MilkIntakeScreen> {
  final _litresCtrl = TextEditingController(text: '12.5');
  final _tempCtrl = TextEditingController(text: '28.0');

  String _selectedFarmer = 'Rameshwar Patel (FMR-1049)';
  String _selectedBreed = 'Murrah Buffalo';
  String _shift = 'Morning'; // Morning or Evening
  double _fatPct = 6.8;
  double _snfPct = 8.8;

  final List<String> _farmers = [
    'Rameshwar Patel (FMR-1049)',
    'Devendra Singh (FMR-1052)',
    'Pooja Choudhary (FMR-1088)',
    'Harishankar Sharma (FMR-1102)',
    'Mukesh Yadav (FMR-1140)',
  ];

  final List<String> _breeds = [
    'Murrah Buffalo',
    'Gir Desi Cow',
    'Sahiwal Cow',
    'Crossbred HF',
    'Jaffrabadi Buffalo',
  ];

  @override
  void dispose() {
    _litresCtrl.dispose();
    _tempCtrl.dispose();
    super.dispose();
  }

  // Rate calculation formula based on cooperative standards
  double get _baseRate => _selectedBreed.contains('Buffalo') ? 46.0 : 36.0;
  double get _fatDifference => (_fatPct - 3.5).clamp(-1.0, 6.0);
  double get _snfDifference => (_snfPct - 8.5).clamp(-1.0, 3.0);
  double get _fatIncentive => _fatDifference * 6.50;
  double get _snfIncentive => _snfDifference * 4.20;
  bool get _isGradeA => _fatPct >= 4.5 && _snfPct >= 8.8;
  double get _qualityBonus => _isGradeA ? 1.50 : 0.0;

  double get _calculatedRatePerLitre {
    final rate = _baseRate + _fatIncentive + _snfIncentive + _qualityBonus;
    return rate.clamp(28.0, 95.0);
  }

  double get _litres => double.tryParse(_litresCtrl.text.trim()) ?? 0.0;
  double get _totalPayout => (_litres * _calculatedRatePerLitre).clamp(0.0, 999999.0);

  void _submitMilkIntake() {
    if (_litres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid milk quantity in litres.')),
      );
      return;
    }

    final payout = _totalPayout;
    final rate = _calculatedRatePerLitre;
    final litres = _litres;
    final fat = _fatPct;
    final snf = _snfPct;
    final farmer = _selectedFarmer;
    final shift = _shift;
    final slipId = 'SLIP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Credit to farmer wallet
    ref.read(milterraWalletProvider.notifier).creditMilkIntake(
          amount: payout,
          litres: litres,
          fatPct: fat,
          snfPct: snf,
          farmerName: farmer,
        );

    // Show printable digital receipt
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: storeGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long, color: storeGreen, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Anand Milk Cooperative',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Digital Milk Pouring Receipt',
                            style: TextStyle(fontSize: 11, color: storeMuted)),
                      ],
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff5fdf7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xffc6ebd0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Receipt #$slipId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                      style: const TextStyle(fontSize: 11, color: storeMuted)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _receiptRow('Farmer Member', farmer),
            _receiptRow('Breed & Cattle', _selectedBreed),
            _receiptRow('Collection Shift', '$shift Shift'),
            _receiptRow('Milk Quantity', '${litres.toStringAsFixed(1)} Litres'),
            _receiptRow('Fat Content', '${fat.toStringAsFixed(1)} %'),
            _receiptRow('SNF Content', '${snf.toStringAsFixed(1)} %'),
            _receiptRow('Calculated Rate', '${storeMoney(rate)} / Litre'),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Net Instant Payout:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: storeGreen)),
                Text(storeMoney(payout),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: storeOrange)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: storeAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: storeGreen, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Successfully Credited to Farmer\'s Milterra Wallet & Available Immediately.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: storeGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Record Next'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: storeGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/balance');
                    },
                    child: const Text('View Wallet'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xff555555))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Cooperative Milk Intake'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Wrap(
                        children: [
                          InkWell(
                            onTap: () => context.go('/cooperative-dashboard'),
                            child: const Text('Cooperative', style: TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                          const Text('Milk Intake & Farmer Settlements',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Screen Title
                      const Text(
                        'Milk Collection Center Passbook',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: storeGreen),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Record daily morning & evening milk pours. Fat & SNF rate formula calculates instant settlement credited straight to the farmer\'s Milterra Wallet.',
                        style: TextStyle(fontSize: 13, color: storeMuted),
                      ),
                      const SizedBox(height: 20),

                      // Two-Column Layout for Desktop / Single column for mobile
                      LayoutBuilder(builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 720;
                        return isDesktop
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 55, child: _buildIntakeFormCard()),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 45, child: _buildRateCalculatorSummary()),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildIntakeFormCard(),
                                  const SizedBox(height: 18),
                                  _buildRateCalculatorSummary(),
                                ],
                              );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntakeFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('1. Member & Intake Details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: storeGreen)),
          const Divider(height: 20),

          // Farmer selection
          const Text('Select Farmer Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedFarmer,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _farmers
                .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) => setState(() => _selectedFarmer = val!),
          ),
          const SizedBox(height: 16),

          // Cattle Breed
          const Text('Cattle Breed / Livestock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedBreed,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: _breeds
                .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedBreed = val!;
                _fatPct = val.contains('Buffalo') ? 6.8 : 4.2;
              });
            },
          ),
          const SizedBox(height: 16),

          // Shift toggle
          const Text('Collection Shift', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _shift = 'Morning'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _shift == 'Morning' ? storeGreen : storeCream,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _shift == 'Morning' ? storeGreen : storeBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wb_sunny_outlined,
                            size: 16, color: _shift == 'Morning' ? Colors.white : storeGreen),
                        const SizedBox(width: 8),
                        Text('Morning (AM)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _shift == 'Morning' ? Colors.white : storeGreen)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _shift = 'Evening'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _shift == 'Evening' ? storeGreen : storeCream,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _shift == 'Evening' ? storeGreen : storeBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.nights_stay_outlined,
                            size: 16, color: _shift == 'Evening' ? Colors.white : storeGreen),
                        const SizedBox(width: 8),
                        Text('Evening (PM)',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _shift == 'Evening' ? Colors.white : storeGreen)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Litres Input
          const Text('Milk Quantity Poured (Litres)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _litresCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'e.g. 12.5',
              border: OutlineInputBorder(),
              suffixText: 'Litres',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [5.0, 10.0, 15.0, 20.0, 25.0].map((quick) {
              return ActionChip(
                label: Text('${quick.toStringAsFixed(0)} L', style: const TextStyle(fontSize: 11)),
                onPressed: () => setState(() => _litresCtrl.text = quick.toStringAsFixed(1)),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),

          // Fat & SNF sliders
          Text('Fat Content: ${_fatPct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Slider(
            value: _fatPct,
            min: 2.5,
            max: 10.0,
            divisions: 75,
            activeColor: storeGreen,
            label: '${_fatPct.toStringAsFixed(1)}%',
            onChanged: (val) => setState(() => _fatPct = val),
          ),

          Text('SNF Content: ${_snfPct.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Slider(
            value: _snfPct,
            min: 7.0,
            max: 11.0,
            divisions: 40,
            activeColor: storeAmber,
            label: '${_snfPct.toStringAsFixed(1)}%',
            onChanged: (val) => setState(() => _snfPct = val),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCalculatorSummary() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('2. Rate Chart & Payout',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: storeGreen)),
          const Divider(height: 20),

          // Quality Grade pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isGradeA ? const Color(0xffe6f4ea) : const Color(0xfffef7e0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _isGradeA ? const Color(0xff1e8e3e) : const Color(0xfff9ab00)),
            ),
            child: Row(
              children: [
                Icon(_isGradeA ? Icons.verified : Icons.info_outline,
                    color: _isGradeA ? const Color(0xff1e8e3e) : const Color(0xffb7791f), size: 18),
                const SizedBox(width: 8),
                Text(
                  _isGradeA ? 'Grade A Milk (Premium Fat & SNF)' : 'Standard Quality Milk',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _isGradeA ? const Color(0xff1e8e3e) : const Color(0xffb7791f),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Calculation breakdown
          _calcItem('Base Milk Price', storeMoney(_baseRate)),
          _calcItem(
            'Fat Bonus (${_fatPct.toStringAsFixed(1)}% vs 3.5%)',
            '${_fatIncentive >= 0 ? "+" : ""}${storeMoney(_fatIncentive)}',
          ),
          _calcItem(
            'SNF Bonus (${_snfPct.toStringAsFixed(1)}% vs 8.5%)',
            '${_snfIncentive >= 0 ? "+" : ""}${storeMoney(_snfIncentive)}',
          ),
          if (_qualityBonus > 0)
            _calcItem('Grade A Quality Bonus', '+${storeMoney(_qualityBonus)}', highlight: true),
          const Divider(height: 20),
          _calcItem('Net Rate per Litre', storeMoney(_calculatedRatePerLitre), isBold: true),
          _calcItem('Total Quantity', '${_litres.toStringAsFixed(1)} Litres'),
          const Divider(height: 20),

          // Total Payout Highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xfffdfaf3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffe8d8b5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Instant Farmer Settlement Amount',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeMuted)),
                const SizedBox(height: 4),
                Text(
                  storeMoney(_totalPayout),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: storeOrange),
                ),
                const SizedBox(height: 4),
                const Text('Settled immediately to member\'s Milterra Wallet',
                    style: TextStyle(fontSize: 11, color: storeGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: storeAmber,
                foregroundColor: storeGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _litres > 0 ? _submitMilkIntake : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Record & Credit Wallet Now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calcItem(String title, String value, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: highlight ? storeGreen : const Color(0xff444444),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? storeGreen : const Color(0xff111111),
            ),
          ),
        ],
      ),
    );
  }
}
