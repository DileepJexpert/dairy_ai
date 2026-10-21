// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';

class CattleInsuranceClaimScreen extends StatefulWidget {
  const CattleInsuranceClaimScreen({super.key});

  @override
  State<CattleInsuranceClaimScreen> createState() => _CattleInsuranceClaimScreenState();
}

class _CattleInsuranceClaimScreenState extends State<CattleInsuranceClaimScreen> {
  String _selectedCattle = 'MIL-0842 (Ganga - गीर गाय)';

  void _submitClaim() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('क्लेम स्वीकृत (Pre-Approved!)', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'क्लेम डॉकेट: CLAIM-2026-99214',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'बीमा राशि: ₹75,000 (नेशनल इंश्योरेंस कंपनी)',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'थूथन बायोमेट्रिक (99.4%) व स्मार्ट कॉलर डेटा सत्यापित। राशि 48 घंटों में आपके बैंक खाते में जमा होगी।',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff064e3b), foregroundColor: Colors.white),
            child: const Text('ठीक है (Done)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('पशु बीमा व बायोमेट्रिक क्लेम (Insurance & Muzzle)'),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Policy Header Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff1e3a8a), Color(0xff2563eb)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xff2563eb).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'पॉलिसी सं.: NIC-PASHU-2025-88392',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Text(
                          'सक्रिय बीमा (Active)',
                          style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'बीमित राशि (Sum Insured): ₹75,000',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'पशु: गंगा (गीर गाय) | प्रीमियम: 50% सरकारी सब्सिडी प्राप्त',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cattle Selector
              DropdownButtonFormField<String>(
                value: _selectedCattle,
                decoration: InputDecoration(
                  labelText: 'बीमित पशु चुनें (Select Insured Cattle)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.pets),
                ),
                items: const [
                  DropdownMenuItem(value: 'MIL-0842 (Ganga - गीर गाय)', child: Text('MIL-0842 (Ganga - गीर गाय)')),
                  DropdownMenuItem(value: 'MIL-0911 (Gauri - साहीवाल)', child: Text('MIL-0911 (Gauri - साहीवाल)')),
                  DropdownMenuItem(value: 'MIL-1024 (Murrah-1 - मुर्रा)', child: Text('MIL-1024 (Murrah-1 - मुर्रा)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCattle = val);
                },
              ),
              const SizedBox(height: 16),

              // Muzzle Print Biometric Scanner Viewfinder
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade400, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Grid lines simulating camera scanner
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        4,
                        (_) => Container(height: 1, color: Colors.green.withValues(alpha: 0.2)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        4,
                        (_) => Container(width: 1, color: Colors.green.withValues(alpha: 0.2)),
                      ),
                    ),
                    // Reticle
                    Container(
                      width: 140,
                      height: 120,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.greenAccent, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.fingerprint, color: Colors.greenAccent, size: 54),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.greenAccent),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'थूथन प्रिंट मिलान: 99.4% (Muzzle Match Genuine)',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // IoT Smart Collar Audit Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sensors, color: Color(0xff064e3b), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'स्मार्ट कॉलर टेलीमेट्री साक्ष्य (IoT Telemetry Proof):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• 19 अक्टूबर को तेज बुखार (40.8°C) का ऑटो-अलर्ट दर्ज।\n'
                      '• 21 अक्टूबर को हृदय गति शून्य व कॉलर डिस्कनेक्ट की पुष्टि।\n'
                      '• जीपीएस जियोफेंसिंग: 22.5645° N, 72.9289° E (मोगर फार्म shed)',
                      style: TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Fast-Track Claim Button
              ElevatedButton.icon(
                onPressed: _submitClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff064e3b),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flash_on, color: Colors.amberAccent),
                label: const Text(
                  '48-घंटे फास्ट-ट्रैक क्लेम दर्ज करें (Submit Claim)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
