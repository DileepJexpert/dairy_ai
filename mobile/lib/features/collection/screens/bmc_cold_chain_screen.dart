// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/maturity/models/maturity_models.dart';
import 'package:dairy_ai/features/maturity/providers/maturity_providers.dart';

class BmcColdChainScreen extends ConsumerWidget {
  const BmcColdChainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bmcAsync = ref.watch(bmcTelemetryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('बीएमसी शीतलन टैंक (BMC Cold Chain IoT)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(bmcTelemetryProvider),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: bmcAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('डेटा लोड करने में असमर्थ')),
            data: (bmc) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Center Header Card
                  _BmcHeaderCard(bmc: bmc),
                  const SizedBox(height: 16),

                  // Tank Temperature & Volume Display
                  _ChillingTankHero(bmc: bmc),
                  const SizedBox(height: 16),

                  // Equipment Status: Agitator, Compressor, Power
                  _EquipmentStatusGrid(bmc: bmc),
                  const SizedBox(height: 16),

                  // Milk Spoilage Prevention Card
                  _SpoilageSecurityCard(bmc: bmc),
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

class _BmcHeaderCard extends StatelessWidget {
  final BmcTelemetryData bmc;
  const _BmcHeaderCard({required this.bmc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xff0284c7).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.severe_cold, color: Color(0xff0284c7), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bmc.centerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'प्रभारी: ${bmc.managerName} | आईडी: ${bmc.centerId}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.green, size: 8),
                SizedBox(width: 4),
                Text('IoT लाइव', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChillingTankHero extends StatelessWidget {
  final BmcTelemetryData bmc;
  const _ChillingTankHero({required this.bmc});

  @override
  Widget build(BuildContext context) {
    final isSafe = bmc.currentTemperatureC <= bmc.targetTemperatureC;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSafe
              ? [const Color(0xff0369a1), const Color(0xff0284c7), const Color(0xff38bdf8)]
              : [const Color(0xffb91c1c), const Color(0xffdc2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff0284c7).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'टैंक तापमान (Tank Temp):',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'लक्ष्य: <= ${bmc.targetTemperatureC}°C',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bmc.currentTemperatureC.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                ' °C',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            isSafe ? '✅ सुरक्षित शीतलन (Optimal Chilled State)' : '⚠️ तापमान चेतावनी (Chilling Alert)',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Tank Capacity Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'दूध भण्डारण: ${bmc.currentVolumeLitres.toInt()} / ${bmc.capacityLitres.toInt()} L',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Text(
                    '${bmc.fillPct.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: bmc.fillPct / 100,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EquipmentStatusGrid extends StatelessWidget {
  final BmcTelemetryData bmc;
  const _EquipmentStatusGrid({required this.bmc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _eqTile('एजिटेटर (Agitator)', '${bmc.agitatorRpm} RPM', 'सक्रिय सामान्य', Icons.sync, Colors.teal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _eqTile('विद्युत आपूर्ति (Power)', bmc.powerSource, 'ग्रिड सक्रिय', Icons.bolt, Colors.amber.shade800),
        ),
      ],
    );
  }

  Widget _eqTile(String title, String main, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(main, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(sub, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _SpoilageSecurityCard extends StatelessWidget {
  final BmcTelemetryData bmc;
  const _SpoilageSecurityCard({required this.bmc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffecfdf5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffa7f3d0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Color(0xff059669), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'दूध खराबी जोखिम: शून्य (Zero Spoilage Risk)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff065f46)),
                ),
                Text(
                  'MBRT समय: ${bmc.mbrtHours} घंटे | बैक्टीरिया नियंत्रण 4°C के नीचे स्थिर',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xff047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
