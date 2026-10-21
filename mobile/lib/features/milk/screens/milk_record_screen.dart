import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_selector/file_selector.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';

class MilkRecordScreen extends ConsumerStatefulWidget {
  const MilkRecordScreen({super.key});

  @override
  ConsumerState<MilkRecordScreen> createState() => _MilkRecordScreenState();
}

class _MilkRecordScreenState extends ConsumerState<MilkRecordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Shared date-wise archive of slips and collection records
  List<Map<String, dynamic>> _dateArchives = [
    {
      'date': '21 Oct 2026',
      'morning': {
        'totalLitres': 175.0,
        'coopLitres': 100.0,
        'hotelLitres': 50.0,
        'retailLitres': 20.0,
        'slipNumber': 'PARCHI-8841',
        'slipLitres': 98.2,
        'slipFat': 4.05,
        'slipSnf': 8.35,
        'slipRate': 40.50,
        'centerName': 'सरस दुग्ध सहकारी समिति (BMC-402)',
        'hasMismatch': true,
        'discrepancy': '-1.8L Shortage (-₹272.90)',
      },
      'evening': {
        'totalLitres': 165.0,
        'coopLitres': 95.0,
        'hotelLitres': 50.0,
        'retailLitres': 20.0,
        'slipNumber': 'PARCHI-8892',
        'slipLitres': 95.0,
        'slipFat': 4.30,
        'slipSnf': 8.60,
        'slipRate': 42.50,
        'centerName': 'सरस दुग्ध सहकारी समिति (BMC-402)',
        'hasMismatch': false,
        'discrepancy': '100% Matched',
      },
    },
    {
      'date': '20 Oct 2026',
      'morning': {
        'totalLitres': 172.0,
        'coopLitres': 102.0,
        'hotelLitres': 50.0,
        'retailLitres': 20.0,
        'slipNumber': 'PARCHI-8710',
        'slipLitres': 102.0,
        'slipFat': 4.25,
        'slipSnf': 8.55,
        'slipRate': 42.00,
        'centerName': 'अमूल चिलिंग सेंटर (BMC-518)',
        'hasMismatch': false,
        'discrepancy': '100% Matched',
      },
      'evening': {
        'totalLitres': 160.0,
        'coopLitres': 90.0,
        'hotelLitres': 50.0,
        'retailLitres': 20.0,
        'slipNumber': 'PARCHI-8765',
        'slipLitres': 89.1,
        'slipFat': 4.10,
        'slipSnf': 8.40,
        'slipRate': 41.00,
        'centerName': 'अमूल चिलिंग सेंटर (BMC-518)',
        'hasMismatch': true,
        'discrepancy': '-0.9L Shortage (-₹85.00)',
      },
    },
    {
      'date': '19 Oct 2026',
      'morning': {
        'totalLitres': 170.0,
        'coopLitres': 100.0,
        'hotelLitres': 50.0,
        'retailLitres': 20.0,
        'slipNumber': 'PARCHI-8604',
        'slipLitres': 100.0,
        'slipFat': 4.35,
        'slipSnf': 8.65,
        'slipRate': 43.00,
        'centerName': 'सरस दुग्ध सहकारी समिति (BMC-402)',
        'hasMismatch': false,
        'discrepancy': '100% Matched',
      },
      'evening': {
        'totalLitres': 158.0,
        'coopLitres': 88.0,
        'hotelLitres': 50.0,
        'retailLitres': 20.0,
        'slipNumber': 'PARCHI-8651',
        'slipLitres': 88.0,
        'slipFat': 4.30,
        'slipSnf': 8.60,
        'slipRate': 42.50,
        'centerName': 'सरस दुग्ध सहकारी समिति (BMC-402)',
        'hasMismatch': false,
        'discrepancy': '100% Matched',
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onSlipSaved(Map<String, dynamic> newSlipData) {
    setState(() {
      // Prepend or update today's morning record in archive
      final todayDate = DateFormat('dd MMM yyyy').format(DateTime.now());
      final existingIndex =
          _dateArchives.indexWhere((a) => a['date'] == todayDate);
      if (existingIndex != -1) {
        _dateArchives[existingIndex]['morning'] = newSlipData;
      } else {
        _dateArchives.insert(0, {
          'date': todayDate,
          'morning': newSlipData,
          'evening': {
            'totalLitres': 160.0,
            'coopLitres': 90.0,
            'hotelLitres': 50.0,
            'retailLitres': 20.0,
            'slipNumber': 'Pending',
            'slipLitres': 0.0,
            'hasMismatch': false,
            'discrepancy': 'Evening shift pending',
          },
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: const Text('दैनिक दूध संकलन, बहु-विक्री व पर्ची मिलान'),
        backgroundColor: const Color(0xff064e3b),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xff34d399),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.point_of_sale),
              text: 'बहु-विक्री प्रविष्टि (Multi-Buyer)',
            ),
            Tab(
              icon: Icon(Icons.document_scanner),
              text: 'पर्ची स्कैन व मिलान (Cross-Verify)',
            ),
            Tab(
              icon: Icon(Icons.folder_shared),
              text: 'दिनांक पर्ची फोल्डर (Date Slips)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DailyMultiBuyerTab(
            onNavigateToScanner: () => _tabController.animateTo(1),
          ),
          _SlipScanAndMismatchTab(
            onSaveSlip: _onSlipSaved,
            onNavigateToFolder: () => _tabController.animateTo(2),
          ),
          _DateWiseSlipFolderTab(archives: _dateArchives),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: Daily Multi-Buyer Sales Entry (बहु-विक्री प्रविष्टि)
// ============================================================================
class BuyerChannelItem {
  String id;
  String channelType; // 'cooperative', 'hotel', 'retail', 'self'
  String buyerName;
  double litres;
  double ratePerLitre;
  double? fat;
  double? snf;
  String paymentMode; // '10_day_cycle', 'cash_upi', 'udhar_khata'
  bool hasSlipAttached;
  String? slipNumber;

  BuyerChannelItem({
    required this.id,
    required this.channelType,
    required this.buyerName,
    required this.litres,
    required this.ratePerLitre,
    this.fat,
    this.snf,
    required this.paymentMode,
    this.hasSlipAttached = false,
    this.slipNumber,
  });

  double get totalAmount => litres * ratePerLitre;
}

class _DailyMultiBuyerTab extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToScanner;

  const _DailyMultiBuyerTab({required this.onNavigateToScanner});

  @override
  ConsumerState<_DailyMultiBuyerTab> createState() =>
      _DailyMultiBuyerTabState();
}

class _DailyMultiBuyerTabState extends ConsumerState<_DailyMultiBuyerTab> {
  DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'morning'; // 'morning', 'evening', 'full_day'
  int _selectedCattleId = 0; // 0 = All Herd Bulk
  bool _autoCalculateTotal = true; // Auto-sums channels into Total Production
  final _totalProductionController = TextEditingController(text: '175.0');
  final _avgFatController = TextEditingController(text: '4.30');
  final _avgSnfController = TextEditingController(text: '8.60');

  late List<BuyerChannelItem> _channels;

  @override
  void initState() {
    super.initState();
    _channels = [
      BuyerChannelItem(
        id: '1',
        channelType: 'cooperative',
        buyerName: 'दुग्ध समिति / BMC बल्क',
        litres: 100.0,
        ratePerLitre: 42.50,
        fat: 4.30,
        snf: 8.60,
        paymentMode: '10_day_cycle',
        hasSlipAttached: true,
        slipNumber: 'Slip #8841',
      ),
      BuyerChannelItem(
        id: '2',
        channelType: 'hotel',
        buyerName: 'निजी होटल व हलवाई (Private Hotel)',
        litres: 50.0,
        ratePerLitre: 100.00, // As specifically requested by user!
        paymentMode: 'cash_upi',
        hasSlipAttached: false,
      ),
      BuyerChannelItem(
        id: '3',
        channelType: 'retail',
        buyerName: 'घर-घर खुदरा ग्राहक (Household Retail)',
        litres: 20.0,
        ratePerLitre: 75.00,
        paymentMode: 'udhar_khata',
        hasSlipAttached: false,
      ),
      BuyerChannelItem(
        id: '4',
        channelType: 'self',
        buyerName: 'घरेलू उपयोग व बछड़े (Calf & Home)',
        litres: 5.0,
        ratePerLitre: 0.0,
        paymentMode: 'cash_upi',
        hasSlipAttached: false,
      ),
    ];
    // Sync total production with initial channels
    final initSum = _channels.fold(0.0, (sum, item) => sum + item.litres);
    _totalProductionController.text = initSum.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _totalProductionController.dispose();
    _avgFatController.dispose();
    _avgSnfController.dispose();
    super.dispose();
  }

  double get _totalProduced =>
      double.tryParse(_totalProductionController.text.trim()) ?? 0.0;

  double get _totalDispatched =>
      _channels.fold(0.0, (sum, item) => sum + item.litres);

  double get _balanceLitres => _totalProduced - _totalDispatched;

  double get _totalRevenue =>
      _channels.fold(0.0, (sum, item) => sum + item.totalAmount);

  double get _cashUpiAmount => _channels
      .where((c) => c.paymentMode == 'cash_upi')
      .fold(0.0, (sum, c) => sum + c.totalAmount);

  double get _coopAmount => _channels
      .where((c) => c.paymentMode == '10_day_cycle')
      .fold(0.0, (sum, c) => sum + c.totalAmount);

  double get _udharAmount => _channels
      .where((c) => c.paymentMode == 'udhar_khata')
      .fold(0.0, (sum, c) => sum + c.totalAmount);

  void _addCustomChannel() {
    setState(() {
      _channels.add(
        BuyerChannelItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          channelType: 'hotel',
          buyerName: 'नया खरीदार (होटल/दुकान)',
          litres: 10.0,
          ratePerLitre: 80.00,
          paymentMode: 'cash_upi',
        ),
      );
      if (_autoCalculateTotal) {
        _totalProductionController.text = _totalDispatched.toStringAsFixed(1);
      }
    });
  }

  void _removeChannel(int index) {
    if (_channels.length <= 1) return;
    setState(() {
      _channels.removeAt(index);
      if (_autoCalculateTotal) {
        _totalProductionController.text = _totalDispatched.toStringAsFixed(1);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _saveEntry() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✅ ${_selectedShift.toUpperCase()} संकलन सुरक्षित: कुल ${_totalDispatched.toStringAsFixed(1)}L (आय: ₹${_totalRevenue.toStringAsFixed(0)})',
        ),
        backgroundColor: const Color(0xff064e3b),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Session Bar
          _buildDateSessionCard(context),

          const SizedBox(height: 14),

          // Total Herd & Production Vat Input
          _buildHerdProductionCard(context, cattleAsync),

          const SizedBox(height: 14),

          // Multi-Buyer Channel Breakdown
          _buildMultiBuyerChannelsSection(context),

          const SizedBox(height: 14),

          // Daily Sales Financial Summary
          _buildDailySummaryCard(context),

          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saveEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff064e3b),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'दैनिक बहु-विक्री सुरक्षित करें (Save Daily Collection)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDateSessionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xfff1f5f9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffcbd5e1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month,
                      color: Color(0xff047857), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'morning',
                  label: Text('☀️ सुबह'),
                ),
                ButtonSegment(
                  value: 'evening',
                  label: Text('🌙 शाम'),
                ),
                ButtonSegment(
                  value: 'full_day',
                  label: Text('🥛 पूरा दिन'),
                ),
              ],
              selected: {_selectedShift},
              onSelectionChanged: (s) =>
                  setState(() => _selectedShift = s.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHerdProductionCard(
      BuildContext context, AsyncValue<List<CattleRef>> cattleAsync) {
    final cattleList = cattleAsync.value ??
        const [
          CattleRef(id: 1, name: 'Ganga (गाय)', tagId: 'MIL-0842'),
          CattleRef(id: 2, name: 'Gauri (गाय)', tagId: 'MIL-0911'),
          CattleRef(id: 3, name: 'Murrah (भैंस)', tagId: 'MIL-1024'),
          CattleRef(id: 4, name: 'Radha (गाय)', tagId: 'MIL-0765'),
        ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Color(0xff047857), size: 18),
              const SizedBox(width: 8),
              const Text(
                'डेयरी कुल उत्पादन व फैट/एसएनएफ (Farm Output Vat)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xff1e293b),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xffdcfce7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Bulk Vat Active',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff166534))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  value: _selectedCattleId,
                  decoration: InputDecoration(
                    labelText: 'पशु / समूह (Source)',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('समस्त डेरी पशु (Total Farm Herd - 18 Animals)'),
                    ),
                    ...cattleList.map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.name} (${c.tagId})'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCattleId = val);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _totalProductionController,
                  decoration: InputDecoration(
                    labelText: 'कुल दूध (L)',
                    suffixText: 'L',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    setState(() {
                      _autoCalculateTotal = false; // User manually overridden
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _autoCalculateTotal = true;
                    _totalProductionController.text = _totalDispatched.toStringAsFixed(1);
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _autoCalculateTotal ? Icons.check_circle : Icons.sync,
                        size: 13,
                        color: _autoCalculateTotal ? const Color(0xff16a34a) : const Color(0xff2563eb),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _autoCalculateTotal
                            ? 'चैनलों से स्वतः कुल योग: ${_totalDispatched.toStringAsFixed(1)} L'
                            : 'चैनलों का कुल योग: ${_totalDispatched.toStringAsFixed(1)} L (यहाँ भरें 🔄)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _autoCalculateTotal ? const Color(0xff16a34a) : const Color(0xff2563eb),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _avgFatController,
                  decoration: InputDecoration(
                    labelText: 'औसत फैट % (Fat)',
                    suffixText: '%',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _avgSnfController,
                  decoration: InputDecoration(
                    labelText: 'औसत एस.एन.एफ % (SNF)',
                    suffixText: '%',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiBuyerChannelsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: Color(0xffb45309), size: 20),
              const SizedBox(width: 8),
              const Text(
                'विभिन्न खरीदार व दरें (Multi-Buyer Channels & Rates)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff1e293b),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addCustomChannel,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('खरीदार जोड़ें'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const Text(
            'एक ही समय में समिति, होटल और खुदरा ग्राहकों को अलग-अलग दरों पर दूध दर्ज करें।',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ..._channels.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return _buildChannelRow(context, idx, item);
          }),
        ],
      ),
    );
  }

  Widget _buildChannelRow(
      BuildContext context, int index, BuyerChannelItem item) {
    Color badgeColor;
    IconData badgeIcon;

    switch (item.channelType) {
      case 'cooperative':
        badgeColor = const Color(0xff047857);
        badgeIcon = Icons.account_balance;
        break;
      case 'hotel':
        badgeColor = const Color(0xffb45309);
        badgeIcon = Icons.restaurant;
        break;
      case 'retail':
        badgeColor = const Color(0xff1e40af);
        badgeIcon = Icons.home;
        break;
      default:
        badgeColor = const Color(0xff64748b);
        badgeIcon = Icons.pets;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: badgeColor.withOpacity(0.12),
                child: Icon(badgeIcon, size: 14, color: badgeColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.buyerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xff0f172a),
                  ),
                ),
              ),
              if (item.hasSlipAttached) ...[
                InkWell(
                  onTap: widget.onNavigateToScanner,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffdcfce7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xff86efac)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.receipt,
                            size: 11, color: Color(0xff166534)),
                        const SizedBox(width: 4),
                        Text(
                          item.slipNumber ?? 'पर्ची संलग्न',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xff166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (_channels.length > 1)
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeChannel(index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.litres.toStringAsFixed(1),
                  decoration: const InputDecoration(
                    labelText: 'मात्रा (Litres)',
                    suffixText: 'L',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final d = double.tryParse(val) ?? 0.0;
                    setState(() {
                      item.litres = d;
                      if (_autoCalculateTotal) {
                        _totalProductionController.text = _totalDispatched.toStringAsFixed(1);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.ratePerLitre.toStringAsFixed(1),
                  decoration: const InputDecoration(
                    labelText: 'दर (Rate/L)',
                    prefixText: '₹',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    final d = double.tryParse(val) ?? 0.0;
                    setState(() => item.ratePerLitre = d);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xffcbd5e1)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('कुल राशि',
                          style: TextStyle(fontSize: 9, color: Colors.grey)),
                      Text(
                        '₹${item.totalAmount.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff064e3b),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('भुगतान माध्यम: ',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 4),
              DropdownButton<String>(
                value: item.paymentMode,
                isDense: true,
                underline: const SizedBox(),
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff0f172a),
                    fontWeight: FontWeight.bold),
                items: const [
                  DropdownMenuItem(
                      value: '10_day_cycle',
                      child: Text('🏛️ समिति 10-दिवसीय भुगतान')),
                  DropdownMenuItem(
                      value: 'cash_upi',
                      child: Text('💵 नगद / UPI प्राप्त')),
                  DropdownMenuItem(
                      value: 'udhar_khata',
                      child: Text('📒 ग्राहक उधार खाता')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => item.paymentMode = val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailySummaryCard(BuildContext context) {
    final isDispatchedMatch = _balanceLitres.abs() < 0.1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffbbf7d0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_outlined,
                  color: Color(0xff16a34a), size: 18),
              const SizedBox(width: 8),
              const Text(
                'दैनिक बिक्री व आय संतुलन (Sales & Revenue Summary)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xff166534),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: !isDispatchedMatch
                    ? () {
                        setState(() {
                          _autoCalculateTotal = true;
                          _totalProductionController.text = _totalDispatched.toStringAsFixed(1);
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDispatchedMatch
                        ? const Color(0xffdcfce7)
                        : (_balanceLitres < -0.05
                            ? const Color(0xfffee2e2)
                            : const Color(0xfffef3c7)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDispatchedMatch
                          ? const Color(0xff86efac)
                          : (_balanceLitres < -0.05
                              ? const Color(0xfffca5a5)
                              : const Color(0xfffcd34d)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isDispatchedMatch
                            ? '✅ दूध वितरण संतुलित (100% Dispatched)'
                            : (_balanceLitres < -0.05
                                ? '⚠️ ${_balanceLitres.abs().toStringAsFixed(1)}L अतिरिक्त वितरण (कुल दूध ${_totalDispatched.toStringAsFixed(1)}L करें 🔄)'
                                : '🥛 शेष दूध: +${_balanceLitres.toStringAsFixed(1)}L बचा'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDispatchedMatch
                              ? const Color(0xff15803d)
                              : (_balanceLitres < -0.05
                                  ? const Color(0xffb91c1c)
                                  : const Color(0xffb45309)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'कुल उत्पादित',
                  '${_totalProduced.toStringAsFixed(1)} L',
                  Colors.blue.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'कुल वितरित',
                  '${_totalDispatched.toStringAsFixed(1)} L',
                  Colors.teal.shade900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  'कुल दैनिक आय',
                  '₹${_totalRevenue.toStringAsFixed(0)}',
                  const Color(0xff15803d),
                  isBold: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💵 नगद/UPI: ₹${_cashUpiAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff1e293b)),
              ),
              Text(
                '🏛️ समिति चक्र: ₹${_coopAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff047857)),
              ),
              Text(
                '📒 ग्राहक उधार: ₹${_udharAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffb45309)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color,
      {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 2: Slip Scanner & Mismatch Cross-Verification ("पर्ची स्कैन व मिलान")
// ============================================================================
class _SlipScanAndMismatchTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onSaveSlip;
  final VoidCallback onNavigateToFolder;

  const _SlipScanAndMismatchTab({
    required this.onSaveSlip,
    required this.onNavigateToFolder,
  });

  @override
  State<_SlipScanAndMismatchTab> createState() =>
      _SlipScanAndMismatchTabState();
}

class _SlipScanAndMismatchTabState extends State<_SlipScanAndMismatchTab> {
  // Dispatched reference from dairy vat
  final double _dairyDispatchedLitres = 100.0;
  final double _dairyExpectedFat = 4.30;
  final double _dairyExpectedSnf = 8.60;

  // Controllers for all extracted/autofilled slip data (100% editable by user!)
  late final TextEditingController _litresController;
  late final TextEditingController _fatController;
  late final TextEditingController _snfController;
  late final TextEditingController _rateController;
  late final TextEditingController _centerNameController;
  late final TextEditingController _slipNumberController;

  bool _isScanning = false;
  bool _hasAutofilled = true;
  String? _uploadedFileName = 'saras_parchi_8841.jpg';

  // Preset Slips for realistic 1-tap testing
  final List<Map<String, dynamic>> _presetSlips = [
    {
      'label': 'पर्ची #1: सरस समिति',
      'center': 'सरस दुग्ध उत्पादक सहकारी समिति (BMC-402)',
      'slipNo': 'PARCHI-8841',
      'litres': 98.2,
      'fat': 4.05,
      'snf': 8.35,
      'rate': 40.50,
      'tag': '1.8L Shortage (कटौती)',
      'isShortage': true,
    },
    {
      'label': 'पर्ची #2: अमूल बीएमसी',
      'center': 'अमूल मिल्क कलेक्शन सेंटर (BMC-518)',
      'slipNo': 'AMUL-9120',
      'litres': 100.0,
      'fat': 4.30,
      'snf': 8.60,
      'rate': 42.50,
      'tag': '100% Match (सटीक)',
      'isShortage': false,
    },
    {
      'label': 'पर्ची #3: मदर डेयरी',
      'center': 'मदर डेयरी किसान सेवा केंद्र (BMC-204)',
      'slipNo': 'MD-7603',
      'litres': 97.5,
      'fat': 3.90,
      'snf': 8.20,
      'rate': 39.20,
      'tag': '2.5L Shortage (बड़ा अंतर)',
      'isShortage': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _litresController = TextEditingController(text: '98.2');
    _fatController = TextEditingController(text: '4.05');
    _snfController = TextEditingController(text: '8.35');
    _rateController = TextEditingController(text: '40.50');
    _centerNameController = TextEditingController(
        text: 'सरस दुग्ध उत्पादक सहकारी समिति (BMC-402)');
    _slipNumberController = TextEditingController(text: 'PARCHI-8841');
  }

  @override
  void dispose() {
    _litresController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    _rateController.dispose();
    _centerNameController.dispose();
    _slipNumberController.dispose();
    super.dispose();
  }

  // Dynamic values parsed from user-editable controllers
  double get _slipLitres =>
      double.tryParse(_litresController.text.trim()) ?? 0.0;
  double get _slipFat => double.tryParse(_fatController.text.trim()) ?? 0.0;
  double get _slipSnf => double.tryParse(_snfController.text.trim()) ?? 0.0;
  double get _slipRatePerLitre =>
      double.tryParse(_rateController.text.trim()) ?? 0.0;
  String get _centerName => _centerNameController.text.trim();
  String get _slipNumber => _slipNumberController.text.trim();

  // Real-time Discrepancy Calculations
  double get _volumeDifference => _slipLitres - _dairyDispatchedLitres;
  double get _fatDifference => _slipFat - _dairyExpectedFat;
  double get _snfDifference => _slipSnf - _dairyExpectedSnf;

  double get _dairyExpectedAmount =>
      _dairyDispatchedLitres *
      ((_dairyExpectedFat * 6.50) + (_dairyExpectedSnf * 2.20));

  double get _slipActualAmount => _slipLitres * _slipRatePerLitre;

  double get _financialDiscrepancy =>
      _slipActualAmount - _dairyExpectedAmount;

  Future<void> _simulateOcrScan({Map<String, dynamic>? preset}) async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(milliseconds: 700));

    final data = preset ?? _presetSlips[0];
    setState(() {
      _isScanning = false;
      _uploadedFileName = preset != null
          ? '${data['slipNo']}.jpg'
          : 'scanned_slip_${DateTime.now().millisecondsSinceEpoch % 10000}.jpg';
      _centerNameController.text = data['center'] as String;
      _slipNumberController.text = data['slipNo'] as String;
      _litresController.text = (data['litres'] as double).toStringAsFixed(1);
      _fatController.text = (data['fat'] as double).toStringAsFixed(2);
      _snfController.text = (data['snf'] as double).toStringAsFixed(2);
      _rateController.text = (data['rate'] as double).toStringAsFixed(2);
      _hasAutofilled = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✨ पर्ची स्कैन हुई व डेटा ऑटो-फिल हो गया! यदि कोई संख्या गलत हो तो नीचे बदलें।'),
          backgroundColor: Color(0xff064e3b),
        ),
      );
    }
  }

  Future<void> _pickSlipFromFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'png', 'jpeg'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        setState(() => _uploadedFileName = file.name);
        await _simulateOcrScan();
      }
    } catch (_) {
      // Ignored
    }
  }

  void _submitAndSaveVerifiedSlip() {
    final hasShortage = _volumeDifference < -0.1 || _fatDifference < -0.05;
    final discrepancyText = hasShortage
        ? '${_volumeDifference.toStringAsFixed(1)}L Shortage (-₹${_financialDiscrepancy.abs().toStringAsFixed(0)})'
        : '100% Matched';

    final slipData = {
      'totalLitres': 175.0,
      'coopLitres': _slipLitres,
      'hotelLitres': 50.0,
      'retailLitres': 20.0,
      'slipNumber': _slipNumber,
      'slipLitres': _slipLitres,
      'slipFat': _slipFat,
      'slipSnf': _slipSnf,
      'slipRate': _slipRatePerLitre,
      'centerName': _centerName,
      'hasMismatch': hasShortage,
      'discrepancy': discrepancyText,
    };

    widget.onSaveSlip(slipData);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xff16a34a), size: 24),
            SizedBox(width: 8),
            Text('पर्ची सत्यापित व सुरक्षित!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('पर्ची क्रमांक: $_slipNumber',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('सत्यापित मात्रा: ${_slipLitres.toStringAsFixed(1)} Litres'),
            Text('सत्यापित फैट/एसएनएफ: ${_slipFat.toStringAsFixed(2)}% / ${_slipSnf.toStringAsFixed(2)}%'),
            Text('कुल शुद्ध भुगतान: ₹${_slipActualAmount.toStringAsFixed(1)}'),
            const SizedBox(height: 8),
            if (hasShortage)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xfffee2e2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'अंतर दर्ज: $discrepancyText',
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xff991b1b),
                      fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'यह पर्ची आज के तारीख फोल्डर में सुरक्षित कर दी गई है।',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onNavigateToFolder();
            },
            child: const Text('तारीख फोल्डर देखें >'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff064e3b)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ठीक है (Done)'),
          ),
        ],
      ),
    );
  }

  Future<void> _raiseDisputeOnWhatsApp() async {
    final message = '''*⚠️ दुग्ध पर्ची व डिस्पैच मिलान आपत्ति (Dairy AI Dispute)*
समिति/केंद्र: $_centerName
पर्ची संख्या: $_slipNumber | दिनांक: ${DateFormat('dd MMM yyyy').format(DateTime.now())} (प्रातः)

*तुलनात्मक मिलान विवरण:*
• डेयरी से भेजा दूध: ${_dairyDispatchedLitres.toStringAsFixed(1)} L | पर्ची में दर्ज: ${_slipLitres.toStringAsFixed(1)} L
  👉 *मात्रा अंतर (Shortage): ${_volumeDifference.toStringAsFixed(1)} L*
• डेयरी फैट: ${_dairyExpectedFat.toStringAsFixed(2)}% | पर्ची फैट: ${_slipFat.toStringAsFixed(2)}%
  👉 *फैट अंतर (Fat Cut): ${_fatDifference.toStringAsFixed(2)}%*
• अपेक्षित भुगतान: ₹${_dairyExpectedAmount.toStringAsFixed(1)} | पर्ची भुगतान: ₹${_slipActualAmount.toStringAsFixed(1)}
  👉 *कुल नुकसान: ₹${_financialDiscrepancy.abs().toStringAsFixed(1)} कम प्राप्त*

निवेदन है कि समिति सचिव/परीक्षक इस अंतर की पुनः जाँच करें व संशोधन पर्ची जारी करें।''';

    final url =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card with Scan Trigger & Preset Chips
          _buildScanActionCard(context),

          const SizedBox(height: 14),

          // 2. Physical Thermal Slip Preview / User-Editable Form
          _buildScannedSlipDataCard(context),

          const SizedBox(height: 14),

          // 3. Cross-Verification & Mismatch Comparison Table
          _buildMismatchComparisonCard(context),

          const SizedBox(height: 14),

          // 4. Primary Action: Submit & Save Verified Slip
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _submitAndSaveVerifiedSlip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff064e3b),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.verified),
              label: const Text(
                'सत्यापित पर्ची सुरक्षित करें (Submit & Save Verified Slip)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 5. Secondary Action: Raise WhatsApp Dispute
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _raiseDisputeOnWhatsApp,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xffb91c1c),
                side: const BorderSide(color: Color(0xffb91c1c), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.warning, size: 18),
              label: const Text(
                'समिति पर आपत्ति दर्ज करें (WhatsApp Dispute)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildScanActionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff047857).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.document_scanner,
                    color: Color(0xff047857), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'दैनिक दूध पर्ची स्कैन व ऑटो-रीड (Scan & Auto-Fill)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xff1e293b),
                      ),
                    ),
                    Text(
                      'थर्मल पर्ची की फोटो लें। फैट, मात्रा व दर ऑटो-फिल होंगे, जिन्हें आप सुधार भी सकते हैं।',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main Upload/Camera Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _pickSlipFromFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff064e3b),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.camera_alt, size: 18),
              label: Text(_isScanning
                  ? '🤖 OCR पर्ची पढ़ी जा रही है...'
                  : 'कैमरा / गैलरी से पर्ची फोटो अपलोड करें'),
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // 1-Click Preset Test Slips
          const Text(
            'त्वरित परीक्षण पर्चियां (1-Click Test Scans):',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff334155)),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presetSlips.map((p) {
                final isShort = p['isShortage'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(
                      isShort ? Icons.warning_amber : Icons.check,
                      size: 14,
                      color: isShort ? Colors.red : Colors.green,
                    ),
                    label: Text(
                      '${p['label']} (${p['tag']})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: isShort
                        ? const Color(0xfffef2f2)
                        : const Color(0xfff0fdf4),
                    side: BorderSide(
                      color: isShort
                          ? const Color(0xfffecaca)
                          : const Color(0xffbbf7d0),
                    ),
                    onPressed: () => _simulateOcrScan(preset: p),
                  ),
                );
              }).toList(),
            ),
          ),

          if (_uploadedFileName != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'स्कैन फ़ाइल: $_uploadedFileName (OCR Verified)',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff166534)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScannedSlipDataCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffefce8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xfffef08a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xffa16207), size: 20),
              const SizedBox(width: 8),
              const Text(
                'पर्ची में मुद्रित विवरण (Auto-Filled & Fully Editable)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xff713f12),
                ),
              ),
              const Spacer(),
              if (_hasAutofilled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xffdcfce7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xff86efac)),
                  ),
                  child: const Text('✨ AI OCR Read',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff166534))),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // User guidance badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xfffef08a)),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_note, size: 16, color: Color(0xffa16207)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'यदि स्कैन में कोई संख्या धुंधली या गलत पढ़ी गई हो, तो नीचे किसी भी बॉक्स पर क्लिक करके सही संख्या लिखें।',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xff854d0e),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Center & Slip Number
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _centerNameController,
                  decoration: const InputDecoration(
                    labelText: 'समिति / केंद्र का नाम',
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _slipNumberController,
                  decoration: const InputDecoration(
                    labelText: 'पर्ची क्रमांक',
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 4 Main Auto-Filled & Editable Numbers
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _litresController,
                  decoration: const InputDecoration(
                    labelText: 'पर्ची दूध (L)',
                    suffixText: 'L',
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _fatController,
                  decoration: const InputDecoration(
                    labelText: 'फैट % (Fat)',
                    suffixText: '%',
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _snfController,
                  decoration: const InputDecoration(
                    labelText: 'एसएनएफ %',
                    suffixText: '%',
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _rateController,
                  decoration: const InputDecoration(
                    labelText: 'दर (₹/L)',
                    prefixText: '₹',
                    isDense: true,
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMismatchComparisonCard(BuildContext context) {
    final hasShortage = _volumeDifference < -0.1;
    final hasFatCut = _fatDifference < -0.05;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (hasShortage || hasFatCut)
              ? const Color(0xfffecaca)
              : const Color(0xffbbf7d0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                (hasShortage || hasFatCut)
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: (hasShortage || hasFatCut)
                    ? const Color(0xffdc2626)
                    : const Color(0xff16a34a),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                (hasShortage || hasFatCut)
                    ? '⚠️ डिस्पैच व पर्ची में अंतर पाया गया (Mismatch Alert)'
                    : '✅ कोई अंतर नहीं (100% Matched)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: (hasShortage || hasFatCut)
                      ? const Color(0xff991b1b)
                      : const Color(0xff166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comparison Table
          Table(
            border: TableBorder.all(color: const Color(0xffe2e8f0)),
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2.5),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xfff1f5f9)),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('मापदंड (Metric)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('डेयरी से भेजा',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('पर्ची में दर्ज',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('अंतर (Discrepancy)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              _buildTableRow(
                'दूध मात्रा (Volume)',
                '${_dairyDispatchedLitres.toStringAsFixed(1)} L',
                '${_slipLitres.toStringAsFixed(1)} L',
                '${_volumeDifference.toStringAsFixed(1)} L',
                isNegative: _volumeDifference < -0.1,
              ),
              _buildTableRow(
                'फैट % (Fat)',
                '${_dairyExpectedFat.toStringAsFixed(2)}%',
                '${_slipFat.toStringAsFixed(2)}%',
                '${_fatDifference.toStringAsFixed(2)}%',
                isNegative: _fatDifference < -0.05,
              ),
              _buildTableRow(
                'एसएनएफ % (SNF)',
                '${_dairyExpectedSnf.toStringAsFixed(2)}%',
                '${_slipSnf.toStringAsFixed(2)}%',
                '${_snfDifference.toStringAsFixed(2)}%',
                isNegative: _snfDifference < -0.05,
              ),
              _buildTableRow(
                'कुल राशि (Amount)',
                '₹${_dairyExpectedAmount.toStringAsFixed(0)}',
                '₹${_slipActualAmount.toStringAsFixed(0)}',
                '₹${_financialDiscrepancy.toStringAsFixed(0)}',
                isNegative: _financialDiscrepancy < -10,
              ),
            ],
          ),

          if (hasShortage || hasFatCut) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xfffee2e2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'नुकसान चेतावनी: आज के डिस्पैच में ${_volumeDifference.abs().toStringAsFixed(1)} लीटर दूध कम तौला गया है तथा फैट में ${_fatDifference.abs().toStringAsFixed(2)}% की कटौती हुई है। कुल नुकसान: ₹${_financialDiscrepancy.abs().toStringAsFixed(0)}। नीचे बटन दबाकर समिति पर तुरंत आपत्ति दर्ज करें।',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xff991b1b),
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TableRow _buildTableRow(
      String label, String dispatched, String slip, String diff,
      {required bool isNegative}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(label, style: const TextStyle(fontSize: 11)),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(dispatched,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1e293b))),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(slip,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1e293b))),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            diff,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isNegative
                  ? const Color(0xffdc2626)
                  : const Color(0xff16a34a),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 3: Date-Wise Scanned Slip Folder & Archive ("दिनांक अनुसार पर्ची फोल्डर")
// ============================================================================
class _DateWiseSlipFolderTab extends StatelessWidget {
  final List<Map<String, dynamic>> archives;

  const _DateWiseSlipFolderTab({required this.archives});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: archives.length,
      itemBuilder: (context, index) {
        final archive = archives[index];
        final date = archive['date'] as String;
        final morning = archive['morning'] as Map<String, dynamic>;
        final evening = archive['evening'] as Map<String, dynamic>;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffe2e8f0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            leading: const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xffecfdf5),
              child: Icon(Icons.folder_shared, color: Color(0xff047857), size: 20),
            ),
            title: Text(
              date,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xff0f172a),
              ),
            ),
            subtitle: Text(
              'प्रातः ${morning['totalLitres']}L | सांय ${evening['totalLitres']}L (पर्चियां संलग्न)',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _buildShiftArchiveRow(
                      context,
                      shiftLabel: '☀️ Morning Shift (प्रातः)',
                      shiftData: morning,
                      date: date,
                    ),
                    const Divider(height: 16),
                    _buildShiftArchiveRow(
                      context,
                      shiftLabel: '🌙 Evening Shift (सांय)',
                      shiftData: evening,
                      date: date,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftArchiveRow(
    BuildContext context, {
    required String shiftLabel,
    required Map<String, dynamic> shiftData,
    required String date,
  }) {
    final hasMismatch = shiftData['hasMismatch'] as bool? ?? false;
    final slipNo = shiftData['slipNumber'] ?? 'Pending';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                shiftLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xff1e293b),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'वितरण: ${shiftData['coopLitres']}L समिति + ${shiftData['hotelLitres']}L होटल (@₹100) + ${shiftData['retailLitres']}L खुदरा',
                style: const TextStyle(fontSize: 11, color: Color(0xff475569)),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasMismatch
                          ? const Color(0xfffee2e2)
                          : const Color(0xffdcfce7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hasMismatch
                          ? '⚠️ ${shiftData['discrepancy']}'
                          : '✅ ${shiftData['discrepancy']}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasMismatch
                            ? const Color(0xffb91c1c)
                            : const Color(0xff166534),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (slipNo != 'Pending')
          ElevatedButton.icon(
            onPressed: () => _showSlipViewerDialog(
                context, date, shiftLabel, shiftData),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff064e3b),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.receipt, size: 14),
            label: const Text('पर्ची देखें', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }

  void _showSlipViewerDialog(
    BuildContext context,
    String date,
    String shiftLabel,
    Map<String, dynamic> shiftData,
  ) {
    final slipRate = (shiftData['slipRate'] as num?)?.toDouble() ?? 40.50;
    final slipLitres = (shiftData['slipLitres'] as num?)?.toDouble() ?? 98.2;
    final slipFat = (shiftData['slipFat'] as num?)?.toDouble() ?? 4.05;
    final slipSnf = (shiftData['slipSnf'] as num?)?.toDouble() ?? 8.35;
    final centerName = shiftData['centerName'] ??
        'सरस दुग्ध उत्पादक सहकारी समिति (बीएमसी केंद्र #402)';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xff047857)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'दुग्ध संकलन पर्ची (Dugdha Slip)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 6),

              // Thermal Slip Simulation Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfffefce8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xfffef08a)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        centerName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Courier',
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                    const Divider(height: 14),
                    Text('दिनांक: $date ($shiftLabel)',
                        style: const TextStyle(
                            fontFamily: 'Courier', fontSize: 11)),
                    Text('पर्ची क्रमांक: ${shiftData['slipNumber']}',
                        style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    const Text('डेयरी उत्पादक: किसान कोड #482 (रामेश्वर लाल)',
                        style: TextStyle(
                            fontFamily: 'Courier', fontSize: 11)),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('दूध मात्रा (Qty):',
                            style: TextStyle(
                                fontFamily: 'Courier', fontSize: 12)),
                        Text('${slipLitres.toStringAsFixed(1)} L',
                            style: const TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('फैट % (Fat):',
                            style: TextStyle(
                                fontFamily: 'Courier', fontSize: 12)),
                        Text('${slipFat.toStringAsFixed(2)}%',
                            style: const TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('एसएनएफ % (SNF):',
                            style: TextStyle(
                                fontFamily: 'Courier', fontSize: 12)),
                        Text('${slipSnf.toStringAsFixed(2)}%',
                            style: const TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('लागू दर (Rate):',
                            style: TextStyle(
                                fontFamily: 'Courier', fontSize: 12)),
                        Text('₹${slipRate.toStringAsFixed(2)}/L',
                            style: const TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('शुद्ध देय राशि:',
                            style: TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(
                          '₹${(slipLitres * slipRate).toStringAsFixed(1)}',
                          style: const TextStyle(
                              fontFamily: 'Courier',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xff064e3b)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (shiftData['hasMismatch'] == true) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xfffee2e2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning,
                          color: Color(0xffdc2626), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'डिस्पैच मिलान अंतर: ${shiftData['discrepancy']}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff991b1b),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final msg =
                        'दूध पर्ची: ${shiftData['slipNumber']} | दिनांक: $date | मात्रा: ${slipLitres}L | कुल राशि: ₹${(slipLitres * slipRate).toStringAsFixed(0)}';
                    launchUrl(
                      Uri.parse(
                          'https://wa.me/?text=${Uri.encodeComponent(msg)}'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff15803d),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.share, size: 16),
                  label: const Text('WhatsApp पर शेयर करें'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
