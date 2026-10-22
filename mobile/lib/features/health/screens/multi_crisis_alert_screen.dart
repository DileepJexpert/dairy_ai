// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class MultiCrisisAlertScreen extends StatefulWidget {
  const MultiCrisisAlertScreen({super.key});

  @override
  State<MultiCrisisAlertScreen> createState() => _MultiCrisisAlertScreenState();
}

class _MultiCrisisAlertScreenState extends State<MultiCrisisAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _shareOnWhatsApp() async {
    const msg =
        '🚨 *MILTERRA आपातकालीन पशु अलर्ट (CODE RED)* 🚨\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        '🐄 *पशु:* गंगा (Ganga) | *टैग:* MIL-0842 (गीर गाय)\n'
        '🌡️ *बुखार:* 40.8°C (105.4°F) - अति-गंभीर\n'
        '⚠️ *थनैला:* दाहिना पिछला थन सूजा, पीला थक्का दूध (-45% उत्पादन)\n'
        '🛑 *हलचल:* 0 कदम (पिछले 2 घंटे से अचल / डाउनर)\n'
        '⏳ *जुगाली:* 0 मिनट (पिछले 5 घंटे से जुगाली ठप)\n'
        '🔥 *हीट:* 21-दिवसीय चक्र (AI तुरंत स्थगित रखें!)\n'
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
        '🩺 *डॉक्टर अनुरोध:* तत्काल IV फ्लुइड व एंटीपायरेटिक आवश्यक!\n'
        '📲 लाइव टेलीमेट्री: https://farmers.milterrafoods.com/#/health/emergency-crisis';

