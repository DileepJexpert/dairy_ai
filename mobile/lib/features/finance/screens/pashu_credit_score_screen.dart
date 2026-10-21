import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/finance/models/pashu_credit_model.dart';
import 'package:dairy_ai/features/finance/providers/pashu_credit_provider.dart';

class PashuCreditScoreScreen extends ConsumerStatefulWidget {
  const PashuCreditScoreScreen({super.key});

  @override
  ConsumerState<PashuCreditScoreScreen> createState() =>
      _PashuCreditScoreScreenState();
}

class _PashuCreditScoreScreenState
    extends ConsumerState<PashuCreditScoreScreen> {
  void _showBankDossierModal(BuildContext context, BankDossier dossier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BankDossierSheet(dossier: dossier),
    );
  }

  void _showApplyLoanModal(
    BuildContext context,
    PreApprovedOffer offer,
    PashuCreditScore score,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ApplyLoanSheet(
        offer: offer,
        score: score,
        onApply: (bank, mode, amount) async {
          Navigator.pop(context);
          final result = await applyKccLoan(
            ref,
            loanType: offer.id == 'offer-kcc' ? 'kcc_dairy' : 'cattle_purchase',
            requestedAmount: amount,
            preferredBank: bank,
            repaymentMode: mode,
          );
          if (!mounted) return;
          _showSuccessDialog(this.context, result);
        },
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('लोन स्वीकृत (Approved!)', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'आवेदन आईडी: ${result['application_id']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'स्वीकृत राशि: ₹${result['sanctioned_amount']} (ब्याज दर: ${result['interest_rate_pct']}%)',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'दैनिक दूध ईएमआई: ₹${result['daily_escrow']}/दिन (दूध पर्ची से स्वतः कटौती)',
              style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result['tracking_message'] ?? 'बैंक द्वारा डिजिटल सत्यापन पूरा हो गया है।',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ठीक है (Done)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creditAsync = ref.watch(pashuCreditScoreProvider);
    final dossierAsync = ref.watch(bankDossierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('पशु क्रेडिट स्कोर व बैंक लोन'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'रिफ्रेश',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(pashuCreditScoreProvider);
              ref.invalidate(bankDossierProvider);
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: creditAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
              child: Text('डेटा लोड करने में त्रुटि: $err'),
            ),
            data: (score) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  // Top Hero: Pashu Credit Score Meter Card
                  _buildScoreHeroCard(context, score),
                  const SizedBox(height: 16),

                  // Bank Loan Dossier Certificate Banner
                  _buildDossierActionBanner(context, dossierAsync),
                  const SizedBox(height: 20),

                  // Pre-Approved Loan Limits
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'प्री-अप्रूव्ड बैंक लोन व छूट (Pre-Approved Limits)',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '100% डिजिटल',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...score.preApprovedOffers.map((offer) {
                    return _buildLoanOfferCard(context, offer, score);
                  }),
                  const SizedBox(height: 20),

                  // 5 Score Pillars Breakdown
                  Text(
                    'स्कोर विश्लेषण व श्रेणियां (Score Pillars)',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...score.pillars.map((pillar) {
                    return _buildPillarCard(context, pillar);
                  }),
                  const SizedBox(height: 20),

                  // Why Banks Trust This Score Info Box
                  _buildWhyBanksTrustCard(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScoreHeroCard(BuildContext context, PashuCreditScore score) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff064e3b),
              Color(0xff065f46),
              Color(0xff047857),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'पशु स्वास्थ्य क्रेडिट स्कोर (Pashu CIBIL)',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${score.farmerName} • ${score.village} (${score.district})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ग्रेड ${score.grade}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Circular Speedometer Display
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: (score.score - 300) / 600,
                    strokeWidth: 14,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.score}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'अधिकतम: ${score.maxScore}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Rating Text Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                score.ratingText,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'समय पर टीकाकरण, शून्य मृत्यु दर और निरंतर दूध संकलन के आधार पर सत्यापित',
              style: TextStyle(color: Colors.white70, fontSize: 11.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierActionBanner(
    BuildContext context,
    AsyncValue<BankDossier?> dossierAsync,
  ) {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'बैंक-रेडी डिजिटल लोन डोजियर (Bank Dossier)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xff1e3a8a),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'पशुआधार, 90-दिन दूध आमदनी व डॉक्टर का रोगमुक्त स्वास्थ्य प्रमाण पत्र',
                    style: TextStyle(fontSize: 11.5, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                dossierAsync.whenData((d) {
                  if (d != null) _showBankDossierModal(context, d);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('प्रमाण पत्र देखें', style: TextStyle(fontSize: 11.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanOfferCard(
    BuildContext context,
    PreApprovedOffer offer,
    PashuCreditScore score,
  ) {
    final isKcc = offer.id == 'offer-kcc';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isKcc ? Colors.green.shade400 : Colors.grey.shade300,
          width: isKcc ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    offer.subsidyBadge,
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              offer.tagline,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (offer.maxAmount > 0) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('प्री-अप्रूव्ड राशि', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                      Text(
                        '₹${offer.maxAmount.toInt()}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ब्याज दर', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                      Text(
                        '${offer.interestRatePct}% p.a.',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('दूध पर्ची ईएमआई', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                      Text(
                        '₹${offer.dailyEscrowEst.toInt()}/दिन',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ] else ...[
                  const Expanded(
                    child: Text(
                      'वार्षिक प्रीमियम दर 4.5% से घटकर मात्र 2.2% (₹1,800/गाय बचत)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bolt, size: 18),
                label: Text(
                  offer.maxAmount > 0 ? 'तुरंत लोन हेतु आवेदन करें' : 'बीमा छूट एक्टिवेट करें',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isKcc ? const Color(0xff16a34a) : context.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showApplyLoanModal(context, offer, score),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarCard(BuildContext context, ScorePillar pillar) {
    final progress = pillar.score / pillar.max;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  pillar.title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${pillar.score} / ${pillar.max}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 0.8 ? Colors.green : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '💡 सुझाव: ${pillar.tips}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyBanksTrustCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: Colors.brown.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                'बैंक व ऋणदाता इस स्कोर पर क्यों भरोसा करते हैं?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.brown.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTrustBullet('1. पशु मृत्यु का शून्य जोखिम: टीकाकरण व तुरंत देसी उपचार से पशु नहीं मरता।'),
          _buildTrustBullet('2. दूध पर्ची से ऑटो-ईएमआई: ₹125/दिन दूध भुगतान से कटने पर कोई डिफॉल्ट नहीं होता।'),
          _buildTrustBullet('3. पशुआधार व जैविक मूल्य: प्रत्येक गाय/भैंस स्वयं बैंक की सुरक्षित धरोहर (Collateral) है।'),
        ],
      ),
    );
  }

  Widget _buildTrustBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, color: Colors.brown.shade800, height: 1.3),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bank Dossier Bottom Sheet Modal
// ---------------------------------------------------------------------------
class _BankDossierSheet extends StatelessWidget {
  final BankDossier dossier;

  const _BankDossierSheet({required this.dossier});

  Future<void> _shareOnWhatsApp(BuildContext context) async {
    final message = '''
📜 *MILTERRA CERTIFIED BANK LOAN DOSSIER*
प्रमाण पत्र संख्या: ${dossier.certificateId}
किसान: ${dossier.farmerName} (${dossier.village}, ${dossier.district})
पशु संख्या: ${dossier.totalCattle} दुधारू पशु

✅ *स्वास्थ्य ऑडिट:*
• एफएमडी व गलघोंटू टीका: ${dossier.fmdVaccineStatus}
• रोगमुक्त स्थिति: प्रमाणित (Zero Chronic Infection)

🥛 *दूध उत्पादन व आमदनी (90 दिन):*
• कुल दूध संकलन: ${dossier.totalLitres90d} लीटर
• औसत मासिक दूध आय: ₹${dossier.avgMonthlyRevenue.toInt()}
• गुणवत्ता: फैट ${dossier.avgFat}% | SNF ${dossier.avgSnf}%

🏦 *ऋण संस्तुति (Underwriting Recommendation):*
• अनुशंसित KCC सीमा: ₹${dossier.recommendedKccLimit.toInt()} (बिना गारंटी @ 4%)
• अनुशंसित दैनिक कटौती: ₹${dossier.escrowDailyDeduction.toInt()}/दिन

सत्यापन कोड: ${dossier.verificationHash}
मिलटेरा डेयरी एआई व पशु चिकित्सा विभाग द्वारा प्रमाणित।
''';

    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'डिजिटल बैंक लोन डोजियर',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'प्रमाण पत्र: ${dossier.certificateId}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(height: 20),
          Expanded(
            child: ListView(
              children: [
                // Seal Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.blue.shade800, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dossier.issuingAuthority,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              'सत्यापन हैश: ${dossier.verificationHash} (वैधता: ${dossier.validUntil})',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Farmer & Herd Summary
                _buildDossierSection('1. किसान व डेयरी विवरण (Farmer Profile)', [
                  'किसान का नाम: ${dossier.farmerName}',
                  'गांव व जिला: ${dossier.village}, ${dossier.district}',
                  'मोबाइल: ${dossier.phone}',
                  'कुल सक्रिय दुधारू पशु: ${dossier.totalCattle}',
                ]),
                const SizedBox(height: 12),

                // Health Audit
                _buildDossierSection('2. पशु स्वास्थ्य व टीका ऑडिट (Veterinary Health)', [
                  'एफएमडी (FMD) टीका: ${dossier.fmdVaccineStatus}',
                  'गलघोंटू व लंगड़ा टीका: ${dossier.hsBqVaccineStatus}',
                  'दीर्घकालिक बीमारी मुक्त: हां (Certified Disease-Free)',
                  'थनैला पुनरावृत्ति दर: शून्य (Zero)',
                ]),
                const SizedBox(height: 12),

                // Milk Cash Flow Audit
                _buildDossierSection('3. प्रमाणित 90-दिन दूध आय (Milk Cash Flow Audit)', [
                  '90 दिन का कुल दूध: ${dossier.totalLitres90d} लीटर',
                  'कुल प्राप्त भुगतान: ₹${dossier.totalRevenue90d.toInt()}',
                  'औसत मासिक आय: ₹${dossier.avgMonthlyRevenue.toInt()} / महीना',
                  'औसत दूध गुणवत्ता: फैट ${dossier.avgFat}% | SNF ${dossier.avgSnf}%',
                ]),
                const SizedBox(height: 12),

                // Loan Recommendation
                _buildDossierSection('4. बैंक ऋण संस्तुति (Loan Underwriting Recommendation)', [
                  'अनुशंसित KCC लोन: ₹${dossier.recommendedKccLimit.toInt()} (0% कोलैटरल)',
                  'ब्याज दर: ${dossier.recommendedInterestRate}% p.a. (3% सरकारी छूट सहित)',
                  'ऋण अदायगी क्षमता (DSCR): 3.4x (अत्यधिक सुरक्षित)',
                  'दैनिक दूध एस्क्रो कटौती: ₹${dossier.escrowDailyDeduction.toInt()}/दिन',
                ]),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share, size: 18),
              label: const Text('बैंक मैनेजर को WhatsApp पर भेजें', style: TextStyle(fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff16a34a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _shareOnWhatsApp(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDossierSection(String title, List<String> lines) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
          const SizedBox(height: 6),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $l', style: const TextStyle(fontSize: 11.5)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Apply Loan Bottom Sheet Modal
// ---------------------------------------------------------------------------
class _ApplyLoanSheet extends StatefulWidget {
  final PreApprovedOffer offer;
  final PashuCreditScore score;
  final Function(String bank, String mode, double amount) onApply;

  const _ApplyLoanSheet({
    required this.offer,
    required this.score,
    required this.onApply,
  });

  @override
  State<_ApplyLoanSheet> createState() => _ApplyLoanSheetState();
}

class _ApplyLoanSheetState extends State<_ApplyLoanSheet> {
  String _selectedBank = 'State Bank of India (SBI)';
  String _selectedRepayment = 'daily_milk_escrow';
  late double _amount;

  final List<String> _banks = [
    'State Bank of India (SBI)',
    'HDFC Bank',
    'Punjab National Bank (PNB)',
    'जिला सहकारी बैंक (District Cooperative Bank)',
    'बैंक ऑफ बड़ौदा (Bank of Baroda)',
  ];

  @override
  void initState() {
    super.initState();
    _amount = widget.offer.maxAmount > 0 ? widget.offer.maxAmount : 100000;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.offer.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'प्री-अप्रूव्ड राशि: ₹${widget.offer.maxAmount.toInt()} (ब्याज दर: ${widget.offer.interestRatePct}%)',
            style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // Select Bank Dropdown
          const Text('पसंदीदा बैंक चुनें (Preferred Bank):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedBank,
                items: _banks
                    .map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBank = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Select Repayment Mode
          const Text('किस्त भुगतान का तरीका (Repayment Mode):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          RadioListTile<String>(
            value: 'daily_milk_escrow',
            groupValue: _selectedRepayment,
            title: const Text('दूध पर्ची से ₹125/दिन स्वतः कटौती (Zero Burden)', style: TextStyle(fontSize: 12.5)),
            subtitle: const Text('रोजाना दूध बिक्री में से छोटी किश्त कटेगी', style: TextStyle(fontSize: 11)),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _selectedRepayment = val!),
          ),
          RadioListTile<String>(
            value: 'monthly_bank_debit',
            groupValue: _selectedRepayment,
            title: const Text('मासिक बैंक खाता ईएमआई (₹3,750/महीना)', style: TextStyle(fontSize: 12.5)),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _selectedRepayment = val!),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff16a34a),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => widget.onApply(_selectedBank, _selectedRepayment, _amount),
              child: const Text('आवेदन सबमिट करें (Confirm & Submit)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
