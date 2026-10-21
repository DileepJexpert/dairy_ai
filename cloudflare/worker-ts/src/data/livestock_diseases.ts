export interface MedicineItem {
  molecule: string;
  tradeNames: string[];
  dosage: string;
  route: string; // 'IV' | 'IM' | 'SC' | 'Intra-mammary' | 'Oral' | 'Topical'
  milkWithdrawal: string; // e.g., '0 hours', '72 hours (3 days)'
  meatWithdrawal: string;
  prescriptionRequired: boolean;
  notes?: string;
}

export interface LivestockDisease {
  id: string;
  name: string;
  hindiName: string;
  scientificName: string;
  category: 'bacterial' | 'viral' | 'protozoal' | 'metabolic' | 'reproductive' | 'parasitic';
  categoryHindi: string;
  animalTypes: ('cow' | 'buffalo' | 'calf' | 'heifer')[];
  severity: 'emergency' | 'urgent' | 'moderate';
  severityHindi: string;
  symptoms: {
    primary: string[];
    secondary: string[];
    vitals: {
      temperatureF: string;
      heartRateBpm: string;
      respirationRateBpm: string;
      rumenMotility: string;
    };
  };
  testingMethods: {
    onFarmTest: string;
    clinicalLabTest: string;
    differentialDiagnosis: string;
  };
  goldenHourTiming: {
    criticalWindow: string;
    seasonalPeak: string;
    consequenceOfDelay: string;
  };
  firstAid: {
    ingredients: string[];
    preparation: string;
    application: string;
    precautions: string[];
  };
  secondaryAid: {
    clinicalProtocol: string;
    ivFluids: string;
    supportiveTherapy: string;
  };
  suggestedMedicines: MedicineItem[];
  prevention: {
    vaccineName?: string;
    vaccineSchedule?: string;
    biosecurity: string[];
  };
}

