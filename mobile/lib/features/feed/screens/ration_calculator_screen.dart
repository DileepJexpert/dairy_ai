import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class RationCalculatorScreen extends ConsumerStatefulWidget {
  const RationCalculatorScreen({super.key});

  @override
  ConsumerState<RationCalculatorScreen> createState() =>
      _RationCalculatorScreenState();
}

class _RationCalculatorScreenState
    extends ConsumerState<RationCalculatorScreen> {
  String _animalType = 'cow'; // 'cow' or 'buffalo'
  double _bodyWeight = 420; // kg
  double _milkYield = 12.0; // Litres/day
  double _fatPercent = 4.2; // %
  bool _isPregnant = false;

  // Available Feeds toggles
  bool _hasGreenFodder = true;
  bool _hasDryBhusa = true;
  bool _hasMustardKhal = true;

  // Real-time calculated diet (ICAR standards)
  double get _dryMatterRequirement {
    // Cow: 2.5% to 3.0% of BW; Buffalo: 3.0% of BW + 0.33 kg DM per kg milk
    final baseFactor = _animalType == 'buffalo' ? 0.030 : 0.028;
    final baseDM = _bodyWeight * baseFactor;
    final milkDM = _milkYield * 0.35;
    final pregnancyBonus = _isPregnant ? 1.0 : 0.0;
    return (baseDM + milkDM + pregnancyBonus);
  }

  // Green Fodder (80% moisture, 20% DM): provides ~50% of roughage DM
  double get _greenFodderKg {
    if (!_hasGreenFodder) return 0;
    // 20 kg green gives 4 kg DM
    final roughageDM = _dryMatterRequirement * 0.65;
    final greenDM = _hasDryBhusa ? roughageDM * 0.55 : roughageDM;
    return (greenDM / 0.20).clamp(10.0, 35.0);
  }

  // Dry Straw/Bhusa (90% DM): provides remainder of roughage DM
  double get _dryStrawKg {
    if (!_hasDryBhusa) return 0;
    final roughageDM = _dryMatterRequirement * 0.65;
    final greenDMSupplied = _hasGreenFodder ? _greenFodderKg * 0.20 : 0.0;
    final remainingRoughageDM = (roughageDM - greenDMSupplied).clamp(2.0, 9.0);
    return (remainingRoughageDM / 0.90);
  }

  // Concentrate Feed (90% DM):
  // Maintenance: 1.5kg cow / 2.0kg buffalo
  // Production: 1kg per 2.5L milk (cow) or 1kg per 2.0L milk (buffalo)
  double get _totalConcentrateKg {
    final maintenance = _animalType == 'buffalo' ? 2.0 : 1.5;
    final milkRatio = _animalType == 'buffalo' ? 2.0 : 2.5;
    final production = _milkYield / milkRatio;
    final pregnancyExtra = _isPregnant ? 1.0 : 0.0;
    return maintenance + production + pregnancyExtra;
  }

  double get _compoundFeedKg {
    if (!_hasMustardKhal) return _totalConcentrateKg;
    // Split 60% compound feed pellets, 40% mustard khal
    return _totalConcentrateKg * 0.60;
  }

  double get _mustardKhalKg {
    if (!_hasMustardKhal) return 0;
    return _totalConcentrateKg * 0.40;
  }

  double get _mineralMixGrams => 50.0;
  double get _saltGrams => 30.0;

  // Costs calculation (Standard North/West/South Indian dairy prices)
  double get _dailyBalancedCost {
    final greenCost = _greenFodderKg * 2.00; // ₹2/kg
    final bhusaCost = _dryStrawKg * 7.50; // ₹7.50/kg
    final feedCost = _compoundFeedKg * 24.00; // ₹24/kg
    final khalCost = _mustardKhalKg * 28.00; // ₹28/kg
    final minMixCost = (_mineralMixGrams / 1000) * 70.00; // ₹70/kg
    final saltCost = (_saltGrams / 1000) * 15.00; // ₹15/kg
    return greenCost + bhusaCost + feedCost + khalCost + minMixCost + saltCost;
  }

  // Traditional unscientific overfeeding of costly grains/churi without balanced green:
  // Typically 6-7 kg expensive grain/khal + excess bhusa = ₹240-270/day
  double get _traditionalUnbalancedCost {
    final grainExcessKg = _totalConcentrateKg * 1.35;
    return (grainExcessKg * 27.0) + (8.0 * 7.50) + (10.0 * 2.00);
  }

  double get _dailySavings =>
      (_traditionalUnbalancedCost - _dailyBalancedCost).clamp(25.0, 110.0);

  double get _monthlySavings => _dailySavings * 30;

  Future<void> _shareRationOnWhatsApp() async {
    final message = '''*🌾 संतुलित पशुआहार व राशन चार्ट (ICAR Dairy AI)*
पशु: ${_animalType == 'cow' ? 'गाय (Cow)' : 'भैंस (Buffalo)'} | वजन: ${_bodyWeight.toInt()} kg
दूध उत्पादन: ${_milkYield.toStringAsFixed(1)} L/दिन (फैट: ${_fatPercent.toStringAsFixed(1)}%)

*दैनिक संतुलित खुराक (Daily Feeding Chart):*
• हरा चारा (Green Fodder): ${_greenFodderKg.toStringAsFixed(1)} kg
• सूखा भूसा (Dry Straw): ${_dryStrawKg.toStringAsFixed(1)} kg
• संतुलित पशुआहार (Feed Pellets): ${_compoundFeedKg.toStringAsFixed(1)} kg
• सरसों/कपासिया खली (Mustard/Cottonseed Khal): ${_mustardKhalKg.toStringAsFixed(1)} kg
• खनिज मिश्रण (Mineral Mixture): ${_mineralMixGrams.toInt()} ग्राम
• सादा नमक (Common Salt): ${_saltGrams.toInt()} ग्राम

*आर्थिक विश्लेषण:*
• दैनिक संतुलित खर्च: ₹${_dailyBalancedCost.toStringAsFixed(1)}/दिन
• परंपरागत खर्च: ₹${_traditionalUnbalancedCost.toStringAsFixed(1)}/दिन
*🔥 अनुमानित मासिक बचत: ₹${_monthlySavings.toStringAsFixed(0)} प्रति पशु!*

Generated via farmers.milterrafoods.com''';

    final url =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: const Text('संतुलित पशुआहार व चारा कैलकुलेटर'),
        backgroundColor: const Color(0xff064e3b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'WhatsApp पर शेयर करें',
            icon: const Icon(Icons.share, color: Colors.greenAccent),
            onPressed: _shareRationOnWhatsApp,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Savings Impact Banner
            _buildSavingsImpactBanner(context),

            // Animal Profile Inputs
            _buildAnimalInputsCard(context),

            // Optimal Diet Output Chart
            _buildBalancedDietCard(context),

            // Cost Comparison & Financial Breakdown
            _buildFinancialBreakdownCard(context),

            // Feeding Best Practices & Water Requirement
            _buildFeedingGuidelinesCard(context),

            const SizedBox(height: 30),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSavingsImpactBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff064e3b), Color(0xff047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff064e3b).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff34d399).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xff34d399)),
                ),
                child: const Text(
                  'ICAR Dairy Ration Engine',
                  style: TextStyle(
                    color: Color(0xffa7f3d0),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.currency_rupee, color: Color(0xff6ee7b7), size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'मासिक बचत: ₹${_monthlySavings.toStringAsFixed(0)} प्रति पशु',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'संतुलित चारा खिलाने से दैनिक आहार खर्च ₹${_dailySavings.toStringAsFixed(0)}/दिन घटता है और दूध में 1 से 1.5 लीटर की वृद्धि होती है।',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalInputsCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xff047857), size: 20),
              SizedBox(width: 8),
              Text(
                'पशु की जानकारी दर्ज करें (Animal Profile)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff1e293b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Animal Type Toggles
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('🐄 देशी / संकर गाय (Cow)'),
                  ),
                  selected: _animalType == 'cow',
                  selectedColor: const Color(0xff047857),
                  labelStyle: TextStyle(
                    color: _animalType == 'cow' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (s) {
                    if (s) setState(() => _animalType = 'cow');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(
                    child: Text('🐃 मुर्राह भैंस (Buffalo)'),
                  ),
                  selected: _animalType == 'buffalo',
                  selectedColor: const Color(0xff047857),
                  labelStyle: TextStyle(
                    color: _animalType == 'buffalo' ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (s) {
                    if (s) setState(() => _animalType = 'buffalo');
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Body Weight Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'पशु का शारीरिक वजन (Body Weight):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_bodyWeight.toInt()} kg',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff047857),
                ),
              ),
            ],
          ),
          Slider(
            value: _bodyWeight,
            min: 300,
            max: 650,
            divisions: 35,
            activeColor: const Color(0xff047857),
            onChanged: (val) => setState(() => _bodyWeight = val),
          ),

          // Milk Yield Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'दैनिक दूध उत्पादन (Daily Milk Yield):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_milkYield.toStringAsFixed(1)} L/दिन',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff047857),
                ),
              ),
            ],
          ),
          Slider(
            value: _milkYield,
            min: 2,
            max: 30,
            divisions: 28,
            activeColor: const Color(0xff047857),
            onChanged: (val) => setState(() => _milkYield = val),
          ),

          // Fat % Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'दूध में फैट % (Milk Fat %):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '${_fatPercent.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff047857),
                ),
              ),
            ],
          ),
          Slider(
            value: _fatPercent,
            min: 3.0,
            max: 9.0,
            divisions: 60,
            activeColor: const Color(0xff047857),
            onChanged: (val) => setState(() => _fatPercent = val),
          ),

          // Pregnancy Bonus Checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'क्या पशु 6 माह से अधिक का गाभिन है? (Late Gestation +1 kg feed)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            value: _isPregnant,
            activeColor: const Color(0xff047857),
            onChanged: (val) => setState(() => _isPregnant = val ?? false),
          ),
        ],
      ),
    );
  }

  Widget _buildBalancedDietCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffa7f3d0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff047857).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, color: Color(0xff047857), size: 20),
              const SizedBox(width: 8),
              const Text(
                'दैनिक संतुलित खुराक (Daily Feeding Chart)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff064e3b),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xffdcfce7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'शुष्क पदार्थ: ${_dryMatterRequirement.toStringAsFixed(1)} kg DM',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff166534),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Diet items table
          _buildDietRow(
            title: '1. हरा चारा (Green Fodder - नेपियर/बरसीम/मक्का)',
            quantity: '${_greenFodderKg.toStringAsFixed(1)} kg',
            sub: 'विटामिन-A व पाचन हेतु अनिवार्य (सुबह 10kg + शाम 10kg)',
            icon: Icons.grass,
            color: Colors.green,
          ),
          const Divider(height: 16),
          _buildDietRow(
            title: '2. सूखा चारा / गेहूं का भूसा (Dry Straw/Bhusa)',
            quantity: '${_dryStrawKg.toStringAsFixed(1)} kg',
            sub: 'रूमेन में रेशे (Fiber) व जुगाली बढ़ाने हेतु',
            icon: Icons.grain,
            color: Colors.amber.shade800,
          ),
          const Divider(height: 16),
          _buildDietRow(
            title: '3. संतुलित पशुआहार (Compound Feed Pellets)',
            quantity: '${_compoundFeedKg.toStringAsFixed(1)} kg',
            sub: 'ऊर्जा व प्रोटीन (Bypass Protein) का मुख्य स्रोत',
            icon: Icons.blur_circular,
            color: Colors.brown,
          ),
          const Divider(height: 16),
          _buildDietRow(
            title: '4. सरसों / बिनौला खली (Mustard/Cottonseed Khal)',
            quantity: '${_mustardKhalKg.toStringAsFixed(1)} kg',
            sub: 'दूध में फैट प्रतिशत व चमक बढ़ाने हेतु',
            icon: Icons.cookie_outlined,
            color: Colors.deepOrange,
          ),
          const Divider(height: 16),
          _buildDietRow(
            title: '5. खनिज मिश्रण (Area-Specific Mineral Mixture)',
            quantity: '${_mineralMixGrams.toInt()} ग्राम',
            sub: 'समय पर मद (Heat) में आने व बांझपन रोकने हेतु',
            icon: Icons.science_outlined,
            color: Colors.teal,
          ),
          const Divider(height: 16),
          _buildDietRow(
            title: '6. सादा नमक (Common Salt)',
            quantity: '${_saltGrams.toInt()} ग्राम',
            sub: 'पानी पीने की इच्छा व पाचन एंजाइम सक्रिय करने हेतु',
            icon: Icons.scatter_plot,
            color: Colors.blueGrey,
          ),
        ],
      ),
    );
  }

  Widget _buildDietRow({
    required String title,
    required String quantity,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xff1e293b),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xfff1f5f9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffcbd5e1)),
          ),
          child: Text(
            quantity,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xff0f172a),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialBreakdownCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffbbf7d0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.savings_outlined, color: Color(0xff16a34a), size: 20),
              SizedBox(width: 8),
              Text(
                'दैनिक खर्च व बचत विश्लेषण (Cost Comparison)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff166534),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffcbd5e1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'परंपरागत खुराक खर्च',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_traditionalUnbalancedCost.toStringAsFixed(1)}/दिन',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xffb91c1c),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'अत्यधिक खली/दलिया से नुकसान',
                        style: TextStyle(fontSize: 9, color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xff86efac)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ICAR संतुलित आहार खर्च',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_dailyBalancedCost.toStringAsFixed(1)}/दिन',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xff15803d),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'अधिकतम दूध व उच्चतम स्वास्थ्य',
                        style: TextStyle(fontSize: 9, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _shareRationOnWhatsApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff16a34a),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text(
                'यह राशन चार्ट WhatsApp पर सेव करें',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedingGuidelinesCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.water_drop, color: Colors.blue, size: 18),
              SizedBox(width: 6),
              Text(
                'महत्वपूर्ण पशुआहार नियम (Golden Rules):',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xff1e293b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• स्वच्छ पेयजल: 1 लीटर दूध उत्पादन पर गाय को 3 से 4 लीटर ताजा पानी चाहिए। 400kg गाय को दिनभर में 60-80 लीटर पानी 24 घंटे उपलब्ध रखें।\n'
            '• दाना भिगोना: दाना या खली को 4 से 6 घंटे पहले भिगोकर खिलाएं ताकि पाचन एंजाइम पूर्ण काम कर सकें।\n'
            '• अचानक आहार न बदलें: आहार में किसी भी प्रकार का बदलाव 4-5 दिनों में धीरे-धीरे करें।',
            style: TextStyle(fontSize: 11, color: Color(0xff475569), height: 1.45),
          ),
        ],
      ),
    );
  }
}
