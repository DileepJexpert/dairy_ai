// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/features/maturity/models/maturity_models.dart';
import 'package:dairy_ai/features/maturity/providers/maturity_providers.dart';

class HeatDetectionScreen extends ConsumerWidget {
  const HeatDetectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(heatAlertsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('स्मार्ट हीट अलर्ट (Heat & Estrus Detection)'),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'होम पर वापस जाएं (Back to Home)',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
        ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: alertsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('डेटा लोड करने में असमर्थ')),
            data: (alerts) {
              if (alerts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('कोई सक्रिय हीट अलर्ट नहीं है। सभी पशु सामान्य हैं।'),
                  ),
                );
              }

              final primeAlert = alerts.first;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Hero Golden Window Dial Card
                  _HeroHeatWindowCard(alert: primeAlert),
                  const SizedBox(height: 16),

                  // Smart Collar Telemetry Inversion: Activity vs Rumination
                  _TelemetryInversionCard(alert: primeAlert),
                  const SizedBox(height: 16),

                  // AM-PM Rule Explanation Card
                  _AmPmRuleCard(alert: primeAlert),
                  const SizedBox(height: 16),

                  // Sire / Sexed Semen Recommendation
                  const Text(
                    'अनुशंसित सांड व सीमेन (Sexed Semen Recommendation)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...primeAlert.sires.map((sire) => _SireCard(sire: sire)),
                  const SizedBox(height: 16),

                  // CTA Button to Book AI Tech
                  ElevatedButton.icon(
                    onPressed: () {
                      final phoneUri = Uri.parse('tel:+919876543210');
                      launchUrl(phoneUri);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff064e3b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.phone_in_talk),
                    label: const Text(
                      'AI तकनीशियन को अभी बुलाएं (Call AI Tech Now)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/vet/booking'),
                    icon: const Icon(Icons.video_call, color: Color(0xff064e3b)),
                    label: const Text('पशु चिकित्सक से ऑनलाइन सलाह लें (Tele-Vet Consultation)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
      ),
    );
  }
}

class _HeroHeatWindowCard extends StatelessWidget {
  final HeatAlert alert;
  const _HeroHeatWindowCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff831843), Color(0xff9d174d), Color(0xffbe185d)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff831843).withValues(alpha: 0.3),
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
                  color: Colors.amberAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '🔥 सक्रिय मद (ESTRUS ACTIVE)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'सटीकता: ${alert.confidencePct.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${alert.cattleName} (${alert.breed})',
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            alert.lactationStage,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, color: Colors.amberAccent, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'स्वर्णिम गर्भाधान समय (Golden Conception Window):',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5),
                      ),
                      Text(
                        '${alert.hoursRemaining.toStringAsFixed(1)} घंटे शेष (Hours Left)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryInversionCard extends StatelessWidget {
  final HeatAlert alert;
  const _TelemetryInversionCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.sensors, color: Color(0xff064e3b), size: 20),
                SizedBox(width: 8),
                Text(
                  'स्मार्ट कॉलर बायो-इंडेक्स (Smart Collar Vitals)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _vitalMetric(
                    'शारीरिक हलचल (Activity)',
                    '+${alert.activitySpikePct}%',
                    'असामान्य उछाल (Spike)',
                    Colors.red.shade700,
                    Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _vitalMetric(
                    'जुगाली समय (Rumination)',
                    '-${alert.ruminationDropPct}%',
                    'मद के कारण कमी',
                    Colors.orange.shade800,
                    Icons.trending_down,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vitalMetric(String title, String val, String sub, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          Text(sub, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _AmPmRuleCard extends StatelessWidget {
  final HeatAlert alert;
  const _AmPmRuleCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffbfdbfe)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline, color: Color(0xff1d4ed8), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'वैज्ञानिक AM-PM गर्भाधान नियम:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff1e3a8a)),
                ),
                const SizedBox(height: 3),
                Text(
                  alert.ruleApplied,
                  style: const TextStyle(fontSize: 12, color: Color(0xff1e40af)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SireCard extends StatelessWidget {
  final SireRecommendation sire;
  const _SireCard({required this.sire});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pets, color: Color(0xff064e3b), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      sire.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.pink.shade200),
                      ),
                      child: const Text(
                        '90% बछिया (Female)',
                        style: TextStyle(fontSize: 9.5, color: Colors.pink, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${sire.organization} | संभावित फैट: ${sire.fatPotentialPct}%',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Text(
            '₹${sire.strawPriceInr.toInt()}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xff064e3b)),
          ),
        ],
      ),
    );
  }
}
