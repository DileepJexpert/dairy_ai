import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';

class CattleLifecycleScreen extends StatefulWidget {
  const CattleLifecycleScreen({super.key, required this.cattleId});

  final String cattleId;

  @override
  State<CattleLifecycleScreen> createState() => _CattleLifecycleScreenState();
}

class _CattleLifecycleScreenState extends State<CattleLifecycleScreen> {
  int _selectedTab = 0; // 0 = Lactation, 1 = Breeding, 2 = Health & Vaccine

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Cattle Lifecycle'),
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
                            onTap: () => context.go('/herd'),
                            child: const Text('Herd Management',
                                style: TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                          Text('Cattle #${widget.cattleId}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cattle Profile Banner
                      _buildCattleBanner(),
                      const SizedBox(height: 20),

                      // Navigation Tabs
                      Row(
                        children: [
                          _tabButton(0, '🥛 Lactation & Milk Yield', Icons.analytics_outlined),
                          const SizedBox(width: 10),
                          _tabButton(1, '🧬 Breeding & Heat Cycle', Icons.favorite_border),
                          const SizedBox(width: 10),
                          _tabButton(2, '💉 Health & Vaccination', Icons.health_and_safety_outlined),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Tab Content
                      if (_selectedTab == 0) _buildLactationTab(),
                      if (_selectedTab == 1) _buildBreedingTab(),
                      if (_selectedTab == 2) _buildHealthTab(),

                      const SizedBox(height: 24),

                      // Quick Tele-Vet Consultation Banner
                      _buildTeleVetActionBanner(),
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

  Widget _tabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? storeGreen : storeWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? storeGreen : storeBorder),
            boxShadow: const [
              BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? storeAmber : storeGreen),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xff222222),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCattleBanner() {
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: storeCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: storeBorder),
            ),
            child: const Icon(Icons.pets, size: 36, color: storeGreen),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Gauri · #${widget.cattleId}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: storeGreen),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xffe6f4ea),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Active Lactating',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xff1e8e3e)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    Text('Breed: Pure Gir Desi Cow',
                        style: TextStyle(fontSize: 12, color: storeMuted, fontWeight: FontWeight.w600)),
                    Text('Age: 4.5 Years (Lactation 3)',
                        style: TextStyle(fontSize: 12, color: storeMuted, fontWeight: FontWeight.w600)),
                    Text('Weight: 425 kg',
                        style: TextStyle(fontSize: 12, color: storeMuted, fontWeight: FontWeight.w600)),
                    Text('RFID: 8400031984210',
                        style: TextStyle(fontSize: 12, color: storeMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLactationTab() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('305-Day Standard Lactation Curve',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
              Text('Current Day: 114 of 305',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeAmberDark)),
            ],
          ),
          const SizedBox(height: 14),

          // Yield KPI strip
          Row(
            children: [
              Expanded(child: _kpiTile('Today\'s Total', '18.4 L', '+0.6 L vs avg', true)),
              const SizedBox(width: 12),
              Expanded(child: _kpiTile('Morning Pour', '10.8 L', 'Fat: 4.4%', false)),
              const SizedBox(width: 12),
              Expanded(child: _kpiTile('Evening Pour', '7.6 L', 'Fat: 4.5%', false)),
              const SizedBox(width: 12),
              Expanded(child: _kpiTile('Cumulative Yield', '2,420 L', 'Target: 4,500 L', true)),
            ],
          ),
          const SizedBox(height: 20),