export const LIVESTOCK_DISEASES: LivestockDisease[] = [
  // 1. Bovine Mastitis
  {
    id: 'bovine-mastitis',
    name: 'Bovine Mastitis (Udder Infection)',
    hindiName: 'थनैला रोग (थन में सूजन व मवाद)',
    scientificName: 'Staphylococcus aureus / Streptococcus agalactiae / E. coli',
    category: 'bacterial',
    categoryHindi: 'जीवाणु जनित (थन/दूध)',
    animalTypes: ['cow', 'buffalo', 'heifer'],
    severity: 'urgent',
    severityHindi: 'तत्काल ध्यान (2-4 घंटे)',
    symptoms: {
      primary: [
        'थन में कठोरता, लालिमा, दर्द और अत्यधिक सूजन',
        'दूध में छीछड़े, थक्के (clots), पानी जैसा पीलापन या खून आना',
        'दूध उत्पादन में अचानक 50-80% भारी गिरावट',
        'पशु को थन छूने न देना व लात मारना'
      ],
      secondary: [
        'तीव्र अवस्था में तेज बुखार और चारा छोड़ देना',
        'संक्रमित थन का ठंडा पड़ना या काला होना (गैंग्रीनस थनैला)',
        'पशु का सुस्त होकर बैठ जाना'
      ],
      vitals: {
        temperatureF: '102.5°F - 105.0°F (तीव्र अवस्था में)',
        heartRateBpm: '70 - 90 bpm',
        respirationRateBpm: '25 - 40 bpm',
        rumenMotility: '1-2 प्रति 2 मिनट (सुस्त)'
      }
    },
    testingMethods: {
      onFarmTest: '1. स्ट्रिप कप टेस्ट: पहली 2-3 धार काली प्लेट पर लें और छीछड़े देखें। 2. सीएमटी (California Mastitis Test): 2 मिली दूध में 2 मिली सीएमटी रीजेंट मिलाकर 15 सेकंड हिलाएं; गाढ़ा जेल बनना थनैला प्रमाणित करता है। 3. पीएच पेपर (ब्रोमोथाइमोल ब्लू): दूध का पीएच 6.8 से ऊपर (गहरा हरा/नीला) आना।',
      clinicalLabTest: 'दूध कल्चर व एंटीबायोग्राम (ABST) द्वारा सटीक जीवाणु व प्रभावी एंटीबायोटिक की पहचान; सोमैटिक सेल काउंट (SCC > 2,00,000 कोशिकाएं/मिली)।',
      differentialDiagnosis: 'शारीरिक चोट, थन में सूजन (हार्ड बैग/उडेमा), लेप्टोस्पायरोसिस।'
    },
    goldenHourTiming: {
      criticalWindow: 'पहले 2 से 4 घंटे (दूध में बदलाव दिखते ही तुरंत उपचार शुरू करें ताकि थन हमेशा के लिए बंद न हो)',
      seasonalPeak: 'ब्याने के पहले 30 दिन व बरसात/मानसून के महीने (नमी व कीचड़ के कारण)',
      consequenceOfDelay: '24-48 घंटे की देरी से थन का स्थायी रूप से सूखना (फाइब्रोसिस), क्वार्टर का अंधा होना या गैंग्रीन।'
    },
    firstAid: {
      ingredients: [
        'ताजा घृतकुमारी (Aloe Vera) - 200 ग्राम (गूदा)',
        'शुद्ध हल्दी पाउडर (Turmeric) - 50 ग्राम',
        'बुझा हुआ चूना (Slaked Lime/Chuna) - 10-15 ग्राम'
      ],
      preparation: 'घृतकुमारी, हल्दी और चूने को मिक्सी या सिलबट्टे पर अच्छी तरह पीसकर गाढ़ा लाल/नारंगी लेप बना लें। आवश्यकतानुसार थोड़ा पानी मिलाएं।',
      application: '1. सबसे पहले संक्रमित थन से सारा खराब दूध अलग बर्तन में दुहकर जमीन में गाड़ दें। 2. थन को गुनगुने पानी से धोकर सुखाएं। 3. तैयार देसी लेप को पूरे थन पर दिन में 3-4 बार लगाएं। 3 से 5 दिन तक लगातार लगाएं।',
      precautions: [
        'खराब दूध को कभी भी फर्श या बाड़े में न गिराएं, इससे अन्य पशुओं में संक्रमण फैलेगा।',
        'संक्रमित पशु को हमेशा सबसे अंत में दुहें।',
        'दूध दुहने वाले हाथ हमेशा साबुन से धोएं।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा इंट्रा-मेमरी एंटीबायोटिक ट्यूब (थन पूरी तरह खाली करने के बाद) चढ़ाना, साथ में सिस्टेमिक एंटीबायोटिक और सूजन-दर्द निवारक इंजेक्शन।',
      ivFluids: 'यदि तेज बुखार व टॉक्सिमिया हो तो 5% डेक्सट्रोज सेलाइन (DNS) 2-3 लीटर IV।',
      supportiveTherapy: 'विटामिन एच (बायोटिन), विटामिन ई + सेलेनियम और जिंक ओरल टॉनिक (थन की कोशिकाओं की मरम्मत हेतु)।'
    },
    suggestedMedicines: [
      {
        molecule: 'Ceftiofur Sodium',
        tradeNames: ['Xyrofur', 'Intacef', 'Ceftiforce'],
        dosage: '1-2 mg/kg शरीर भार (1 ग्राम वायल 400 किग्रा गाय हेतु) IM/SC',
        route: 'IM / SC',
        milkWithdrawal: '0 घंटे (दूध फेंकने की आवश्यकता नहीं - डेयरी सुरक्षित)',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'दूध में एंटीबायोटिक अवशेष न छोड़ने वाली सर्वोत्तम दवा।'
      },
      {
        molecule: 'Meloxicam + Paracetamol',
        tradeNames: ['Melonex Plus', 'Melox-P', 'Zobid-M'],
        dosage: '15 - 20 मिली IM (एक बार दैनिक, 3 दिन)',
        route: 'IM',
        milkWithdrawal: '72 घंटे (3 दिन)',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'थन का दर्द, लाली व तापमान तुरंत कम करता है।'
      },
      {
        molecule: 'Amoxicillin + Cloxacillin (Intramammary)',
        tradeNames: ['Pendistrin-SH', 'Tilox intramammary', 'Mammitel'],
        dosage: '1 ट्यूब प्रति संक्रमित क्वार्टर (दूध पूरी तरह निकालने के बाद 12 घंटे के अंतराल पर)',
        route: 'Intra-mammary',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '7 दिन',
        prescriptionRequired: true,
        notes: 'थन की नली को स्प्रिट से साफ करके ही ट्यूब चढ़ाएं।'
      }
    ],
    prevention: {
      vaccineName: 'Mastitis Autogenous Bacterin (उपलब्धता अनुसार)',
      vaccineSchedule: 'दूध दुहने के तुरंत बाद 0.5% पोविडोन आयोडीन में टीट-डिप (Teat Dip) करें।',
      biosecurity: [
        'दूध दुहने के 45 मिनट बाद तक गाय को बैठने न दें (चारा डालकर खड़ा रखें ताकि थन का छेद बंद हो सके)।',
        'बाड़े का फर्श सूखा व चूना छिड़का हुआ रखें।',
        'पूर्ण हस्त दोहन (Full Hand Milking) करें, अंगूठा दबाकर न दुहें।'
      ]
    }
  },

  // 2. Hemorrhagic Septicemia (HS)
  {
    id: 'hemorrhagic-septicemia',
    name: 'Hemorrhagic Septicemia - HS',
    hindiName: 'गलघोंटू रोग (घुर्रा / नाविक ज्वर)',
    scientificName: 'Pasteurella multocida (Serotype B:2)',
    category: 'bacterial',
    categoryHindi: 'जीवाणु जनित (तीव्र घातक)',
    animalTypes: ['buffalo', 'cow', 'calf'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-2 घंटे)',
    symptoms: {
      primary: [
        'अचानक तेज बुखार (104°F से 107°F)',
        'गले, जबड़े के नीचे और गलकंबल में गर्म, कठोर व अत्यंत दर्दनाक सूजन',
        'मुंह से लगातार लार टपकना व जीभ बाहर निकलना',
        'सांस लेने में भारी घरघराहट या घुर्र-घुर्र की आवाज (Stertorous breathing)'
      ],
      secondary: [
        'आंखें लाल होना व पानी बहना',
        'पशु का दम घुटना और बेचैनी से जमीन पर गिरना',
        'खून मिश्रित दस्त (अंतिम अवस्था)'
      ],
      vitals: {
        temperatureF: '104.0°F - 107.0°F (अत्यंत उच्च)',
        heartRateBpm: '90 - 120 bpm (अति तीव्र)',
        respirationRateBpm: '40 - 65 bpm (गंभीर कष्ट)',
        rumenMotility: '0 (पूर्ण बंद / रूमेन गतिहीन)'
      }
    },
    testingMethods: {
      onFarmTest: 'गले की सूजन को अंगुली से दबाने पर गड्ढा पड़ना (Pitting edema), तेज बुखार और घुर्र-घुर्र सांस की आवाज।',
      clinicalLabTest: 'कान की नस से रक्त स्मीयर लेकर मिथाइलीन ब्लू या जीम्सा स्टेनिंग; दोनों सिरों पर रंग ग्रहण करने वाले बाइपोलर जीवाणु (Bipolar rods) दिखना।',
      differentialDiagnosis: 'एंथ्रेक्स (Anthrax), ब्लैक क्वार्टर (BQ), तीव्र रूमेन अफारा।'
    },
    goldenHourTiming: {
      criticalWindow: 'पहले 0 से 6 घंटे! यदि बुखार व सूजन के पहले 6 घंटे में एंटीबायोटिक नहीं दी गई तो दम घुटने से 85% मृत्यु निश्चित है।',
      seasonalPeak: 'मानसून का आगमन (जून से सितंबर) और सर्दियों में ठंडी हवा व नमी।',
      consequenceOfDelay: '12-24 घंटे के भीतर श्वासनली दबने (Asphyxiation) और एंडोटॉक्सिक शॉक से मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'बर्फ की थैली या ठंडा पानी',
        'सूखी खुली जगह (वेंटिलेशन)',
        'डॉक्टर को आपातकालीन कॉल (टोल फ्री 1962)'
      ],
      preparation: 'पशु को तुरंत ठंडी व हवादार जगह पर खड़ा करें। सिर ऊंचा रखें।',
      application: '1. गले की सूजन पर ठंडे पानी या बर्फ की सिंकाई करें ताकि सूजन थोड़ी दबे। 2. पशु का सिर ऊपर की ओर सहारा देकर रखें ताकि सांस की नली खुली रहे।',
      precautions: [
        '🚨 सख्त चेतावनी: पशु को मुंह से कभी भी कोई पानी, तेल या काढ़ा (Drenching) न पिलाएं! गले की मांसपेशियां लकवाग्रस्त होती हैं, दवा फेफड़ों में जाकर तुरंत दम घोंट देगी।',
        'पशु को पैदल बिल्कुल न चलाएं।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा तुरंत उच्च डोज सेफ्टियोफर या ऑक्सीटेट्रासाइक्लिन IV/IM और गले की सूजन घटाने हेतु कोर्टिकोस्टेरॉयड / फ्लूनेक्सिन मेग्लुमाइन IV।',
      ivFluids: 'नॉर्मल सेलाइन (NS) 2-3 लीटर IV धीमी गति से (एंडोटॉक्सिक शॉक से बचाने हेतु)।',
      supportiveTherapy: 'एंटीहिस्टामिनिक (Pheniramine maleate) 10 मिली IM और ब्रोम्हेक्सिन सांस आसान करने हेतु।'
    },
    suggestedMedicines: [
      {
        molecule: 'Ceftiofur Sodium',
        tradeNames: ['Intacef Tazo', 'Xyrofur', 'Naxcel'],
        dosage: '1 - 2 ग्राम IV या गहरा IM (तत्काल)',
        route: 'IV / IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'पाश्चुरेला जीवाणु के विरुद्ध जीवनरक्षक दवा।'
      },
      {
        molecule: 'Flunixin Meglumine',
        tradeNames: ['Megludyne', 'Finadyne', 'Flunitas'],
        dosage: '2.2 mg/kg शरीर भार (15-20 मिली IV)',
        route: 'IV',
        milkWithdrawal: '36 घंटे',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'गले की सूजन व एंडोटॉक्सिन को तेजी से घटाता है।'
      },
      {
        molecule: 'Oxytetracycline LA',
        tradeNames: ['Terramycin LA', 'Oxytet LA', 'Zodex LA'],
        dosage: '20 mg/kg शरीर भार (30-40 मिली गहरा IM दो जगहों पर)',
        route: 'IM',
        milkWithdrawal: '7 दिन',
        meatWithdrawal: '28 दिन',
        prescriptionRequired: true,
        notes: 'लंबे समय तक सुरक्षा प्रदान करने हेतु।'
      }
    ],
    prevention: {
      vaccineName: 'एचएस ऑयल एडजुवेंट / एलम प्रेसिपिटेटेड वैक्सीन (Raksha-HS)',
      vaccineSchedule: 'प्रतिवर्ष मई-जून (मानसून से 1 माह पूर्व) सभी 6 माह से ऊपर के पशुओं को 2-3 मिली SC लगाएं।',
      biosecurity: [
        'संक्रमित पशु के लार व चारे के संपर्क में स्वस्थ पशु को न आने दें।',
        'यदि पशु की मृत्यु हो जाए तो शव को 6 फीट गहरे गड्ढे में चूना डालकर गाड़ें।'
      ]
    }
  },

  // 3. Black Quarter (BQ)
  {
    id: 'black-quarter',
    name: 'Black Quarter - BQ',
    hindiName: 'लंगड़ा बुखार (जहरबाद / चरचरा / सुजका)',
    scientificName: 'Clostridium chauvoei',
    category: 'bacterial',
    categoryHindi: 'जीवाणु जनित (घातक मांसपेशी सड़न)',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-4 घंटे)',
    symptoms: {
      primary: [
        'अचानक एक पैर से अत्यधिक लंगड़ाना',
        'पुट्ठे, जांघ, कंधे या गर्दन की भारी मांसपेशियों में गर्म व दर्दनाक सूजन',
        'सूजन वाले हिस्से पर हाथ दबाने पर चर-चर (Crepitation/Crackling) की आवाज आना',
        'तेज बुखार (104°F से 106°F) व चारा-पानी बंद'
      ],
      secondary: [
        'सूजन वाला स्थान बाद में ठंडा, बेजान व काला पड़ जाना',
        'चीरा लगाने पर बदबूदार झागदार काला खून निकलना',
        'पशु का जमीन पर गिर जाना व कंपन'
      ],
      vitals: {
        temperatureF: '104.5°F - 106.5°F',
        heartRateBpm: '85 - 110 bpm',
        respirationRateBpm: '35 - 50 bpm',
        rumenMotility: '0 (बंद)'
      }
    },
    testingMethods: {
      onFarmTest: 'जांघ/पुट्ठे की सूजन पर हथेली फेरने या दबाने पर सूखे पत्तों जैसी चर-चर आवाज (गैस के बुलबुले)।',
      clinicalLabTest: 'सूजन से सुई द्वारा द्रव खींचकर ग्राम स्टेनिंग: ग्राम-पॉजिटिव स्पोर-युक्त छड़ें (Clostridium chauvoei)।',
      differentialDiagnosis: 'एंथ्रेक्स, सांप का काटना, हड्डी टूटना (Fracture), बिजली का झटका।'
    },
    goldenHourTiming: {
      criticalWindow: 'लंगड़ापन या सूजन के पहले 4 घंटे! एक बार विषैली गैस मांसपेशियों में फैल जाए तो उपचार असंभव हो जाता है।',
      seasonalPeak: 'मानसून के महीने, नए जुते हुए खेतों में चरने के बाद (मिट्टी से स्पोर्स ग्रहण करना)।',
      consequenceOfDelay: '12-24 घंटे के अंदर 95% मृत्यु दर।'
    },
    firstAid: {
      ingredients: [
        '3% हाइड्रोजन पेरोक्साइड (Hydrogen Peroxide)',
        'पोटैशियम परमैंगनेट (लाल दवा)',
        'आपातकालीन पशु चिकित्सक कॉल'
      ],
      preparation: 'पशु को छायादार शांत स्थान पर लिटाएं। चलने पर पूर्ण प्रतिबंध लगाएं।',
      application: '1. सूजन वाले स्थान पर ठंडा पानी डालें। 2. यदि चिकित्सक चीरा लगाएं तो हाइड्रोजन पेरोक्साइड से धोएं (ऑक्सीजन मिलने से एनारोबिक क्लोस्ट्रीडियम मरता है)।',
      precautions: [
        'पशु को जबरन बिल्कुल न चलाएं, जहर तेजी से दिल में फैलेगा।',
        'खुले में चीरा लगाकर खून जमीन पर न बहाएं, मिट्टी में बीजाणु 20 साल जीवित रहते हैं।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा तुरंत भारी मात्रा में पेनिसिलिन (Procaine Penicillin G 40,000 IU/kg) सूजन के चारों ओर और IV/IM देना।',
      ivFluids: '5% डेक्सट्रोज नॉर्मल सेलाइन 2-3 लीटर IV।',
      supportiveTherapy: 'मेगाडोज एनाल्जेसिक (Meloxicam 0.5 mg/kg) और बी-कॉम्प्लेक्स।'
    },
    suggestedMedicines: [
      {
        molecule: 'Procaine + Benzylpenicillin',
        tradeNames: ['Bistrepen', 'Penbistrep', 'Procaine Penicillin G'],
        dosage: '30,000 - 40,000 IU/kg IM (40 लाख यूनिट वायल) और सूजन के चारों ओर स्थानीय इंजेक्शन',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '10 दिन',
        prescriptionRequired: true,
        notes: 'क्लोस्ट्रीडियम के लिए सबसे अचूक दवा यदि 4 घंटे में दी जाए।'
      },
      {
        molecule: 'Oxytetracycline Injection',
        tradeNames: ['Terramycin 100mg/ml', 'Oxytet', 'Zodex'],
        dosage: '10 mg/kg शरीर भार IV धीमी गति से',
        route: 'IV',
        milkWithdrawal: '7 दिन',
        meatWithdrawal: '21 दिन',
        prescriptionRequired: true,
        notes: 'पेनिसिलिन उपलब्ध न होने पर द्वितीय विकल्प।'
      },
      {
        molecule: 'Meloxicam',
        tradeNames: ['Melonex', 'Melox', 'Mlobe'],
        dosage: '15 - 20 मिली गहरा IM',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'तीव्र दर्द व सूजन निवारक।'
      }
    ],
    prevention: {
      vaccineName: 'रक्षा-बीक्यू (Raksha-BQ) या संयुक्त HS+BQ वैक्सीन',
      vaccineSchedule: 'प्रतिवर्ष मई माह में 6 माह से अधिक उम्र के गोवंश/भैंस को 3 मिली SC।',
      biosecurity: [
        'मृत पशु की खाल कभी न उतारें! शव को बिना चीरे 6 फीट गहरे गड्ढे में चूना डालकर दफनाएं।',
        'संक्रमित चारागाह में अन्य पशुओं की चराई रोकें।'
      ]
    }
  },

  // 4. Foot and Mouth Disease (FMD)
  {
    id: 'foot-and-mouth-disease',
    name: 'Foot and Mouth Disease - FMD',
    hindiName: 'खुरपका-मुंहपका (खुरहा / बेरा)',
    scientificName: 'Aphthovirus (Picornaviridae - Types O, A, Asia-1)',
    category: 'viral',
    categoryHindi: 'विषाणु जनित (अत्यंत संक्रामक)',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'urgent',
    severityHindi: 'तत्काल पृथक्करण व देखभाल',
    symptoms: {
      primary: [
        'मुंह से लगातार रस्सी जैसी लंबी चिपचिपी लार (Ropy drooling) टपकना',
        'जीभ, मसूड़ों, तालू व होंठों के अंदर दर्दनाक छाले व फफोले',
        'खुरों के बीच (Interdigital cleft) में छाले व घाव, जिससे पशु लंगड़ाता है',
        'दूध उत्पादन में 80-90% की विनाशकारी गिरावट'
      ],
      secondary: [
        'तेज बुखार (104°F से 106°F) व होंठों को बार-बार चप-चप बजाना (Lip smacking)',
        'थन पर छाले पड़ने से थनैला होना',
        'छोटे बछड़ों में बिना लक्षण दिल का दौरा पड़ना (टाइगर हार्ट - Tiger Heart)'
      ],
      vitals: {
        temperatureF: '104.0°F - 106.0°F',
        heartRateBpm: '75 - 95 bpm',
        respirationRateBpm: '30 - 45 bpm',
        rumenMotility: '1 प्रति 2 मिनट (कम)'
      }
    },
    testingMethods: {
      onFarmTest: 'मुंह से लंबी लार बहना, जीभ व खुरों के बीच कच्चे लाल छाले और पैर पटकना।',
      clinicalLabTest: 'छालों के द्रव या पपड़ी का आरटी-पीसीआर (RT-PCR) या एंटीजन एलिसा (ELISA) टेस्ट।',
      differentialDiagnosis: 'वेसिकुलर स्टोमैटाइटिस, रेंडरपेस्ट (उन्मूलित), खुर सड़न (Foot Rot)।'
    },
    goldenHourTiming: {
      criticalWindow: 'लार टपकने के पहले 12 घंटे! तुरंत पशु को अलग बांधें व मुंह-खुर की सफाई शुरू करें ताकि कीड़े (Maggots) न पड़ें।',
      seasonalPeak: 'सर्दियों का मौसम (नवंबर से फरवरी) और पशु मेलों/खरीद-फरोख्त के दौरान।',
      consequenceOfDelay: 'खुर का स्थायी रूप से उखड़ना (Sloughing), बांझपन व दूध उत्पादन हमेशा के लिए आधा रह जाना।'
    },
    firstAid: {
      ingredients: [
        'पोटैशियम परमैंगनेट (लाल दवा) - 1 ग्राम प्रति 1 लीटर पानी',
        'मीठा सोडा (Sodium Bicarbonate) - 2 चम्मच',
        'शहद + सुहागा (Borax) या शुद्ध घी + हल्दी पाउडर',
        'नीला थोथा (Copper Sulfate) - 2% खुर धोने हेतु'
      ],
      preparation: '1. लाल दवा के हल्के गुलाबी पानी से मुंह व खुर धोएं। 2. भुना हुआ सुहागा (10 ग्राम) शहद (50 ग्राम) में मिलाकर लेप बनाएं।',
      application: '1. दिन में 2 बार मुंह को लाल दवा के पानी से साफ करें। 2. जीभ व मसूड़ों पर शहद-सुहागा या घी-हल्दी का लेप अंगुली से हल्के-हल्के लगाएं। 3. खुरों को धोकर साफ रखें व मक्खी-रोधी स्प्रे (Topicure) छिड़कें। 4. दलिया व गुड़ जैसा नरम चारा दें।',
      precautions: [
        'बीमार पशु को स्वस्थ झुंड से कम से कम 50 मीटर दूर बांधें।',
        'पशु को कीचड़ व गोबर में न खड़ा होने दें, खुर सड़ जाएंगे।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'वायरस की सीधी दवा नहीं होती; पशु चिकित्सक द्वारा द्वितीयक जीवाणु संक्रमण व निमोनिया रोकने हेतु ब्रॉड-स्पेक्ट्रम एंटीबायोटिक, दर्द निवारक व बुखार की दवा दी जाती है।',
      ivFluids: 'यदि पशु डिहाइड्रेट हो तो 5% डेक्सट्रोज सेलाइन 2-3 लीटर IV।',
      supportiveTherapy: 'विटामिन ए, ई और सी इंजेक्शन घाव भरने व रोग प्रतिरोधक क्षमता बढ़ाने हेतु।'
    },
    suggestedMedicines: [
      {
        molecule: 'Meloxicam + Paracetamol',
        tradeNames: ['Melonex Plus', 'Zobid-M', 'Melox-P'],
        dosage: '15 - 20 मिली IM (दैनिक 3-4 दिन)',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'मुंह व खुर के दर्द को शांत करता है ताकि पशु जुगाली कर सके।'
      },
      {
        molecule: 'Ceftiofur Sodium',
        tradeNames: ['Intacef', 'Xyrofur', 'Excenel'],
        dosage: '1 ग्राम IM (प्रतिदिन 3 दिन)',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '4 दिन',
        prescriptionRequired: true,
        notes: 'खुरों में सड़न व फेफड़ों के संक्रमण से बचाता है।'
      },
      {
        molecule: 'Topicure / Charmil Spray',
        tradeNames: ['Topicure++', 'D-Mag', 'Scavon'],
        dosage: 'खुरों व घावों पर दिन में 2 बार स्प्रे करें',
        route: 'Topical',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'मक्खियों को दूर रखता है और कीड़े पड़ने से रोकता है।'
      }
    ],
    prevention: {
      vaccineName: 'एफएमडी वैक्सीन (Raksha-Ovac / Footvax)',
      vaccineSchedule: 'वर्ष में दो बार (सितंबर-अक्टूबर और मार्च-अप्रैल) राष्ट्रीय पशु रोग नियंत्रण कार्यक्रम (NADCP) के तहत नि:शुल्क।',
      biosecurity: [
        'बाड़े के मुख्य द्वार पर चूने व फिनाइल का फुट-बाथ (Foot bath) बनाएं।',
        'संक्रमित क्षेत्र से नया पशु न खरीदें।'
      ]
    }
  },

  // 5. Lumpy Skin Disease (LSD)
  {
    id: 'lumpy-skin-disease',
    name: 'Lumpy Skin Disease - LSD',
    hindiName: 'लम्पी त्वचा रोग (गांठदार त्वचा रोग)',
    scientificName: 'Capripoxvirus (Poxviridae)',
    category: 'viral',
    categoryHindi: 'विषाणु जनित (मक्खी/मच्छर जनित)',
    animalTypes: ['cow', 'heifer', 'calf', 'buffalo'],
    severity: 'urgent',
    severityHindi: 'तत्काल देखभाल व घाव प्रबंधन',
    symptoms: {
      primary: [
        'पूरे शरीर, सिर, गर्दन, थन व जननांगों पर 2 से 5 सेमी की कठोर गोल गांठें (Nodules) उभरना',
        'तेज बुखार (104°F से 106°F) जो कई दिनों तक बना रहे',
        'पैरों, गलकंबल और सीने में भारी सूजन (Edema), जिससे चलने में परेशानी',
        'आंख और नाक से पानी व गाढ़ा स्राव बहना'
      ],
      secondary: [
        'गांठों का पककर फूटना और गहरे गड्ढेदार अल्सर (Sitfast घाव) बन जाना',
        'दूध में भारी गिरावट व ब्याने वाली गायों में गर्भपात',
        'घावों में कीड़े (Maggots) पड़ना'
      ],
      vitals: {
        temperatureF: '104.0°F - 106.5°F',
        heartRateBpm: '80 - 100 bpm',
        respirationRateBpm: '30 - 45 bpm',
        rumenMotility: '1-2 प्रति 2 मिनट'
      }
    },
    testingMethods: {
      onFarmTest: 'त्वचा पर सिक्के जैसी गोल उभरी कठोर गांठें, तेज बुखार और पैरों में पानी जैसी सूजन।',
      clinicalLabTest: 'त्वचा की पपड़ी या बायोप्सी का पीसीआर (Real-Time PCR) टेस्ट।',
      differentialDiagnosis: 'स्यूडो-लम्पी (Bovine Herpesvirus 2), रिंगवर्म, टिक बाइट एलर्जी।'
    },
    goldenHourTiming: {
      criticalWindow: 'बुखार व पहली 2-3 गांठें दिखते ही पहले 24 घंटे! तुरंत नीम-हल्दी लेप व मक्खी-मच्छर नियंत्रण शुरू करें।',
      seasonalPeak: 'बरसात के बाद (जुलाई से नवंबर) जब मच्छर, डास और चिचड़ियां अत्यधिक सक्रिय होते हैं।',
      consequenceOfDelay: 'गांठों के सड़ने से सेप्सिस, घावों में कीड़े पड़ना और महीनों तक पशु का कंकाल बन जाना।'
    },
    firstAid: {
      ingredients: [
        'ताजा नीम के पत्ते - 100 ग्राम',
        'हल्दी पाउडर - 50 ग्राम',
        'लहसुन की कलियां - 10 नग',
        'शुद्ध नारियल का तेल - 250 मिली',
        'पान के पत्ते (10 नग) + काली मिर्च (10 ग्राम) + गुड़ (100 ग्राम) - मौखिक काढ़ा'
      ],
      preparation: '1. मौखिक लड्डू: पान के पत्ते, काली मिर्च, नमक व गुड़ को सिलबट्टे पर कूटकर लड्डू बनाएं। 2. घाव का तेल: नारियल तेल में नीम, हल्दी व लहसुन को धीमी आंच पर पकाकर छान लें।',
      application: '1. गुड़-पान-काली मिर्च का लड्डू दिन में 3 बार पहले दिन दें, फिर 2 बार अगले 7 दिन तक खिलाएं (प्रतिरोधक क्षमता बढ़ाता है)। 2. गांठों व घावों पर तैयार नीम-हल्दी का तेल दिन में 2 बार लगाएं। 3. शाम को बाड़े में नीम व गूगल का धुआं करें।',
      precautions: [
        'पशु को चिचड़ी, मच्छर व डास (Flies) से बचाएं, यही वायरस फैलाते हैं।',
        'गांठों को जबरदस्ती खुरचकर न छीलें।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा द्वितीयक त्वचा व फेफड़े के संक्रमण रोकने हेतु एनरोफ्लोक्सासिन या ऑक्सीटेट्रासाइक्लिन, बुखार/सूजन हेतु मेलोक्सीकैम और एंटीहिस्टामिनिक इंजेक्शन।',
      ivFluids: 'कमजोरी की स्थिति में 5% डेक्सट्रोज व इलेक्ट्रोलाइट्स 2 लीटर IV।',
      supportiveTherapy: 'विटामिन ए, ई, बायोटिन और जिंक टॉनिक त्वचा के पुनर्निर्माण हेतु।'
    },
    suggestedMedicines: [
      {
        molecule: 'Enrofloxacin 10%',
        tradeNames: ['Baytril', 'Enrocin', 'Fortivir'],
        dosage: '5 mg/kg शरीर भार (15-20 मिली IM दैनिक 3 दिन)',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '14 दिन',
        prescriptionRequired: true,
        notes: 'त्वचा के गहरे संक्रमण व निमोनिया से बचाता है।'
      },
      {
        molecule: 'Meloxicam + Paracetamol',
        tradeNames: ['Melonex Plus', 'Zobid-M'],
        dosage: '15 - 20 मिली IM',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '15 दिन',
        prescriptionRequired: true,
        notes: 'तेज बुखार व जोड़ों की सूजन तुरंत कम करता है।'
      },
      {
        molecule: 'Pheniramine Maleate',
        tradeNames: ['Avil', 'Cadistin', 'Belavil'],
        dosage: '10 मिली IM',
        route: 'IM',
        milkWithdrawal: '24 घंटे',
        meatWithdrawal: '3 दिन',
        prescriptionRequired: true,
        notes: 'एलर्जी व खुजली शांत करता है।'
      }
    ],
    prevention: {
      vaccineName: 'गोट पॉक्स वैक्सीन (Goat Pox Vaccine - Uttarkashi Strain) / Lumpi-ProVacInd',
      vaccineSchedule: 'सभी स्वस्थ गोवंश को 3 मिली SC सालाना लगाएं (लम्पी के प्रकोप से पहले)।',
      biosecurity: [
        'बाड़े में बूटॉक्स (Deltamethrin 12.5%) 2 मिली/लीटर पानी का छिड़काव करें।',
        'संक्रमित पशु का दूध बछड़े को उबालकर ही पिलाएं।'
      ]
    }
  },

  // 6. Bovine Theileriosis
  {
    id: 'bovine-theileriosis',
    name: 'Bovine Theileriosis (Tick Fever)',
    hindiName: 'थायलेरियासिस (चिचड़ी बुखार / टीक फीवर)',
    scientificName: 'Theileria annulata (Hyalomma tick vector)',
    category: 'protozoal',
    categoryHindi: 'प्रोटोजोआ / चिचड़ी जनित',
    animalTypes: ['cow', 'calf', 'heifer', 'buffalo'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (12-24 घंटे)',
    symptoms: {
      primary: [
        'लगातार अत्यधिक तेज बुखार (105°F से 107°F) जो सामान्य दवाओं से न उतरे',
        'कंधे के आगे की लिम्फ ग्रंथि (Prescapular Lymph Node) का नींबू या आम के आकार जितना फूल जाना',
        'अत्यधिक खून की कमी (Anemia) - आंख और मसूड़ों का सफेद या पीला पड़ना',
        'आंखों से आंसू बहना व कॉर्निया का सफेद/धुंधला होना'
      ],
      secondary: [
        'सांस तेजी से फूलना व हांफना (फेफड़ों में पानी भरना)',
        'अंतिम अवस्था में कॉफी जैसे रंग का पेशाब',
        'क्रॉस-ब्रीड (HF / जर्सी) गायों व बछड़ों में 60-80% मृत्यु दर'
      ],
      vitals: {
        temperatureF: '105.0°F - 107.5°F (अत्यधिक तीव्र)',
        heartRateBpm: '90 - 125 bpm',
        respirationRateBpm: '45 - 65 bpm (हांफना)',
        rumenMotility: '0-1 प्रति 2 मिनट'
      }
    },
    testingMethods: {
      onFarmTest: 'कंधे के आगे की लिम्फ गांठ को छूने पर कठोर व फूली हुई मिलना, 106°F बुखार और आंखों की झिल्ली सफेद होना।',
      clinicalLabTest: '1. लिम्फ नोड से सुई द्वारा द्रव खींचकर स्मीयर बनाना: कोच ब्लू बॉडीज (Koch blue bodies schizonts) दिखना। 2. कान की नस से ब्लड स्मीयर: आरबीसी में थायलेरिया पिरोप्लाज्म।',
      differentialDiagnosis: 'बेबेसियोसिस (Babesiosis), एनाप्लास्मोसिस, गलघोंटू (HS)।'
    },
    goldenHourTiming: {
      criticalWindow: 'लिम्फ ग्रंथि सूजने व बुखार के पहले 24 घंटे! यदि हीमोग्लोबिन 5 ग्राम से नीचे गिरा तो दवा भी पशु को नहीं बचा पाएगी।',
      seasonalPeak: 'गर्मियां व बारिश (मई से सितंबर) जब हयालोमा चिचड़ी बाड़े में अंडे देती है।',
      consequenceOfDelay: 'गंभीर पल्मोनरी एडिमा (फेफड़ों में झाग), हाइपोक्सिया और 3-5 दिन में मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'ठंडे पानी की पट्टियां (सिर पर)',
        'दस्ताने पहनकर चिचड़ियां चुनना व नष्ट करना',
        'गुड़ (250 ग्राम) + मीठा सोडा (50 ग्राम) का घोल'
      ],
      preparation: 'पशु को ठंडे छायादार बाड़े में रखें। पंखा चलाएं।',
      application: '1. सिर व रीढ़ पर ठंडे पानी की पट्टी रखें। 2. शरीर पर लगी चिचड़ियों को हाथ से हटाकर फिनाइल या आग में नष्ट करें (फर्श पर न कुचलें)। 3. तुरंत पशु चिकित्सक को बुलाएं।',
      precautions: [
        '🚨 चेतावनी: यह बीमारी केवल बुखार की दवा (Paracetamol) से ठीक नहीं होती, इसके लिए विशेष एंटीप्रोटोजोअल इंजेक्शन अनिवार्य है।',
        'पशु को धूप या तनाव में न लाएं।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा जीवनरक्षक बूपरवाक्वोन (Buparvaquone) 2.5 mg/kg गहरा IM देना। साथ में लॉन्ग-एक्टिंग ऑक्सीटेट्रासाइक्लिन।',
      ivFluids: 'रक्त चढ़ाना (Blood Transfusion) यदि PCV < 12% हो; डेक्सट्रोज 5% धीमी गति से।',
      supportiveTherapy: 'आयरन इंजेक्शन (Iron Dextran), विटामिन बी-कॉम्प्लेक्स (B12 सहित) और लिवर टॉनिक।'
    },
    suggestedMedicines: [
      {
        molecule: 'Buparvaquone',
        tradeNames: ['Butalex', 'Zubion', 'Buparvon'],
        dosage: '1 मिली प्रति 20 किग्रा शरीर भार (400 किग्रा गाय हेतु 20 मिली) गर्दन के पुट्ठे में गहरा IM',
        route: 'IM',
        milkWithdrawal: '48 घंटे',
        meatWithdrawal: '42 दिन',
        prescriptionRequired: true,
        notes: 'थायलेरियासिस की एकमात्र अचूक व चमत्कारी जीवनरक्षक दवा।'
      },
      {
        molecule: 'Oxytetracycline LA 200mg/ml',
        tradeNames: ['Terramycin LA', 'Zodex LA'],
        dosage: '20 mg/kg IM (20-30 मिली)',
        route: 'IM',
        milkWithdrawal: '7 दिन',
        meatWithdrawal: '28 दिन',
        prescriptionRequired: true,
        notes: 'बूपरवाक्वोन के असर को दोगुना करता है।'
      },
      {
        molecule: 'Iron Dextran + Vit B12',
        tradeNames: ['Feritas', 'Imferon', 'Belamyl'],
        dosage: '10 मिली गहरा IM (सप्ताह में दो बार)',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'नष्ट हुए लाल रक्त कणों (RBCs) को पुनः बनाता है।'
      }
    ],
    prevention: {
      vaccineName: 'थायलेरिया वैक्सीन (Raksha-Vac T)',
      vaccineSchedule: 'क्रॉस-ब्रीड बछड़ों को 2 माह की उम्र में एक बार 3 मिली SC।',
      biosecurity: [
        'बाड़े की दीवारों की दरारों में ब्यूटाक्स (Deltamethrin) या फ्लुमेथ्रिन का नियमित छिड़काव करें।',
        'हर माह पशु पर पोर-ऑन (Pour-on) चिचड़ी नाशक दवा लगाएं।'
      ]
    }
  },

  // 7. Bovine Babesiosis (Redwater Fever)
  {
    id: 'bovine-babesiosis',
    name: 'Bovine Babesiosis (Redwater Fever)',
    hindiName: 'बेबेसियोसिस (लाल पेशाब रोग / चिचड़ी मूत्र ज्वर)',
    scientificName: 'Babesia bigemina / Babesia bovis (Rhipicephalus microplus)',
    category: 'protozoal',
    categoryHindi: 'प्रोटोजोआ / चिचड़ी जनित',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-6 घंटे)',
    symptoms: {
      primary: [
        'गहरा लाल, कॉफी या वाइन जैसा लाल पेशाब (Hemoglobinuria)',
        'अचानक बहुत तेज बुखार (105°F से 107°F)',
        'आंखों व मसूड़ों का पीला व फीका पड़ना (गंभीर पीलिया व एनीमिया)',
        'दिल की धड़कन इतनी तेज होना कि 2-3 फीट दूर से आवाज सुनाई दे (Pipe-stem pulse)'
      ],
      secondary: [
        'पशु का लड़खड़ाना व खड़े होने में असमर्थ होना',
        'पेशाब झागदार होना और रखने पर नीचे खून न बैठना (सच्चा हीमोग्लोबिन्यूरिया)',
        'गुर्दे (Kidneys) फेल होने से कोमा व मृत्यु'
      ],
      vitals: {
        temperatureF: '105.0°F - 107.0°F',
        heartRateBpm: '100 - 130 bpm (अति तीव्र व धड़कता हुआ)',
        respirationRateBpm: '40 - 60 bpm',
        rumenMotility: '0 (बंद)'
      }
    },
    testingMethods: {
      onFarmTest: 'कांच के गिलास में पेशाब इकट्ठा करें: यदि पेशाब पारदर्शी गहरा लाल है और 30 मिनट रखने पर नीचे कोई थक्का नहीं जमता, तो यह बेबेसियोसिस का हीमोग्लोबिन्यूरिया है।',
      clinicalLabTest: 'कान की नस से ब्लड स्मीयर बनाकर जीम्सा स्टेनिंग: आरबीसी के अंदर नाशपाती के आकार के जुड़े हुए जोड़े (Paired pear-shaped piroplasms) दिखना।',
      differentialDiagnosis: 'ब्याने के बाद का लाल पेशाब (PPH - जिसमें बुखार नहीं होता), लेप्टोस्पायरोसिस, हेमोचूरिया।'
    },
    goldenHourTiming: {
      criticalWindow: 'लाल पेशाब दिखने के पहले 6 से 12 घंटे! गुर्दे ब्लॉक होने से पहले दवा दी जानी चाहिए।',
      seasonalPeak: 'मानसून व गर्मी (चिचड़ियों का प्रकोप काल)।',
      consequenceOfDelay: '24-48 घंटे में गुर्दे फेल (Renal failure) और रक्तहीनता से मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'गुनगुना पानी + ग्लूकोज (250 ग्राम)',
        'मीठा सोडा (Sodium Bicarbonate) - 50 ग्राम',
        'पशु को शांत छायादार स्थान में रखना'
      ],
      preparation: 'पशु को बिना हिलाए-डुलाए आराम से लिटाएं।',
      application: '1. 1 लीटर पानी में ग्लूकोज व मीठा सोडा घोलकर पिलाएं (गुर्दों में एसिड व हीमोग्लोबिन जमने से रोकेगा)। 2. पशु पर ठंडा पानी न डालें और न ही उसे दूर चलाएं (दिल का दौरा पड़ सकता है)। 3. तुरंत बेरिनिल/डिमिनजीन का इंजेक्शन लगवाएं।',
      precautions: [
        '🚨 पशु को जबरन बिल्कुल न चलाएं, लाल रक्त कण इतने कम होते हैं कि दिमाग में ऑक्सीजन नहीं पहुंचती।',
        'बिना डॉक्टर के परामर्श के गलत दवा न दें।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा डिमिनाजीन एसिट्यूरेट (Berenil) 3.5-7 mg/kg गहरा IM या इमिडोकार्ब डिप्रोपियोनेट 1.2 mg/kg SC।',
      ivFluids: 'रिंगर्स लैक्टेट (RL) या नॉर्मल सेलाइन 2-3 लीटर IV धीमी गति से (गुर्दे साफ करने हेतु)।',
      supportiveTherapy: 'विटामिन बी-कॉम्प्लेक्स, आयरन और लिवर प्रोटेक्टिव इंजेक्शन।'
    },
    suggestedMedicines: [
      {
        molecule: 'Diminazene Aceturate',
        tradeNames: ['Berenil', 'Diminasan', 'Babesin'],
        dosage: '3.5 - 7 mg/kg शरीर भार (400 किग्रा गाय हेतु 20-30 मिली गहरा IM)',
        route: 'IM',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '21 दिन',
        prescriptionRequired: true,
        notes: 'बेबेसिया प्रोटोजोआ को नष्ट करने वाली प्रथम श्रेणी की दवा।'
      },
      {
        molecule: 'Imidocarb Dipropionate',
        tradeNames: ['Imizol', 'Bicarb'],
        dosage: '1.2 mg/kg शरीर भार (1 मिली प्रति 100 किग्रा SC)',
        route: 'SC',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '28 दिन',
        prescriptionRequired: true,
        notes: 'बेबेसियोसिस और एनाप्लास्मोसिस दोनों में अत्यंत प्रभावी।'
      },
      {
        molecule: 'Sodium Acid Phosphate + B12',
        tradeNames: ['Tonophosphan', 'Urimin', 'Belamyl'],
        dosage: '15 - 20 मिली IV/IM',
        route: 'IV / IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'लाल रक्त कोशिकाओं की झिल्ली को मजबूत करता है।'
      }
    ],
    prevention: {
      vaccineName: 'चिचड़ी नियंत्रण (Acaricide Dip/Spray)',
      vaccineSchedule: 'हर 21-28 दिन पर पशु व बाड़े में चिचड़ी नाशक दवा का छिड़काव।',
      biosecurity: [
        'बाड़े में ब्यूटॉक्स (Deltamethrin) का स्प्रे करें।',
        'संक्रमित चारागाह से पशुओं को दूर रखें।'
      ]
    }
  },

  // 8. Milk Fever (Hypocalcemia)
  {
    id: 'milk-fever',
    name: 'Milk Fever (Parturient Paresis / Hypocalcemia)',
    hindiName: 'दूध ज्वर (कैल्शियम की कमी / प्रसवकालीन पक्षाघात)',
    scientificName: 'Acute Hypocalcemia (Serum Calcium < 5 mg/dL)',
    category: 'metabolic',
    categoryHindi: 'उपापचयी (कैल्शियम न्यूनता)',
    animalTypes: ['cow', 'buffalo'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-2 घंटे)',
    symptoms: {
      primary: [
        'ब्याने के 24 से 72 घंटे के भीतर पशु का बैठ जाना और उठ न पाना',
        'गर्दन को मोड़कर पेट/कोख की तरफ सटाकर रखना (विशिष्ट "S-Curve" मुद्रा)',
        'कान, सींग, थन और पैर बिल्कुल बर्फ जैसे ठंडे पड़ना',
        'शरीर का तापमान सामान्य से कम होना (97°F - 100°F - नाम "दूध ज्वर" है पर बुखार नहीं होता!)'
      ],
      secondary: [
        'आंखों की पुतलियां फैलना व सूखी थूथन',
        'गोबर-पेशाब बंद होना (आंतों का लकवा)',
        'पशु का करवट के बल लेट जाना (Lateral recumbency) व पेट में गैस भरना'
      ],
      vitals: {
        temperatureF: '97.0°F - 100.0°F (सामान्य से कम / Subnormal)',
        heartRateBpm: '70 - 90 bpm (धीमी व कमजोर धड़कन)',
        respirationRateBpm: '15 - 25 bpm (धीमी)',
        rumenMotility: '0 (पूर्ण बंद)'
      }
    },
    testingMethods: {
      onFarmTest: 'ब्याने के बाद गाय का बैठना, गर्दन पेट की ओर मुड़ना, कान ठंडे होना और थर्मामीटर में तापमान 100°F से नीचे आना।',
      clinicalLabTest: 'सीरम कैल्शियम परीक्षण: रक्त में कैल्शियम स्तर 5 मिलीग्राम/डेसीलीटर से कम (सामान्य: 9-11 mg/dL)।',
      differentialDiagnosis: 'कीटोसिस (Ketosis), डाउंनर काउ सिंड्रोम, गर्भाशय फटना, मस्टाइटिस टॉक्सिमिया।'
    },
    goldenHourTiming: {
      criticalWindow: 'पहले 0 से 4 घंटे! जितनी जल्दी कैल्शियम नस में चढ़ेगा, पशु 15 मिनट में उठ खड़ा होगा। 24 घंटे लेटे रहने पर मांसपेशियां दबकर हमेशा के लिए बेकार हो जाती हैं।',
      seasonalPeak: 'ब्याने के तुरंत बाद (दिन 1 से दिन 3) - विशेष रूप से 3 से 6 ब्यांत की अधिक दूध देने वाली गायों में।',
      consequenceOfDelay: '12-18 घंटे में ब्लोट (अफारा) व कोमा से मृत्यु या स्थायी डाउंनर काउ।'
    },
    firstAid: {
      ingredients: [
        'पुआल/भूसे की बोरियां (पशु को सहारा देने हेतु)',
        'कंबल या बोरी (शरीर गर्म रखने हेतु)',
        'आपातकालीन पशु चिकित्सक कॉल'
      ],
      preparation: 'पशु को तुरंत सीने के बल (Sternal position) बिठाएं, करवट न गिरने दें।',
      application: '1. पुआल की बोरियों से पशु की दोनों तरफ सहारा देकर उसे सीने के बल सीधा बिठाएं ताकि पेट में गैस न भरे। 2. शरीर और कानों को जूट की बोरी से रगड़ें व ढकें। 3. थनों से दूध बिल्कुल न निकालें।',
      precautions: [
        '🚨 सख्त जीवन-मरण चेतावनी: बेहोश या लेटे हुए पशु को मुंह से कभी भी कोई पानी, तेल या काढ़ा न पिलाएं! निगलने वाली मांसपेशियां लकवाग्रस्त होती हैं, पानी फेफड़ों में जाकर तुरंत मार देगा।',
        'ब्याने के पहले 48 घंटे में गाय का सारा दूध एक साथ कभी न दुहें।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा कैल्शियम बोरो ग्लूकोनेट 25% (CBG 450 मिली) धीमी गति से IV नस में चढ़ाना (स्टेथोस्कोप से दिल की धड़कन सुनते हुए) और शेष सब-क्यूटेनियस।',
      ivFluids: 'कैल्शियम-मैग्नीशियम-फास्फोरस संयुक्त इन्फ्यूजन (Mifex / Calborol 450 ml IV)।',
      supportiveTherapy: 'पशु के खड़े होने के बाद ओरल कैल्शियम जेल (Cal-Up / Bovikalc) 300 ग्राम मुंह से देना।'
    },
    suggestedMedicines: [
      {
        molecule: 'Calcium Borogluconate 25% + Mg + P',
        tradeNames: ['Mifex', 'Calborol', 'Intacal'],
        dosage: '450 मिली की पूरी बोतल (250 मिली धीमी IV नस में 15 मिनट में + 200 मिली चमड़ी के नीचे SC)',
        route: 'IV / SC',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'दूध ज्वर की 100% चमत्कारी जीवनरक्षक दवा; नस में बहुत धीमी गति से चढ़ाएं।'
      },
      {
        molecule: 'Ionic Oral Calcium Gel',
        tradeNames: ['Cal-Up Gel', 'Bovikalc', 'Ostovet Gel'],
        dosage: '300 ग्राम की ट्यूब (पशु के खड़े होने के बाद और पुनः 12 घंटे बाद)',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'दुबारा कैल्शियम गिरने से रोकता है; केवल होश में होने पर दें।'
      },
      {
        molecule: 'Tonophosphan (Phosphorus)',
        tradeNames: ['Tonophosphan', 'Urimin'],
        dosage: '10 - 15 मिली IM',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'मांसपेशियों की ताकत तुरंत बहाल करता है।'
      }
    ],
    prevention: {
      vaccineName: 'डीसीएडी आहार (DCAD Diet) व खनिज मिश्रण',
      vaccineSchedule: 'ब्याने से 15 दिन पूर्व कम कैल्शियम व अधिक फास्फोरस वाला सूखा चारा दें।',
      biosecurity: [
        'ब्याने के 12 घंटे पहले और ब्याने के तुरंत बाद 1-1 ट्यूब ओरल कैल्शियम जेल पिलाएं।',
        'गर्भावस्था के अंतिम महीने में अत्यधिक हरा बरसीम या अत्यधिक कैल्शियम सप्लीमेंट न दें।'
      ]
    }
  },

  // 9. Ruminal Tympany / Bloat
  {
    id: 'ruminal-bloat',
    name: 'Ruminal Tympany (Acute Bloat)',
    hindiName: 'तीव्र रूमेन अफारा (पेट फूलना / गैस का रुकना)',
    scientificName: 'Acute Ruminal Tympany (Frothy or Free-gas bloat)',
    category: 'metabolic',
    categoryHindi: 'उपापचयी / पाचन विकार',
    animalTypes: ['cow', 'buffalo', 'calf', 'heifer'],
    severity: 'emergency',
    severityHindi: 'अत्यंत आपातकालीन (0-30 मिनट)',
    symptoms: {
      primary: [
        'बायां पेट (Left Flank) गुब्बारे या ढोलक की तरह अत्यधिक फूल जाना',
        'बाएं पेट पर थपकी मारने पर ढोल जैसी आवाज (Drum-like ping) आना',
        'सांस लेने में भारी तकलीफ, मुंह खोलकर हांफना व जीभ बाहर निकालना',
        'बेचैनी से बार-बार उठना-बैठना और पिछले पैर से पेट पर लात मारना'
      ],
      secondary: [
        'आंखें बाहर की ओर उभरना व मुंह से झाग निकलना',
        'पशु का दम घुटकर जमीन पर गिरना',
        'गैस के दबाव से फेफड़े व डायफ्राम फटने से मृत्यु'
      ],
      vitals: {
        temperatureF: '99.0°F - 102.0°F (सामान्य)',
        heartRateBpm: '100 - 140 bpm (गंभीर तनाव)',
        respirationRateBpm: '50 - 75 bpm (गंभीर दम घुटना)',
        rumenMotility: 'प्रारंभ में तेज, बाद में पूर्ण शून्य'
      }
    },
    testingMethods: {
      onFarmTest: 'बाएं पेट का रीढ़ की हड्डी से ऊपर उठ जाना, अंगुली से बजाने पर गूंजती हुई ढोलक जैसी आवाज और मुंह खोलकर हांफना।',
      clinicalLabTest: 'पेट में पेट-नली (Stomach tube) डालकर गैस का निकलना या झागदार द्रव निकलना।',
      differentialDiagnosis: 'अन्नप्रणाली में रुकावट (Choke - आलू/सेब का अटकना), डायाफ्रामिक हर्निया, वागस इनडाइजेशन।'
    },
    goldenHourTiming: {
      criticalWindow: 'पहले 0 से 30 मिनट! यदि गैस अत्यधिक भर गई तो फेफड़ों पर दबाव पड़ने से 45 मिनट में दम घुटकर पशु मर सकता है।',
      seasonalPeak: 'सर्दियों व वसंत में जब पशु को ओस युक्त ताजा बरसीम, अल्फा-अल्फा या गीला हरा चारा अधिक खिलाया जाता है।',
      consequenceOfDelay: 'डायफ्राम टूटने व कार्डियोवैस्कुलर शॉक से आधे घंटे में मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'शुद्ध सरसों या अलसी का तेल - 250 से 400 मिली',
        'असली हींग (Asafoetida) - 15 से 20 ग्राम',
        'अजवाइन व सौंठ पाउडर - 50 ग्राम',
        'लकड़ी की खपच्ची (मुंह में बांधने हेतु)'
      ],
      preparation: 'तेल को हल्का गुनगुना करके उसमें हींग व अजवाइन घोल लें।',
      application: '1. पशु के मुंह में आड़ी लकड़ी (Wood bit) रखकर रस्सी से सींगों के पीछे बांधें ताकि मुंह खुला रहे व लार गिरने से गैस निकलती रहे। 2. पशु का अगला हिस्सा (अगले पैर) ऊंचे चबूतरे या ढलान पर रखें ताकि फेफड़ों पर दबाव कम हो। 3. हींग-तेल का मिश्रण नाल से धीरे-धीरे मुंह के कोने से पिलाएं (झाग तोड़ेगा)। 4. पशु को धीरे-धीरे टहलाएं।',
      precautions: [
        '🚨 पशु को कभी भी लेटने न दें! लेटने पर गैस नली पूरी बंद हो जाएगी और 10 मिनट में दम टूट जाएगा।',
        'जल्दबाजी में नाल फेफड़ों में न डालें।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'अति-आपातकालीन स्थिति में जब पशु गिरने लगे तो पशु चिकित्सक द्वारा बाएं पेट में ट्रोकार और कैनुला (Trocar & Cannula) या 14G सुई घोंपकर तुरंत गैस निकालना।',
      ivFluids: 'शॉक की स्थिति में 5% डेक्सट्रोज सेलाइन IV।',
      supportiveTherapy: 'सिमेथिकोन / पोलोक्सालीन एंटी-ब्लोट सस्पेंशन पेट में सीधे या मुंह से डालना।'
    },
    suggestedMedicines: [
      {
        molecule: 'Simethicone + Dill Oil',
        tradeNames: ['Bloatosil', 'Tympol', 'Afanil', 'Tympanil'],
        dosage: '100 मिली की पूरी बोतल 500 मिली पानी या तेल में मिलाकर तुरंत पिलाएं',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'झागदार अफारे के बुलबुलों को 5 मिनट में फोड़कर गैस मुक्त करता है।'
      },
      {
        molecule: 'Mustard Oil + Asafoetida (Heeng)',
        tradeNames: ['पारंपरिक देसी नुस्खा'],
        dosage: 'सरसों तेल 250 मिली + हींग 15 ग्राम',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'सर्फेक्टेंट की तरह काम करता है, घर पर उपलब्ध सबसे तेज उपचार।'
      },
      {
        molecule: 'Live Yeast + Probiotics Bolus',
        tradeNames: ['Levucell SC', 'Rumen FS', 'Biolac'],
        dosage: '2 बोलस सुबह-शाम (गैस निकलने के बाद 3 दिन तक)',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'रूमेन के सूक्ष्मजीवों को पुनः जीवित करता है।'
      }
    ],
    prevention: {
      vaccineName: 'संतुलित चारा प्रबंधन',
      vaccineSchedule: 'गीला बरसीम खिलाने से पहले हमेशा 2-3 किलो सूखा भूसा या पुआल खिलाएं।',
      biosecurity: [
        'पशु को खाली पेट अचानक अत्यधिक हरा रसीला बरसीम या सड़ा हुआ अनाज न खाने दें।',
        'चारे में 1% मीठा सोडा मिलाएं।'
      ]
    }
  },

  // 10. Subacute Ruminal Acidosis (SARA)
  {
    id: 'ruminal-acidosis',
    name: 'Ruminal Acidosis (Grain Overload / SARA)',
    hindiName: 'रूमेन एसिडोसिस (पेट में तेजाब बनना / अनाज का अफारा)',
    scientificName: 'Acute / Subacute Lactic Acidosis (Rumen pH < 5.5)',
    category: 'metabolic',
    categoryHindi: 'उपापचयी / पोषण संबंधी',
    animalTypes: ['cow', 'buffalo', 'heifer', 'calf'],
    severity: 'urgent',
    severityHindi: 'तत्काल क्षारीय उपचार (2-6 घंटे)',
    symptoms: {
      primary: [
        'पशु द्वारा अत्यधिक दाना, आटा, रोटी, दलिया या चावल खाने के बाद सुस्त होना',
        'चारा पूरी तरह छोड़ देना व जुगाली बंद होना',
        'पतला, झागदार, खट्टा बदबूदार पीले-भूरे रंग का दस्त (Sour-smelling diarrhea)',
        'पेट में छप-छप पानी जैसी आवाज आना (रूमेन में पानी भरना)'
      ],
      secondary: [
        'आंखें अंदर धंसना (गंभीर निर्जलीकरण)',
        'दांत पीसना व पेट दर्द से कराहना',
        'बाद के दिनों में पैरों के खुरों में जलन व लंगड़ापन (लेमिनाइटिस)'
      ],
      vitals: {
        temperatureF: '99.5°F - 101.5°F (सामान्य या कम)',
        heartRateBpm: '85 - 110 bpm',
        respirationRateBpm: '35 - 50 bpm (गहरी व तेज सांस)',
        rumenMotility: '0 (पूर्ण गतिहीन)'
      }
    },
    testingMethods: {
      onFarmTest: 'अनाज खाने का इतिहास, गोबर में खट्टी सड़े आटे जैसी गंध और पीएच स्ट्रिप से पेशाब/गोबर का अम्लीय (pH < 5.5) आना।',
      clinicalLabTest: 'रूमेन द्रव की जांच: पीएच 5.0 से नीचे आना और सूक्ष्मदर्शी में उपयोगी प्रोटोजोआ का मरा हुआ पाया जाना।',
      differentialDiagnosis: 'विषाक्तता (Poisoning), आंतों का मुड़ना (Volvulus), एबोमेसम विस्थापन (LDA)।'
    },
    goldenHourTiming: {
      criticalWindow: 'दाना खाने के पहले 6 से 12 घंटे! लैक्टिक एसिड रक्त में घुलकर एसिडोसिस करे, उससे पहले पेट को न्यूट्रलाइज करना जरूरी है।',
      seasonalPeak: 'त्योहारों के बाद (बची हुई रोटियां/अनाज खिलाना) या अचानक दाने की मात्रा बढ़ाना।',
      consequenceOfDelay: 'रूमेन की परत जलना (रूमेनाइटिस), लिवर में फोड़े और टॉक्सिक शॉक से मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'मीठा सोडा (Sodium Bicarbonate / Baking Soda) - 150 से 200 ग्राम',
        'गुनगुना पानी - 1 से 2 लीटर',
        'सूखा भूसा या पुआल'
      ],
      preparation: 'मीठे सोडे को 1 लीटर गुनगुने पानी में पूरी तरह घोल लें।',
      application: '1. तैयार मीठे सोडे का घोल नाल द्वारा तुरंत पिलाएं। 6 घंटे बाद 100 ग्राम पुनः दें। 2. दाना, खली, चोकर, दलिया, साइलेज सब तुरंत हटा लें। 3. केवल सूखा भूसा ही खाने को दें।',
      precautions: [
        '🚨 पशु को कभी भी तेल, घी या खट्टी छाछ न दें! यह एसिडोसिस को और अधिक भड़का देगा।',
        'पशु को पानी की बाल्टी के सामने अकेला न छोड़ें (अत्यधिक पानी पीने से रूमेन फट सकता है)।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'गंभीर स्थिति में पेट-नली द्वारा रूमेन की धुलाई (Rumen Lavage) करके खमीरयुक्त सड़ा दाना बाहर निकालना।',
      ivFluids: 'सोडियम बाइकार्बोनेट 1.3% या 5% इन्फ्यूजन IV (रिंगर्स लैक्टेट कभी न दें, क्योंकि लैक्टेट पहले से बढ़ा होता है!)।',
      supportiveTherapy: 'विटामिन बी1 (Thiamine 1-2 ग्राम IM) मस्तिष्क को पोलियोएन्सेफलोमलेशिया से बचाने हेतु।'
    },
    suggestedMedicines: [
      {
        molecule: 'Sodium Bicarbonate (Baking Soda)',
        tradeNames: ['मीठा सोडा पाउडर', 'Sodabicarb Powder'],
        dosage: '150 - 200 ग्राम पानी में घोलकर मुंह से (दिन में दो बार)',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'पेट के तेजाब को शांत करने का सबसे सरल व असरदार उपाय।'
      },
      {
        molecule: 'Thiamine Hydrochloride (Vit B1)',
        tradeNames: ['Tribivet', 'Neurobion', 'Berin'],
        dosage: '15 - 20 मिली IM या धीमी IV',
        route: 'IM / IV',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'एसिडोसिस से दिमाग पर होने वाले लकवे (Polio) को रोकता है।'
      },
      {
        molecule: 'Rumen Buffers & Probiotics',
        tradeNames: ['Bufzone', 'Rumentas', 'Ecowip'],
        dosage: '100 ग्राम पाउडर प्रतिदिन 3 दिन तक',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'रूमेन के पीएच को 6.5 पर स्थिर करता है।'
      }
    ],
    prevention: {
      vaccineName: 'दाना प्रबंधन',
      vaccineSchedule: 'दुधारू पशुओं के दाने में 1% मीठा सोडा हमेशा मिलाकर खिलाएं।',
      biosecurity: [
        'दाना भंडार का ताला बंद रखें ताकि पशु अचानक बोरी में मुंह न मार सके।',
        'दाने की मात्रा में अचानक वृद्धि न करें; 7-10 दिन में धीरे-धीरे बढ़ाएं।'
      ]
    }
  },

  // 11. Post-Parturient Hemoglobinuria (PPH)
  {
    id: 'post-parturient-hemoglobinuria',
    name: 'Post-Parturient Hemoglobinuria - PPH',
    hindiName: 'ब्याने के बाद लाल पेशाब (फास्फोरस की कमी का लाल पेशाब)',
    scientificName: 'Nutritional Hypophosphatemia (Inorganic P < 2.0 mg/dL)',
    category: 'metabolic',
    categoryHindi: 'उपापचयी / खनिज न्यूनता',
    animalTypes: ['buffalo', 'cow'],
    severity: 'urgent',
    severityHindi: 'तत्काल फास्फोरस उपचार (12-24 घंटे)',
    symptoms: {
      primary: [
        'ब्याने के 2 से 6 सप्ताह बाद कॉफी, चाय या डार्क रेड वाइन जैसा लाल पेशाब आना',
        'शरीर का तापमान बिल्कुल सामान्य या हल्का कम होना (कोई बुखार नहीं!)',
        'अत्यधिक कमजोरी, हांफना व दूध उत्पादन में भारी गिरावट',
        'मिट्टी, दीवार या ईंट चाटना (पाइका - Pica लक्षण)'
      ],
      secondary: [
        'आंखों की झिल्लियों का गहरा पीला व सफेद होना (गंभीर पीलिया व खून की कमी)',
        'दिल की धड़कन तेज होना व पशु का लड़खड़ाना',
        'लाल रक्त कणों के स्वतः फटने से गंभीर एनीमिया'
      ],
      vitals: {
        temperatureF: '100.5°F - 102.0°F (सामान्य - बुखार बिल्कुल नहीं)',
        heartRateBpm: '85 - 115 bpm (तेज धड़कन)',
        respirationRateBpm: '30 - 45 bpm',
        rumenMotility: '1-2 प्रति 2 मिनट'
      }
    },
    testingMethods: {
      onFarmTest: 'ब्याने के 15-30 दिन बाद लाल पेशाब और थर्मामीटर में 101°F (सामान्य तापमान) - यह चिचड़ी बुखार (Babesiosis) से अलग करता है जिसमें 106°F बुखार होता है।',
      clinicalLabTest: 'सीरम अकार्बनिक फास्फोरस परीक्षण: स्तर 2 मिलीग्राम/डेसीलीटर से नीचे (सामान्य: 4-7 mg/dL)।',
      differentialDiagnosis: 'बेबेसियोसिस (Babesiosis - तेज बुखार होता है), लेप्टोस्पायरोसिस, हेमोचूरिया।'
    },
    goldenHourTiming: {
      criticalWindow: 'लाल पेशाब दिखने के पहले 24 से 48 घंटे! यदि फास्फोरस नहीं दिया गया तो 3-4 दिन में हीमोग्लोबिन 3 ग्राम से नीचे गिरकर पशु मर जाएगा।',
      seasonalPeak: 'सर्दियों का मौसम और अत्यधिक हरा बरसीम खिलाने वाले क्षेत्रों में (बरसीम में कैल्शियम अधिक और फास्फोरस बहुत कम होता है)।',
      consequenceOfDelay: 'अनियंत्रित हीमोलिसिस व दिल का दौरा पड़ने से मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'सोडियम एसिड फास्फेट पाउडर (Sodium Acid Phosphate) - 60 ग्राम',
        'गन्ने का गुड़ या शीरा (Molasses) - 500 ग्राम',
        'गेहूं का चोकर व सूखा भूसा'
      ],
      preparation: '60 ग्राम सोडियम एसिड फास्फेट पाउडर को 500 ग्राम गुड़ के शरबत में घोलें।',
      application: '1. तैयार फास्फोरस व गुड़ का शरबत दिन में 2 बार नाल से पिलाएं। 2. हरा बरसीम खिलाना तुरंत बंद कर दें। 3. गेहूं का चोकर (जिसमें प्राकृतिक फास्फोरस प्रचुर होता है) खिलाएं।',
      precautions: [
        'हरा बरसीम और सरसों की पत्तियां तुरंत बंद करें।',
        'पशु को किसी भी प्रकार की दौड़-भाग न कराएं।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा सोडियम एसिड फास्फेट (Urimin / Tonophosphan) 60 ग्राम का 10% घोल बनाकर IV नस में चढ़ाना, साथ में 60 ग्राम चमड़ी के नीचे।',
      ivFluids: 'यदि हीमोग्लोबिन बहुत कम हो तो स्वस्थ पशु का ताजा रक्त चढ़ाना (Blood Transfusion 3-4 लीटर)।',
      supportiveTherapy: 'आयरन डेक्सट्रान, विटामिन बी12 और कॉपर-कोबाल्ट खनिज सप्लीमेंट।'
    },
    suggestedMedicines: [
      {
        molecule: 'Sodium Acid Phosphate Injection',
        tradeNames: ['Tonophosphan', 'Urimin', 'Phospha-Vet'],
        dosage: '20 - 30 मिली IV और 20 मिली SC (दैनिक 3-4 दिन)',
        route: 'IV / SC',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'फास्फोरस की कमी को दूर कर लाल पेशाब को 24 घंटे में बंद करता है।'
      },
      {
        molecule: 'Sodium Acid Phosphate Oral Powder',
        tradeNames: ['Urimin Powder', 'Phos-Care', 'P-Sol'],
        dosage: '60 ग्राम पाउडर सुबह-शाम 5 दिन तक गुड़ में मिलाकर दें',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'रक्त में फास्फोरस का स्तर बनाए रखता है।'
      },
      {
        molecule: 'Iron Dextran + Vit B12',
        tradeNames: ['Feritas', 'Belamyl'],
        dosage: '10 मिली गहरा IM',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'टूटे हुए हीमोग्लोबिन की जगह नया खून बनाता है।'
      }
    ],
    prevention: {
      vaccineName: 'खनिज मिश्रण प्रबंधन',
      vaccineSchedule: 'प्रतिदिन 50 ग्राम एग्रीमिन फोर्ट या चेलैटेड मिनरल मिक्सर (Chelated Mineral Mixture) दाने में मिलाकर खिलाएं।',
      biosecurity: [
        'बरसीम के साथ हमेशा गेहूं का चोकर व फास्फोरस युक्त दाना दें।',
        'ब्याने के बाद दूध देने वाली भैंसों के आहार में कैल्शियम व फास्फोरस का अनुपात 2:1 रखें।'
      ]
    }
  },

  // 12. Retained Fetal Membranes (ROP)
  {
    id: 'retained-placenta',
    name: 'Retained Fetal Membranes (ROP)',
    hindiName: 'जेर का रुकना (जेर न गिरना / आंवल न पड़ना)',
    scientificName: 'Retained Placenta (Failure of detachment > 12 hours post-calving)',
    category: 'reproductive',
    categoryHindi: 'प्रजनन / प्रसव संबंधी',
    animalTypes: ['cow', 'buffalo'],
    severity: 'urgent',
    severityHindi: 'तत्काल देखभाल (12-24 घंटे)',
    symptoms: {
      primary: [
        'ब्याने के 8 से 12 घंटे बाद भी जेर (Placenta) का बाहर न गिरना',
        'योनि से जेर के टुकड़े या झिल्ली बाहर लटकते रहना',
        'योनि से अत्यधिक बदबूदार सड़ा हुआ मटमैला पानी गिरना',
        'पशु द्वारा बार-बार पूंछ उठाना व पेट में जोर लगाना'
      ],
      secondary: [
        'हल्का बुखार (103°F) व भूख कम होना',
        'दूध उत्पादन में अचानक गिरावट',
        'गर्भाशय में संक्रमण (मेट्राइटिस) होकर बांझपन का खतरा'
      ],
      vitals: {
        temperatureF: '101.5°F - 103.5°F (संक्रमण होने पर)',
        heartRateBpm: '70 - 85 bpm',
        respirationRateBpm: '20 - 30 bpm',
        rumenMotility: '1-2 प्रति 2 मिनट'
      }
    },
    testingMethods: {
      onFarmTest: 'ब्याने के 12 घंटे बाद योनि के बाहर जेर का लटकना या बच्चेदानी में फंसा होना।',
      clinicalLabTest: 'योनि परीक्षण (Per-Vaginal examination) द्वारा बंद गर्भाशय ग्रीवा व जेर की स्थिति देखना।',
      differentialDiagnosis: 'गर्भाशय भ्रंश (Prolapse), गर्भाशय का फटना, अधूरा प्रसव (अंदर दूसरा मृत बछड़ा होना)।'
    },
    goldenHourTiming: {
      criticalWindow: 'पहले 12 से 24 घंटे! कभी भी जेर को जबरदस्ती हाथ से न खींचे। प्राकृतिक गर्भाशय संकुचन प्रेरित करें।',
      seasonalPeak: 'गर्मियां व विटामिन ई-सेलेनियम की कमी वाले क्षेत्रों में अधिक।',
      consequenceOfDelay: 'गर्भाशय में सेप्टिक मेट्राइटिस, खून में जहर फैलना और स्थायी बांझपन।'
    },
    firstAid: {
      ingredients: [
        'पुराना गुड़ - 250 ग्राम',
        'अजवाइन - 25 ग्राम',
        'सोंठ पाउडर - 25 ग्राम',
        'हल्दी - 25 ग्राम',
        'मेथी दाना - 50 ग्राम'
      ],
      preparation: 'गुड़, अजवाइन, सोंठ, मेथी और हल्दी को 2 लीटर पानी में 10 मिनट उबालकर काढ़ा बनाएं।',
      application: '1. तैयार गुनगुना काढ़ा ब्याने के तुरंत बाद और 12 घंटे बाद पिलाएं (यह गर्भाशय को प्राकृतिक रूप से सिकोड़कर जेर गिराता है)। 2. लटकती हुई जेर को साफ धागे से बांधकर घुटने के ऊपर तक काट दें ताकि उस पर पैर न पड़े। 3. जेर पर 50 ग्राम का कोई हल्का वजन (जैसे ईंट का छोटा टुकड़ा) बांध सकते हैं।',
      precautions: [
        '🚨 सख्त चेतावनी: जेर को कभी भी हाथ से जबरन न खींचें! जबरदस्ती खींचने से बच्चेदानी के फूल (Caruncles) छिल जाते हैं, भारी रक्तस्राव होता है और गाय हमेशा के लिए बांझ हो जाती है।',
        'गिरे हुए जेर को कभी भी गाय को न खाने दें (यह गले में फंसकर या अपच करके जानलेवा हो सकता है)। इसे जमीन में गहरा गाड़ें।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा पीजीएफ2-अल्फा (PGF2alpha) इंजेक्शन 2 मिली IM या ऑक्सीटोसिन (यदि ब्याने के 24 घंटे के भीतर हो)।',
      ivFluids: 'यदि बुखार व सुस्ती हो तो 5% डेक्सट्रोज सेलाइन 2 लीटर IV।',
      supportiveTherapy: 'गर्भाशय के अंदर एंटीबैक्टीरियल बोलस (Cleanex / Furea) रखना और सिस्टेमिक सेफ्टियोफर एंटीबायोटिक।'
    },
    suggestedMedicines: [
      {
        molecule: 'Herbal Uterine Cleanser Liquid',
        tradeNames: ['Exapar Liquid', 'Utrasafe', 'Replanta', 'Involon'],
        dosage: '100 मिली सुबह-शाम 3 से 5 दिन तक',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'गर्भाशय की गंदगी व जेर के अवशेषों को पूरी तरह साफ करता है।'
      },
      {
        molecule: 'Cloprostenol (PGF2alpha)',
        tradeNames: ['Pragma', 'Vetmate', 'Lutalyse'],
        dosage: '2 मिली गहरा IM (ब्याने के 24 से 36 घंटे बाद)',
        route: 'IM',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '1 दिन',
        prescriptionRequired: true,
        notes: 'गर्भाशय ग्रीवा को खोलकर जेर व मवाद को बाहर फेंकता है।'
      },
      {
        molecule: 'Intrauterine Antibacterial Bolus',
        tradeNames: ['Cleanex Bolus', 'Furea', 'Metricare'],
        dosage: '2 से 4 बोलस गर्भाशय के अंदर रखना (पशु चिकित्सक द्वारा)',
        route: 'Other',
        milkWithdrawal: '48 घंटे',
        meatWithdrawal: '7 दिन',
        prescriptionRequired: true,
        notes: 'बच्चेदानी में सड़न व बदबूदार मवाद बनने से रोकता है।'
      }
    ],
    prevention: {
      vaccineName: 'गर्भावधि पोषण प्रबंधन',
      vaccineSchedule: 'ब्याने से 1 माह पूर्व विटामिन ई + सेलेनियम (E-Care Se) का इंजेक्शन लगाएं।',
      biosecurity: [
        'ब्याने के बाद कैल्शियम की कमी (मिल्क फीवर) न होने दें।',
        'प्रसव कक्ष को सूखा, साफ व चूना छिड़का हुआ रखें।'
      ]
    }
  },

  // 13. Uterine & Vaginal Prolapse
  {
    id: 'uterine-prolapse',
    name: 'Uterine / Vaginal Prolapse (Eversion)',
    hindiName: 'फूल/पिछा दिखाना (पांछा निकलना / बच्चेदानी का बाहर आना)',
    scientificName: 'Complete Uterine / Incomplete Vaginal Prolapse',
    category: 'reproductive',
    categoryHindi: 'प्रजनन / आपातकालीन',
    animalTypes: ['buffalo', 'cow'],
    severity: 'emergency',
    severityHindi: 'अति-आपातकालीन (0-2 घंटे)',
    symptoms: {
      primary: [
        'योनि के बाहर लाल रंग का फुटबॉल जैसा चिकना गोला (योनि भ्रंश) निकलना',
        'या ब्याने के बाद पूरी बच्चेदानी का उल्टा होकर बाहर लटकना जिस पर लाल-भूरे बटन (Cotyledons) लगे हों',
        'पशु का लगातार पीछे की ओर जोर लगाना (Severe Straining)',
        'पशु का बेचैन होकर बैठना व पेशाब रुकना'
      ],
      secondary: [
        'बाहर निकले अंग का सूखना, धूल-मिट्टी लगना और खून बहना',
        'कौवों, कुत्तों या मक्खियों द्वारा नोचे जाने का खतरा',
        'पेशाब की थैली मुड़ जाने से पेशाब का पूर्ण बंद होना'
      ],
      vitals: {
        temperatureF: '100.5°F - 102.5°F',
        heartRateBpm: '85 - 110 bpm (तनाव व दर्द से तेज)',
        respirationRateBpm: '25 - 40 bpm',
        rumenMotility: '1 प्रति 2 मिनट'
      }
    },
    testingMethods: {
      onFarmTest: 'योनि से बाहर लाल मांस का बड़ा गोला लटकना; यदि उस पर मशरूम जैसे बटन (Cotyledons) हैं तो यह पूरी बच्चेदानी (Uterine prolapse) है।',
      clinicalLabTest: 'शारीरिक दृश्य परीक्षण एवं योनि ग्रीवा की स्थिति।',
      differentialDiagnosis: 'योनि का ट्यूमर, गर्भाशय का सिस्ट, हीमेटोमा।'
    },
    goldenHourTiming: {
      criticalWindow: 'पहले 0 से 2 घंटे! जब तक अंग ताजा, नम व गुलाबी है, उसे आसानी से अंदर चढ़ाया जा सकता है। सूखने व सूजने के बाद चढ़ाना अत्यंत कठिन होता है।',
      seasonalPeak: 'ब्याने के अंतिम माह में (योनि भ्रंश) व ब्याने के 24-48 घंटे के भीतर (गर्भाशय भ्रंश) - विशेष रूप से भैंसों में।',
      consequenceOfDelay: 'अंग में गैंग्रीन, सेप्सिस, पेशाब की थैली फटना और 12 घंटे में मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'साफ सूती चादर या कपड़ा',
        'पोटैशियम परमैंगनेट (हल्का लाल दवा का पानी) या ठंडा पानी',
        'पीसी हुई चीनी (Sugar) या बर्फ की थैली',
        'पुआल के बंडल (पिछला हिस्सा ऊंचा करने हेतु)'
      ],
      preparation: 'चादर को ठंडे लाल दवा के पानी में भिगो लें।',
      application: '1. बाहर निकले अंग को तुरंत साफ भीगी चादर से पूरी तरह ढक दें ताकि उस पर धूल, मक्खी व कौवे न लगें। 2. पशु का पिछला हिस्सा पुआल की बोरियों पर रखकर 1 फीट ऊंचा करें ताकि जोर कम लगे। 3. यदि अंग बहुत सूज गया हो तो उस पर चीनी या बर्फ छिड़कें (चीनी पानी सोखकर सूजन को आधा कर देती है)। 4. तुरंत डॉक्टर को बुलाएं।',
      precautions: [
        '🚨 बाहर निकले अंग को कभी भी बिना धोए या जमीन पर घिसटने न दें।',
        'जबरदस्ती अंगूठे गड़ाकर अंदर न ठूंसें, इससे बच्चेदानी फट सकती है और जानलेवा रक्तस्राव हो सकता है।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा एपिड्यूरल एनेस्थीसिया (Epidural Anesthesia - 2% Lignocaine 5 मिली रीढ़ की हड्डी में) देकर जोर बंद करना, अंग को धोकर सावधानीपूर्वक अंदर बैठाना और ब्यूहनर सुचर (Buhner Suture) या रस्सी का पांछा बांधना।',
      ivFluids: 'कैल्शियम बोरो ग्लूकोनेट (Mifex 450 ml IV) क्योंकि कैल्शियम की कमी से गर्भाशय की टोन खत्म होती है।',
      supportiveTherapy: 'एंटीबायोटिक (Ceftiofur 1g IM) और दर्द निवारक (Meloxicam 15 ml IM)।'
    },
    suggestedMedicines: [
      {
        molecule: 'Lignocaine Hydrochloride 2%',
        tradeNames: ['Xylocaine 2%', 'Lox 2%'],
        dosage: '5 - 7 मिली एपिड्यूरल इंजेक्शन (पशु चिकित्सक द्वारा)',
        route: 'Other',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'पशु के पीछे का जोर लगाना 15 मिनट में बंद करता है ताकि अंग चढ़ाया जा सके।'
      },
      {
        molecule: 'Calcium Borogluconate 25%',
        tradeNames: ['Mifex', 'Calborol'],
        dosage: '450 मिली IV धीमी गति से',
        route: 'IV',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: true,
        notes: 'मांसपेशियों को ताकत देता है जिससे अंग दुबारा बाहर न आए।'
      },
      {
        molecule: 'Herbal Prolapse Powders',
        tradeNames: ['Prolap-Care', 'Pro-Fix', 'Uterotone'],
        dosage: '50 ग्राम प्रतिदिन 10 दिन तक',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'पेल्विक लिगामेंट्स को मजबूत करने में सहायक।'
      }
    ],
    prevention: {
      vaccineName: 'बाड़े का ढलान प्रबंधन',
      vaccineSchedule: 'बाड़े के फर्श को पीछे की ओर गहरा ढलान न दें; पशु का पिछला हिस्सा हमेशा थोड़ा ऊंचा रखें।',
      biosecurity: [
        'गर्भवती पशु को संतुलित खनिज मिश्रण व पर्याप्त कैल्शियम दें।',
        'अधिक जोर लगाने वाले पशु को तुरंत डॉक्टर को दिखाएं।'
      ]
    }
  },

  // 14. Fascioliasis (Liver Fluke)
  {
    id: 'fascioliasis-liver-fluke',
    name: 'Fascioliasis (Liver Fluke Disease)',
    hindiName: 'लिवर फ्लूक (यकृत कृमि / गलसुआ / पित्त की नाली के कीड़े)',
    scientificName: 'Fasciola gigantica / Fasciola hepatica',
    category: 'parasitic',
    categoryHindi: 'परजीवी जनित (आंतरिक कृमि)',
    animalTypes: ['buffalo', 'cow', 'calf', 'heifer'],
    severity: 'moderate',
    severityHindi: 'मध्यम / पुराना रोग (नियमित डीवर्मिंग)',
    symptoms: {
      primary: [
        'निचले जबड़े के नीचे पानी जैसी नर्म, बिना दर्द वाली सूजन आना (बॉटल जॉ - Bottle Jaw)',
        'यह सूजन रात में बढ़ जाती है और दिन में थोड़ा कम हो जाती है',
        'पशु का लगातार सूखना, पसलियां दिखना व दूध आधा रह जाना',
        'पुराना पतला दस्त या रुक-रुक कर कब्ज होना'
      ],
      secondary: [
        'आंखों की झिल्ली बिल्कुल सफेद व पीली होना (गंभीर रक्तहीनता)',
        'बाल रूखे, बेजान व आसानी से टूटने वाले होना',
        'लिवर सिरोसिस होने से पशु की धीरे-धीरे मृत्यु'
      ],
      vitals: {
        temperatureF: '101.0°F - 102.5°F (सामान्य)',
        heartRateBpm: '70 - 85 bpm',
        respirationRateBpm: '20 - 30 bpm',
        rumenMotility: '1 प्रति 2 मिनट (सुस्त)'
      }
    },
    testingMethods: {
      onFarmTest: 'निचले जबड़े के नीचे दबाने पर पानी जैसी सूजन (Bottle Jaw) और दलदली/नहर किनारे चराने का इतिहास।',
      clinicalLabTest: 'गोबर की जांच (Sedimentation technique): माइक्रोस्कोप में सुनहरे पीले रंग के बड़े ढक्कनदार अंडे (Operculated fluke eggs) दिखना।',
      differentialDiagnosis: 'पेट के गोल कृमि (Amphistomiasis), जोन्स रोग (Johne\'s Disease - JD), कुपोषण।'
    },
    goldenHourTiming: {
      criticalWindow: 'मानसून के तुरंत बाद और वसंत में रूटीन डीवर्मिंग! जबड़े के नीचे सूजन आने का अर्थ है कि लिवर 50% से अधिक खराब हो चुका है।',
      seasonalPeak: 'नहरों, तालाबों व जलभराव वाले क्षेत्रों में बरसात के बाद (अक्टूबर से मार्च) जब घोंघे (Snails) परजीवी फैलाते हैं।',
      consequenceOfDelay: 'लिवर का पूरी तरह फाइब्रोसिस होना व अत्यधिक खून की कमी से मृत्यु।'
    },
    firstAid: {
      ingredients: [
        'पशु को नहर/तालाब के किनारे चराने से रोकना',
        'गुड़ (100 ग्राम) + लोहे का सप्लीमेंट',
        'डीवर्मिंग दवा (Oxyclozanide / Triclabendazole)'
      ],
      preparation: 'पशु को सूखे बाड़े में रखें और सूखा चारा दें।',
      application: '1. पशु को तालाब, पोखर या जलकुंभी वाली जगहों से दूर रखें। 2. तुरंत पशु चिकित्सक द्वारा सुझाई गई लिवर फ्लूक की पेट के कीड़े वाली दवा खाली पेट पिलाएं। 3. दवा देने के 3 दिन बाद से लिवर टॉनिक शुरू करें।',
      precautions: [
        'साधारण एल्बेंडाजोल (Albendazole) लिवर फ्लूक पर पूरी तरह काम नहीं करती, विशेष फ्लुकिसाइड दवा ही दें।',
        'गर्भवती पशु को दवा देने से पहले पशु चिकित्सक से पुष्टि करें।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'पशु चिकित्सक द्वारा ट्राइक्लाबेन्डाजोल (Triclabendazole 12 mg/kg) या ऑक्सीक्लोजानाइड (Oxyclozanide 10-15 mg/kg) ओरल सस्पेंशन देना।',
      ivFluids: 'गंभीर कमजोरी में 5% डेक्सट्रोज व अमीनो एसिड इन्फ्यूजन।',
      supportiveTherapy: 'आयरन इंजेक्शन (Feritas 10 ml IM) और लिवर टॉनिक (Brotone 50 ml oral 15 दिन तक)।'
    },
    suggestedMedicines: [
      {
        molecule: 'Oxyclozanide + Levamisole',
        tradeNames: ['Zanil', 'Distodin', 'Levafuke', 'Nilzan'],
        dosage: '90 - 100 मिली की बोतल खाली पेट मुंह से (400 किग्रा पशु हेतु)',
        route: 'Oral',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '14 दिन',
        prescriptionRequired: true,
        notes: 'वयस्क लिवर फ्लूक और पेट के कीड़ों को पूरी तरह साफ करता है।'
      },
      {
        molecule: 'Triclabendazole',
        tradeNames: ['Fasken', 'Fasinex', 'Flukex'],
        dosage: '10 मिली प्रति 100 किग्रा शरीर भार',
        route: 'Oral',
        milkWithdrawal: '72 घंटे',
        meatWithdrawal: '28 दिन',
        prescriptionRequired: true,
        notes: 'कच्चे (Immature) और पक्के दोनों तरह के लिवर फ्लूक को मारता है।'
      },
      {
        molecule: 'Liver Extract Tonic',
        tradeNames: ['Brotone', 'Liv-52 Protec', 'Belamyl'],
        dosage: '50 मिली प्रतिदिन 15 से 20 दिन तक दाने में',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'क्षतिग्रस्त यकृत (Liver) की मरम्मत कर भूख व दूध बढ़ाता है।'
      }
    ],
    prevention: {
      vaccineName: 'रणनीतिक डीवर्मिंग कैलेंडर',
      vaccineSchedule: 'वर्ष में 2 बार (मानसून से पहले मई में और मानसून के बाद अक्टूबर-नवंबर में) डीवर्मिंग कराएं।',
      biosecurity: [
        'तालाबों व जलभराव में घोंघों (Snails) के नियंत्रण हेतु कॉपर सल्फेट (नीला थोथा) का हल्का छिड़काव या बत्तख पालन करें।',
        'तालाब के किनारे की ताजी घास काटकर तुरंत न खिलाएं।'
      ]
    }
  },

  // 15. Calf Scours (Colibacillosis)
  {
    id: 'calf-scours',
    name: 'Calf Scours (Colibacillosis / Calf Diarrhea)',
    hindiName: 'बछड़े का सफेद दस्त (सफेद हगना / नवजात दस्त)',
    scientificName: 'Enterotoxigenic E. coli (ETEC) / Rotavirus / Coronavirus',
    category: 'bacterial',
    categoryHindi: 'जीवाणु/विषाणु (नवजात बछड़ा)',
    animalTypes: ['calf'],
    severity: 'emergency',
    severityHindi: 'आपातकालीन (0-4 घंटे)',
    symptoms: {
      primary: [
        '1 से 30 दिन के नवजात बछड़े को पतला, सफेद, पीला या मटमैला बदबूदार दस्त होना',
        'बछड़े की आंखें अंदर गड्ढे में धंस जाना (Sunken Eyes - गंभीर निर्जलीकरण)',
        'कान, मुंह और थूथन बिल्कुल ठंडे पड़ना',
        'दूध पीने से पूरी तरह मना करना व खड़े न हो पाना'
      ],
      secondary: [
        'चमड़ी की लचक खत्म होना (Skin tenting > 3 सेकंड)',
        'शरीर का तापमान 100°F से नीचे गिरना',
        'अम्लरक्तता (Acidosis) और कोमा से 24 घंटे में मृत्यु'
      ],
      vitals: {
        temperatureF: '98.5°F - 101.5°F (गंभीर स्थिति में सामान्य से कम)',
        heartRateBpm: '100 - 140 bpm',
        respirationRateBpm: '35 - 55 bpm',
        rumenMotility: 'लागू नहीं (रूमेन अविकसित)'
      }
    },
    testingMethods: {
      onFarmTest: 'स्किन टेंट टेस्ट (Skin Tent Test): गर्दन की चमड़ी को ऊपर खींचकर छोड़ें; यदि चमड़ी तुरंत वापस न जाकर 3 सेकंड तक मुड़ी रहे, तो बछड़ा 8-10% डिहाइड्रेट है और जीवन खतरे में है।',
      clinicalLabTest: 'दस्त के नमूने का एलिसा या पीसीआर (रोटावायरस/ई.कोलाई टॉक्सिन पहचान)।',
      differentialDiagnosis: 'कोक्सीडियोसिस (खूनी दस्त), साल्मोनेलोसिस, अत्यधिक दूध पिलाना (Nutritional scours)।'
    },
    goldenHourTiming: {
      criticalWindow: 'पहले 0 से 4 घंटे! बछड़ा संक्रमण से नहीं बल्कि पानी और नमक की कमी (Dehydration) से मरता है। तुरंत ओआरएस घोल शुरू करें।',
      seasonalPeak: 'सर्दियों का मौसम व गंदे गीले प्रसव बाड़े।',
      consequenceOfDelay: '12-24 घंटे के अंदर हाइपोवोलेमिक शॉक से बछड़े की मौत।'
    },
    firstAid: {
      ingredients: [
        'ओआरएस पैकेट (ORS) या घरेलू इलेक्ट्रोलाइट घोल:',
        '1 लीटर उबला व ठंडा किया हुआ पानी',
        '2 चम्मच ग्लूकोज या चीनी',
        'आधा चम्मच सादा नमक',
        'आधा चम्मच मीठा सोडा (Baking Soda)'
      ],
      preparation: '1 लीटर गुनगुने पानी में चीनी, नमक व मीठा सोडा घोलकर जीवनरक्षक ओआरएस तैयार करें।',
      application: '1. तैयार ओआरएस घोल 1 से 2 लीटर दिन में 3-4 बार बछड़े को बोतल या कटोरी से पिलाएं। 2. बछड़े को मां का दूध 12 घंटे बाद थोड़ा-थोड़ा दें (दूध पूरी तरह कई दिनों तक बंद न करें)। 3. बछड़े को सूखी पुआल पर रखें व कंबल से ढकें।',
      precautions: [
        '🚨 केवल एंटीबायोटिक गोली खिलाने से बछड़ा नहीं बचेगा, जब तक शरीर में पानी व इलेक्ट्रोलाइट नहीं जाएगा।',
        'ठंडे पानी से ओआरएस न बनाएं, हमेशा गुनगुना दें।'
      ]
    },
    secondaryAid: {
      clinicalProtocol: 'यदि बछड़े की आंखें बहुत धंस चुकी हों और वह खड़ा न हो पा रहा हो, तो पशु चिकित्सक द्वारा रिंगर्स लैक्टेट (RL) या डेक्सट्रोज नॉर्मल सेलाइन 1 से 2 लीटर IV नस में तुरंत चढ़ाना।',
      ivFluids: 'रिंगर्स लैक्टेट + 5% डेक्सट्रोज IV।',
      supportiveTherapy: 'एमोक्सिसिलिन-क्लैवुलैनिक एसिड या एनरोफ्लोक्सासिन ओरल सिरप और काओलिन-पेक्टिन आंत सुरक्षा हेतु।'
    },
    suggestedMedicines: [
      {
        molecule: 'Oral Electrolyte Sachets (ORS)',
        tradeNames: ['Intalyte', 'Electral', 'Calf-Lyte'],
        dosage: '1 पैकेट 2 लीटर गुनगुने पानी में घोलकर दिन में 3 बार पिलाएं',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'बछड़े के दस्त का नंबर 1 जीवनरक्षक उपचार।'
      },
      {
        molecule: 'Herbal Anti-Diarrheal Powder / Bolus',
        tradeNames: ['Neblon Powder', 'Diaroak', 'Biotrim-DS'],
        dosage: '15 ग्राम पाउडर दिन में 2 बार चावल के मांड में मिलाकर दें',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '0 दिन',
        prescriptionRequired: false,
        notes: 'आंतों की सूजन शांत कर दस्त तुरंत बांधता है।'
      },
      {
        molecule: 'Enrofloxacin Oral Solution',
        tradeNames: ['Baytril 10%', 'Enrocin Oral'],
        dosage: '2.5 - 5 mg/kg शरीर भार (3-5 मिली ओरल)',
        route: 'Oral',
        milkWithdrawal: '0 घंटे',
        meatWithdrawal: '14 दिन',
        prescriptionRequired: true,
        notes: 'ई.कोलाई और साल्मोनेला जीवाणुओं को नष्ट करता है।'
      }
    ],
    prevention: {
      vaccineName: 'खीस (Colostrum) प्रबंधन',
      vaccineSchedule: 'जन्म के पहले 2 घंटे के भीतर बछड़े को उसके वजन का 10% (लगभग 2-3 लीटर) मां का पहला गाढ़ा खीस अनिवार्य रूप से पिलाएं!',
      biosecurity: [
        'खीस में मां की रोग प्रतिरोधक एंटीबॉडीज होती हैं जो बछड़े को 3 महीने तक सभी रोगों से बचाती हैं।',
        'नाभि को जन्म के तुरंत बाद 2% टिंचर आयोडीन में डुबोएं।'
      ]
    }
  }
];
