import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class FarmerHealthTriageScreen extends ConsumerStatefulWidget {
  const FarmerHealthTriageScreen({super.key});

  @override
  ConsumerState<FarmerHealthTriageScreen> createState() =>
      _FarmerHealthTriageScreenState();
}

class _FarmerHealthTriageScreenState
    extends ConsumerState<FarmerHealthTriageScreen> {
  String _selectedAnimalType = 'cow'; // 'cow' or 'buffalo'
  final Set<String> _selectedSymptoms = {'swelling', 'udder_clot'};
  String? _selectedCattleTag = 'Ganga (#0842)';
  bool _hasAnalyzed = true;

  // Active diagnosis display
  String _diagnosedCondition = 'तीव्र थनैला रोग (Acute Bovine Mastitis)';
  String _severityLevel = 'high'; // 'low', 'medium', 'high', 'emergency'
  double _confidence = 0.92;
  String _clinicalSummary =
      'थन में सूजन व दूध में छीछड़े आना जीवाणु संक्रमण (Bacterial Mastitis) का स्पष्ट संकेत है। तत्काल देसी लेप लगाएं व दूध पूरी तरह निकालें।';

  List<String> _firstAidIngredients = [
    'ताजा घृतकुमारी (Aloe Vera) - 200 ग्राम (गूदा)',
    'शुद्ध हल्दी पाउडर (Turmeric) - 50 ग्राम',
    'बुझा हुआ चूना (Slaked Lime/Chuna) - 10-15 ग्राम',
  ];

  String _firstAidPreparation =
      'घृतकुमारी, हल्दी और चूने को सिलबट्टे या मिक्सी में पीसकर गाढ़ा लाल/नारंगी लेप बना लें। आवश्यकतानुसार थोड़ा पानी मिलाएँ।';

  String _firstAidApplication =
      '1. पहले संक्रमित थन से सारा खराब दूध अलग बर्तन में दुहकर नष्ट कर दें (जमीन पर न गिराएँ)।\n'
      '2. थन को गुनगुने पानी से धोकर सुखाएँ।\n'
      '3. तैयार देसी लेप को पूरे थन व बाड़े पर दिन में 3 से 4 बार अच्छी तरह लगाएँ। लगातार 3-5 दिन तक दोहराएँ।';

  String _vitalPrecaution =
      'सावधानी: इस गाय को सबसे अंत में दुहें ताकि अन्य स्वस्थ पशुओं में संक्रमण न फैले। यदि 24 घंटे में बुखार या सूजन कम न हो तो तुरंत पशु चिकित्सक को बुलाएँ।';

  final List<Map<String, dynamic>> _quickDiseaseCards = [
    {
      'title': 'थनैला रोग',
      'sub': 'Mastitis',
      'icon': Icons.water_drop,
      'color': Color(0xffbe185d),
      'symptoms': ['swelling', 'udder_clot', 'low_milk'],
      'condition': 'तीव्र थनैला रोग (Acute Bovine Mastitis)',
      'severity': 'high',
      'confidence': 0.92,
      'summary':
          'थन में सूजन व दूध में छीछड़े आना जीवाणु संक्रमण (Bacterial Mastitis) का स्पष्ट संकेत है। तत्काल देसी लेप लगाएं।',
      'ingredients': [
        'ताजा घृतकुमारी (Aloe Vera) - 200 ग्राम',
        'शुद्ध हल्दी पाउडर (Turmeric) - 50 ग्राम',
        'बुझा हुआ चूना (Chuna) - 10-15 ग्राम',
      ],
      'prep':
          'घृतकुमारी, हल्दी और चूने को पीसकर गाढ़ा लाल/नारंगी लेप तैयार करें।',
      'apply':
          'संक्रमित थन को खाली करके पूरे थन पर दिन में 3-4 बार लेप लगाएं। 3 दिन तक जारी रखें।',
      'precaution':
          'इस पशु को सबसे अंत में दुहें ताकि स्वस्थ पशुओं में थनैला न फैले।',
    },
    {
      'title': 'अफारा व गैस',
      'sub': 'Bloat / Tympany',
      'icon': Icons.radio_button_checked,
      'color': Color(0xffb45309),
      'symptoms': ['bloat', 'off_feed', 'belly_kick'],
      'condition': 'तीव्र रूमेन अफारा (Acute Ruminal Bloat/Tympany)',
      'severity': 'emergency',
      'confidence': 0.95,
      'summary':
          'बायां पेट ढोल की तरह फूलना व सांस लेने में तकलीफ होना जानलेवा अफारा का लक्षण है। तुरंत मुंह में लकड़ी का बित्ता फंसाएं।',
      'ingredients': [
        'सरसों या अलसी का तेल (Mustard Oil) - 100-150 मिली',
        'असली हींग (Asafoetida) - 10-15 ग्राम',
        'मेथी दाना व सौंठ पाउडर - 25 ग्राम',
        'काला नमक - 25 ग्राम',
      ],
      'prep':
          'तेल को हल्का गुनगुना करें। उसमें हींग, मेथी व नमक मिलाकर 250 मिली गुनगुने पानी में घोलें।',
      'apply':
          'नाल (Drenching bottle) की सहायता से पशु की जीभ दबाए बिना धीरे-धीरे मुंह के कोने से पिलाएं। पशु का सिर ऊंचा रखें।',
      'precaution':
          'अत्यंत महत्वपूर्ण: पशु को लिटाएं नहीं! उसे धीरे-धीरे टहलाएं। मुंह में लकड़ी की खपच्ची रस्सी से बांधें ताकि मुंह खुला रहे व झागदार गैस निकलती रहे।',
    },
    {
      'title': 'लम्पी स्किन',
      'sub': 'Lumpy Skin (LSD)',
      'icon': Icons.bubble_chart,
      'color': Color(0xff7c2d12),
      'symptoms': ['skin_nodules', 'fever', 'salivation'],
      'condition': 'गांठदार त्वचा रोग (Lumpy Skin Disease - LSD)',
      'severity': 'high',
      'confidence': 0.90,
      'summary':
          'त्वचा पर 2-5 सेमी की कठोर गांठें, तेज बुखार व पैरों में सूजन वायरस जनित लम्पी रोग है। नीम व हल्दी का काढ़ा व लेप दें।',
      'ingredients': [
        'नीम के पत्ते व हल्दी - 50-50 ग्राम',
        'शुद्ध नारियल तेल - 100 मिली',
        'पान के पत्ते, काली मिर्च व गुड़ - 20 ग्राम (मौखिक काढ़ा)',
      ],
      'prep':
          'नीम व हल्दी को नारियल तेल में उबालकर घाव भरने का तेल तैयार करें। पान, काली मिर्च व गुड़ का लड्डू बनाकर खिलाएं।',
      'apply':
          'घावों पर नीम-हल्दी का तेल सुबह-शाम लगाएं। पान-काली मिर्च-गुड़ का मिश्रण दिन में 2 बार 3 दिन तक खिलाएं।',
      'precaution':
          'पशु को मक्खी-मच्छरों से बचाने हेतु बाड़े में नीम की धूनी करें। स्वस्थ पशुओं से तुरंत अलग बाँधें।',
    },
    {
      'title': 'खुरपका-मुंहपका',
      'sub': 'FMD / Foot Rot',
      'icon': Icons.pan_tool,
      'color': Color(0xff1e3a8a),
      'symptoms': ['salivation', 'limping', 'mouth_sores'],
      'condition': 'खुरपका व मुंहपका (Foot & Mouth Disease - FMD)',
      'severity': 'high',
      'confidence': 0.88,
      'summary':
          'मुंह से लार के तार गिरना, खुरों के बीच छाले व लंगड़ाना। पोटाश (लाल दवा) के पानी से खुर धोएं।',
      'ingredients': [
        'लाल दवा (पोटेशियम परमैंगनेट 1:1000 घोल)',
        'कत्था, हल्दी व शहद - 20 ग्राम (मुंह के छालों हेतु)',
        'कपूर व सरसों का तेल - खुर के कीड़े व घाव रोकने हेतु',
      ],
      'prep':
          'गुनगुने पानी में चुटकी भर लाल दवा डालकर गुलाबी पानी बनाएं। कत्था व हल्दी शहद में मिलाकर पेस्ट बनाएं।',
      'apply':
          'खुरों को दिन में 2 बार लाल दवा के पानी से धोएं। मुंह के छालों पर कत्था-हल्दी-शहद का लेप लगाएं।',
      'precaution':
          'पशु को मुलायम दलिया, मांड या हरा मुलायम चारा दें। कड़े चारे से मुंह में दर्द बढ़ सकता है।',
    },
    {
      'title': 'दूध का बुखार',
      'sub': 'Milk Fever',
      'icon': Icons.vaccines,
      'color': Color(0xff065f46),
      'symptoms': ['downer', 'cold_body', 'off_feed'],
      'condition': 'प्रसव उपरांत हाइपोकैल्सीमिया (Milk Fever)',
      'severity': 'emergency',
      'confidence': 0.94,
      'summary':
          'ब्याने के 24-48 घंटे बाद गाय का बैठ जाना, गर्दन मोड़कर बैठना व शरीर ठंडा होना। यह कैल्शियम की अचानक कमी से होता है।',
      'ingredients': [
        'तुरंत आपातकालीन पशु चिकित्सक (IV Calcium Borogluconate)',
        'ओरल कैल्शियम जेल (यदि पशु निगलने की स्थिति में हो)',
      ],
      'prep':
          'यह एक चिकित्सीय आपातकाल है! मुंह में कुछ भी जबरदस्ती न डालें जब तक पशु होश में न हो।',
      'apply':
          'पशु चिकित्सक द्वारा नस में (IV) कैल्शियम चढ़वाना ही एकमात्र जीवनरक्षक इलाज है।',
      'precaution':
          'चेतावनी: जबरदस्ती पानी या दवा नाल से न पिलाएं! फेफड़ों में दवा जाने से पशु की तुरंत मौत (ड्रेंचिंग न्यूमोनिया) हो सकती है।',
    },
  ];

  final List<Map<String, String>> _symptomLibrary = [
    {'id': 'swelling', 'hi': 'थन में सूजन / कड़ापन', 'en': 'Udder Swelling'},
    {'id': 'udder_clot', 'hi': 'दूध में छीछड़े / खून', 'en': 'Blood/Clots in Milk'},
    {'id': 'bloat', 'hi': 'बायां पेट फूलना (अफारा)', 'en': 'Bloated Left Flank'},
    {'id': 'off_feed', 'hi': 'चारा-पानी बंद करना', 'en': 'Off Feed / Loss of Appetite'},
    {'id': 'fever', 'hi': 'तेज बुखार / कांपना', 'en': 'Fever / Shivering'},
    {'id': 'salivation', 'hi': 'मुंह से लार टपकना', 'en': 'Excessive Salivation'},
    {'id': 'limping', 'hi': 'लंगड़ा कर चलना', 'en': 'Limping / Lameness'},
    {'id': 'skin_nodules', 'hi': 'त्वचा पर गांठें / फफोले', 'en': 'Skin Nodules / Lumps'},
    {'id': 'downer', 'hi': 'बैठ जाना / उठ न पाना', 'en': 'Downer Cow / Inability to Rise'},
    {'id': 'diarrhea', 'hi': 'पतला / बदबूदार गोबर', 'en': 'Diarrhea / Loose Dung'},
    {'id': 'cold_body', 'hi': 'कान व सींग ठंडे पड़ना', 'en': 'Cold Ears & Extremities'},
    {'id': 'belly_kick', 'hi': 'पेट पर पैर मारना (दर्द)', 'en': 'Kicking at Belly (Colic)'},
  ];

  void _applyQuickCard(Map<String, dynamic> card) {
    setState(() {
      _selectedSymptoms.clear();
      _selectedSymptoms.addAll((card['symptoms'] as List).cast<String>());
      _diagnosedCondition = card['condition'] as String;
      _severityLevel = card['severity'] as String;
      _confidence = card['confidence'] as double;
      _clinicalSummary = card['summary'] as String;
      _firstAidIngredients = (card['ingredients'] as List).cast<String>();
      _firstAidPreparation = card['prep'] as String;
      _firstAidApplication = card['apply'] as String;
      _vitalPrecaution = card['precaution'] as String;
      _hasAnalyzed = true;
    });
  }

  void _analyzeSymptoms() {
    setState(() {
      _hasAnalyzed = true;
      if (_selectedSymptoms.contains('bloat') ||
          _selectedSymptoms.contains('belly_kick')) {
        _applyQuickCard(_quickDiseaseCards[1]);
      } else if (_selectedSymptoms.contains('skin_nodules')) {
        _applyQuickCard(_quickDiseaseCards[2]);
      } else if (_selectedSymptoms.contains('mouth_sores') ||
          (_selectedSymptoms.contains('salivation') &&
              _selectedSymptoms.contains('limping'))) {
        _applyQuickCard(_quickDiseaseCards[3]);
      } else if (_selectedSymptoms.contains('downer') ||
          _selectedSymptoms.contains('cold_body')) {
        _applyQuickCard(_quickDiseaseCards[4]);
      } else {
        // Default to mastitis or general checkup
        _applyQuickCard(_quickDiseaseCards[0]);
      }
    });
  }

  Future<void> _shareOnWhatsApp() async {
    final message = '''*🚨 पशु स्वास्थ्य रिपोर्ट व प्राथमिक उपचार (Dairy AI)*
पशु: $_selectedCattleTag ($_selectedAnimalType)
संभावित रोग: $_diagnosedCondition
गंभीरता: ${_severityLevel.toUpperCase()} (सटीकता: ${(_confidence * 100).toInt()}%)

*लक्षण:*
${_selectedSymptoms.map((s) => '• $s').join('\n')}

*देसी प्राथमिक उपचार (ICAR/NDDB):*
• सामग्री: ${_firstAidIngredients.join(', ')}
• विधि: $_firstAidPreparation

*सावधानी:*
$_vitalPrecaution

कृप्या डॉक्टर साहब सलाह दें या तत्काल विज़िट बुक करें।''';

    final url = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(message)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _callEmergencyHelpline() async {
    final url = Uri.parse('tel:1962'); // National Animal Emergency Helpline
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff8fafc),
      appBar: AppBar(
        title: const Text('पशु रोग पहचान व देसी प्राथमिक उपचार'),
        backgroundColor: const Color(0xff064e3b),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '1962 पशु आपातकालीन हेल्पलाइन',
            icon: const Icon(Icons.emergency, color: Colors.amberAccent),
            onPressed: _callEmergencyHelpline,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Emergency Banner
            _buildEmergencyCallHeader(context),

            // Link to Full Disease Directory
            _buildEncyclopediaBanner(context),

            // Visual Quick Select Carousel
            _buildQuickDiseaseCarousel(context),

            // Interactive Symptom Checker
            _buildSymptomSelector(context),

            // AI Triage & Ethno-Veterinary Diagnosis Result
            if (_hasAnalyzed) _buildDiagnosisAndRemedyCard(context),

            // SOS Connect Bar
            _buildSosActionButtons(context),

            const SizedBox(height: 40),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCallHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xfffee2e2),
        border: Border(bottom: BorderSide(color: Color(0xfffecaca))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xffdc2626),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '24/7 राष्ट्रीय पशु आपातकालीन हेल्पलाइन: 1962',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xff991b1b),
                  ),
                ),
                Text(
                  'गंभीर स्थिति या अफारा/मिल्क फीवर में बिना देरी कॉल करें।',
                  style: TextStyle(fontSize: 11, color: Color(0xffb91c1c)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _callEmergencyHelpline,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffdc2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Call 1962', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEncyclopediaBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffbbf7d0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff16a34a),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📚 संपूर्ण पशु रोग ज्ञानकोश (Veterinary Directory)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color: Color(0xff166534),
                  ),
                ),
                Text(
                  '15+ प्रमुख रोग, जांच विधियां, स्वर्णिम समय, देसी लेप व दवाएं',
                  style: TextStyle(fontSize: 11, color: Color(0xff15803d)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.push('/health/diseases');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff16a34a),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ज्ञानकोश खोलें', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDiseaseCarousel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: Color(0xffd97706), size: 20),
              SizedBox(width: 6),
              Text(
                'त्वरित देसी उपचार देखें (One-Tap Emergency Remedies)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff1e293b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickDiseaseCards.map((c) {
                final color = c['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () => _applyQuickCard(c),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 135,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(c['icon'] as IconData,
                                size: 18, color: color),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            c['title'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xff0f172a),
                            ),
                          ),
                          Text(
                            c['sub'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffe2e8f0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.healing, color: Color(0xff047857), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'पशु के लक्षण चुनें (Select Observed Symptoms)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xff064e3b),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedSymptoms.length} चुने गए',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff047857),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Animal Type & Cattle ID Selector
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xfff1f5f9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAnimalType,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'cow', child: Text('🐄 देशी/HF गाय (Cow)')),
                          DropdownMenuItem(
                              value: 'buffalo',
                              child: Text('🐃 मुर्राह भैंस (Buffalo)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedAnimalType = v);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xfff1f5f9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCattleTag,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'Ganga (#0842)',
                              child: Text('Ganga (#0842)')),
                          DropdownMenuItem(
                              value: 'Gauri (#0911)',
                              child: Text('Gauri (#0911)')),
                          DropdownMenuItem(
                              value: 'Murrah (#1024)',
                              child: Text('Murrah (#1024)')),
                          DropdownMenuItem(
                              value: 'Guest Animal',
                              child: Text('अन्य पशु (Guest)')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCattleTag = v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Symptoms Chip Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _symptomLibrary.map((s) {
                final isSelected = _selectedSymptoms.contains(s['id']);
                return FilterChip(
                  label: Text(
                    '${s['hi']} (${s['en']})',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : const Color(0xff334155),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xff047857),
                  backgroundColor: const Color(0xfff8fafc),
                  checkmarkColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xff047857)
                          : const Color(0xffcbd5e1),
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedSymptoms.add(s['id']!);
                      } else {
                        _selectedSymptoms.remove(s['id']);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // Analyze Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _selectedSymptoms.isEmpty ? null : _analyzeSymptoms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff064e3b),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.psychology, size: 20),
                label: const Text(
                  'रोग जाँचें व देसी उपचार देखें (Analyze & Get Remedies)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnosisAndRemedyCard(BuildContext context) {
    Color severityColor;
    String severityLabel;

    switch (_severityLevel) {
      case 'emergency':
        severityColor = const Color(0xffdc2626);
        severityLabel = '🔴 आपातकाल (Emergency - तुरंत डॉक्टर बुलाएं)';
        break;
      case 'high':
        severityColor = const Color(0xffea580c);
        severityLabel = '🟠 गंभीर (High - तत्काल उपचार आवश्यक)';
        break;
      case 'medium':
        severityColor = const Color(0xffd97706);
        severityLabel = '🟡 मध्यम (Moderate - निगरानी रखें)';
        break;
      default:
        severityColor = const Color(0xff16a34a);
        severityLabel = '🟢 सामान्य (Mild - प्राथमिक उपचार पर्याप्त)';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: severityColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: severityColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Severity Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    severityLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: severityColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'सटीकता: ${(_confidence * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: severityColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Diagnosed Condition Title
                  Text(
                    _diagnosedCondition,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff0f172a),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _clinicalSummary,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                  ),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Ethno-Veterinary Remedy Section
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xffdcfce7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.eco,
                            color: Color(0xff15803d), size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'प्रमाणित देसी प्राथमिक उपचार (ICAR/NDDB Formulations)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xff14532d),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Ingredients List
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff0fdf4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xffbbf7d0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'आवश्यक घरेलू सामग्री (Ingredients):',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xff166534),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._firstAidIngredients.map(
                          (ing) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 14, color: Color(0xff16a34a)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    ing,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff14532d),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Preparation
                  const Text(
                    'बनाने की विधि (Preparation):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xff1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _firstAidPreparation,
                    style: const TextStyle(fontSize: 12, color: Color(0xff334155), height: 1.4),
                  ),

                  const SizedBox(height: 10),

                  // Application Method
                  const Text(
                    'उपयोग की विधि (Application & Dosing):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xff1e293b),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _firstAidApplication,
                    style: const TextStyle(fontSize: 12, color: Color(0xff334155), height: 1.4),
                  ),

                  const SizedBox(height: 12),

                  // Precaution Box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xfffffbeb),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xfffde68a)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Color(0xffb45309), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _vitalPrecaution,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xff92400e),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
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
      ),
    );
  }

  Widget _buildSosActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _shareOnWhatsApp,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff15803d),
                side: const BorderSide(color: Color(0xff15803d), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text(
                'व्हाट्सएप पर डॉक्टर को भेजें',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/vet/booking'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffbe185d),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.video_call, size: 20),
              label: const Text(
                'पशु चिकित्सक परामर्श',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
