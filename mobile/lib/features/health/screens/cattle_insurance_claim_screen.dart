import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/feed/providers/feed_provider.dart' show cattleListProvider;

class CattleInsuranceClaimScreen extends ConsumerStatefulWidget {
  const CattleInsuranceClaimScreen({super.key});

  @override
  ConsumerState<CattleInsuranceClaimScreen> createState() =>
      _CattleInsuranceClaimScreenState();
}

class _CattleInsuranceClaimScreenState
    extends ConsumerState<CattleInsuranceClaimScreen> {
  String? _selectedCattleId;

  void _submitClaim(String cattleName, String tagId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('क्लेम दर्ज हुआ (Claim Registered)', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'क्लेम डॉकेट: CLAIM-2026-${DateTime.now().millisecondsSinceEpoch % 100000}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'बीमित पशु: $cattleName ($tagId)',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'बीमा कंपनी: नेशनल इंश्योरेंस कंपनी (NIC)',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'पशुआधार बायोमेट्रिक व डिजिटल डेटा सत्यापन के बाद क्लेम राशि 48 घंटों में आपके पंजीकृत बैंक खाते में स्थानांतरित की जाएगी।',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff064e3b),
              foregroundColor: Colors.white,
            ),
            child: const Text('ठीक है (Done)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cattleAsync = ref.watch(cattleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('पशु बीमा व क्लेम (Insurance & Claims)'),
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: cattleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('त्रुटि: $err')),
            data: (cattleList) {
              if (cattleList.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 72, color: Colors.blueGrey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'कोई बीमित पशु पंजीकृत नहीं है',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'सरकारी सब्सिडी व पशुधन बीमा क्लेम के लिए पहले अपने पशु को पशुआधार ई-टैग के साथ पंजीकृत करें।',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/herd/add'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff047857),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('पहला पशु जोड़ें (Add Cattle)'),
                      ),
                    ],
                  ),
                );
              }

              final selectedCattle = cattleList.firstWhere(
                (c) => c.id == _selectedCattleId,
                orElse: () => cattleList.first,
              );

              return ListView(
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'पॉलिसी सं.: NIC-PASHU-2026-${selectedCattle.tagId}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Text(
                              'सक्रिय बीमा (Active)',
                              style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'बीमित राशि (Sum Insured): ₹75,000',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'पशु: ${selectedCattle.name} (${selectedCattle.breed}) | प्रीमियम: 50% सरकारी सब्सिडी प्राप्त',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cattle Selector
                  DropdownButtonFormField<String>(
                    value: selectedCattle.id,
                    decoration: InputDecoration(
                      labelText: 'बीमित पशु चुनें (Select Insured Cattle)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.pets),
                    ),
                    items: cattleList
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} (${c.tagId} - ${c.breed})'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCattleId = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Muzzle Print Biometric Scanner Viewfinder
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.green.shade400, width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (_) => Container(
                                height: 1,
                                color: Colors.green.withValues(alpha: 0.2)),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            4,
                            (_) => Container(
                                width: 1,
                                color: Colors.green.withValues(alpha: 0.2)),
                          ),
                        ),
                        Container(
                          width: 140,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.greenAccent, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.fingerprint,
                                color: Colors.greenAccent, size: 54),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.greenAccent),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.greenAccent, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'थूथन प्रिंट: ${selectedCattle.tagId} (Muzzle Ready)',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Telemetry Status Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.sensors,
                                color: Color(0xff064e3b), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'डिजिटल सत्यापन साक्ष्य (Digital Verification Proof):',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• पशु टैग: ${selectedCattle.tagId}\n'
                          '• नस्ल: ${selectedCattle.breed}\n'
                          '• डिजिटल पशुआधार से राष्ट्रीय पशुधन मिशन (NDLM) सत्यापित।',
                          style: const TextStyle(
                              fontSize: 12, height: 1.4, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Fast-Track Claim Button
                  ElevatedButton.icon(
                    onPressed: () => _submitClaim(
                        selectedCattle.name, selectedCattle.tagId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff064e3b),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.flash_on, color: Colors.amberAccent),
                    label: const Text(
                      '48-घंटे फास्ट-ट्रैक क्लेम दर्ज करें (Submit Claim)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
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
