// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/maturity/models/maturity_models.dart';
import 'package:dairy_ai/features/maturity/providers/maturity_providers.dart';

class GobardhanCarbonScreen extends ConsumerWidget {
  const GobardhanCarbonScreen({super.key});

  void _showWithdrawModal(BuildContext context, double balance) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: Color(0xff064e3b), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'कार्बन क्रेडिट निकासी (Withdraw Credits)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'उपलब्ध राशि: ₹${balance.toInt()}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'UPI आईडी / बैंक खाता',
                hintText: 'ramesh@upi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.payment),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('₹${balance.toInt()} आपके बैंक खाते में सफलतापूर्वक क्रेडिट कर दिए गए हैं।'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff064e3b),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('निकासी पुष्टि करें (Withdraw Now)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gobardhanAsync = ref.watch(gobardhanDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('गोबरधन व कार्बन क्रेडिट्स (GOBARdhan & Carbon)'),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: gobardhanAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('डेटा लोड करने में असमर्थ')),
            data: (data) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Circular Economy Income Banner
                  _HeroIncomeBanner(data: data),
                  const SizedBox(height: 16),

                  // Carbon Credits Wallet Card
                  _CarbonWalletCard(
                    data: data,
                    onWithdraw: () => _showWithdrawModal(context, data.withdrawableBalanceInr),
                  ),
                  const SizedBox(height: 16),

                  // 3-Pillar Breakdown (Biogas LPG, Slurry Fertilizer, Carbon)
                  const Text(
                    'गोबरधन चक्रीय अर्थव्यवस्था (Circular Economy Breakdown):',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _PillarCard(
                    icon: Icons.local_fire_department,
                    color: Colors.deepOrange,
                    title: 'बायोगैस ईंधन बचत (Biogas LPG)',
                    value: '₹${data.monthlyLpgSavingsInr.toInt()} / माह',
                    subtitle: '${data.monthlyBiogasM3.toInt()} m³ गैस = 2.8 एलपीजी सिलेंडर बचत',
                  ),
                  const SizedBox(height: 8),
                  _PillarCard(
                    icon: Icons.grass,
                    color: Colors.green,
                    title: 'जैविक खाद स्लरी (Bio-Slurry Fertilizer)',
                    value: '₹${data.bioSlurryValueInr.toInt()} / माह',
                    subtitle: '${data.bioSlurryLitres.toInt()} लीटर जैविक NPK स्लरी खाद खेत के लिए',
                  ),
                  const SizedBox(height: 8),
                  _PillarCard(
                    icon: Icons.eco,
                    color: const Color(0xff064e3b),
                    title: 'कार्बन ऑफसेट आय (Carbon Credits)',
                    value: '₹${data.carbonRevenueInr.toInt()} / माह',
                    subtitle: '${data.co2eMitigationTons} टन CO2e मीथेन रोकथाम गोल्ड स्टैंडर्ड सत्यापित',
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroIncomeBanner extends StatelessWidget {
  final GobardhanData data;
  const _HeroIncomeBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff064e3b), Color(0xff065f46), Color(0xff047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff064e3b).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🌱 कचरे से कंचन (Wealth from Waste)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xff78350f)),
                ),
              ),
              const Icon(Icons.recycling, color: Colors.white70, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'गोबरधन कुल मासिक अतिरिक्त आय:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${data.totalMonthlyCircularIncomeInr.toInt()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                ' / महीना अतिरिक्त बचत व आय',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarbonWalletCard extends StatelessWidget {
  final GobardhanData data;
  final VoidCallback onWithdraw;
  const _CarbonWalletCard({required this.data, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff86efac)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Color(0xff16a34a), size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'कार्बन वॉलेट शेष (Carbon Balance):',
                    style: TextStyle(fontSize: 12, color: Color(0xff166534)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '₹${data.withdrawableBalanceInr.toInt()}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff14532d),
                ),
              ),
              Text(
                '${data.carbonCreditsEarned} गोल्ड स्टैंडर्ड क्रेडिट्स (@ ₹900/क्रेडिट)',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: onWithdraw,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff16a34a),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('निकासी करें →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;

  const _PillarCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
