import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows an authentic, interactive NABL-accredited laboratory purity certificate modal.
Future<void> showLabPurityDialog(BuildContext context, {String? defaultCategory}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => _LabPurityDialog(initialCategory: defaultCategory),
  );
}

class _LabPurityDialog extends StatefulWidget {
  const _LabPurityDialog({this.initialCategory});
  final String? initialCategory;

  @override
  State<_LabPurityDialog> createState() => _LabPurityDialogState();
}

class _LabPurityDialogState extends State<_LabPurityDialog> {
  late int _selectedTab;
  final TextEditingController _batchController = TextEditingController();
  bool _copied = false;

  final List<({
    String title,
    String sku,
    String batch,
    String testDate,
    String certNo,
    List<({String parameter, String standard, String result, String status})> tests,
  })> _certificates = [
    (
      title: 'A2 Sahiwal Cow Bilona Ghee',
      sku: 'MILTERRA Pure A2 Cow Ghee (1L)',
      batch: 'MLT-CG-2409',
      testDate: '02 Oct 2026',
      certNo: 'NABL/FSSAI-TC-8891/26',
      tests: [
        (parameter: 'B.R. Reading @ 40°C', standard: '40.0 - 43.0', result: '41.2', status: 'PASS'),
        (parameter: 'Reichert-Meissl (RM) Value', standard: 'Min 28.0', result: '28.8', status: 'PASS'),
        (parameter: 'Polenske Value', standard: '1.0 - 2.0', result: '1.6', status: 'PASS'),
        (parameter: 'Free Fatty Acids (as Oleic)', standard: 'Max 1.4%', result: '0.38%', status: 'PASS'),
        (parameter: 'Baudouin Test (Vanaspati/Veg Fat)', standard: 'Negative', result: 'Negative (Nil)', status: 'PASS'),
        (parameter: 'Mineral Oil / Paraffin Test', standard: 'Negative', result: 'Negative (Nil)', status: 'PASS'),
        (parameter: 'A2 Beta-Casein DNA Purity', standard: '100% A2 Allele', result: '100% Pure Indigenous', status: 'PASS'),
      ],
    ),
    (
      title: 'Wood-Pressed Mustard Oil',
      sku: 'MILTERRA Lakdi Ghani Mustard Oil (1L)',
      batch: 'MLT-MO-2410',
      testDate: '04 Oct 2026',
      certNo: 'NABL/FSSAI-TC-8912/26',
      tests: [
        (parameter: 'Extraction Temperature', standard: 'Cold-pressed < 45°C', result: '36.8°C', status: 'PASS'),
        (parameter: 'Argemone Oil Test', standard: 'Negative', result: 'Negative (Nil)', status: 'PASS'),
        (parameter: 'Free Fatty Acids (as Oleic)', standard: 'Max 1.5%', result: '0.45%', status: 'PASS'),
        (parameter: 'Saponification Value', standard: '168 - 177', result: '173.2', status: 'PASS'),
        (parameter: 'Iodine Value', standard: '96 - 112', result: '104.5', status: 'PASS'),
        (parameter: 'Artificial Color / Preservatives', standard: 'Negative', result: 'Negative (Nil)', status: 'PASS'),
      ],
    ),
    (
      title: 'A2 Murrah Buffalo Cultured Ghee',
      sku: 'MILTERRA Traditional Buffalo Ghee (1L)',
      batch: 'MLT-BG-2408',
      testDate: '28 Sep 2026',
      certNo: 'NABL/FSSAI-TC-8874/26',
      tests: [
        (parameter: 'B.R. Reading @ 40°C', standard: '40.0 - 43.5', result: '41.8', status: 'PASS'),
        (parameter: 'Reichert-Meissl (RM) Value', standard: 'Min 30.0', result: '31.2', status: 'PASS'),
        (parameter: 'Free Fatty Acids (as Oleic)', standard: 'Max 1.4%', result: '0.41%', status: 'PASS'),
        (parameter: 'Baudouin Test (Veg Oil/Fat)', standard: 'Negative', result: 'Negative (Nil)', status: 'PASS'),
        (parameter: 'Moisture Content', standard: 'Max 0.3%', result: '0.12%', status: 'PASS'),
        (parameter: 'Pesticide Residue (240 Compounds)', standard: 'Below Det. Limit', result: 'Not Detected (0.00)', status: 'PASS'),
      ],
    ),
    (
      title: 'Fresh A2 Sahiwal Malai Paneer',
      sku: 'MILTERRA Artisanal Malai Paneer (200g)',
      batch: 'MLT-PN-2410',
      testDate: '06 Oct 2026',
      certNo: 'NABL/FSSAI-TC-8920/26',
      tests: [
        (parameter: 'Milk Fat on Dry Matter', standard: 'Min 50.0%', result: '54.2%', status: 'PASS'),
        (parameter: 'Moisture Content', standard: 'Max 60.0%', result: '53.8%', status: 'PASS'),
        (parameter: 'Protein Content (per 100g)', standard: 'Min 16.0g', result: '18.4g', status: 'PASS'),
        (parameter: 'Starch / Synthetic Adulterants', standard: 'Negative', result: 'Negative (Nil)', status: 'PASS'),
        (parameter: 'Coliform / E. Coli Count', standard: 'Absent / g', result: 'Absent / Zero', status: 'PASS'),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedTab = 0;
    if (widget.initialCategory != null) {
      final cat = widget.initialCategory!.toLowerCase();
      if (cat.contains('oil') || cat.contains('mustard')) {
        _selectedTab = 1;
      } else if (cat.contains('buffalo')) {
        _selectedTab = 2;
      } else if (cat.contains('paneer') || cat.contains('milk') || cat.contains('dairy')) {
        _selectedTab = 3;
      }
    }
    _batchController.text = _certificates[_selectedTab].batch;
  }

  @override
  void dispose() {
    _batchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _certificates[_selectedTab];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: NABL Quality Seal
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
              decoration: const BoxDecoration(
                color: Color(0xff164e2e),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified, color: Color(0xff86efac), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NABL ACCREDITED LAB VERIFICATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xff86efac),
                            letterSpacing: 1.0,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '100% Purity & Chemical-Free Certification',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Tab Bar for 4 Products
            Container(
              decoration: const BoxDecoration(
                color: Color(0xfff8fafc),
                border: Border(bottom: BorderSide(color: Color(0xffe2e8f0))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: List.generate(_certificates.length, (idx) {
                    final item = _certificates[idx];
                    final isSel = _selectedTab == idx;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        selected: isSel,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedTab = idx;
                              _batchController.text = _certificates[idx].batch;
                            });
                          }
                        },
                        label: Text(item.title),
                        selectedColor: const Color(0xff164e2e),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : const Color(0xff334155),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSel ? const Color(0xff164e2e) : const Color(0xffcbd5e1),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Batch & Certification Information Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffbbf7d0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xff15803d), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Batch: ${active.batch}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xff166534),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xffdcfce7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'BATCH TESTED & VERIFIED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xff15803d),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tested Date: ${active.testDate} · Certificate: ${active.certNo}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Scrollable Test Results Table
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xffe2e8f0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            color: const Color(0xfff1f5f9),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: const Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    'Purity Parameter',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff334155),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'FSSAI Standard',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff334155),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Milterra Result',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff334155),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 48,
                                  child: Text(
                                    'Status',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xff334155),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Table Rows
                          ...List.generate(active.tests.length, (i) {
                            final t = active.tests[i];
                            final isEven = i % 2 == 0;
                            return Container(
                              color: isEven ? Colors.white : const Color(0xfff8fafc),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      t.parameter,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff1e293b),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      t.standard,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xff64748b),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      t.result,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xff15803d),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffdcfce7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PASS',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xff166534),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Laboratory Credentials Footer Note
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xfffffbeb),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xfffef3c7)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, size: 14, color: Color(0xffb45309)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Testing conducted in accordance with FSSAI (Food Safety and Standards Authority of India) manual of methods for oils, fats and dairy products.',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xff92400e),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dialog Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xfff8fafc),
                border: Border(top: BorderSide(color: Color(0xffe2e8f0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xff164e2e),
                      side: const BorderSide(color: Color(0xff164e2e)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: 'https://milterrafoods.com/lab-purity-certificates.html#${active.batch.toLowerCase()}',
                      ));
                      setState(() => _copied = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _copied = false);
                      });
                    },
                    icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                    label: Text(
                      _copied ? 'Link Copied!' : 'Share Certificate',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff164e2e),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close Window',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