          // Visual simulated lactation graph bars
          Container(
            height: 160,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfffdfaf3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffe8d8b5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Monthly Yield Trend (Litres/Day)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeMuted)),
                    Text('Peak Lactation: Month 2 (21.5 L/day)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeGreen)),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _barColumn('M1 (Calving)', 16.2, 22.0, false),
                    _barColumn('M2 (Peak)', 21.5, 22.0, true),
                    _barColumn('M3 (High)', 19.8, 22.0, false),
                    _barColumn('M4 (Current)', 18.4, 22.0, false),
                    _barColumn('M5 (Est)', 16.5, 22.0, false),
                    _barColumn('M6 (Est)', 14.8, 22.0, false),
                    _barColumn('M7 (Est)', 13.0, 22.0, false),
                    _barColumn('M8 (Est)', 10.5, 22.0, false),
                    _barColumn('M9 (Dry-off)', 6.0, 22.0, false),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '💡 Milterra Advisory: Gauri is in late-stage peak lactation. Maintain high bypass protein pellets (20%) and liquid calcium to prevent negative energy balance.',
            style: TextStyle(fontSize: 12, color: storeGreen, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _barColumn(String label, double val, double max, bool isPeak) {
    final heightRatio = (val / max).clamp(0.1, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${val.toStringAsFixed(1)}L',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.bold, color: isPeak ? storeAmberDark : storeGreen)),
        const SizedBox(height: 4),
        Container(
          width: 22,
          height: 90 * heightRatio,
          decoration: BoxDecoration(
            color: isPeak ? storeAmber : storeGreen.withValues(alpha: 0.75),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 9, color: storeMuted)),
      ],
    );
  }

  Widget _kpiTile(String title, String val, String sub, bool isGold) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeMuted)),
          const SizedBox(height: 2),
          Text(val,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: isGold ? storeOrange : storeGreen)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: Color(0xff555555))),
        ],
      ),
    );
  }

  Widget _buildBreedingTab() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reproductive & Insemination Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xffe6f4ea),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xff1e8e3e)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xff1e8e3e), size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confirmed Pregnant · 45-Day Ultrasound Scan Positive',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xff1e8e3e), fontSize: 13)),
                      SizedBox(height: 2),
                      Text('Sire: Gir Bull #GB-RAJ-9901 · A2 Certified Semen Straw',
                          style: TextStyle(fontSize: 11, color: Color(0xff2d3748))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _milestoneRow('Artificial Insemination (AI) Date', '14 July 2026', 'Completed', true),
          _milestoneRow('Ultrasound Pregnancy Scan', '28 August 2026', 'Positive', true),
          _milestoneRow('Mandatory Dry-Off Date', '21 February 2027', 'In 163 Days', false),
          _milestoneRow('Expected Calving Date', '21 April 2027', 'In 222 Days', false),
        ],
      ),
    );
  }

  Widget _milestoneRow(String title, String date, String badge, bool isDone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(date, style: const TextStyle(fontSize: 11, color: storeMuted)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xffe6f4ea) : storeCream,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDone ? const Color(0xff1e8e3e) : storeBorder),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDone ? const Color(0xff1e8e3e) : storeGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Veterinary Health & Vaccination Registry',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
          const SizedBox(height: 14),

          _healthItem(
            title: 'Foot & Mouth Disease (FMD) Bi-Annual Vaccine',
            date: 'Administered 12 May 2026',
            status: 'UP TO DATE',
            isClean: true,
          ),
          _healthItem(
            title: 'Hemorrhagic Septicemia (HS) Vaccine',
            date: 'Administered 18 June 2026',
            status: 'UP TO DATE',
            isClean: true,
          ),
          _healthItem(
            title: 'Sub-clinical Mastitis Somatic Cell Count (SCC)',
            date: 'Tested 04 Sep 2026: 140,000 cells/ml (Normal < 200k)',
            status: 'HEALTHY',
            isClean: true,
          ),
          _healthItem(
            title: 'Internal Parasite Deworming (Albendazole)',
            date: 'Due in 18 days (29 Sep 2026)',
            status: 'SCHEDULED',
            isClean: false,
          ),
        ],
      ),
    );
  }

  Widget _healthItem({
    required String title,
    required String date,
    required String status,
    required bool isClean,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isClean ? Icons.check_circle : Icons.schedule,
              color: isClean ? storeSuccess : storeAmber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(fontSize: 11, color: storeMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isClean ? const Color(0xffe6f4ea) : const Color(0xfffef7e0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isClean ? const Color(0xff1e8e3e) : const Color(0xffb7791f),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeleVetActionBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff12231c),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medical_services_outlined, color: storeAmber, size: 26),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need an immediate Vet Checkup for Gauri?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 3),
                Text('Consult verified bovine veterinarians via video call or book an on-farm diagnostic visit.',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: storeAmber,
              foregroundColor: storeGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => context.push('/vet/booking?cattleId=${widget.cattleId}'),
            icon: const Icon(Icons.video_call_outlined, size: 18),
            label: const Text('Book Tele-Vet Now', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
