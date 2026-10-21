// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/foundation.dart';

@immutable
class MedicineItem {
  final String molecule;
  final List<String> tradeNames;
  final String dosage;
  final String route; // 'IV', 'IM', 'SC', 'Intra-mammary', 'Oral', 'Topical'
  final String milkWithdrawal;
  final String meatWithdrawal;
  final bool prescriptionRequired;
  final String? notes;

  const MedicineItem({
    required this.molecule,
    required this.tradeNames,
    required this.dosage,
    required this.route,
    required this.milkWithdrawal,
    required this.meatWithdrawal,
    this.prescriptionRequired = true,
    this.notes,
  });

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      molecule: json['molecule'] as String? ?? '',
      tradeNames: (json['tradeNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      dosage: json['dosage'] as String? ?? '',
      route: json['route'] as String? ?? 'IM',
      milkWithdrawal: json['milkWithdrawal'] as String? ?? '0 hours',
      meatWithdrawal: json['meatWithdrawal'] as String? ?? '0 days',
      prescriptionRequired: json['prescriptionRequired'] as bool? ?? true,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'molecule': molecule,
        'tradeNames': tradeNames,
        'dosage': dosage,
        'route': route,
        'milkWithdrawal': milkWithdrawal,
        'meatWithdrawal': meatWithdrawal,
        'prescriptionRequired': prescriptionRequired,
        'notes': notes,
      };
}

@immutable
class DiseaseVitals {
  final String temperatureF;
  final String heartRateBpm;
  final String respirationRateBpm;
  final String rumenMotility;

  const DiseaseVitals({
    required this.temperatureF,
    required this.heartRateBpm,
    required this.respirationRateBpm,
    required this.rumenMotility,
  });

  factory DiseaseVitals.fromJson(Map<String, dynamic> json) {
    return DiseaseVitals(
      temperatureF: json['temperatureF'] as String? ?? '101.5°F',
      heartRateBpm: json['heartRateBpm'] as String? ?? '70 bpm',
      respirationRateBpm: json['respirationRateBpm'] as String? ?? '25 bpm',
      rumenMotility: json['rumenMotility'] as String? ?? '2 per 2 min',
    );
  }
}

@immutable
class LivestockDisease {
  final String id;
  final String name;
  final String hindiName;
  final String scientificName;
  final String category; // 'bacterial', 'viral', 'protozoal', 'metabolic', 'reproductive', 'parasitic'
  final String categoryHindi;
  final List<String> animalTypes; // 'cow', 'buffalo', 'calf', 'heifer'
  final String severity; // 'emergency', 'urgent', 'moderate'
  final String severityHindi;
  final List<String> primarySymptoms;
  final List<String> secondarySymptoms;
  final DiseaseVitals vitals;
  final String onFarmTest;
  final String clinicalLabTest;
  final String differentialDiagnosis;
  final String criticalWindow;
  final String seasonalPeak;
  final String consequenceOfDelay;
  final List<String> firstAidIngredients;
  final String firstAidPreparation;
  final String firstAidApplication;
  final List<String> firstAidPrecautions;
  final String clinicalProtocol;
  final String ivFluids;
  final String supportiveTherapy;
  final List<MedicineItem> suggestedMedicines;
  final String? vaccineName;
  final String? vaccineSchedule;
  final List<String> biosecurity;

  const LivestockDisease({
    required this.id,
    required this.name,
    required this.hindiName,
    required this.scientificName,
    required this.category,
    required this.categoryHindi,
    required this.animalTypes,
    required this.severity,
    required this.severityHindi,
    required this.primarySymptoms,
    required this.secondarySymptoms,
    required this.vitals,
    required this.onFarmTest,
    required this.clinicalLabTest,
    required this.differentialDiagnosis,
    required this.criticalWindow,
    required this.seasonalPeak,
    required this.consequenceOfDelay,
    required this.firstAidIngredients,
    required this.firstAidPreparation,
    required this.firstAidApplication,
    required this.firstAidPrecautions,
    required this.clinicalProtocol,
    required this.ivFluids,
    required this.supportiveTherapy,
    required this.suggestedMedicines,
    this.vaccineName,
    this.vaccineSchedule,
    required this.biosecurity,
  });