    final url = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(msg)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: const Color(0xfff8fafc),
        appBar: AppBar(
          title: const Text('🚨 आपातकालीन आईसीयू मॉनिटर (ICU Telemetry)'),
          backgroundColor: const Color(0xff991b1b),
          foregroundColor: Colors.white,
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
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'WhatsApp पर अलर्ट भेजें',
              onPressed: _shareOnWhatsApp,
            ),
          ],
        ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Flashing / Pulsing Code Red Banner
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        const Color(0xff7f1d1d),
                        const Color(0xffb91c1c),
                        _pulseController.value,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffdc2626).withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: Color(0xffb91c1c), size: 32),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🚨 कोड रेड: बहु-अंग संकट (MULTI-CRISIS EMERGENCY)',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'गंगा गाय (टैग #MIL-0842) - गीर देशी नस्ल',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'उम्र: 4.5 वर्ष • दुधारू (Lactation 2, दिन 72) • वजन: 420 kg',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Real-Time Sensor Vitals Grid (5 Live Meters)
              const Text(
                'कॉलर लाइव टेलीमेट्री (Live IoT Collar Vitals - Just Now)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isWide ? 1.4 : 1.3,
                    children: [
                      _buildVitalTile(
                        icon: Icons.thermostat,
                        color: const Color(0xffdc2626),
                        title: 'तापमान (Body Temp)',
                        value: '40.8 °C',
                        subValue: '105.4 °F (Normal: 38.5°)',
                        status: '🚨 अति-गंभीर बुखार (+2.3°)',
                        isDanger: true,
                      ),
                      _buildVitalTile(
                        icon: Icons.airline_seat_recline_extra,
                        color: const Color(0xffea580c),
                        title: 'हलचल (Movement)',
                        value: '0 Steps',
                        subValue: 'पिछले 125 मिनट से शून्य',
                        status: '🛑 अचल (Downer Cow)',
                        isDanger: true,
                      ),
                      _buildVitalTile(
                        icon: Icons.timer_off,
                        color: const Color(0xffc026d3),
                        title: 'जुगाली (Rumination)',
                        value: '0 Min',
                        subValue: 'पिछले 5 घंटे में 0 मिनट',
                        status: '⏳ रूमेन गतिरोध (Stasis)',
                        isDanger: true,
                      ),
                      _buildVitalTile(
                        icon: Icons.favorite,
                        color: const Color(0xffe11d48),
                        title: 'हृदय गति (Heart Rate)',
                        value: '96 BPM',
                        subValue: 'सामान्य: 60-70 bpm',
                        status: '⚠️ तेज धड़कन (Pain Distress)',
                        isDanger: true,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // 5 Active Simultaneous Alerts (Detailed Breakdown Cards)
              const Text(
                'पशु में एक साथ सक्रिय 5 गंभीर संकट (5 Simultaneous Alerts)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              _buildCrisisDetailCard(
                icon: Icons.thermostat,
                color: const Color(0xffdc2626),
                title: '1. अति-गंभीर बुखार (Hyperpyrexia - 40.8°C / 105.4°F)',
                badge: '🚨 40.8°C FEVER',
                details:
                    'पिछले 4 घंटे से लगातार 105.4°F पर स्थिर। यह सामान्य थकावट नहीं बल्कि रक्तप्रवाह में बैक्टीरिया और टॉक्सिन फैलने (Endotoxemia) का संकेत है।',
                urgency: 'तुरंत माथे पर ठंडा पानी डालें व एंटीपायरेटिक (Flunixin) दें।',
              ),
              const SizedBox(height: 10),

              _buildCrisisDetailCard(
                icon: Icons.water_drop,
                color: const Color(0xffb91c1c),
                title: '2. तीव्र क्लिनिकल थनैला (Acute Toxic Mastitis)',
                badge: '⚠️ तीव्र थनैला (MASTITIS)',
                details:
                    'दाहिना पिछला थन (Right Hind Quarter) गर्म, सूजा व अत्यधिक दर्दनाक। दूध में पीले थक्के, मवाद व पानी आ रहा है। दूध उत्पादन में 45% की भारी गिरावट।',
                urgency: 'थन को हर 30 मिनट में खाली (Frequent Milking) करें + एंटीबायोटिक ट्यूब।',
              ),
              const SizedBox(height: 10),

              _buildCrisisDetailCard(
                icon: Icons.airline_seat_flat,
                color: const Color(0xffea580c),
                title: '3. अचल पशु / डाउनर सिंड्रोम (No Movement Till 2 Hours)',
                badge: '🛑 2 घंटे से 0 हलचल (DOWNER)',
                details:
                    'सेंसर द्वारा पिछले 125 मिनट से 0 कदम और 0 गतिविधि दर्ज की गई है। अत्यधिक दर्द, कमजोरी या डिहाइड्रेशन के कारण गाय फर्श पर गिर गई है और उठने में असमर्थ है।',
                urgency: 'गाय के नीचे सूखा नरम भूसा बिछाएं, दोनों तरफ करवट बदलते रहें।',
              ),
              const SizedBox(height: 10),

              _buildCrisisDetailCard(
                icon: Icons.access_time_filled,
                color: const Color(0xff7c3aed),
                title: '4. रूमेन गतिरोध (No Jugali / Stalled Rumination Since 5 Hours)',
                badge: '⏳ 5 घंटे से 0 जुगाली (RUMEN ATOMY)',
                details:
                    'पिछले 300 मिनट (5 घंटे) में रूमेन की गतिविधि और जुगाली बिल्कुल शून्य (0 min) रही है। पेट में किण्वन रुकने से एसिडोसिस और गैस (Tympany) का गंभीर खतरा उत्पन्न हो गया है।',
                urgency: 'रूमेन स्टिमुलेंट बोलस व प्रोबायोटिक तत्काल दें।',
              ),
              const SizedBox(height: 10),

              _buildCrisisDetailCard(
                icon: Icons.whatshot,
                color: const Color(0xffdb2777),
                title: '5. 21-दिवसीय हीट चक्र (Estrus Co-occurrence / AI Suspended)',
                badge: '🔥 मद चक्र (AI तुरंत स्थगित रखें!)',
                details:
                    'हार्मोनल 21-दिवसीय मद चक्र मेल खा रहा है, लेकिन वर्तमान में थनैला व 105.4°F बुखार के कारण कृत्रिम गर्भाधान (AI) सख्त वर्जित है! गर्भाधान करने पर गर्भपात या गर्भाशय सड़ने का खतरा रहेगा।',
                urgency: 'पहले थनैला और बुखार ठीक करें, इस चक्र में गर्भाधान न करें।',
              ),

              const SizedBox(height: 20),

              // AI Clinical Triage Synthesis Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xfffef2f2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xfffecaca), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.smart_toy, color: Color(0xffdc2626), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'एआई वेटरनरी क्लिनिकल निष्कर्ष (AI Diagnosis Synthesis)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xff991b1b),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      'तीव्र विषैला थनैला व सेप्टिक शॉक (Acute Toxic Mastitis with Secondary Hypomotility & Downer Syndrome)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff7f1d1d),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'गंगा गाय में 40.8°C बुखार, 5 घंटे से शून्य जुगाली और 2 घंटे से अचल पड़े रहना अत्यंत आपातकालीन स्थिति है। यह केवल हीट का मामला नहीं है—थनैला के विषैले बैक्टीरिया खून में फैल रहे हैं। 2 घंटे के भीतर तत्काल चिकित्सकीय उपचार न मिलने पर पशु की जान को खतरा हो सकता है।',
                      style: TextStyle(fontSize: 12, color: Color(0xff450a0a), height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Emergency Medicines & First Aid Checklist
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.medical_services, color: Color(0xff064e3b), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'आपातकालीन दवाएं व प्राथमिक उपचार (First Aid & Medicines)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    _buildMedRow(
                      '1. Flunixin Meglumine (Megludyne) 15-20ml IV/IM',
                      '105.4°F बुखार व थनैला टॉक्सिन का शॉक तुरंत रोकने हेतु',
                    ),
                    _buildMedRow(
                      '2. Intramammary Infusion (Cobactan LC / Pendistrin-SH)',
                      'सूजे हुए थन में सीधे चढ़ाने हेतु एंटीबायोटिक ट्यूब',
                    ),
                    _buildMedRow(
                      '3. Ringer Lactate / Dextrose 5% (3-4 Litres IV)',
                      'शॉक, निर्जलीकरण (Dehydration) व डाउनर अवस्था से बाहर लाने हेतु',
                    ),
                    _buildMedRow(
                      '4. Rumen Motor / Appetizer Bolus (Rumentas / Biosacc)',
                      'ठप पड़ी जुगाली (Rumen Motility) पुनः शुरू करने हेतु',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Emergency Call & Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final phone = Uri.parse('tel:+919876543210');
                        launchUrl(phone);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffdc2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone_in_talk, size: 22),
                      label: const Text(
                        'डॉक्टर को SOS कॉल',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareOnWhatsApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send, size: 20),
                      label: const Text(
                        'WhatsApp रिपोर्ट',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.push('/vet/booking'),
                icon: const Icon(Icons.video_call, color: Color(0xff064e3b)),
                label: const Text('पशु चिकित्सक से ऑनलाइन सलाह लें (Tele-Vet Booking)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildVitalTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subValue,
    required String status,
    required bool isDanger,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDanger ? color.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: isDanger ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                subValue,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCrisisDetailCard({
    required IconData icon,
    required Color color,
    required String title,
    required String badge,
    required String details,
    required String urgency,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            details,
            style: const TextStyle(fontSize: 12, color: Color(0xff334155), height: 1.35),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.deepOrange, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'तत्काल कदम: $urgency',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xffc2410c),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedRow(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Color(0xff047857), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
