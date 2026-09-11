import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';

class BatchCertificateScreen extends StatelessWidget {
  const BatchCertificateScreen({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Milk Purity Test'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Wrap(
                        children: [
                          InkWell(
                            onTap: () => context.go('/purity'),
                            child: const Text('Purity Assurance',
                                style: TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                          Text('Batch Certificate #$batchId',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Certificate Document Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: storeWhite,
                          borderRadius: BorderRadius.circular(StoreLayout.radius),
                          border: Border.all(color: storeBorder),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0a000000), blurRadius: 16, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header banner
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.verified, color: storeGreen, size: 24),
                                        const SizedBox(width: 8),
                                        Text(
                                          'MILTERRA QUALITY ASSURANCE',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: storeGreen.withValues(alpha: 0.8),
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Certificate of Laboratory Analysis',
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: storeGreen),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('Accredited under ISO/IEC 17025 & FSSAI Standards',
                                        style: TextStyle(fontSize: 12, color: storeMuted)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: storeCream,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: storeBorder),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.qr_code_2, size: 48, color: storeGreen),
                                      const SizedBox(height: 4),
                                      Text(batchId,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),

                            // Batch Summary
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xfffdfaf3),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xffe8d8b5)),
                              ),
                              child: Wrap(
                                spacing: 24,
                                runSpacing: 12,
                                children: [
                                  _metaItem('BATCH NUMBER', batchId),
                                  _metaItem('PRODUCT NAME', 'A2 Desi Vedic Cow Ghee'),
                                  _metaItem('TESTING DATE', '10 Sep 2026'),
                                  _metaItem('EXPIRY / BEST BEFORE', '09 Sep 2027'),
                                  _metaItem('FARM SOURCE', 'Gir Somnath, Gujarat'),
                                  _metaItem('NABL LAB CODE', 'NABL-TC-8891'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Verified Quality Test Table
                            const Text(
                              'Physicochemical & Microbial Analysis Results',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen),
                            ),
                            const SizedBox(height: 12),

                            _testResultRow(
                              parameter: 'Moisture Content',
                              fssaiLimit: 'Max 0.50 %',
                              observedValue: '0.16 %',
                              isPass: true,
                            ),
                            _testResultRow(
                              parameter: 'Free Fatty Acids (FFA as Oleic)',
                              fssaiLimit: 'Max 1.40 %',
                              observedValue: '0.28 %',
                              isPass: true,
                            ),
                            _testResultRow(
                              parameter: 'Reichert-Meissl (RM) Value',
                              fssaiLimit: 'Min 28.0',
                              observedValue: '31.2',
                              isPass: true,
                            ),
                            _testResultRow(
                              parameter: 'Baudouin Test (Hydrogenated Fat)',
                              fssaiLimit: 'NEGATIVE',
                              observedValue: 'NEGATIVE',
                              isPass: true,
                            ),
                            _testResultRow(
                              parameter: 'Total Microbial Plate Count',
                              fssaiLimit: '< 100 CFU/g',
                              observedValue: '< 10 CFU/g',
                              isPass: true,
                            ),
                            _testResultRow(
                              parameter: 'Aflatoxin M1 Contaminant',
                              fssaiLimit: 'Max 0.50 ppb',
                              observedValue: 'NOT DETECTED (< 0.05 ppb)',
                              isPass: true,
                            ),
                            _testResultRow(
                              parameter: 'A2 Beta-Casein DNA Allele',
                              fssaiLimit: '100% A2 Certified',
                              observedValue: '100% Pure A2 Allele (Zero A1)',
                              isPass: true,
                            ),
                            const Divider(height: 32),

                            // Sign-off & Download Action
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Chief Quality Officer, Milterra Labs',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text('Digitally Verified with SHA-256 Hash',
                                        style: TextStyle(fontSize: 11, color: storeMuted)),
                                  ],
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: storeAmber,
                                    foregroundColor: storeGreen,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: storeGreen,
                                        content: Text(
                                            'Certificate for $batchId downloaded successfully to your device.'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_outlined, size: 18),
                                  label: const Text('Download Official PDF',
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _metaItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: storeGreen)),
      ],
    );
  }

  Widget _testResultRow({
    required String parameter,
    required String fssaiLimit,
    required String observedValue,
    required bool isPass,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xfff0f0f0))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 40,
            child: Text(parameter, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 25,
            child: Text('Limit: $fssaiLimit', style: const TextStyle(fontSize: 12, color: storeMuted)),
          ),
          Expanded(
            flex: 25,
            child: Text(observedValue,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: storeGreen)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPass ? const Color(0xffe6f4ea) : const Color(0xfffce8e6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPass ? 'PASS' : 'FAIL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isPass ? const Color(0xff1e8e3e) : const Color(0xffd93025),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