  factory LivestockDisease.fromJson(Map<String, dynamic> json) {
    final sym = json['symptoms'] as Map<String, dynamic>? ?? {};
    final vitalsJson = sym['vitals'] as Map<String, dynamic>? ?? {};
    final testJson = json['testingMethods'] as Map<String, dynamic>? ?? {};
    final timeJson = json['goldenHourTiming'] as Map<String, dynamic>? ?? {};
    final aid1 = json['firstAid'] as Map<String, dynamic>? ?? {};
    final aid2 = json['secondaryAid'] as Map<String, dynamic>? ?? {};
    final prev = json['prevention'] as Map<String, dynamic>? ?? {};

    return LivestockDisease(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      hindiName: json['hindiName'] as String? ?? '',
      scientificName: json['scientificName'] as String? ?? '',
      category: json['category'] as String? ?? 'bacterial',
      categoryHindi: json['categoryHindi'] as String? ?? '',
      animalTypes: (json['animalTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['cow', 'buffalo'],
      severity: json['severity'] as String? ?? 'urgent',
      severityHindi: json['severityHindi'] as String? ?? '',
      primarySymptoms: (sym['primary'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      secondarySymptoms: (sym['secondary'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      vitals: DiseaseVitals.fromJson(vitalsJson),
      onFarmTest: testJson['onFarmTest'] as String? ?? '',
      clinicalLabTest: testJson['clinicalLabTest'] as String? ?? '',
      differentialDiagnosis: testJson['differentialDiagnosis'] as String? ?? '',
      criticalWindow: timeJson['criticalWindow'] as String? ?? '',
      seasonalPeak: timeJson['seasonalPeak'] as String? ?? '',
      consequenceOfDelay: timeJson['consequenceOfDelay'] as String? ?? '',
      firstAidIngredients: (aid1['ingredients'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      firstAidPreparation: aid1['preparation'] as String? ?? '',
      firstAidApplication: aid1['application'] as String? ?? '',
      firstAidPrecautions: (aid1['precautions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      clinicalProtocol: aid2['clinicalProtocol'] as String? ?? '',
      ivFluids: aid2['ivFluids'] as String? ?? '',
      supportiveTherapy: aid2['supportiveTherapy'] as String? ?? '',
      suggestedMedicines: (json['suggestedMedicines'] as List<dynamic>?)
              ?.map((e) => MedicineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      vaccineName: prev['vaccineName'] as String?,
      vaccineSchedule: prev['vaccineSchedule'] as String?,
      biosecurity: (prev['biosecurity'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Offline comprehensive dataset (15 major livestock diseases)
/// Always available even with no rural internet connectivity!
final List<LivestockDisease> fallbackLivestockDiseases = [
  // 1. Mastitis
  const LivestockDisease(
    id: 'bovine-mastitis',
    name: 'Bovine Mastitis (Udder Infection)',
    hindiName: 'थनैला रोग (थन में सूजन व छीछड़े)',
    scientificName: 'Staphylococcus aureus / Streptococcus agalactiae / E. coli',
    category: 'bacterial',
    categoryHindi: 'जीवाणु जनित (थन/दूध)',
    animalTypes: ['cow', 'buffalo', 'heifer'],
    severity: 'urgent',
    severityHindi: 'तत्काल ध्यान (2-4 घंटे)',
    primarySymptoms: [
      'थन में कठोरता, अत्यधिक सूजन, दर्द और लालिमा',
      'दूध में छीछड़े, थक्के (clots), पीलापन या खून आना',
      'दूध उत्पादन में अचानक 50-80% की भारी गिरावट',
      'पशु द्वारा थन छूने न देना व लात मारना',
    ],
    secondarySymptoms: [
      'तीव्र अवस्था में तेज बुखार (103°F-105°F)',
      'थन का ठंडा पड़ना या काला होना (गैंग्रीनस थनैला)',
      'चारा छोड़ना व सुस्त होकर बैठना',
    ],
    vitals: DiseaseVitals(
      temperatureF: '102.5°F - 105.0°F (तीव्र अवस्था में)',
      heartRateBpm: '70 - 90 bpm',
      respirationRateBpm: '25 - 40 bpm',
      rumenMotility: '1-2 प्रति 2 मिनट',
    ),
    onFarmTest:
        '1. स्ट्रिप कप टेस्ट: पहली 2-3 धार काली प्लेट पर लें और छीछड़े देखें। 2. सीएमटी (California Mastitis Test): 2 मिली दूध में 2 मिली सीएमटी रीजेंट मिलाकर 15 सेकंड हिलाएं; गाढ़ा जेल बनना थनैला प्रमाणित करता है। 3. पीएच पेपर (ब्रोमोथाइमोल ब्लू): दूध का पीएच 6.8 से ऊपर (गहरा हरा/नीला) आना।',
    clinicalLabTest:
        'दूध कल्चर व एंटीबायोग्राम (ABST) द्वारा सटीक जीवाणु व प्रभावी एंटीबायोटिक की पहचान; सोमैटिक सेल काउंट (SCC > 2,00,000)।',
    differentialDiagnosis: 'शारीरिक चोट, थन में सूजन (उडेमा), लेप्टोस्पायरोसिस।',
    criticalWindow:
        'पहले 2 से 4 घंटे! दूध में बदलाव दिखते ही तुरंत उपचार शुरू करें ताकि थन हमेशा के लिए बंद न हो।',
    seasonalPeak:
        'ब्याने के पहले 30 दिन व बरसात/मानसून के महीने (नमी व कीचड़ के कारण)।',
    consequenceOfDelay:
        '24-48 घंटे की देरी से थन का स्थायी रूप से सूखना (फाइब्रोसिस) या क्वार्टर का अंधा होना।',
    firstAidIngredients: [
      'ताजा घृतकुमारी (Aloe Vera) - 200 ग्राम (गूदा)',
      'शुद्ध हल्दी पाउडर (Turmeric) - 50 ग्राम',
      'बुझा हुआ चूना (Slaked Lime/Chuna) - 10-15 ग्राम',
    ],
    firstAidPreparation:
        'घृतकुमारी, हल्दी और चूने को मिक्सी या सिलबट्टे पर पीसकर गाढ़ा लाल/नारंगी लेप बना लें।',
    firstAidApplication:
        '1. सबसे पहले संक्रमित थन से सारा खराब दूध अलग बर्तन में दुहकर जमीन में गाड़ दें। 2. थन को गुनगुने पानी से धोकर सुखाएं। 3. तैयार देसी लेप को पूरे थन पर दिन में 3-4 बार लगाएं। 3 से 5 दिन दोहराएं।',
    firstAidPrecautions: [
      'खराब दूध को कभी भी फर्श या बाड़े में न गिराएं, इससे अन्य पशुओं में संक्रमण फैलेगा।',
      'संक्रमित पशु को हमेशा सबसे अंत में दुहें।',
      'दूध दुहने वाले हाथ हमेशा साबुन से धोएं।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा इंट्रा-मेमरी एंटीबायोटिक ट्यूब चढ़ाना (थन पूरी तरह खाली करने के बाद), साथ में सिस्टेमिक एंटीबायोटिक और सूजन-दर्द निवारक इंजेक्शन।',
    ivFluids: 'तेज बुखार व टॉक्सिमिया में 5% डेक्सट्रोज सेलाइन 2-3 लीटर IV।',
    supportiveTherapy:
        'विटामिन एच (बायोटिन), विटामिन ई + सेलेनियम और जिंक ओरल टॉनिक।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Ceftiofur Sodium',
        tradeNames: ['Xyrofur', 'Intacef', 'Ceftiforce'],
        dosage: '1-2 mg/kg शरीर भार (1 ग्राम वायल 400 किग्रा गाय हेतु) IM/SC',
        route: 'IM / SC',
        milkWithdrawal: '0 घंटे (दूध फेंकने की आवश्यकता नहीं - डेयरी सुरक्षित)',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'दूध में एंटीबायोटिक अवशेष न छोड़ने वाली सर्वोत्तम दवा।',
      ),
      MedicineItem(
        molecule: 'Meloxicam + Paracetamol',
        tradeNames: ['Melonex Plus', 'Melox-P', 'Zobid-M'],
        dosage: '15 - 20 मिली IM (एक बार दैनिक, 3 दिन)',
        route: 'IM',
        milkWithdrawal: '72 घंटे (3 दिन)',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'थन का दर्द, लाली व तापमान तुरंत कम करता है।',
      ),
      MedicineItem(
        molecule: 'Amoxicillin + Cloxacillin (Intramammary)',
        tradeNames: ['Pendistrin-SH', 'Tilox intramammary', 'Mammitel'],
        dosage: '1 ट्यूब प्रति संक्रमित क्वार्टर (12 घंटे के अंतराल पर)',
        route: 'Intra-mammary',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '7 दिन',
        prescriptionRequired: true,
        notes: 'थन की नली को स्प्रिट से साफ करके ही ट्यूब चढ़ाएं।',
      ),
    ],
    vaccineName: 'टीट-डिप (Teat Dip) स्वच्छता प्रोटोकॉल',
    vaccineSchedule: 'दूध दुहने के तुरंत बाद 0.5% पोविडोन आयोडीन में टीट-डिप करें।',
    biosecurity: [
      'दूध दुहने के 45 मिनट बाद तक गाय को बैठने न दें (चारा डालकर खड़ा रखें)।',
      'बाड़े का फर्श सूखा व चूना छिड़का हुआ रखें।',
      'पूर्ण हस्त दोहन (Full Hand Milking) करें, अंगूठा दबाकर न दुहें।',
    ],
  ),

  // 2. Hemorrhagic Septicemia (HS)
  const LivestockDisease(
    id: 'hemorrhagic-septicemia',
    name: 'Hemorrhagic Septicemia - HS',
    hindiName: 'गलघोंटू रोग (घुर्रा / नाविक ज्वर)',
    scientificName: 'Pasteurella multocida (Serotype B:2)',
    category: 'bacterial',
    categoryHindi: 'जीवाणु जनित (तीव्र घातक)',
    animalTypes: ['buffalo', 'cow', 'calf'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-2 घंटे)',
    primarySymptoms: [
      'अचानक तेज बुखार (104°F से 107°F)',
      'गले, जबड़े के नीचे और गलकंबल में गर्म, कठोर व अत्यंत दर्दनाक सूजन',
      'मुंह से लगातार लार टपकना व जीभ बाहर निकलना',
      'सांस लेने में भारी घरघराहट या घुर्र-घुर्र की आवाज (Stertorous breathing)',
    ],
    secondarySymptoms: [
      'आंखें लाल होना व पानी बहना',
      'पशु का दम घुटना और बेचैनी से जमीन पर गिरना',
      'खून मिश्रित दस्त (अंतिम अवस्था)',
    ],
    vitals: DiseaseVitals(
      temperatureF: '104.0°F - 107.0°F (अत्यधिक तीव्र)',
      heartRateBpm: '90 - 120 bpm (अति तीव्र)',
      respirationRateBpm: '40 - 65 bpm (गंभीर कष्ट)',
      rumenMotility: '0 (पूर्ण बंद)',
    ),
    onFarmTest:
        'गले की सूजन को अंगुली से दबाने पर गड्ढा पड़ना (Pitting edema), तेज बुखार और घुर्र-घुर्र सांस की आवाज।',
    clinicalLabTest:
        'रक्त स्मीयर लेकर मिथाइलीन ब्लू या जीम्सा स्टेनिंग; दोनों सिरों पर रंग ग्रहण करने वाले बाइपोलर जीवाणु (Bipolar rods) दिखना।',
    differentialDiagnosis: 'एंथ्रेक्स, ब्लैक क्वार्टर (BQ), तीव्र रूमेन अफारा।',
    criticalWindow:
        'पहले 0 से 6 घंटे! यदि पहले 6 घंटे में एंटीबायोटिक नहीं दी गई तो दम घुटने से 85% मृत्यु निश्चित है।',
    seasonalPeak: 'मानसून का आगमन (जून से सितंबर) और सर्दियों में ठंडी हवा व नमी।',
    consequenceOfDelay:
        '12-24 घंटे के भीतर श्वासनली दबने (Asphyxiation) और एंडोटॉक्सिक शॉक से मृत्यु।',
    firstAidIngredients: [
      'बर्फ की थैली या ठंडा पानी',
      'सूखी खुली जगह (वेंटिलेशन)',
      'डॉक्टर को आपातकालीन कॉल (टोल फ्री 1962)',
    ],
    firstAidPreparation: 'पशु को तुरंत ठंडी व हवादार जगह पर खड़ा करें। सिर ऊंचा रखें।',
    firstAidApplication:
        '1. गले की सूजन पर ठंडे पानी या बर्फ की सिंकाई करें ताकि सूजन थोड़ी दबे। 2. पशु का सिर ऊपर की ओर सहारा देकर रखें ताकि सांस की नली खुली रहे।',
    firstAidPrecautions: [
      '🚨 सख्त चेतावनी: पशु को मुंह से कभी भी कोई पानी, तेल या काढ़ा (Drenching) न पिलाएं! गले की मांसपेशियां लकवाग्रस्त होती हैं, दवा फेफड़ों में जाकर तुरंत दम घोंट देगी।',
      'पशु को पैदल बिल्कुल न चलाएं।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा तुरंत उच्च डोज सेफ्टियोफर या ऑक्सीटेट्रासाइक्लिन IV/IM और गले की सूजन घटाने हेतु कोर्टिकोस्टेरॉयड / फ्लूनेक्सिन मेग्लुमाइन IV।',
    ivFluids: 'नॉर्मल सेलाइन (NS) 2-3 लीटर IV धीमी गति से।',
    supportiveTherapy: 'एंटीहिस्टामिनिक (Pheniramine maleate) 10 मिली IM।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Ceftiofur Sodium',
        tradeNames: ['Intacef Tazo', 'Xyrofur', 'Naxcel'],
        dosage: '1 - 2 ग्राम IV या गहरा IM (तत्काल)',
        route: 'IV / IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'पाश्चुरेला जीवाणु के विरुद्ध जीवनरक्षक दवा।',
      ),
      MedicineItem(
        molecule: 'Flunixin Meglumine',
        tradeNames: ['Megludyne', 'Finadyne', 'Flunitas'],
        dosage: '2.2 mg/kg शरीर भार (15-20 मिली IV)',
        route: 'IV',
        milkWithdrawal: '36 घंटे',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'गले की सूजन व एंडोटॉक्सिन को तेजी से घटाता है।',
      ),
      MedicineItem(
        molecule: 'Oxytetracycline LA',
        tradeNames: ['Terramycin LA', 'Oxytet LA', 'Zodex LA'],
        dosage: '20 mg/kg शरीर भार (30-40 मिली गहरा IM)',
        route: 'IM',
        milkWithdrawal: '7 दिन',
        meatWithdrawal: '28 दिन',
        prescriptionRequired: true,
        notes: 'लंबे समय तक सुरक्षा प्रदान करने हेतु।',
      ),
    ],
    vaccineName: 'एचएस ऑयल एडजुवेंट / एलम प्रेसिपिटेटेड वैक्सीन (Raksha-HS)',
    vaccineSchedule: 'प्रतिवर्ष मई-जून (मानसून से 1 माह पूर्व) सभी 6 माह से ऊपर के पशुओं को 2-3 मिली SC लगाएं।',
    biosecurity: [
      'संक्रमित पशु के लार व चारे के संपर्क में स्वस्थ पशु को न आने दें।',
      'यदि पशु की मृत्यु हो जाए तो शव को 6 फीट गहरे गड्ढे में चूना डालकर गाड़ें।',
    ],
  ),

  // 3. Black Quarter (BQ)
  const LivestockDisease(
    id: 'black-quarter',
    name: 'Black Quarter - BQ',
    hindiName: 'लंगड़ा बुखार (जहरबाद / चरचरा / सुजका)',
    scientificName: 'Clostridium chauvoei',
    category: 'bacterial',
    categoryHindi: 'जीवाणु जनित (घातक मांसपेशी सड़न)',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-4 घंटे)',
    primarySymptoms: [
      'अचानक एक पैर से अत्यधिक लंगड़ाना',
      'पुट्ठे, जांघ, कंधे या गर्दन की भारी मांसपेशियों में गर्म व दर्दनाक सूजन',
      'सूजन वाले हिस्से पर हाथ दबाने पर चर-चर (Crepitation) की आवाज आना',
      'तेज बुखार (104°F से 106°F) व चारा-पानी बंद',
    ],
    secondarySymptoms: [
      'सूजन वाला स्थान बाद में ठंडा, बेजान व काला पड़ जाना',
      'चीरा लगाने पर बदबूदार झागदार काला खून निकलना',
      'पशु का जमीन पर गिर जाना व कंपन',
    ],
    vitals: DiseaseVitals(
      temperatureF: '104.5°F - 106.5°F',
      heartRateBpm: '85 - 110 bpm',
      respirationRateBpm: '35 - 50 bpm',
      rumenMotility: '0 (बंद)',
    ),
    onFarmTest:
        'जांघ/पुट्ठे की सूजन पर हथेली फेरने या दबाने पर सूखे पत्तों जैसी चर-चर आवाज (गैस के बुलबुले)।',
    clinicalLabTest:
        'सूजन से सुई द्वारा द्रव खींचकर ग्राम स्टेनिंग: ग्राम-पॉजिटिव स्पोर-युक्त छड़ें (Clostridium chauvoei)।',
    differentialDiagnosis: 'एंथ्रेक्स, सांप का काटना, हड्डी टूटना (Fracture)।',
    criticalWindow:
        'लंगड़ापन या सूजन के पहले 4 घंटे! एक बार विषैली गैस मांसपेशियों में फैल जाए तो उपचार असंभव हो जाता है।',
    seasonalPeak: 'मानसून के महीने, नए जुते हुए खेतों में चरने के बाद।',
    consequenceOfDelay: '12-24 घंटे के अंदर 95% मृत्यु दर।',
    firstAidIngredients: [
      '3% हाइड्रोजन पेरोक्साइड (Hydrogen Peroxide)',
      'पोटैशियम परमैंगनेट (लाल दवा)',
      'आपातकालीन पशु चिकित्सक कॉल',
    ],
    firstAidPreparation: 'पशु को छायादार शांत स्थान पर लिटाएं। चलने पर पूर्ण प्रतिबंध लगाएं।',
    firstAidApplication:
        '1. सूजन वाले स्थान पर ठंडा पानी डालें। 2. यदि चिकित्सक चीरा लगाएं तो हाइड्रोजन पेरोक्साइड से धोएं (ऑक्सीजन मिलने से एनारोबिक बैक्टीरिया मरता है)।',
    firstAidPrecautions: [
      'पशु को जबरन बिल्कुल न चलाएं, जहर तेजी से दिल में फैलेगा।',
      'खुले में चीरा लगाकर खून जमीन पर न बहाएं, मिट्टी में बीजाणु 20 साल जीवित रहते हैं।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा तुरंत भारी मात्रा में पेनिसिलिन (Procaine Penicillin G 40,000 IU/kg) सूजन के चारों ओर और IV/IM देना।',
    ivFluids: '5% डेक्सट्रोज नॉर्मल सेलाइन 2-3 लीटर IV।',
    supportiveTherapy: 'मेगाडोज एनाल्जेसिक (Meloxicam 0.5 mg/kg) और बी-कॉम्प्लेक्स।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Procaine + Benzylpenicillin',
        tradeNames: ['Bistrepen', 'Penbistrep', 'Procaine Penicillin G'],
        dosage: '30,000 - 40,000 IU/kg IM (40 लाख यूनिट वायल) और सूजन के चारों ओर स्थानीय इंजेक्शन',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '10 दिन',
        prescriptionRequired: true,
        notes: 'क्लोस्ट्रीडियम के लिए सबसे अचूक दवा यदि 4 घंटे में दी जाए।',
      ),
      MedicineItem(
        molecule: 'Meloxicam',
        tradeNames: ['Melonex', 'Melox', 'Mlobe'],
        dosage: '15 - 20 मिली गहरा IM',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'तीव्र दर्द व सूजन निवारक।',
      ),
    ],
    vaccineName: 'रक्षा-बीक्यू (Raksha-BQ) या संयुक्त HS+BQ वैक्सीन',
    vaccineSchedule: 'प्रतिवर्ष मई माह में 6 माह से अधिक उम्र के पशुओं को 3 मिली SC।',
    biosecurity: [
      'मृत पशु की खाल कभी न उतारें! शव को बिना चीरे 6 फीट गहरे गड्ढे में चूना डालकर दफनाएं।',
      'संक्रमित चारागाह में अन्य पशुओं की चराई रोकें।',
    ],
  ),

  // 4. Foot and Mouth Disease (FMD)
  const LivestockDisease(
    id: 'foot-and-mouth-disease',
    name: 'Foot and Mouth Disease - FMD',
    hindiName: 'खुरपका-मुंहपका (खुरहा / बेरा)',
    scientificName: 'Aphthovirus (Types O, A, Asia-1)',
    category: 'viral',
    categoryHindi: 'विषाणु जनित (अत्यंत संक्रामक)',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'urgent',
    severityHindi: 'तत्काल पृथक्करण व देखभाल',
    primarySymptoms: [
      'मुंह से लगातार रस्सी जैसी लंबी चिपचिपी लार (Ropy drooling) टपकना',
      'जीभ, मसूड़ों, तालू व होंठों के अंदर दर्दनाक छाले व फफोले',
      'खुरों के बीच (Interdigital cleft) में छाले व घाव, जिससे पशु लंगड़ाता है',
      'दूध उत्पादन में 80-90% की विनाशकारी गिरावट',
    ],
    secondarySymptoms: [
      'तेज बुखार (104°F से 106°F) व होंठों को बार-बार चप-चप बजाना (Lip smacking)',
      'थन पर छाले पड़ने से थनैला होना',
      'छोटे बछड़ों में बिना लक्षण दिल का दौरा पड़ना (टाइगर हार्ट)',
    ],
    vitals: DiseaseVitals(
      temperatureF: '104.0°F - 106.0°F',
      heartRateBpm: '75 - 95 bpm',
      respirationRateBpm: '30 - 45 bpm',
      rumenMotility: '1 प्रति 2 मिनट',
    ),
    onFarmTest:
        'मुंह से लंबी लार बहना, जीभ व खुरों के बीच कच्चे लाल छाले और पैर पटकना।',
    clinicalLabTest:
        'छालों के द्रव या पपड़ी का आरटी-पीसीआर (RT-PCR) या एंटीजन एलिसा (ELISA) टेस्ट।',
    differentialDiagnosis: 'वेसिकुलर स्टोमैटाइटिस, खुर सड़न (Foot Rot)।',
    criticalWindow:
        'लार टपकने के पहले 12 घंटे! तुरंत पशु को अलग बांधें व मुंह-खुर की सफाई शुरू करें ताकि कीड़े (Maggots) न पड़ें।',
    seasonalPeak: 'सर्दियों का मौसम (नवंबर से फरवरी) और पशु मेलों के दौरान।',
    consequenceOfDelay:
        'खुर का स्थायी रूप से उखड़ना (Sloughing), बांझपन व दूध उत्पादन हमेशा के लिए आधा रह जाना।',
    firstAidIngredients: [
      'पोटैशियम परमैंगनेट (लाल दवा) - 1 ग्राम प्रति 1 लीटर पानी',
      'मीठा सोडा (Sodium Bicarbonate) - 2 चम्मच',
      'शहद + भुना सुहागा (Borax) या शुद्ध घी + हल्दी पाउडर',
      'मक्खी-रोधी स्प्रे (Topicure / D-Mag)',
    ],
    firstAidPreparation:
        '1. लाल दवा के हल्के गुलाबी पानी से मुंह व खुर धोएं। 2. भुना हुआ सुहागा (10 ग्राम) शहद (50 ग्राम) में मिलाकर लेप बनाएं।',
    firstAidApplication:
        '1. दिन में 2 बार मुंह को लाल दवा के पानी से साफ करें। 2. जीभ व मसूड़ों पर शहद-सुहागा या घी-हल्दी का लेप अंगुली से हल्के-हल्के लगाएं। 3. खुरों को धोकर साफ रखें व मक्खी-रोधी स्प्रे छिड़कें। 4. दलिया व गुड़ जैसा नरम चारा दें।',
    firstAidPrecautions: [
      'बीमार पशु को स्वस्थ झुंड से कम से कम 50 मीटर दूर बांधें।',
      'पशु को कीचड़ व गोबर में न खड़ा होने दें, खुर सड़ जाएंगे।',
    ],
    clinicalProtocol:
        'वायरस की सीधी दवा नहीं होती; पशु चिकित्सक द्वारा द्वितीयक जीवाणु संक्रमण व निमोनिया रोकने हेतु ब्रॉड-स्पेक्ट्रम एंटीबायोटिक, दर्द निवारक व बुखार की दवा दी जाती है।',
    ivFluids: 'डिहाइड्रेशन में 5% डेक्सट्रोज सेलाइन 2-3 लीटर IV।',
    supportiveTherapy: 'विटामिन ए, ई और सी इंजेक्शन घाव भरने हेतु।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Meloxicam + Paracetamol',
        tradeNames: ['Melonex Plus', 'Zobid-M', 'Melox-P'],
        dosage: '15 - 20 मिली IM (दैनिक 3-4 दिन)',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'मुंह व खुर के दर्द को शांत करता है ताकि पशु जुगाली कर सके।',
      ),
      MedicineItem(
        molecule: 'Ceftiofur Sodium',
        tradeNames: ['Intacef', 'Xyrofur', 'Excenel'],
        dosage: '1 ग्राम IM (प्रतिदिन 3 दिन)',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'खुरों में सड़न व फेफड़ों के संक्रमण से बचाता है।',
      ),
      MedicineItem(
        molecule: 'Topicure Spray',
        tradeNames: ['Topicure++', 'D-Mag', 'Scavon'],
        dosage: 'खुरों व घावों पर दिन में 2 बार स्प्रे करें',
        route: 'Topical',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'मक्खियों को दूर रखता है और कीड़े पड़ने से रोकता है।',
      ),
    ],
    vaccineName: 'एफएमडी वैक्सीन (Raksha-Ovac / Footvax)',
    vaccineSchedule: 'वर्ष में दो बार (सितंबर-अक्टूबर और मार्च-अप्रैल) राष्ट्रीय टीकाकरण कार्यक्रम के तहत।',
    biosecurity: [
      'बाड़े के मुख्य द्वार पर चूने व फिनाइल का फुट-बाथ बनाएं।',
      'संक्रमित क्षेत्र से नया पशु न खरीदें।',
    ],
  ),

  // 5. Lumpy Skin Disease (LSD)
  const LivestockDisease(
    id: 'lumpy-skin-disease',
    name: 'Lumpy Skin Disease - LSD',
    hindiName: 'लम्पी त्वचा रोग (गांठदार त्वचा रोग)',
    scientificName: 'Capripoxvirus (Poxviridae)',
    category: 'viral',
    categoryHindi: 'विषाणु जनित (मक्खी/मच्छर जनित)',
    animalTypes: ['cow', 'heifer', 'calf', 'buffalo'],
    severity: 'urgent',
    severityHindi: 'तत्काल देखभाल व घाव प्रबंधन',
    primarySymptoms: [
      'पूरे शरीर, सिर, गर्दन, थन व जननांगों पर 2 से 5 सेमी की कठोर गोल गांठें (Nodules) उभरना',
      'तेज बुखार (104°F से 106°F) जो कई दिनों तक बना रहे',
      'पैरों, गलकंबल और सीने में भारी सूजन (Edema), जिससे चलने में परेशानी',
      'आंख और नाक से पानी व गाढ़ा स्राव बहना',
    ],
    secondarySymptoms: [
      'गांठों का पककर फूटना और गहरे गड्ढेदार अल्सर बन जाना',
      'दूध में भारी गिरावट व गर्भवती गायों में गर्भपात',
      'घावों में कीड़े (Maggots) पड़ना',
    ],
    vitals: DiseaseVitals(
      temperatureF: '104.0°F - 106.5°F',
      heartRateBpm: '80 - 100 bpm',
      respirationRateBpm: '30 - 45 bpm',
      rumenMotility: '1-2 प्रति 2 मिनट',
    ),
    onFarmTest:
        'त्वचा पर सिक्के जैसी गोल उभरी कठोर गांठें, तेज बुखार और पैरों में पानी जैसी सूजन।',
    clinicalLabTest: 'त्वचा की पपड़ी या बायोप्सी का पीसीआर (Real-Time PCR) टेस्ट।',
    differentialDiagnosis: 'स्यूडो-लम्पी (BHV-2), रिंगवर्म, टिक बाइट एलर्जी।',
    criticalWindow:
        'बुखार व पहली 2-3 गांठें दिखते ही पहले 24 घंटे! तुरंत नीम-हल्दी लेप व मक्खी-मच्छर नियंत्रण शुरू करें।',
    seasonalPeak: 'बरसात के बाद (जुलाई से नवंबर) जब मच्छर, डास और चिचड़ियां अत्यधिक सक्रिय होते हैं।',
    consequenceOfDelay:
        'गांठों के सड़ने से सेप्सिस, घावों में कीड़े पड़ना और महीनों तक पशु का कंकाल बन जाना।',
    firstAidIngredients: [
      'ताजा नीम के पत्ते - 100 ग्राम',
      'हल्दी पाउडर - 50 ग्राम',
      'लहसुन की कलियां - 10 नग',
      'शुद्ध नारियल का तेल - 250 मिली',
      'पान के पत्ते (10 नग) + काली मिर्च (10 ग्राम) + गुड़ (100 ग्राम) - मौखिक काढ़ा',
    ],
    firstAidPreparation:
        '1. मौखिक लड्डू: पान के पत्ते, काली मिर्च, नमक व गुड़ को कूटकर लड्डू बनाएं। 2. घाव का तेल: नारियल तेल में नीम, हल्दी व लहसुन को धीमी आंच पर पकाकर छान लें।',
    firstAidApplication:
        '1. गुड़-पान-काली मिर्च का लड्डू दिन में 3 बार पहले दिन दें, फिर 2 बार अगले 7 दिन तक खिलाएं। 2. गांठों व घावों पर तैयार नीम-हल्दी का तेल दिन में 2 बार लगाएं। 3. शाम को बाड़े में नीम व गूगल का धुआं करें।',
    firstAidPrecautions: [
      'पशु को चिचड़ी, मच्छर व डास से बचाएं, यही वायरस फैलाते हैं।',
      'गांठों को जबरदस्ती खुरचकर न छीलें।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा द्वितीयक त्वचा व फेफड़े के संक्रमण रोकने हेतु एनरोफ्लोक्सासिन, बुखार/सूजन हेतु मेलोक्सीकैम और एंटीहिस्टामिनिक इंजेक्शन।',
    ivFluids: 'कमजोरी में 5% डेक्सट्रोज व इलेक्ट्रोलाइट्स 2 लीटर IV।',
    supportiveTherapy: 'विटामिन ए, ई, बायोटिन और जिंक टॉनिक।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Enrofloxacin 10%',
        tradeNames: ['Baytril', 'Enrocin', 'Fortivir'],
        dosage: '5 mg/kg शरीर भार (15-20 मिली IM दैनिक 3 दिन)',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '14 दिन',
        prescriptionRequired: true,
        notes: 'त्वचा के गहरे संक्रमण व निमोनिया से बचाता है।',
      ),
      MedicineItem(
        molecule: 'Meloxicam + Paracetamol',
        tradeNames: ['Melonex Plus', 'Zobid-M'],
        dosage: '15 - 20 मिली IM',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'तेज बुखार व जोड़ों की सूजन तुरंत कम करता है।',
      ),
      MedicineItem(
        molecule: 'Pheniramine Maleate',
        tradeNames: ['Avil', 'Cadistin'],
        dosage: '10 मिली IM',
        route: 'IM',
        milkWithdrawal: '24 घंटे',
        meatWithdrawal: '3 दिन',
        prescriptionRequired: true,
        notes: 'एलर्जी व खुजली शांत करता है।',
      ),
    ],
    vaccineName: 'गोट पॉक्स वैक्सीन (Goat Pox Vaccine) / Lumpi-ProVacInd',
    vaccineSchedule: 'सभी स्वस्थ गोवंश को 3 मिली SC सालाना लगाएं।',
    biosecurity: [
      'बाड़े में बूटॉक्स (Deltamethrin 12.5%) 2 मिली/लीटर पानी का छिड़काव करें।',
      'संक्रमित पशु का दूध बछड़े को उबालकर ही पिलाएं।',
    ],
  ),

  // 6. Milk Fever (Hypocalcemia)
  const LivestockDisease(
    id: 'milk-fever',
    name: 'Milk Fever (Parturient Paresis / Hypocalcemia)',
    hindiName: 'दूध ज्वर (कैल्शियम की कमी / प्रसवकालीन पक्षाघात)',
    scientificName: 'Acute Hypocalcemia (Serum Calcium < 5 mg/dL)',
    category: 'metabolic',
    categoryHindi: 'उपापचयी (कैल्शियम न्यूनता)',
    animalTypes: ['cow', 'buffalo'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-2 घंटे)',
    primarySymptoms: [
      'ब्याने के 24 से 72 घंटे के भीतर पशु का बैठ जाना और उठ न पाना',
      'गर्दन को मोड़कर पेट/कोख की तरफ सटाकर रखना (विशिष्ट "S-Curve" मुद्रा)',
      'कान, सींग, थन और पैर बिल्कुल बर्फ जैसे ठंडे पड़ना',
      'शरीर का तापमान सामान्य से कम होना (97°F - 100°F - नाम "दूध ज्वर" है पर बुखार नहीं होता!)',
    ],
    secondarySymptoms: [
      'आंखों की पुतलियां फैलना व सूखी थूथन',
      'गोबर-पेशाब बंद होना (आंतों का लकवा)',
      'पशु का करवट के बल लेट जाना व पेट में गैस भरना',
    ],
    vitals: DiseaseVitals(
      temperatureF: '97.0°F - 100.0°F (सामान्य से कम)',
      heartRateBpm: '70 - 90 bpm (धीमी धड़कन)',
      respirationRateBpm: '15 - 25 bpm',
      rumenMotility: '0 (पूर्ण बंद)',
    ),
    onFarmTest:
        'ब्याने के बाद गाय का बैठना, गर्दन पेट की ओर मुड़ना, कान ठंडे होना और थर्मामीटर में तापमान 100°F से नीचे आना।',
    clinicalLabTest:
        'सीरम कैल्शियम परीक्षण: रक्त में कैल्शियम स्तर 5 मिलीग्राम/डेसीलीटर से कम (सामान्य: 9-11 mg/dL)।',
    differentialDiagnosis: 'कीटोसिस (Ketosis), डाउंनर काउ सिंड्रोम, गर्भाशय फटना।',
    criticalWindow:
        'पहले 0 से 4 घंटे! जितनी जल्दी कैल्शियम नस में चढ़ेगा, पशु 15 मिनट में उठ खड़ा होगा। 24 घंटे लेटे रहने पर मांसपेशियां दबकर स्थायी खराब हो जाती हैं।',
    seasonalPeak: 'ब्याने के तुरंत बाद (दिन 1 से दिन 3) - विशेष रूप से 3 से 6 ब्यांत की अधिक दूध देने वाली गायों में।',
    consequenceOfDelay:
        '12-18 घंटे में ब्लोट (गैस) व कोमा से मृत्यु या स्थायी डाउंनर काउ।',
    firstAidIngredients: [
      'पुआल/भूसे की बोरियां (पशु को सहारा देने हेतु)',
      'कंबल या बोरी (शरीर गर्म रखने हेतु)',
      'आपातकालीन पशु चिकित्सक कॉल',
    ],
    firstAidPreparation: 'पशु को तुरंत सीने के बल (Sternal position) बिठाएं, करवट न गिरने दें।',
    firstAidApplication:
        '1. पुआल की बोरियों से पशु की दोनों तरफ सहारा देकर उसे सीने के बल सीधा बिठाएं ताकि पेट में गैस न भरे। 2. शरीर और कानों को जूट की बोरी से रगड़ें व ढकें। 3. थनों से दूध बिल्कुल न निकालें।',
    firstAidPrecautions: [
      '🚨 सख्त जीवन-मरण चेतावनी: बेहोश या लेटे हुए पशु को मुंह से कभी भी कोई पानी, तेल या काढ़ा न पिलाएं! निगलने वाली मांसपेशियां लकवाग्रस्त होती हैं, पानी फेफड़ों में जाकर तुरंत मार देगा।',
      'ब्याने के पहले 48 घंटे में गाय का सारा दूध एक साथ कभी न दुहें।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा कैल्शियम बोरो ग्लूकोनेट 25% (CBG 450 मिली) धीमी गति से IV नस में चढ़ाना (स्टेथोस्कोप से दिल की धड़कन सुनते हुए) और शेष सब-क्यूटेनियस।',
    ivFluids: 'कैल्शियम-मैग्नीशियम-फास्फोरस इन्फ्यूजन (Mifex / Calborol 450 ml IV)।',
    supportiveTherapy:
        'पशु के खड़े होने के बाद ओरल कैल्शियम जेल (Cal-Up / Bovikalc) 300 ग्राम मुंह से देना।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Calcium Borogluconate 25% + Mg + P',
        tradeNames: ['Mifex', 'Calborol', 'Intacal'],
        dosage: '450 मिली बोतल (250 मिली धीमी IV नस में + 200 मिली SC)',
        route: 'IV / SC',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'दूध ज्वर की 100% चमत्कारी जीवनरक्षक दवा; नस में बहुत धीमी गति से चढ़ाएं।',
      ),
      MedicineItem(
        molecule: 'Ionic Oral Calcium Gel',
        tradeNames: ['Cal-Up Gel', 'Bovikalc', 'Ostovet Gel'],
        dosage: '300 ग्राम ट्यूब (खड़े होने के बाद और 12 घंटे बाद)',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'दुबारा कैल्शियम गिरने से रोकता है; केवल होश में होने पर दें।',
      ),
      MedicineItem(
        molecule: 'Tonophosphan (Phosphorus)',
        tradeNames: ['Tonophosphan', 'Urimin'],
        dosage: '10 - 15 मिली IM',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'मांसपेशियों की ताकत तुरंत बहाल करता है।',
      ),
    ],
    vaccineName: 'डीसीएडी आहार (DCAD Diet) व खनिज प्रबंधन',
    vaccineSchedule: 'ब्याने से 15 दिन पूर्व कम कैल्शियम व अधिक फास्फोरस वाला सूखा चारा दें।',
    biosecurity: [
      'ब्याने के 12 घंटे पहले और ब्याने के तुरंत बाद 1-1 ट्यूब ओरल कैल्शियम जेल पिलाएं।',
      'गर्भावस्था के अंतिम महीने में अत्यधिक हरा बरसीम या अत्यधिक कैल्शियम सप्लीमेंट न दें।',
    ],
  ),

  // 7. Ruminal Tympany / Bloat
  const LivestockDisease(
    id: 'ruminal-bloat',
    name: 'Ruminal Tympany (Acute Bloat)',
    hindiName: 'तीव्र रूमेन अफारा (पेट फूलना / गैस का रुकना)',
    scientificName: 'Acute Ruminal Tympany (Frothy or Free-gas bloat)',
    category: 'metabolic',
    categoryHindi: 'उपापचयी / पाचन विकार',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'emergency',
    severityHindi: 'अत्यंत आपातकालीन (0-30 मिनट)',
    primarySymptoms: [
      'बायां पेट (Left Flank) गुब्बारे या ढोलक की तरह अत्यधिक फूल जाना',
      'बाएं पेट पर थपकी मारने पर ढोल जैसी आवाज (Drum-like ping) आना',
      'सांस लेने में भारी तकलीफ, मुंह खोलकर हांफना व जीभ बाहर निकालना',
      'बेचैनी से बार-बार उठना-बैठना और पिछले पैर से पेट पर लात मारना',
    ],
    secondarySymptoms: [
      'आंखें बाहर की ओर उभरना व मुंह से झाग निकलना',
      'पशु का दम घुटकर जमीन पर गिरना',
      'गैस के दबाव से फेफड़े व डायफ्राम फटने से मृत्यु',
    ],
    vitals: DiseaseVitals(
      temperatureF: '99.0°F - 102.0°F (सामान्य)',
      heartRateBpm: '100 - 140 bpm (तनाव)',
      respirationRateBpm: '50 - 75 bpm (दम घुटना)',
      rumenMotility: '0 (गतिहीन)',
    ),
    onFarmTest:
        'बाएं पेट का रीढ़ की हड्डी से ऊपर उठ जाना, अंगुली से बजाने पर गूंजती हुई ढोलक जैसी आवाज और मुंह खोलकर हांफना।',
    clinicalLabTest: 'पेट में पेट-नली डालकर गैस या झागदार द्रव निकलना।',
    differentialDiagnosis: 'अन्नप्रणाली में रुकावट (Choke - आलू/सेब का अटकना), डायाफ्रामिक हर्निया।',
    criticalWindow:
        'पहले 0 से 30 मिनट! यदि गैस अत्यधिक भर गई तो फेफड़ों पर दबाव पड़ने से 45 मिनट में दम घुटकर पशु मर सकता है।',
    seasonalPeak: 'सर्दियों व वसंत में जब पशु को ओस युक्त ताजा बरसीम या गीला हरा चारा अधिक खिलाया जाता है।',
    consequenceOfDelay: 'डायफ्राम टूटने व कार्डियोवैस्कुलर शॉक से आधे घंटे में मृत्यु।',
    firstAidIngredients: [
      'शुद्ध सरसों या अलसी का तेल - 250 से 400 मिली',
      'असली हींग (Asafoetida) - 15 से 20 ग्राम',
      'अजवाइन व सौंठ पाउडर - 50 ग्राम',
      'लकड़ी की खपच्ची (मुंह में बांधने हेतु)',
    ],
    firstAidPreparation: 'तेल को हल्का गुनगुना करके उसमें हींग व अजवाइन घोल लें।',
    firstAidApplication:
        '1. पशु के मुंह में आड़ी लकड़ी रखकर रस्सी से सींगों के पीछे बांधें ताकि मुंह खुला रहे व लार गिरने से गैस निकलती रहे। 2. पशु का अगला हिस्सा ऊंचे चबूतरे पर रखें। 3. हींग-तेल का मिश्रण नाल से धीरे-धीरे मुंह के कोने से पिलाएं। 4. पशु को धीरे-धीरे टहलाएं।',
    firstAidPrecautions: [
      '🚨 पशु को कभी भी लेटने न दें! लेटने पर गैस नली पूरी बंद हो जाएगी और 10 मिनट में दम टूट जाएगा।',
      'जल्दबाजी में नाल फेफड़ों में न डालें।',
    ],
    clinicalProtocol:
        'अति-आपातकालीन स्थिति में जब पशु गिरने लगे तो पशु चिकित्सक द्वारा बाएं पेट में ट्रोकार और कैनुला (Trocar & Cannula) घोंपकर तुरंत गैस निकालना।',
    ivFluids: 'शॉक में 5% डेक्सट्रोज सेलाइन IV।',
    supportiveTherapy: 'सिमेथिकोन एंटी-ब्लोट सस्पेंशन पेट में सीधे या मुंह से डालना।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Simethicone + Dill Oil',
        tradeNames: ['Bloatosil', 'Tympol', 'Afanil'],
        dosage: '100 मिली बोतल 500 मिली पानी या तेल में मिलाकर तुरंत पिलाएं',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'झागदार अफारे के बुलबुलों को 5 मिनट में फोड़कर गैस मुक्त करता है।',
      ),
      MedicineItem(
        molecule: 'Mustard Oil + Asafoetida (Heeng)',
        tradeNames: ['पारंपरिक देसी नुस्खा'],
        dosage: 'सरसों तेल 250 मिली + हींग 15 ग्राम',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'सर्फेक्टेंट की तरह काम करता है, सबसे तेज घरेलू उपचार।',
      ),
    ],
    vaccineName: 'संतुलित चारा प्रबंधन',
    vaccineSchedule: 'गीला बरसीम खिलाने से पहले हमेशा 2-3 किलो सूखा भूसा या पुआल खिलाएं।',
    biosecurity: [
      'पशु को खाली पेट अचानक अत्यधिक हरा रसीला बरसीम न खाने दें।',
      'चारे में 1% मीठा सोडा मिलाएं।',
    ],
  ),

  // 8. Bovine Theileriosis
  const LivestockDisease(
    id: 'bovine-theileriosis',
    name: 'Bovine Theileriosis (Tick Fever)',
    hindiName: 'थायलेरियासिस (चिचड़ी बुखार / टीक फीवर)',
    scientificName: 'Theileria annulata (Hyalomma tick vector)',
    category: 'protozoal',
    categoryHindi: 'प्रोटोजोआ / चिचड़ी जनित',
    animalTypes: ['cow', 'calf', 'heifer', 'buffalo'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (12-24 घंटे)',
    primarySymptoms: [
      'लगातार अत्यधिक तेज बुखार (105°F से 107°F) जो सामान्य दवाओं से न उतरे',
      'कंधे के आगे की लिम्फ ग्रंथि (Prescapular Lymph Node) का नींबू या आम जितना फूल जाना',
      'अत्यधिक खून की कमी (Anemia) - आंख और मसूड़ों का सफेद या पीला पड़ना',
      'आंखों से आंसू बहना व कॉर्निया का सफेद/धुंधला होना',
    ],
    secondarySymptoms: [
      'सांस तेजी से फूलना व हांफना',
      'अंतिम अवस्था में कॉफी जैसे रंग का पेशाब',
      'क्रॉस-ब्रीड गायों व बछड़ों में 60-80% मृत्यु दर',
    ],
    vitals: DiseaseVitals(
      temperatureF: '105.0°F - 107.5°F (अत्यधिक तीव्र)',
      heartRateBpm: '90 - 125 bpm',
      respirationRateBpm: '45 - 65 bpm',
      rumenMotility: '0-1 प्रति 2 मिनट',
    ),
    onFarmTest:
        'कंधे के आगे की लिम्फ गांठ को छूने पर कठोर व फूली हुई मिलना, 106°F बुखार और आंखों की झिल्ली सफेद होना।',
    clinicalLabTest:
        'लिम्फ नोड से सुई द्वारा द्रव खींचकर स्मीयर बनाना: कोच ब्लू बॉडीज (Koch blue bodies) दिखना। ब्लड स्मीयर में थायलेरिया पिरोप्लाज्म।',
    differentialDiagnosis: 'बेबेसियोसिस, एनाप्लास्मोसिस, गलघोंटू (HS)।',
    criticalWindow:
        'लिम्फ ग्रंथि सूजने व बुखार के पहले 24 घंटे! यदि हीमोग्लोबिन 5 ग्राम से नीचे गिरा तो दवा भी पशु को नहीं बचा पाएगी।',
    seasonalPeak: 'गर्मियां व बारिश (मई से सितंबर) जब हयालोमा चिचड़ी अत्यधिक फैलती है।',
    consequenceOfDelay: 'पल्मोनरी एडिमा, हाइपोक्सिया और 3-5 दिन में मृत्यु।',
    firstAidIngredients: [
      'ठंडे पानी की पट्टियां (सिर पर)',
      'दस्ताने पहनकर चिचड़ियां चुनना व नष्ट करना',
      'गुड़ (250 ग्राम) + मीठा सोडा का घोल',
    ],
    firstAidPreparation: 'पशु को ठंडे छायादार बाड़े में रखें। पंखा चलाएं।',
    firstAidApplication:
        '1. सिर व रीढ़ पर ठंडे पानी की पट्टी रखें। 2. शरीर पर लगी चिचड़ियों को हटाकर नष्ट करें। 3. तुरंत पशु चिकित्सक को बुलाएं।',
    firstAidPrecautions: [
      '🚨 यह बीमारी केवल बुखार की दवा से ठीक नहीं होती, इसके लिए विशेष एंटीप्रोटोजोअल इंजेक्शन अनिवार्य है।',
      'पशु को धूप या तनाव में न लाएं।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा जीवनरक्षक बूपरवाक्वोन (Buparvaquone) 2.5 mg/kg गहरा IM देना। साथ में लॉन्ग-एक्टिंग ऑक्सीटेट्रासाइक्लिन।',
    ivFluids: 'रक्त चढ़ाना (Blood Transfusion) यदि PCV < 12% हो।',
    supportiveTherapy: 'आयरन इंजेक्शन (Iron Dextran), विटामिन बी-कॉम्प्लेक्स और लिवर टॉनिक।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Buparvaquone',
        tradeNames: ['Butalex', 'Zubion', 'Buparvon'],
        dosage: '1 मिली प्रति 20 किग्रा शरीर भार (400 किग्रा गाय हेतु 20 मिली) गहरा IM',
        route: 'IM',
        milkWithdrawal: '48 घंटे',
        meatWithdrawal: '42 दिन',
        prescriptionRequired: true,
        notes: 'थायलेरियासिस की एकमात्र अचूक व चमत्कारी जीवनरक्षक दवा।',
      ),
      MedicineItem(
        molecule: 'Oxytetracycline LA 200mg/ml',
        tradeNames: ['Terramycin LA', 'Zodex LA'],
        dosage: '20 mg/kg IM (20-30 मिली)',
        route: 'IM',
        milkWithdrawal: '7 दिन',
        meatWithdrawal: '28 दिन',
        prescriptionRequired: true,
        notes: 'बूपरवाक्वोन के असर को दोगुना करता है।',
      ),
      MedicineItem(
        molecule: 'Iron Dextran + Vit B12',
        tradeNames: ['Feritas', 'Imferon', 'Belamyl'],
        dosage: '10 मिली गहरा IM (सप्ताह में दो बार)',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'नष्ट हुए लाल रक्त कणों को पुनः बनाता है।',
      ),
    ],
    vaccineName: 'थायलेरिया वैक्सीन (Raksha-Vac T)',
    vaccineSchedule: 'क्रॉस-ब्रीड बछड़ों को 2 माह की उम्र में एक बार 3 मिली SC।',
    biosecurity: [
      'बाड़े की दीवारों की दरारों में ब्यूटाक्स (Deltamethrin) का नियमित छिड़काव करें।',
      'हर माह पशु पर पोर-ऑन (Pour-on) चिचड़ी नाशक दवा लगाएं।',
    ],
  ),

  // 9. Bovine Babesiosis
  const LivestockDisease(
    id: 'bovine-babesiosis',
    name: 'Bovine Babesiosis (Redwater Fever)',
    hindiName: 'बेबेसियोसिस (लाल पेशाब रोग / चिचड़ी मूत्र ज्वर)',
    scientificName: 'Babesia bigemina / Babesia bovis',
    category: 'protozoal',
    categoryHindi: 'प्रोटोजोआ / चिचड़ी जनित',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-6 घंटे)',
    primarySymptoms: [
      'गहरा लाल, कॉफी या वाइन जैसा लाल पेशाब (Hemoglobinuria)',
      'अचानक बहुत तेज बुखार (105°F से 107°F)',
      'आंखों व मसूड़ों का पीला व फीका पड़ना (गंभीर पीलिया व एनीमिया)',
      'दिल की धड़कन इतनी तेज होना कि दूर से आवाज सुनाई दे (Pipe-stem pulse)',
    ],
    secondarySymptoms: [
      'पशु का लड़खड़ाना व खड़े होने में असमर्थ होना',
      'पेशाब झागदार होना और रखने पर नीचे खून न बैठना',
      'गुर्दे फेल होने से कोमा व मृत्यु',
    ],
    vitals: DiseaseVitals(
      temperatureF: '105.0°F - 107.0°F',
      heartRateBpm: '100 - 130 bpm (अति तीव्र)',
      respirationRateBpm: '40 - 60 bpm',
      rumenMotility: '0 (बंद)',
    ),
    onFarmTest:
        'कांच के गिलास में पेशाब लें: यदि पेशाब पारदर्शी गहरा लाल है और 30 मिनट रखने पर नीचे कोई थक्का नहीं जमता, तो यह बेबेसियोसिस है।',
    clinicalLabTest:
        'ब्लड स्मीयर में जीम्सा स्टेनिंग: आरबीसी के अंदर जुड़े हुए नाशपाती के आकार के जोड़े (Paired pear-shaped piroplasms)।',
    differentialDiagnosis: 'ब्याने के बाद का लाल पेशाब (PPH - बुखार नहीं होता), लेप्टोस्पायरोसिस।',
    criticalWindow:
        'लाल पेशाब दिखने के पहले 6 से 12 घंटे! गुर्दे ब्लॉक होने से पहले दवा दी जानी चाहिए।',
    seasonalPeak: 'मानसून व गर्मी (चिचड़ियों का प्रकोप काल)।',
    consequenceOfDelay: '24-48 घंटे में गुर्दे फेल (Renal failure) और रक्तहीनता से मृत्यु।',
    firstAidIngredients: [
      'गुनगुना पानी + ग्लूकोज (250 ग्राम)',
      'मीठा सोडा (Sodium Bicarbonate) - 50 ग्राम',
      'पशु को शांत छायादार स्थान में रखना',
    ],
    firstAidPreparation: 'पशु को बिना हिलाए-डुलाए आराम से लिटाएं।',
    firstAidApplication:
        '1. 1 लीटर पानी में ग्लूकोज व मीठा सोडा घोलकर पिलाएं (गुर्दों में एसिड व हीमोग्लोबिन जमने से रोकेगा)। 2. पशु पर ठंडा पानी न डालें और न ही उसे दूर चलाएं। 3. तुरंत बेरिनिल इंजेक्शन लगवाएं।',
    firstAidPrecautions: [
      '🚨 पशु को जबरन बिल्कुल न चलाएं, लाल रक्त कण इतने कम होते हैं कि दिल का दौरा पड़ सकता है।',
      'गलत दवा देकर समय नष्ट न करें।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा डिमिनाजीन एसिट्यूरेट (Berenil) 3.5-7 mg/kg गहरा IM या इमिडोकार्ब डिप्रोपियोनेट 1.2 mg/kg SC।',
    ivFluids: 'रिंगर्स लैक्टेट (RL) 2-3 लीटर IV धीमी गति से।',
    supportiveTherapy: 'विटामिन बी-कॉम्प्लेक्स, आयरन और लिवर प्रोटेक्टिव इंजेक्शन।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Diminazene Aceturate',
        tradeNames: ['Berenil', 'Diminasan', 'Babesin'],
        dosage: '3.5 - 7 mg/kg शरीर भार (400 किग्रा गाय हेतु 20-30 मिली गहरा IM)',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '21 दिन',
        prescriptionRequired: true,
        notes: 'बेबेसिया प्रोटोजोआ को नष्ट करने वाली प्रथम श्रेणी की दवा।',
      ),
      MedicineItem(
        molecule: 'Imidocarb Dipropionate',
        tradeNames: ['Imizol', 'Bicarb'],
        dosage: '1.2 mg/kg शरीर भार (1 मिली प्रति 100 किग्रा SC)',
        route: 'SC',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '28 दिन',
        prescriptionRequired: true,
        notes: 'बेबेसियोसिस और एनाप्लास्मोसिस दोनों में अत्यंत प्रभावी।',
      ),
    ],
    vaccineName: 'चिचड़ी नियंत्रण (Acaricide Dip/Spray)',
    vaccineSchedule: 'हर 21-28 दिन पर पशु व बाड़े में चिचड़ी नाशक दवा का छिड़काव।',
    biosecurity: [
      'बाड़े में ब्यूटॉक्स (Deltamethrin) का स्प्रे करें।',
      'संक्रमित चारागाह से पशुओं को दूर रखें।',
    ],
  ),

  // 10. Post-Parturient Hemoglobinuria (PPH)
  const LivestockDisease(
    id: 'post-parturient-hemoglobinuria',
    name: 'Post-Parturient Hemoglobinuria - PPH',
    hindiName: 'ब्याने के बाद लाल पेशाब (फास्फोरस की कमी)',
    scientificName: 'Nutritional Hypophosphatemia (Inorganic P < 2.0 mg/dL)',
    category: 'metabolic',
    categoryHindi: 'उपापचयी / खनिज न्यूनता',
    animalTypes: ['buffalo', 'cow'],
    severity: 'urgent',
    severityHindi: 'तत्काल फास्फोरस उपचार (12-24 घंटे)',
    primarySymptoms: [
      'ब्याने के 2 से 6 सप्ताह बाद कॉफी या डार्क रेड वाइन जैसा लाल पेशाब आना',
      'शरीर का तापमान बिल्कुल सामान्य या हल्का कम (कोई बुखार नहीं!)',
      'अत्यधिक कमजोरी, हांफना व दूध उत्पादन में भारी गिरावट',
      'मिट्टी, दीवार या ईंट चाटना (पाइका लक्षण)',
    ],
    secondarySymptoms: [
      'आंखों की झिल्लियों का गहरा पीला व सफेद होना',
      'दिल की धड़कन तेज होना व पशु का लड़खड़ाना',
      'लाल रक्त कणों के स्वतः फटने से गंभीर एनीमिया',
    ],
    vitals: DiseaseVitals(
      temperatureF: '100.5°F - 102.0°F (सामान्य - कोई बुखार नहीं)',
      heartRateBpm: '85 - 115 bpm',
      respirationRateBpm: '30 - 45 bpm',
      rumenMotility: '1-2 प्रति 2 मिनट',
    ),
    onFarmTest:
        'ब्याने के 15-30 दिन बाद लाल पेशाब और थर्मामीटर में 101°F (सामान्य तापमान) - यह चिचड़ी बुखार से अलग करता है जिसमें 106°F बुखार होता है।',
    clinicalLabTest:
        'सीरम अकार्बनिक फास्फोरस परीक्षण: स्तर 2 मिलीग्राम/डेसीलीटर से नीचे।',
    differentialDiagnosis: 'बेबेसियोसिस (तेज बुखार होता है), लेप्टोस्पायरोसिस।',
    criticalWindow:
        'लाल पेशाब दिखने के पहले 24 से 48 घंटे! यदि फास्फोरस नहीं दिया गया तो 3-4 दिन में हीमोग्लोबिन 3 ग्राम से नीचे गिरकर पशु मर जाएगा।',
    seasonalPeak: 'सर्दियों का मौसम और अत्यधिक हरा बरसीम खिलाने वाले क्षेत्रों में।',
    consequenceOfDelay: 'अनियंत्रित हीमोलिसिस व दिल का दौरा पड़ने से मृत्यु।',
    firstAidIngredients: [
      'सोडियम एसिड फास्फेट पाउडर - 60 ग्राम',
      'गन्ने का गुड़ या शीरा - 500 ग्राम',
      'गेहूं का चोकर व सूखा भूसा',
    ],
    firstAidPreparation: '60 ग्राम सोडियम एसिड फास्फेट पाउडर को 500 ग्राम गुड़ के शरबत में घोलें।',
    firstAidApplication:
        '1. तैयार फास्फोरस व गुड़ का शरबत दिन में 2 बार नाल से पिलाएं। 2. हरा बरसीम खिलाना तुरंत बंद कर दें। 3. गेहूं का चोकर खिलाएं।',
    firstAidPrecautions: [
      'हरा बरसीम और सरसों की पत्तियां तुरंत बंद करें।',
      'पशु को किसी भी प्रकार की दौड़-भाग न कराएं।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा सोडियम एसिड फास्फेट (Urimin / Tonophosphan) 60 ग्राम का 10% घोल बनाकर IV नस में चढ़ाना, साथ में 60 ग्राम चमड़ी के नीचे।',
    ivFluids: 'स्वस्थ पशु का ताजा रक्त चढ़ाना (Blood Transfusion 3-4 लीटर) यदि आवश्यक हो।',
    supportiveTherapy: 'आयरन डेक्सट्रान, विटामिन बी12 और खनिज सप्लीमेंट।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Sodium Acid Phosphate Injection',
        tradeNames: ['Tonophosphan', 'Urimin', 'Phospha-Vet'],
        dosage: '20 - 30 मिली IV और 20 मिली SC (दैनिक 3-4 दिन)',
        route: 'IV / SC',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'फास्फोरस की कमी को दूर कर लाल पेशाब को 24 घंटे में बंद करता है।',
      ),
      MedicineItem(
        molecule: 'Sodium Acid Phosphate Powder',
        tradeNames: ['Urimin Powder', 'Phos-Care'],
        dosage: '60 ग्राम पाउडर सुबह-शाम 5 दिन तक गुड़ में दें',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'रक्त में फास्फोरस का स्तर बनाए रखता है।',
      ),
    ],
    vaccineName: 'खनिज मिश्रण प्रबंधन',
    vaccineSchedule: 'प्रतिदिन 50 ग्राम एग्रीमिन फोर्ट या चेलैटेड मिनरल मिक्सर दाने में मिलाकर खिलाएं।',
    biosecurity: [
      'बरसीम के साथ हमेशा गेहूं का चोकर व फास्फोरस युक्त दाना दें।',
      'आहार में कैल्शियम व फास्फोरस का अनुपात 2:1 रखें।',
    ],
  ),

  // 11. Retained Placenta (ROP)
  const LivestockDisease(
    id: 'retained-placenta',
    name: 'Retained Fetal Membranes (ROP)',
    hindiName: 'जेर का रुकना (जेर न गिरना / आंवल न पड़ना)',
    scientificName: 'Retained Placenta (Failure > 12 hours post-calving)',
    category: 'reproductive',
    categoryHindi: 'प्रजनन / प्रसव संबंधी',
    animalTypes: ['cow', 'buffalo'],
    severity: 'urgent',
    severityHindi: 'तत्काल देखभाल (12-24 घंटे)',
    primarySymptoms: [
      'ब्याने के 8 से 12 घंटे बाद भी जेर (Placenta) का बाहर न गिरना',
      'योनि से जेर के टुकड़े या झिल्ली बाहर लटकते रहना',
      'योनि से अत्यधिक बदबूदार सड़ा हुआ मटमैला पानी गिरना',
      'पशु द्वारा बार-बार पूंछ उठाना व पेट में जोर लगाना',
    ],
    secondarySymptoms: [
      'हल्का बुखार (103°F) व भूख कम होना',
      'दूध उत्पादन में अचानक गिरावट',
      'गर्भाशय में संक्रमण (मेट्राइटिस) होकर बांझपन का खतरा',
    ],
    vitals: DiseaseVitals(
      temperatureF: '101.5°F - 103.5°F',
      heartRateBpm: '70 - 85 bpm',
      respirationRateBpm: '20 - 30 bpm',
      rumenMotility: '1-2 प्रति 2 मिनट',
    ),
    onFarmTest: 'ब्याने के 12 घंटे बाद योनि के बाहर जेर का लटकना या बच्चेदानी में फंसा होना।',
    clinicalLabTest: 'योनि परीक्षण द्वारा बंद गर्भाशय ग्रीवा व जेर की स्थिति देखना।',
    differentialDiagnosis: 'गर्भाशय भ्रंश (Prolapse), गर्भाशय का फटना, अधूरा प्रसव।',
    criticalWindow:
        'पहले 12 से 24 घंटे! कभी भी जेर को जबरदस्ती हाथ से न खींचे। प्राकृतिक गर्भाशय संकुचन प्रेरित करें।',
    seasonalPeak: 'गर्मियां व विटामिन ई-सेलेनियम की कमी वाले क्षेत्रों में अधिक।',
    consequenceOfDelay: 'गर्भाशय में सेप्टिक मेट्राइटिस, खून में जहर फैलना और स्थायी बांझपन।',
    firstAidIngredients: [
      'पुराना गुड़ - 250 ग्राम',
      'अजवाइन - 25 ग्राम',
      'सोंठ पाउडर - 25 ग्राम',
      'हल्दी - 25 ग्राम',
      'मेथी दाना - 50 ग्राम',
    ],
    firstAidPreparation:
        'गुड़, अजवाइन, सोंठ, मेथी और हल्दी को 2 लीटर पानी में 10 मिनट उबालकर काढ़ा बनाएं।',
    firstAidApplication:
        '1. तैयार गुनगुना काढ़ा ब्याने के तुरंत बाद और 12 घंटे बाद पिलाएं (यह गर्भाशय को प्राकृतिक रूप से सिकोड़कर जेर गिराता है)। 2. लटकती हुई जेर को साफ धागे से बांधकर घुटने के ऊपर तक काट दें।',
    firstAidPrecautions: [
      '🚨 सख्त चेतावनी: जेर को कभी भी हाथ से जबरन न खींचें! जबरदस्ती खींचने से बच्चेदानी के फूल छिल जाते हैं, भारी रक्तस्राव होता है और गाय हमेशा के लिए बांझ हो जाती है।',
      'गिरे हुए जेर को कभी भी गाय को न खाने दें। इसे जमीन में गहरा गाड़ें।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा पीजीएफ2-अल्फा (PGF2alpha) इंजेक्शन 2 मिली IM या ऑक्सीटोसिन (यदि 24 घंटे के भीतर हो)।',
    ivFluids: 'बुखार व सुस्ती में 5% डेक्सट्रोज सेलाइन 2 लीटर IV।',
    supportiveTherapy: 'गर्भाशय के अंदर एंटीबैक्टीरियल बोलस (Cleanex / Furea) रखना।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Herbal Uterine Cleanser Liquid',
        tradeNames: ['Exapar Liquid', 'Utrasafe', 'Replanta'],
        dosage: '100 मिली सुबह-शाम 3 से 5 दिन तक',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'गर्भाशय की गंदगी व जेर के अवशेषों को पूरी तरह साफ करता है।',
      ),
      MedicineItem(
        molecule: 'Cloprostenol (PGF2alpha)',
        tradeNames: ['Pragma', 'Vetmate', 'Lutalyse'],
        dosage: '2 मिली गहरा IM',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '1 दिन',
        prescriptionRequired: true,
        notes: 'गर्भाशय ग्रीवा को खोलकर जेर व मवाद को बाहर फेंकता है।',
      ),
    ],
    vaccineName: 'गर्भावधि पोषण प्रबंधन',
    vaccineSchedule: 'ब्याने से 1 माह पूर्व विटामिन ई + सेलेनियम (E-Care Se) का इंजेक्शन लगाएं।',
    biosecurity: [
      'ब्याने के बाद कैल्शियम की कमी (मिल्क फीवर) न होने दें।',
      'प्रसव कक्ष को सूखा, साफ व चूना छिड़का हुआ रखें।',
    ],
  ),

  // 12. Uterine & Vaginal Prolapse
  const LivestockDisease(
    id: 'uterine-prolapse',
    name: 'Uterine / Vaginal Prolapse (Eversion)',
    hindiName: 'फूल/पिछा दिखाना (पांछा निकलना / बच्चेदानी का बाहर आना)',
    scientificName: 'Complete Uterine / Incomplete Vaginal Prolapse',
    category: 'reproductive',
    categoryHindi: 'प्रजनन / आपातकालीन',
    animalTypes: ['buffalo', 'cow'],
    severity: 'emergency',
    severityHindi: 'अति-आपातकालीन (0-2 घंटे)',
    primarySymptoms: [
      'योनि के बाहर लाल रंग का फुटबॉल जैसा चिकना गोला (योनि भ्रंश) निकलना',
      'या ब्याने के बाद पूरी बच्चेदानी का उल्टा होकर बाहर लटकना जिस पर लाल-भूरे बटन (Cotyledons) लगे हों',
      'पशु का लगातार पीछे की ओर जोर लगाना (Severe Straining)',
      'पशु का बेचैन होकर बैठना व पेशाब रुकना',
    ],
    secondarySymptoms: [
      'बाहर निकले अंग का सूखना, धूल-मिट्टी लगना और खून बहना',
      'कौवों, कुत्तों या मक्खियों द्वारा नोचे जाने का खतरा',
      'पेशाब की थैली मुड़ जाने से पेशाब का पूर्ण बंद होना',
    ],
    vitals: DiseaseVitals(
      temperatureF: '100.5°F - 102.5°F',
      heartRateBpm: '85 - 110 bpm',
      respirationRateBpm: '25 - 40 bpm',
      rumenMotility: '1 प्रति 2 मिनट',
    ),
    onFarmTest:
        'योनि से बाहर लाल मांस का बड़ा गोला लटकना; यदि उस पर मशरूम जैसे बटन हैं तो यह पूरी बच्चेदानी (Uterine prolapse) है।',
    clinicalLabTest: 'शारीरिक दृश्य परीक्षण एवं योनि ग्रीवा की स्थिति।',
    differentialDiagnosis: 'योनि का ट्यूमर, गर्भाशय का सिस्ट, हीमेटोमा।',
    criticalWindow:
        'पहले 0 से 2 घंटे! जब तक अंग ताजा, नम व गुलाबी है, उसे आसानी से अंदर चढ़ाया जा सकता है। सूखने व सूजने के बाद चढ़ाना अत्यंत कठिन होता है।',
    seasonalPeak: 'ब्याने के अंतिम माह में (योनि भ्रंश) व ब्याने के 24-48 घंटे के भीतर (गर्भाशय भ्रंश)।',
    consequenceOfDelay: 'अंग में गैंग्रीन, सेप्सिस, पेशाब की थैली फटना और 12 घंटे में मृत्यु।',
    firstAidIngredients: [
      'साफ सूती चादर या कपड़ा',
      'पोटैशियम परमैंगनेट (हल्का लाल दवा का पानी) या ठंडा पानी',
      'पीसी हुई चीनी (Sugar) या बर्फ की थैली',
      'पुआल के बंडल (पिछला हिस्सा ऊंचा करने हेतु)',
    ],
    firstAidPreparation: 'चादर को ठंडे लाल दवा के पानी में भिगो लें।',
    firstAidApplication:
        '1. बाहर निकले अंग को तुरंत साफ भीगी चादर से पूरी तरह ढक दें। 2. पशु का पिछला हिस्सा पुआल की बोरियों पर रखकर 1 फीट ऊंचा करें। 3. यदि अंग बहुत सूज गया हो तो उस पर चीनी या बर्फ छिड़कें (चीनी पानी सोखकर सूजन को आधा कर देती है)। 4. तुरंत डॉक्टर को बुलाएं।',
    firstAidPrecautions: [
      '🚨 बाहर निकले अंग को कभी भी बिना धोए या जमीन पर घिसटने न दें।',
      'जबरदस्ती अंगूठे गड़ाकर अंदर न ठूंसें, इससे बच्चेदानी फट सकती है।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा एपिड्यूरल एनेस्थीसिया देकर जोर बंद करना, अंग को धोकर अंदर बैठाना और ब्यूहनर सुचर या रस्सी का पांछा बांधना।',
    ivFluids: 'कैल्शियम बोरो ग्लूकोनेट (Mifex 450 ml IV) मांसपेशियों की टोन बहाल करने हेतु।',
    supportiveTherapy: 'एंटीबायोटिक (Ceftiofur 1g IM) और दर्द निवारक (Meloxicam 15 ml IM)।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Lignocaine Hydrochloride 2%',
        tradeNames: ['Xylocaine 2%', 'Lox 2%'],
        dosage: '5 - 7 मिली एपिड्यूरल इंजेक्शन',
        route: 'Other',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'पशु के पीछे का जोर लगाना 15 मिनट में बंद करता है ताकि अंग चढ़ाया जा सके।',
      ),
      MedicineItem(
        molecule: 'Calcium Borogluconate 25%',
        tradeNames: ['Mifex', 'Calborol'],
        dosage: '450 मिली IV धीमी गति से',
        route: 'IV',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'मांसपेशियों को ताकत देता है जिससे अंग दुबारा बाहर न आए।',
      ),
    ],
    vaccineName: 'बाड़े का ढलान प्रबंधन',
    vaccineSchedule: 'बाड़े के फर्श को पीछे की ओर गहरा ढलान न दें; पशु का पिछला हिस्सा थोड़ा ऊंचा रखें।',
    biosecurity: [
      'गर्भवती पशु को संतुलित खनिज मिश्रण व पर्याप्त कैल्शियम दें।',
      'अधिक जोर लगाने वाले पशु को तुरंत डॉक्टर को दिखाएं।',
    ],
  ),

  // 13. Fascioliasis (Liver Fluke)
  const LivestockDisease(
    id: 'fascioliasis-liver-fluke',
    name: 'Fascioliasis (Liver Fluke Disease)',
    hindiName: 'लिवर फ्लूक (यकृत कृमि / गलसुआ / पित्त की नाली के कीड़े)',
    scientificName: 'Fasciola gigantica / Fasciola hepatica',
    category: 'parasitic',
    categoryHindi: 'परजीवी जनित (आंतरिक कृमि)',
    animalTypes: ['buffalo', 'cow', 'calf', 'heifer'],
    severity: 'moderate',
    severityHindi: 'मध्यम / पुराना रोग (नियमित डीवर्मिंग)',
    primarySymptoms: [
      'निचले जबड़े के नीचे पानी जैसी नर्म, बिना दर्द वाली सूजन आना (बॉटल जॉ - Bottle Jaw)',
      'यह सूजन रात में बढ़ जाती है और दिन में थोड़ा कम हो जाती है',
      'पशु का लगातार सूखना, पसलियां दिखना व दूध आधा रह जाना',
      'पुराना पतला दस्त या रुक-रुक कर कब्ज होना',
    ],
    secondarySymptoms: [
      'आंखों की झिल्ली बिल्कुल सफेद व पीली होना (गंभीर रक्तहीनता)',
      'बाल रूखे, बेजान व आसानी से टूटने वाले होना',
      'लिवर सिरोसिस होने से पशु की धीरे-धीरे मृत्यु',
    ],
    vitals: DiseaseVitals(
      temperatureF: '101.0°F - 102.5°F (सामान्य)',
      heartRateBpm: '70 - 85 bpm',
      respirationRateBpm: '20 - 30 bpm',
      rumenMotility: '1 प्रति 2 मिनट',
    ),
    onFarmTest:
        'निचले जबड़े के नीचे दबाने पर पानी जैसी सूजन (Bottle Jaw) और दलदली/नहर किनारे चराने का इतिहास।',
    clinicalLabTest:
        'गोबर की जांच: माइक्रोस्कोप में सुनहरे पीले रंग के बड़े ढक्कनदार अंडे (Operculated fluke eggs) दिखना।',
    differentialDiagnosis: 'पेट के गोल कृमि, जोन्स रोग (JD), कुपोषण।',
    criticalWindow:
        'मानसून के तुरंत बाद और वसंत में रूटीन डीवर्मिंग! जबड़े के नीचे सूजन आने का अर्थ है कि लिवर 50% से अधिक खराब हो चुका है।',
    seasonalPeak: 'नहरों, तालाबों व जलभराव वाले क्षेत्रों में बरसात के बाद (अक्टूबर से मार्च)।',
    consequenceOfDelay: 'लिवर का पूरी तरह फाइब्रोसिस होना व अत्यधिक खून की कमी से मृत्यु।',
    firstAidIngredients: [
      'पशु को नहर/तालाब के किनारे चराने से रोकना',
      'गुड़ (100 ग्राम) + लोहे का सप्लीमेंट',
      'डीवर्मिंग दवा (Oxyclozanide / Triclabendazole)',
    ],
    firstAidPreparation: 'पशु को सूखे बाड़े में रखें और सूखा चारा दें।',
    firstAidApplication:
        '1. पशु को तालाब, पोखर या जलकुंभी वाली जगहों से दूर रखें। 2. तुरंत पशु चिकित्सक द्वारा सुझाई गई पेट के कीड़े वाली दवा खाली पेट पिलाएं। 3. दवा देने के 3 दिन बाद से लिवर टॉनिक शुरू करें।',
    firstAidPrecautions: [
      'साधारण एल्बेंडाजोल लिवर फ्लूक पर पूरी तरह काम नहीं करती, विशेष फ्लुकिसाइड दवा ही दें।',
      'गर्भवती पशु को दवा देने से पहले पशु चिकित्सक से पुष्टि करें।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा ट्राइक्लाबेन्डाजोल (12 mg/kg) या ऑक्सीक्लोजानाइड (10-15 mg/kg) ओरल सस्पेंशन देना।',
    ivFluids: 'गंभीर कमजोरी में 5% डेक्सट्रोज व अमीनो एसिड इन्फ्यूजन।',
    supportiveTherapy: 'आयरन इंजेक्शन और लिवर टॉनिक (Brotone 50 ml oral 15 दिन तक)।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Oxyclozanide + Levamisole',
        tradeNames: ['Zanil', 'Distodin', 'Nilzan'],
        dosage: '90 - 100 मिली की बोतल खाली पेट मुंह से (400 किग्रा पशु हेतु)',
        route: 'Oral',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '14 दिन',
        prescriptionRequired: true,
        notes: 'वयस्क लिवर फ्लूक और पेट के कीड़ों को पूरी तरह साफ करता है।',
      ),
      MedicineItem(
        molecule: 'Liver Extract Tonic',
        tradeNames: ['Brotone', 'Liv-52 Protec'],
        dosage: '50 मिली प्रतिदिन 15 से 20 दिन तक दाने में',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'क्षतिग्रस्त यकृत (Liver) की मरम्मत कर भूख व दूध बढ़ाता है।',
      ),
    ],
    vaccineName: 'रणनीतिक डीवर्मिंग कैलेंडर',
    vaccineSchedule: 'वर्ष में 2 बार (मानसून से पहले मई में और मानसून के बाद अक्टूबर-नवंबर में) डीवर्मिंग कराएं।',
    biosecurity: [
      'तालाबों व जलभराव में घोंघों के नियंत्रण हेतु कॉपर सल्फेट का हल्का छिड़काव या बत्तख पालन करें।',
      'तालाब के किनारे की ताजी घास काटकर तुरंत न खिलाएं।',
    ],
  ),

