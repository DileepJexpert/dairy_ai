import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/store_design.dart';

class AboutMilterraScreen extends StatelessWidget {
  const AboutMilterraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'About Milterra'),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Breadcrumb
                            Wrap(
                              children: [
                                InkWell(
                                  onTap: () => context.go('/shop'),
                                  child: const Text('Home',
                                      style: TextStyle(fontSize: 12, color: storeMuted)),
                                ),
                                const Text(' › ',
                                    style: TextStyle(fontSize: 12, color: storeMuted)),
                                const Text('About Milterra',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen)),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Hero Banner
                            _buildHeroBanner(),
                            const SizedBox(height: 32),

                            // 3 Pillars Overview
                            _buildPillarsRow(),
                            const SizedBox(height: 40),

                            // 5 Vedic Sanskaras of Bilona Churning
                            _buildVedicSanskarasSection(),
                            const SizedBox(height: 40),

                            // Direct Farmer Collective Section
                            _buildFarmerCollectiveSection(context),
                            const SizedBox(height: 40),

                            // Laboratory Purity & Quality Assurance
                            _buildLabPuritySection(context),
                            const SizedBox(height: 40),

                            // Bottom Call to Action
                            _buildBottomCTA(context),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const StoreFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      decoration: BoxDecoration(
        color: storeGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: storeGreen.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: storeAmber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: storeAmber),
            ),
            child: const Text(
              'OUR PHILOSOPHY & CRAFT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: storeAmber,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Pure Sourcing. Vedic Craft.\nFarmer Prosperity.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Milterra was founded on a singular conviction: genuine dairy should be produced with patience, deep respect for indigenous cattle, and direct economic fairness for rural dairy farming families. We reject industrial shortcuts, synthetic additives, and unfair middlemen.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsRow() {
    final pillars = [
      {
        'icon': Icons.grass_outlined,
        'title': '100% Grass-Fed Indigenous Breeds',
        'desc':
            'Sourced exclusively from ethically grazed Indian Gir cows and Murrah buffaloes free to roam open pastures.',
      },
      {
        'icon': Icons.local_fire_department_outlined,
        'title': 'Vedic Bilona Churning',
        'desc':
            'Cultured whole-milk curd churned slowly with wooden bi-directional bilonas and simmered on firewood.',
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'Direct Farmer Payouts',
        'desc':
            'Transparent Fat & SNF digital pricing paid instantly to farmer Milterra Wallets with zero broker margins.',
      },
    ];

    return Row(
      children: pillars.map((p) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: storeBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: storeSage,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(p['icon'] as IconData, color: storeGreen, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  p['title'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: storeGreen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p['desc'] as String,
                  style: const TextStyle(fontSize: 12, color: storeMuted, height: 1.4),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVedicSanskarasSection() {
    final sanskaras = [
      {
        'step': '01',
        'title': 'Ethical Milking (Ahinsa)',
        'desc':
            'The newborn calf is fed to satisfaction before morning milking begins. Hand-milked in serene stress-free open sheds.',
      },
      {
        'step': '02',
        'title': 'Earthen Boiling (Mitti ke Bartan)',
        'desc':
            'Fresh whole milk is slowly brought to a simmer over dung-cake firewood in heavy clay vats, preserving vital A2 beta-casein proteins.',
      },
      {
        'step': '03',
        'title': 'Overnight Curd Culturing',
        'desc':
            'Cooled milk is inoculated with pure heritage starter culture and left to set undisturbed in clay pots into dense probiotic dahi.',
      },
      {
        'step': '04',
        'title': 'Brahma Muhurta Wooden Bilona',
        'desc':
            'Before sunrise, cultured curd is churned bi-directionally using hand-carved wooden bilonas to separate rich makkhan from butter-milk.',
      },
      {
        'step': '05',
        'title': 'Slow Firewood Clarification',
        'desc':
            'Fresh white makkhan is slowly clarified on low heat with betel leaves until golden granular crystal granules emerge naturally.',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: storeAmber, size: 22),
              SizedBox(width: 8),
              Text(
                'The 5 Vedic Sanskaras of Bilona Ghee',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: storeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Unlike industrial ghee made from heated separator cream in hours, Milterra Vedic Bilona Ghee requires 30 liters of pure milk and 36 hours of patient artisan craftsmanship for a single liter.',
            style: TextStyle(fontSize: 13, color: storeMuted, height: 1.4),
          ),
          const SizedBox(height: 22),
          ...sanskaras.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: storeCream,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: storeBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: storeGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s['step']!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: storeAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['title']!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: storeGreen,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            s['desc']!,
                            style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFarmerCollectiveSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: storeSage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '124+ Farmer Families. Zero Middlemen.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: storeGreen,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Every morning and evening, our cooperative members deliver milk to digital collection kiosks. Milk Fat & SNF percentages are measured transparently via ultrasonic analyzers, and earnings are credited directly into their Milterra Wallets within minutes. This guarantees farmers fair compensation 25% higher than traditional dairy conglomerates.',
                  style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: storeGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.push('/cooperative/intake'),
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('View Cooperative Milk Intake Slip System'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: storeBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COOPERATIVE IMPACT',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeMuted)),
                  SizedBox(height: 10),
                  Text('₹8.92 Lakhs+',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: storeGreen)),
                  Text('Direct Milk Payouts Disbursed',
                      style: TextStyle(fontSize: 11, color: storeMuted)),
                  Divider(height: 20),
                  Text('100% Traceable',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: storeGreen)),
                  Text('Tag-level Herd Health Records',
                      style: TextStyle(fontSize: 11, color: storeMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabPuritySection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: storeGreen, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'NABL Accredited Lab Testing & Verifiable Batches',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: storeGreen,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: storeGreen,
                  side: const BorderSide(color: storeGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => context.push('/purity/certificate/BATCH-2026-0911A'),
                icon: const Icon(Icons.qr_code, size: 16),
                label: const Text('View Sample Lab Certificate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Every batch of Milterra A2 Ghee and Dairy is tested under ISO/IEC 17025 standards for moisture, free fatty acids, RM value, Baudouin test, aflatoxins, and 100% A2 beta-casein allele verification.',
            style: TextStyle(fontSize: 13, color: storeMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _metricPill('99.4% Purity Score', Icons.check_circle_outline),
              _metricPill('100% A2 Beta-Casein', Icons.biotech_outlined),
              _metricPill('Zero Preservatives', Icons.block_outlined),
              _metricPill('Zero Added Water', Icons.water_drop_outlined),
              _metricPill('Zero Synthetic Dyes', Icons.palette_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: storeCream,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: storeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: storeGreen),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: storeGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: storeGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'Taste Genuine Vedic Dairy from Indigenous Herds',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Direct farm-to-table delivery in temperature-controlled sustainable packaging.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: storeAmber,
                  foregroundColor: storeGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: () => context.go('/shop'),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Explore Dairy Collection',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white60),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: () => context.push('/herd/lifecycle/MIL-2024-0842'),
                icon: const Icon(Icons.pets_outlined, size: 18),
                label: const Text('Meet Our Cattle Herd',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
