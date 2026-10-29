import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';

/// Dairy Society & Procurement ERP Operator Console.
/// Provides:
/// 1. Rapid Shift Milk Ingestion Queue (Fat/SNF evaluation, receipt slip, WhatsApp).
/// 2. Live Shift Aggregation & BMC Milk Can Dispatch (Cans, temperature, vehicle, seals).
/// 3. 10-Day Cycle Billing Run (Pakhwada Settlement, Cattle Feed Deductions, Net Payouts, Bank NEFT batch).
class SocietyOperatorScreen extends ConsumerStatefulWidget {
  const SocietyOperatorScreen({super.key, this.centerId = 'center-01'});

  final String centerId;

  @override
  ConsumerState<SocietyOperatorScreen> createState() =>
      _SocietyOperatorScreenState();
}

class _SocietyOperatorScreenState extends ConsumerState<SocietyOperatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selected date & shift
  final DateTime _selectedDate = DateTime.now();
  String _selectedShift = 'morning'; // 'morning' or 'evening'

  // Rapid Intake Form State
  String _selectedFarmerId = 'farmer-1001';
  String _selectedFarmerName = 'Ramesh Patel';
  String _selectedFarmerPhone = '9876510001';
  String _selectedAnimal = 'cow'; // 'cow' or 'buffalo'

  final _litresController = TextEditingController(text: '18.5');
  final _fatController = TextEditingController(text: '4.2');
  final _snfController = TextEditingController(text: '8.6');
  final _tempController = TextEditingController(text: '28.0');

  // Fast demo farmers directory
  final List<Map<String, String>> _farmersList = [
    {'id': 'farmer-1001', 'name': 'Ramesh Patel', 'phone': '9876510001', 'code': 'M-01'},
    {'id': 'farmer-1002', 'name': 'Suresh Yadav', 'phone': '9876510002', 'code': 'M-02'},
    {'id': 'farmer-1003', 'name': 'Anita Devi', 'phone': '9876510003', 'code': 'M-03'},
    {'id': 'farmer-1004', 'name': 'Baldev Singh', 'phone': '9876510004', 'code': 'M-04'},
    {'id': 'farmer-1005', 'name': 'Pooja Sharma', 'phone': '9876510005', 'code': 'M-05'},
  ];

  // Ingestion queue items (Today's live shift)
  final List<Map<String, dynamic>> _shiftQueue = [
    {
      'id': 'col-101',
      'farmer_id': 'farmer-1001',
      'farmer_name': 'Ramesh Patel',
      'farmer_phone': '9876510001',
      'quantity_litres': 22.0,
      'fat_pct': 4.3,
      'snf_pct': 8.7,
      'rate_per_litre': 43.50,
      'net_amount': 957.00,
      'grade': 'A',
      'time': '06:15 AM',
    },
    {
      'id': 'col-102',
      'farmer_id': 'farmer-1002',
      'farmer_name': 'Suresh Yadav',
      'farmer_phone': '9876510002',
      'quantity_litres': 28.5,
      'fat_pct': 6.8,
      'snf_pct': 9.1,
      'rate_per_litre': 62.40,
      'net_amount': 1778.40,
      'grade': 'A',
      'time': '06:22 AM',
    },
    {
      'id': 'col-103',
      'farmer_id': 'farmer-1003',
      'farmer_name': 'Anita Devi',
      'farmer_phone': '9876510003',
      'quantity_litres': 14.0,
      'fat_pct': 4.0,
      'snf_pct': 8.5,
      'rate_per_litre': 41.20,
      'net_amount': 576.80,
      'grade': 'B',
      'time': '06:34 AM',
    },
  ];

  // Dispatch state
  bool _isDispatched = false;
  final _tankerNoController = TextEditingController(text: 'HR-45-B-1082');
  final _driverNameController = TextEditingController(text: 'Ramesh Singh');
  final _driverPhoneController = TextEditingController(text: '9876543210');
  final _sealsController = TextEditingController(text: 'SEAL-891, SEAL-892');
  final _dispatchTempController = TextEditingController(text: '4.2');

  // 10-day Cycle Billing state
  final String _selectedCycle = '2026-10-C2 (11-20 Oct)';
  bool _isCycleDisbursed = false;

  final List<Map<String, dynamic>> _farmerCycleStatements = [
    {
      'farmer_id': 'farmer-1001',
      'farmer_name': 'Ramesh Patel',
      'code': 'M-01',
      'shifts_count': 18,
      'total_litres': 245.5,
      'avg_fat': 4.25,
      'avg_snf': 8.65,
      'gross_amount': 10556.50,
      'feed_deduction': 1800.00, // 2 bags cattle feed
      'cash_advance': 500.00,
      'net_payout': 8256.50,
      'bank_account': '65210088921',
      'bank_ifsc': 'SBIN0001245',
      'upi_id': '9876510001@upi',
      'status': 'pending',
    },
    {
      'farmer_id': 'farmer-1002',
      'farmer_name': 'Suresh Yadav',
      'code': 'M-02',
      'shifts_count': 20,
      'total_litres': 312.0,
      'avg_fat': 6.80,
      'avg_snf': 9.05,
      'gross_amount': 19468.80,
      'feed_deduction': 2400.00, // 1 bag mineral mix + 2 bags feed
      'cash_advance': 0.00,
      'net_payout': 17068.80,
      'bank_account': '40891238491',
      'bank_ifsc': 'PUNB0182900',
      'upi_id': '9876510002@upi',
      'status': 'pending',
    },
    {
      'farmer_id': 'farmer-1003',
      'farmer_name': 'Anita Devi',
      'code': 'M-03',
      'shifts_count': 16,
      'total_litres': 168.0,
      'avg_fat': 4.10,
      'avg_snf': 8.55,
      'gross_amount': 6972.00,
      'feed_deduction': 900.00,
      'cash_advance': 0.00,
      'net_payout': 6072.00,
      'bank_account': '31902847120',
      'bank_ifsc': 'BARB0KARNAL',
      'upi_id': '9876510003@upi',
      'status': 'pending',
    },
    {
      'farmer_id': 'farmer-1004',
      'farmer_name': 'Baldev Singh',
      'code': 'M-04',
      'shifts_count': 19,
      'total_litres': 280.0,
      'avg_fat': 4.30,
      'avg_snf': 8.70,
      'gross_amount': 12180.00,
      'feed_deduction': 1500.00,
      'cash_advance': 1000.00,
      'net_payout': 9680.00,
      'bank_account': '50100234192',
      'bank_ifsc': 'HDFC0001092',
      'upi_id': '9876510004@upi',
      'status': 'pending',
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
    _litresController.dispose();
    _fatController.dispose();
    _snfController.dispose();
    _tempController.dispose();
    _tankerNoController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    _sealsController.dispose();
    _dispatchTempController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dynamic Pricing Calculation
  // ---------------------------------------------------------------------------
  double _calculateCurrentRate() {
    final fat = double.tryParse(_fatController.text) ?? 4.0;
    final snf = double.tryParse(_snfController.text) ?? 8.5;
    final isCow = _selectedAnimal == 'cow';

    double rate;
    if (isCow) {
      rate = 36.50 + ((fat - 3.5) * 3.8) + ((snf - 8.5) * 2.6);
      if (fat >= 4.2 && snf >= 8.6) rate += 1.20; // Grade A incentive
    } else {
      rate = 58.50 + ((fat - 6.0) * 6.4) + ((snf - 9.0) * 3.2);
      if (fat >= 7.0 && snf >= 9.0) rate += 2.00;
    }
    return math.max(20.0, _roundToDouble(rate, 2));
  }

  static double _roundToDouble(double val, int places) {
    final mod = math.pow(10.0, places);
    return ((val * mod).round().toDouble()) / mod;
  }

  void _recordIntake() {
    final litres = double.tryParse(_litresController.text) ?? 0.0;
    final fat = double.tryParse(_fatController.text) ?? 4.0;
    final snf = double.tryParse(_snfController.text) ?? 8.5;

    if (litres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया सही दूध की मात्रा (Litres) दर्ज करें')),
      );
      return;
    }

    final rate = _calculateCurrentRate();
    final net = _roundToDouble(litres * rate, 2);
    final now = DateFormat('hh:mm a').format(DateTime.now());

    final newRecord = {
      'id': 'col-${DateTime.now().millisecondsSinceEpoch.toString().slice(-4)}',
      'farmer_id': _selectedFarmerId,
      'farmer_name': _selectedFarmerName,
      'farmer_phone': _selectedFarmerPhone,
      'quantity_litres': litres,
      'fat_pct': fat,
      'snf_pct': snf,
      'rate_per_litre': rate,
      'net_amount': net,
      'grade': (fat >= 4.2 && snf >= 8.6) ? 'A' : 'B',
      'time': now,
    };

    setState(() {
      _shiftQueue.insert(0, newRecord);
    });

    _showThermalSlipModal(newRecord);
  }

  void _showThermalSlipModal(Map<String, dynamic> record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Icon(Icons.check_circle, color: Color(0xff047857), size: 48),
              const SizedBox(height: 8),
              const Text(
                'दूध संग्रहण पर्ची (MILK INTAKE SLIP)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'Milterra Dairy Cooperative Society • Center #04',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xfff8fafc),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffe2e8f0)),
                ),
                child: Column(
                  children: [
                    _slipRow('किसान (Farmer):', '${record['farmer_name']} (${record['farmer_id']})'),
                    _slipRow('दिनांक व शिफ्ट:', '${DateFormat('dd-MMM-yyyy').format(_selectedDate)} (${_selectedShift.toUpperCase()})'),
                    _slipRow('दूध मात्रा (Quantity):', '${record['quantity_litres']} Litres'),
                    _slipRow('फैट % (Fat):', '${record['fat_pct']} %'),
                    _slipRow('एसएनएफ % (SNF):', '${record['snf_pct']} %'),
                    _slipRow('गुणवत्ता ग्रेड:', 'Grade ${record['grade']}'),
                    _slipRow('दर (Rate/Litre):', '₹${record['rate_per_litre']} /L'),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'कुल राशि (Payable):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '₹${record['net_amount']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Color(0xff047857),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('प्रिंट पर्ची'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('थर्मल प्रिंटर पर पर्ची भेजी गई')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.chat),
                      label: const Text('WhatsApp पर्ची'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xff25D366)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final text = '🥛 *MILTERRA MILK SLIP*\n'
                            'किसान: *${record['farmer_name']}*\n'
                            'मात्रा: *${record['quantity_litres']} L* | Fat: *${record['fat_pct']}%* | SNF: *${record['snf_pct']}%*\n'
                            'दर: ₹${record['rate_per_litre']}/L\n'
                            'कुल राशि: *₹${record['net_amount']}*\n'
                            'दिनांक: ${DateFormat('dd-MM-yyyy').format(_selectedDate)} (${_selectedShift.toUpperCase()})';
                        final url = 'https://api.whatsapp.com/send?phone=91${record['farmer_phone']}&text=${Uri.encodeComponent(text)}';
                        launchUrl(Uri.parse(url));
                      },
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

  Widget _slipRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xff475569))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dispatch Handler
  // ---------------------------------------------------------------------------
  void _executeDispatch() {
    setState(() {
      _isDispatched = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xff047857),
        content: Text(
          'दूध सफलतापूर्वक बीएमसी (${_tankerNoController.text}) को डिस्पैच किया गया!',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Disburse 10-day Payout
  // ---------------------------------------------------------------------------
  void _executeDisburse() {
    setState(() {
      _isCycleDisbursed = true;
      for (final s in _farmerCycleStatements) {
        s['status'] = 'paid';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xff047857),
        content: Text('पखवाड़ा बिल भुगतान सफल! सभी किसानों के बैंक खाते/UPI में राशि ट्रांसफर की गई।'),
      ),
    );
  }

  void _showAddAdvanceModal() {
    String advFarmer = _farmersList.first['id']!;
    String advType = 'cattle_feed';
    final descController = TextEditingController(text: '2 बैग बाईपास प्रोटीन पशुआहार (50kg)');
    final amtController = TextEditingController(text: '2400');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'पशुआहार / दवा एडवांस कटौती जोड़ें',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Text(
                'यह राशि किसान के अगले 10-दिवसीय दूध बिल से स्वतः काट ली जाएगी।',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: advFarmer,
                decoration: const InputDecoration(labelText: 'किसान चुनें (Select Farmer)', border: OutlineInputBorder()),
                items: _farmersList.map((f) => DropdownMenuItem(value: f['id'], child: Text('${f['name']} (${f['code']})'))).toList(),
                onChanged: (v) => advFarmer = v ?? advFarmer,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: advType,
                decoration: const InputDecoration(labelText: 'एडवांस का प्रकार (Type)', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cattle_feed', child: Text('🌾 पशुआहार / खल / चूरी (Feed)')),
                  DropdownMenuItem(value: 'silage', child: Text('🌽 साइलेज गांठ (Silage Bale)')),
                  DropdownMenuItem(value: 'vet_medicine', child: Text('💊 दवा / मिनरल मिक्स (Vet Med)')),
                  DropdownMenuItem(value: 'cash_advance', child: Text('💵 नकद एडवांस (Cash Advance)')),
                ],
                onChanged: (v) => advType = v ?? advType,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'विवरण (Description)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amtController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'राशि (Amount in ₹)', border: OutlineInputBorder(), prefixText: '₹ '),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xff047857), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('₹${amtController.text} का एडवांस रिकॉर्ड हुआ और पखवाड़ा बिल में जोड़ा गया।')),
                    );
                  },
                  child: const Text('कटौती शेड्यूल करें (Save Deduction)'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        backgroundColor: const Color(0xff064e3b),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'डेयरी समिति व बीएमसी ऑपरेटर',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Karnal Rural VLCC #04 • ${DateFormat('dd MMM').format(_selectedDate)} (${_selectedShift.toUpperCase()})',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          // Shift Toggle
          PopupMenuButton<String>(
            tooltip: 'शिफ्ट बदलें',
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(_selectedShift == 'morning' ? Icons.wb_sunny : Icons.nightlight_round, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(_selectedShift.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            onSelected: (shift) => setState(() => _selectedShift = shift),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'morning', child: Text('🌅 Morning Shift')),
              PopupMenuItem(value: 'evening', child: Text('🌇 Evening Shift')),
            ],
          ),
          const FarmerAuthAction(nextRoute: '/collection/operator'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.flash_on, size: 18), text: 'त्वरित दूध एंट्री'),
            Tab(icon: Icon(Icons.local_shipping_outlined, size: 18), text: 'शिफ्ट सारांश व डिस्पैच'),
            Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: '10-दिवसीय पखवाड़ा बिलिंग'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildRapidIntakeTab(context),
              _buildShiftSummaryTab(context),
              _buildCycleBillingTab(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Rapid Milk Intake Queue
  // ---------------------------------------------------------------------------
  Widget _buildRapidIntakeTab(BuildContext context) {
    final currentRate = _calculateCurrentRate();
    final litres = double.tryParse(_litresController.text) ?? 0.0;
    final liveTotal = _roundToDouble(litres * currentRate, 2);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Farmer Quick Selector Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Text('1. किसान चुनें (Select Member Farmer)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xffecfdf5), borderRadius: BorderRadius.circular(6)),
                      child: Text('Selected: $_selectedFarmerName', style: const TextStyle(color: Color(0xff047857), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _farmersList.map((f) {
                      final isSelected = f['id'] == _selectedFarmerId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(Icons.person, size: 16, color: isSelected ? Colors.white : const Color(0xff047857)),
                          label: Text('${f['code']}: ${f['name']}'),
                          selected: isSelected,
                          selectedColor: const Color(0xff047857),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 12),
                          onSelected: (_) {
                            setState(() {
                              _selectedFarmerId = f['id']!;
                              _selectedFarmerName = f['name']!;
                              _selectedFarmerPhone = f['phone']!;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Milk Input & Quality Testing Parameters Card
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xffe2e8f0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Text('2. दूध परीक्षण व मात्रा (Tester & Weight)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChoiceChip(
                          label: const Text('🐄 गाय (Cow)'),
                          selected: _selectedAnimal == 'cow',
                          selectedColor: const Color(0xff047857),
                          labelStyle: TextStyle(color: _selectedAnimal == 'cow' ? Colors.white : Colors.black87, fontSize: 11),
                          onSelected: (_) => setState(() => _selectedAnimal = 'cow'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('🐃 भैंस (Buffalo)'),
                          selected: _selectedAnimal == 'buffalo',
                          selectedColor: const Color(0xff047857),
                          labelStyle: TextStyle(color: _selectedAnimal == 'buffalo' ? Colors.white : Colors.black87, fontSize: 11),
                          onSelected: (_) => setState(() => _selectedAnimal = 'buffalo'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _litresController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'दूध मात्रा (Litres)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.water_drop, color: Colors.blue)),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fatController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'फैट % (Fat)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.opacity, color: Colors.amber)),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _snfController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'एसएनएफ % (SNF)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.analytics_outlined, color: Colors.teal)),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _tempController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'तापमान (°C)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.thermostat, color: Colors.red)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Live Pricing Engine Result Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xffecfdf5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xffa7f3d0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('लागू दर (Calculated Rate):', style: TextStyle(fontSize: 12, color: Color(0xff065f46))),
                          Text('₹$currentRate / Litre', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xff065f46))),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('कुल देय राशि (Shift Total):', style: TextStyle(fontSize: 12, color: Color(0xff065f46))),
                          Text('₹$liveTotal', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xff047857))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('✅ दूध स्वीकारें व पर्ची जारी करें (Record & Issue Slip)', style: TextStyle(fontSize: 14)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff047857),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _recordIntake,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Live Shift Queue Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('आज की शिफ्ट एंट्री (${_shiftQueue.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('कुल: ${_shiftQueue.fold(0.0, (acc, e) => acc + (e['quantity_litres'] as double)).toStringAsFixed(1)} L', style: const TextStyle(color: Color(0xff047857), fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),

        // Shift Queue List
        ..._shiftQueue.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0.5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xffe2e8f0))),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xffecfdf5),
                child: Text(item['grade'], style: const TextStyle(color: Color(0xff047857), fontWeight: FontWeight.bold)),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item['farmer_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('₹${item['net_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff047857), fontSize: 14)),
                ],
              ),
              subtitle: Text(
                '${item['quantity_litres']} L • Fat: ${item['fat_pct']}% • SNF: ${item['snf_pct']}% • ₹${item['rate_per_litre']}/L • ${item['time']}',
                style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.print_outlined, size: 20),
                onPressed: () => _showThermalSlipModal(item),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Shift Summary & BMC Can Dispatch
  // ---------------------------------------------------------------------------
  Widget _buildShiftSummaryTab(BuildContext context) {
    final totalLitres = _shiftQueue.fold(0.0, (acc, e) => acc + (e['quantity_litres'] as double));
    final totalAmount = _shiftQueue.fold(0.0, (acc, e) => acc + (e['net_amount'] as double));
    final cansCount = math.max(1, (totalLitres / 40.0).ceil());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Real-time Shift KPIs
        Row(
          children: [
            Expanded(
              child: _summaryKpiCard(
                title: 'कुल दूध (Litres)',
                value: '${totalLitres.toStringAsFixed(1)} L',
                icon: Icons.water_drop,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryKpiCard(
                title: 'किसान (Farmers)',
                value: '${_shiftQueue.length}',
                icon: Icons.groups,
                color: const Color(0xff047857),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryKpiCard(
                title: 'कुल राशि (Payable)',
                value: '₹${totalAmount.toStringAsFixed(0)}',
                icon: Icons.currency_rupee,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // BMC Milk Can Dispatch Form
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _isDispatched ? const Color(0xffa7f3d0) : const Color(0xffe2e8f0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('दूध कैन व टैंकर डिस्पैच (Chilling Center Dispatch)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isDispatched ? const Color(0xffecfdf5) : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isDispatched ? 'DISPATCHED TO BMC' : 'PENDING DISPATCH',
                        style: TextStyle(
                          color: _isDispatched ? const Color(0xff047857) : Colors.orange.shade800,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$cansCount Cans (40L)',
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'कैन संख्या (40L Cans)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _dispatchTempController,
                        decoration: const InputDecoration(labelText: 'डिस्पैच तापमान (°C)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.thermostat)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tankerNoController,
                  decoration: const InputDecoration(labelText: 'टैंकर / वाहन नंबर (Vehicle No)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_shipping)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _sealsController,
                  decoration: const InputDecoration(labelText: 'कैन सील नंबर (Tamper-Proof Seals)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _driverNameController,
                        decoration: const InputDecoration(labelText: 'चालक का नाम (Driver)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _driverPhoneController,
                        decoration: const InputDecoration(labelText: 'चालक फोन (Phone)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: Icon(_isDispatched ? Icons.check_circle : Icons.send),
                    label: Text(_isDispatched ? '✅ बीएमसी को सफलतापूर्वक डिस्पैच हो गया' : '🚀 बीएमसी को दूध डिस्पैच करें (Dispatch to BMC)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _isDispatched ? Colors.blueGrey : const Color(0xff064e3b),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isDispatched ? null : _executeDispatch,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryKpiCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xff64748b))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: 10-Day Cycle Billing ERP & Deductions
  // ---------------------------------------------------------------------------
  Widget _buildCycleBillingTab(BuildContext context) {
    final totalCycleLitres = _farmerCycleStatements.fold(0.0, (acc, e) => acc + (e['total_litres'] as double));
    final grossCycleAmount = _farmerCycleStatements.fold(0.0, (acc, e) => acc + (e['gross_amount'] as double));
    final totalFeedDeduction = _farmerCycleStatements.fold(0.0, (acc, e) => acc + (e['feed_deduction'] as double));
    final netDisbursement = _farmerCycleStatements.fold(0.0, (acc, e) => acc + (e['net_payout'] as double));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cycle Banner & Period Selector
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff064e3b), Color(0xff047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('10-दिवसीय पखवाड़ा बिलिंग (10-Day Settlement)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                    child: Text(_selectedCycle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('सकल दूध (Gross Milk):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${totalCycleLitres.toStringAsFixed(1)} L (₹${grossCycleAmount.toStringAsFixed(0)})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('पशुआहार कटौती (Deductions):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('-₹${totalFeedDeduction.toStringAsFixed(0)}', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('शुद्ध बैंक भुगतान (Net Payout):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('₹${netDisbursement.toStringAsFixed(2)}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action Toolbar
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('एडवांस कटौती जोड़ें', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: _showAddAdvanceModal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.account_balance, size: 16),
                label: Text(_isCycleDisbursed ? 'भुगतान पूर्ण (Paid)' : '1-क्लिक बैंक ट्रांसफर', style: const TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: _isCycleDisbursed ? Colors.blueGrey : const Color(0xff047857),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: _isCycleDisbursed ? null : _executeDisburse,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Farmer Cycle Statements List Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('किसान पखवाड़ा विवरण (${_farmerCycleStatements.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('कटौती विवरण सहित', style: TextStyle(color: Color(0xff64748b), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),

        // Farmer Cycle Statements Cards
        ..._farmerCycleStatements.map((stmt) {
          final isPaid = stmt['status'] == 'paid' || _isCycleDisbursed;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xffe2e8f0))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${stmt['code']}: ${stmt['farmer_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xffecfdf5) : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPaid ? 'PAID VIA NEFT' : 'PENDING APPROVAL',
                          style: TextStyle(
                            color: isPaid ? const Color(0xff047857) : Colors.amber.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'कुल दूध: ${stmt['total_litres']} L (${stmt['shifts_count']} शिफ्ट) • Avg Fat: ${stmt['avg_fat']}% • Avg SNF: ${stmt['avg_snf']}%',
                    style: const TextStyle(fontSize: 12, color: Color(0xff64748b)),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('सकल दूध राशि:', style: TextStyle(fontSize: 12, color: Color(0xff475569))),
                      Text('₹${stmt['gross_amount']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('पशुआहार व एडवांस कटौती:', style: TextStyle(fontSize: 12, color: Colors.deepOrange)),
                      Text('-₹${stmt['feed_deduction']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('शुद्ध देय भुगतान (Net Payout):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('₹${stmt['net_payout']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff047857))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('बैंक खाता: ${stmt['bank_account']} (${stmt['bank_ifsc']}) • UPI: ${stmt['upi_id']}', style: const TextStyle(fontSize: 11, color: Color(0xff94a3b8))),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

extension _StringSlice on String {
  String slice(int start) => substring(length + start);
}