  // 14. Calf Scours (Colibacillosis)
  const LivestockDisease(
    id: 'calf-scours',
    name: 'Calf Scours (Colibacillosis / Calf Diarrhea)',
    hindiName: 'बछड़े का सफेद दस्त (सफेद हगना / नवजात दस्त)',
    scientificName: 'Enterotoxigenic E. coli (ETEC) / Rotavirus',
    category: 'bacterial',
    categoryHindi: 'जीवाणु/विषाणु (नवजात बछड़ा)',
    animalTypes: ['calf'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-4 घंटे)',
    primarySymptoms: [
      '1 से 30 दिन के नवजात बछड़े को पतला, सफेद, पीला या मटमैला बदबूदार दस्त होना',
      'बछड़े की आंखें अंदर गड्ढे में धंस जाना (Sunken Eyes - गंभीर निर्जलीकरण)',
      'कान, मुंह और थूथन बिल्कुल ठंडे पड़ना',
      'दूध पीने से पूरी तरह मना करना व खड़े न हो पाना',
    ],
    secondarySymptoms: [
      'चमड़ी की लचक खत्म होना (Skin tenting > 3 सेकंड)',
      'शरीर का तापमान 100°F से नीचे गिरना',
      'अम्लरक्तता (Acidosis) और कोमा से 24 घंटे में मृत्यु',
    ],
    vitals: DiseaseVitals(
      temperatureF: '98.5°F - 101.5°F (गंभीर स्थिति में कम)',
      heartRateBpm: '100 - 140 bpm',
      respirationRateBpm: '35 - 55 bpm',
      rumenMotility: 'लागू नहीं (रूमेन अविकसित)',
    ),
    onFarmTest:
        'स्किन टेंट टेस्ट: गर्दन की चमड़ी को ऊपर खींचकर छोड़ें; यदि चमड़ी तुरंत वापस न जाकर 3 सेकंड तक मुड़ी रहे, तो बछड़ा 8-10% डिहाइड्रेट है और जीवन खतरे में है।',
    clinicalLabTest: 'दस्त के नमूने का एलिसा या पीसीआर टेस्ट।',
    differentialDiagnosis: 'कोक्सीडियोसिस (खूनी दस्त), साल्मोनेलोसिस, अत्यधिक दूध पिलाना।',
    criticalWindow:
        'पहले 0 से 4 घंटे! बछड़ा संक्रमण से नहीं बल्कि पानी और नमक की कमी (Dehydration) से मरता है। तुरंत ओआरएस घोल शुरू करें।',
    seasonalPeak: 'सर्दियों का मौसम व गंदे गीले प्रसव बाड़े।',
    consequenceOfDelay: '12-24 घंटे के अंदर हाइपोवोलेमिक शॉक से बछड़े की मौत।',
    firstAidIngredients: [
      'ओआरएस पैकेट (ORS) या घरेलू इलेक्ट्रोलाइट घोल:',
      '1 लीटर उबला व ठंडा किया हुआ पानी',
      '2 चम्मच ग्लूकोज या चीनी',
      'आधा चम्मच सादा नमक',
      'आधा चम्मच मीठा सोडा (Baking Soda)',
    ],
    firstAidPreparation:
        '1 लीटर गुनगुने पानी में चीनी, नमक व मीठा सोडा घोलकर जीवनरक्षक ओआरएस तैयार करें।',
    firstAidApplication:
        '1. तैयार ओआरएस घोल 1 से 2 लीटर दिन में 3-4 बार बछड़े को पिलाएं। 2. बछड़े को मां का दूध 12 घंटे बाद थोड़ा-थोड़ा दें। 3. बछड़े को सूखी पुआल पर रखें व कंबल से ढकें।',
    firstAidPrecautions: [
      '🚨 केवल एंटीबायोटिक गोली खिलाने से बछड़ा नहीं बचेगा, जब तक शरीर में पानी व इलेक्ट्रोलाइट नहीं जाएगा।',
      'ठंडे पानी से ओआरएस न बनाएं, हमेशा गुनगुना दें।',
    ],
    clinicalProtocol:
        'यदि बछड़े की आंखें बहुत धंस चुकी हों, तो पशु चिकित्सक द्वारा रिंगर्स लैक्टेट (RL) 1 से 2 लीटर IV नस में तुरंत चढ़ाना।',
    ivFluids: 'रिंगर्स लैक्टेट + 5% डेक्सट्रोज IV।',
    supportiveTherapy: 'एमोक्सिसिलिन ओरल सिरप और काओलिन-पेक्टिन आंत सुरक्षा हेतु।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Oral Electrolyte Sachets (ORS)',
        tradeNames: ['Intalyte', 'Electral', 'Calf-Lyte'],
        dosage: '1 पैकेट 2 लीटर गुनगुने पानी में घोलकर दिन में 3 बार पिलाएं',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'बछड़े के दस्त का नंबर 1 जीवनरक्षक उपचार।',
      ),
      MedicineItem(
        molecule: 'Herbal Anti-Diarrheal Powder',
        tradeNames: ['Neblon Powder', 'Diaroak'],
        dosage: '15 ग्राम पाउडर दिन में 2 बार चावल के मांड में मिलाकर दें',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'आंतों की सूजन शांत कर दस्त तुरंत बांधता है।',
      ),
    ],
    vaccineName: 'खीस (Colostrum) प्रबंधन',
    vaccineSchedule: 'जन्म के पहले 2 घंटे के भीतर बछड़े को उसके वजन का 10% मां का पहला गाढ़ा खीस अनिवार्य रूप से पिलाएं!',
    biosecurity: [
      'खीस में मां की रोग प्रतिरोधक एंटीबॉडीज होती हैं जो बछड़े को 3 महीने तक सभी रोगों से बचाती हैं।',
      'नाभि को जन्म के तुरंत बाद 2% टिंचर आयोडीन में डुबोएं।',
    ],
  ),

  // 15. Bovine Ketosis
  const LivestockDisease(
    id: 'bovine-ketosis',
    name: 'Bovine Ketosis (Acetonemia)',
    hindiName: 'कीटोसिस रोग (कीटो एसिडोसिस / भूख न लगना)',
    scientificName: 'Subclinical / Clinical Acetonemia',
    category: 'metabolic',
    categoryHindi: 'उपापचयी / ऊर्जा न्यूनता',
    animalTypes: ['cow', 'buffalo'],
    severity: 'urgent',
    severityHindi: 'तत्काल ऊर्जा प्रबंधन (24 घंटे)',
    primarySymptoms: [
      'ब्याने के 2 से 8 सप्ताह बाद दूध देने वाली गाय का दाना-खली खाने से मना करना',
      'गाय केवल सूखा भूसा खाती है, पौष्टिक दाने को सूंघकर छोड़ देती है',
      'पशु के सांस और दूध में मीठी, सड़ी हुई क्लोरोफॉर्म या नेलपॉलिश रिमूवर जैसी एसीटोन की गंध',
      'दूध उत्पादन में अचानक 40-60% की गिरावट व शरीर का तेजी से सूखना',
    ],
    secondarySymptoms: [
      'नर्वस कीटोसिस: दीवारों को चाटना, खुरली को चबाना, अजीब आवाज निकालना व लड़खड़ाना',
      'गोबर सूखा, काला व गेंद जैसा कठोर होना',
      'लिवर में चर्बी (Fatty Liver) जमने से स्थायी कमजोरी',
    ],
    vitals: DiseaseVitals(
      temperatureF: '101.0°F - 102.5°F (सामान्य)',
      heartRateBpm: '65 - 80 bpm',
      respirationRateBpm: '20 - 30 bpm',
      rumenMotility: '1 प्रति 2 मिनट (सुस्त)',
    ),
    onFarmTest:
        '1. मूत्र कीटोन स्ट्रिप (Ketostix): ताजे पेशाब में स्ट्रिप डुबोने पर 15 सेकंड में गहरा बैंगनी रंग आना। 2. मुंह की सांस से मीठी एसीटोन गंध आना।',
    clinicalLabTest: 'रक्त में बीटा-हाइड्रॉक्सीब्यूटायरेट (BHB > 1.4 mmol/L) स्तर का बढ़ना।',
    differentialDiagnosis: 'अमाशय का मुड़ना (Abomasal displacement), मेट्राइटिस, ट्रॉमेटिक रेटिकुलोपेरिटोनाइटिस (TRP - तार चुभना)।',
    criticalWindow:
        'ब्याने के दूसरे-तीसरे हफ्ते में भूख कम होते ही! यदि 3 दिन अनदेखा किया गया तो लिवर स्थायी खराब हो जाएगा।',
    seasonalPeak: 'ब्याने के 2 से 8 सप्ताह बाद उच्च दुग्ध उत्पादन वाले पशुओं में।',
    consequenceOfDelay: 'फैटी लिवर सिंड्रोम, गंभीर दुर्बलता व स्थायी दूध नुकसान।',
    firstAidIngredients: [
      'प्रोपाइलीन ग्लाइकोल (Propylene Glycol) - 250 मिली या',
      'पुराना गुड़ (500 ग्राम) + मीठा सोडा (100 ग्राम)',
      'गुनगुना पानी - 1 लीटर',
    ],
    firstAidPreparation: '500 ग्राम गुड़ को 1 लीटर गुनगुने पानी में घोलकर उसमें मीठा सोडा मिलाएं।',
    firstAidApplication:
        '1. तैयार गुड़ का घोल या 250 मिली प्रोपाइलीन ग्लाइकोल नाल से सुबह-शाम 4 दिन तक पिलाएं (यह तुरंत ग्लूकोज बनाता है)। 2. पशु को स्वादिष्ट हरा चारा दें।',
    firstAidPrecautions: [
      'पशु को जबरदस्ती तेल या घी न पिलाएं, इससे कीटोन बॉडीज और बढ़ेंगी।',
      'अकेला सूखा भूसा न खिलाएं।',
    ],
    clinicalProtocol:
        'पशु चिकित्सक द्वारा 50% डेक्सट्रोज (500 मिली IV नस में) चढ़ाना, साथ में ग्लूकोकोर्टिकोइड (Isoflupredone acetate 10 मिली IM)।',
    ivFluids: '50% डेक्सट्रोज 500 मिली IV तेज गति से।',
    supportiveTherapy: 'विटामिन बी3 (नायसिन), कोलीन क्लोराइड और लिवर टॉनिक।',
    suggestedMedicines: [
      MedicineItem(
        molecule: 'Propylene Glycol',
        tradeNames: ['Enerdin', 'Ketocare', 'Pro-Glycol'],
        dosage: '250 मिली सुबह-शाम 4 दिन तक मुंह से',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'पेट में सीधे ग्लूकोज में बदलकर कीटोसिस को 48 घंटे में खत्म करता है।',
      ),
      MedicineItem(
        molecule: 'Dextrose 50% IV',
        tradeNames: ['Dextrose 50%', 'G-50'],
        dosage: '500 मिली IV नस में (पशु चिकित्सक द्वारा)',
        route: 'IV',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'रक्त में गिरे शर्करा स्तर को 10 मिनट में सामान्य करता है।',
      ),
    ],
    vaccineName: 'संक्रमणकालीन (Transition) पोषण',
    vaccineSchedule: 'ब्याने से 21 दिन पहले और ब्याने के 21 दिन बाद बाईपास फैट व नायसिन सप्लीमेंट दें।',
    biosecurity: [
      'ब्याने के समय गाय को अत्यधिक मोटी न होने दें (आदर्श BCS 3.25-3.5)।',
      'ब्याने के बाद दाने की मात्रा धीरे-धीरे बढ़ाएं।',
    ],
  ),
];
