import 'package:flutter/material.dart';
import 'package:dairy_ai/features/milk/widgets/thermal_slip_dialog.dart';

/// A selectable milk slip item.
class MilkSlipOption {
  final String slipId;
  final String title;
  final String shift;
  final String date;
  final String tagId;
  final String centerName;
  final double quantityLitres;
  final double fatPct;
  final double snfPct;
  final double ratePerLitre;
  final String? statusBadge;
  final bool isLatest;

  const MilkSlipOption({
    required this.slipId,
    required this.title,
    required this.shift,
    required this.date,
    required this.tagId,
    required this.centerName,
    required this.quantityLitres,
    required this.fatPct,
    required this.snfPct,
    required this.ratePerLitre,
    this.statusBadge,
    this.isLatest = false,
  });

  double get totalAmount => quantityLitres * ratePerLitre;
}

/// Interactive Slip Picker Modal allowing the farmer to choose which slip to print,
/// or create an on-demand custom slip.
class MilkSlipSelectorModal extends StatefulWidget {
  final String farmerName;

  const MilkSlipSelectorModal({
    super.key,
    required this.farmerName,
  });

  @override
  State<MilkSlipSelectorModal> createState() => _MilkSlipSelectorModalState();
}

class _MilkSlipSelectorModalState extends State<MilkSlipSelectorModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Custom Slip Form State
  String _customShift = 'MORNING';
  final _customTagController = TextEditingController(text: 'MIL-0842 (Ganga)');
  final _customCenterController =
      TextEditingController(text: 'सरस दुग्ध सहकारी समिति (BMC-402)');
  final _customLitresController = TextEditingController(text: '12.5');
  final _customFatController = TextEditingController(text: '4.8');
  final _customSnfController = TextEditingController(text: '8.9');
  final _customRateController = TextEditingController(text: '42.00');

  late final List<MilkSlipOption> _recentSlips;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _recentSlips = [
      const MilkSlipOption(
        slipId: 'SLIP-TODAY-01',
        title: 'आज प्रातः (Today Morning)',
        shift: 'MORNING',
        date: '22 Oct 2026',
        tagId: 'MIL-0842 (Ganga गाय)',
        centerName: 'सरस दुग्ध सहकारी समिति (BMC-402)',
        quantityLitres: 12.5,
        fatPct: 4.8,
        snfPct: 8.9,
        ratePerLitre: 42.00,
        statusBadge: '✅ नवीनतम प्रविष्टि',
        isLatest: true,
      ),
      const MilkSlipOption(
        slipId: 'SLIP-TODAY-02',
        title: 'आज सांय (Today Evening)',
        shift: 'EVENING',
        date: '22 Oct 2026',
        tagId: 'MIL-1024 (Murrah भैंस)',
        centerName: 'स्थानीय डेयरी / निजी संकलन',
        quantityLitres: 14.0,
        fatPct: 7.2,
        snfPct: 9.3,
        ratePerLitre: 62.00,
        statusBadge: '✅ उच्च गुणवत्ता फैट',
      ),
      const MilkSlipOption(
        slipId: 'PARCHI-8892',
        title: 'कल सांय (Yesterday Evening)',
        shift: 'EVENING',
        date: '21 Oct 2026',
        tagId: 'सहकारी समिति बल्क',
        centerName: 'सरस दुग्ध सहकारी समिति (BMC-402)',
        quantityLitres: 95.0,
        fatPct: 4.30,
        snfPct: 8.60,
        ratePerLitre: 42.50,
        statusBadge: '✅ 100% Matched',
      ),
      const MilkSlipOption(
        slipId: 'PARCHI-8841',
        title: 'कल प्रातः (Yesterday Morning)',
        shift: 'MORNING',
        date: '21 Oct 2026',
        tagId: 'सहकारी समिति बल्क',
        centerName: 'सरस दुग्ध सहकारी समिति (BMC-402)',
        quantityLitres: 98.2,
        fatPct: 4.05,
        snfPct: 8.35,
        ratePerLitre: 40.50,
        statusBadge: '⚠️ -1.8L Shortage',
      ),
      const MilkSlipOption(
        slipId: 'PARCHI-8710',
        title: '20 Oct 2026 (प्रातः)',
        shift: 'MORNING',
        date: '20 Oct 2026',
        tagId: 'अमूल चिलिंग व बल्क',
        centerName: 'अमूल चिलिंग सेंटर (BMC-518)',
        quantityLitres: 102.0,
        fatPct: 4.25,
        snfPct: 8.55,
        ratePerLitre: 42.00,
        statusBadge: '✅ 100% Matched',
      ),
      const MilkSlipOption(
        slipId: 'PARCHI-8765',
        title: '20 Oct 2026 (सांय)',
        shift: 'EVENING',
        date: '20 Oct 2026',
        tagId: 'अमूल चिलिंग व बल्क',
        centerName: 'अमूल चिलिंग सेंटर (BMC-518)',
        quantityLitres: 89.1,
        fatPct: 4.10,
        snfPct: 8.40,
        ratePerLitre: 41.00,
        statusBadge: '⚠️ -0.9L Shortage',
      ),
    ];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customTagController.dispose();
    _customCenterController.dispose();
    _customLitresController.dispose();
    _customFatController.dispose();
    _customSnfController.dispose();
    _customRateController.dispose();
    super.dispose();
  }

  void _openThermalSlip(MilkSlipOption slip) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => ThermalSlipDialog(
        farmerName: widget.farmerName,
        tagId: slip.tagId,
        shift: slip.shift,
        quantityLitres: slip.quantityLitres,
        fatPct: slip.fatPct,
        snfPct: slip.snfPct,
        ratePerLitre: slip.ratePerLitre,
        slipId: slip.slipId,
        centerName: slip.centerName,
        date: slip.date,
      ),
    );
  }

  void _printCustomSlip() {
    final qty = double.tryParse(_customLitresController.text.trim()) ?? 10.0;
    final fat = double.tryParse(_customFatController.text.trim()) ?? 5.0;
    final snf = double.tryParse(_customSnfController.text.trim()) ?? 8.5;
    final rate = double.tryParse(_customRateController.text.trim()) ?? 45.0;

    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => ThermalSlipDialog(
        farmerName: widget.farmerName,
        tagId: _customTagController.text.trim().isEmpty
            ? 'निजी संकलन'
            : _customTagController.text.trim(),
        shift: _customShift,
        quantityLitres: qty,
        fatPct: fat,
        snfPct: snf,
        ratePerLitre: rate,
        slipId:
            'CUSTOM-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        centerName: _customCenterController.text.trim().isEmpty
            ? 'MILTERRA DAIRY'
            : _customCenterController.text.trim(),
        date: '22 Oct 2026',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 660),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xff064e3b),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xff047857),
                    radius: 20,
                    child: Icon(Icons.print, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'दूध पर्ची चयन (Select Milk Slip)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                color: Color(0xffa7f3d0), size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'किसान: ${widget.farmerName}',
                              style: const TextStyle(
                                color: Color(0xffa7f3d0),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xff064e3b),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xff064e3b),
              indicatorWeight: 3,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.receipt_long, size: 18),
                  text: 'हाल की पर्चियां (Recent)',
                ),
                Tab(
                  icon: Icon(Icons.edit_note, size: 18),
                  text: 'कस्टम पर्ची (Custom Slip)',
                ),
              ],
            ),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRecentSlipsList(),
                  _buildCustomSlipForm(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSlipsList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _recentSlips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final slip = _recentSlips[index];
        final isSelectedHighlight = slip.isLatest;

        return Container(
          decoration: BoxDecoration(
            color: isSelectedHighlight
                ? const Color(0xffecfdf5)
                : const Color(0xfff8fafc),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelectedHighlight
                  ? const Color(0xff047857)
                  : const Color(0xffe2e8f0),
              width: isSelectedHighlight ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        slip.shift == 'MORNING'
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_round,
                        size: 16,
                        color: slip.shift == 'MORNING'
                            ? Colors.amber.shade800
                            : Colors.indigo,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        slip.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xff0f172a),
                        ),
                      ),
                    ],
                  ),
                  if (slip.statusBadge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: slip.statusBadge!.contains('Shortage')
                            ? const Color(0xfffee2e2)
                            : const Color(0xffdcfce7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        slip.statusBadge!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: slip.statusBadge!.contains('Shortage')
                              ? const Color(0xff991b1b)
                              : const Color(0xff166534),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'पर्ची: ${slip.slipId} • केंद्र: ${slip.centerName}',
                style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
              ),
              Text(
                'स्रोत/पशु: ${slip.tagId}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff334155),
                ),
              ),
              const Divider(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'मात्रा: ${slip.quantityLitres.toStringAsFixed(1)}L  |  फैट: ${slip.fatPct.toStringAsFixed(1)}%  |  SNF: ${slip.snfPct.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xff475569)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'दर: ₹${slip.ratePerLitre.toStringAsFixed(2)}/L  ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xff475569),
                            ),
                          ),
                          Text(
                            'कुल: ₹${slip.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xff064e3b),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openThermalSlip(slip),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff064e3b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.print, size: 15),
                    label: const Text(
                      '🖨️ पर्ची देखें',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomSlipForm() {
    final qty = double.tryParse(_customLitresController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_customRateController.text.trim()) ?? 0.0;
    final total = qty * rate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'त्वरित कस्टम पर्ची बनाएं (Create Spot / Private Sale Slip)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),

          // Shift selection chips
          Row(
            children: [
              const Text('शिफ्ट (Shift): ',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('☀️ प्रातः (Morning)'),
                selected: _customShift == 'MORNING',
                selectedColor: const Color(0xffdcfce7),
                onSelected: (val) {
                  if (val) setState(() => _customShift = 'MORNING');
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('🌙 सांय (Evening)'),
                selected: _customShift == 'EVENING',
                selectedColor: const Color(0xffdcfce7),
                onSelected: (val) {
                  if (val) setState(() => _customShift = 'EVENING');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  decoration: const InputDecoration(
                    labelText: 'पशु टैग / स्रोत',
                    hintText: 'उदा. MIL-0842 / गंगा गाय',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _customCenterController,
                  decoration: const InputDecoration(
                    labelText: 'डेयरी / क्रेता केंद्र',
                    hintText: 'उदा. सरस दुग्ध समिति',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customLitresController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'मात्रा (Litres)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customFatController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'फैट % (Fat)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customSnfController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'SNF %',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customRateController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'दर ₹/L',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Total preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xff86efac)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'कुल देय राशि (Net Total):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '₹ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xff047857),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _printCustomSlip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff064e3b),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.print, size: 20),
              label: const Text(
                '🖨️ पर्ची प्रिंट व WhatsApp रसीद जारी करें',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
