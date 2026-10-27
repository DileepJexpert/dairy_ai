import { Hono } from 'hono';
import { HTTPException } from 'hono/http-exception';
import { z } from 'zod';
import type { Env } from '../types/env.js';
import { requireAuth } from './commerce.js';
import { getFarmerByUserId } from './farmers.js';

export const aiChatRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

const TriageRequestSchema = z.object({
  cattle_id: z.string().min(1),
  symptoms: z.string().min(3).max(2000),
  photo_urls: z.array(z.string()).optional(),
});

const ChatMessageSchema = z.object({
  message: z.string().optional(),
  content: z.string().optional(),
  cattle_id: z.string().optional(),
  language: z.string().optional(),
  channel: z.string().optional(),
});

// ---------------------------------------------------------------------------
// Clinical Triage Scoring Engine (Rule-based Expert System)
// ---------------------------------------------------------------------------

export interface TriageResult {
  severity: number; // 1-10
  severity_level: 'low' | 'medium' | 'high' | 'emergency';
  preliminary_diagnosis: string;
  confidence: number;
  recommended_action: 'self_care' | 'schedule_visit' | 'video_consult' | 'emergency';
  reasoning: string;
}

export function evaluateTriage(
  symptoms: string,
  sensorData?: { temperature?: number | null; heart_rate?: number | null; activity_level?: number | null } | null
): TriageResult {
  let score = 0;
  const reasons: string[] = [];

  // 1. Evaluate Sensor Data
  if (sensorData) {
    const temp = sensorData.temperature;
    const hr = sensorData.heart_rate;
    const activity = sensorData.activity_level;

    if (temp && temp > 40.0) {
      score += 3;
      reasons.push(`High fever (${temp}°C)`);
    } else if (temp && temp > 39.5) {
      score += 2;
      reasons.push(`Elevated body temperature (${temp}°C)`);
    }

    if (hr && hr > 80) {
      score += 2;
      reasons.push(`High heart rate (${hr} bpm)`);
    }

    if (activity !== null && activity !== undefined && activity < 20) {
      score += 2;
      reasons.push(`Very low physical activity (${activity})`);
    }
  }

  // 2. Keyword Symptom Scoring
  const sLower = symptoms.toLowerCase();
  const keywords: Record<string, number> = {
    'down': 4, 'collapsed': 4, 'cannot stand': 4,
    'bloat': 3, 'bloated': 3,
    'mastitis': 3, 'udder': 2, 'swollen udder': 3,
    'blood': 3, 'bleeding': 3,
    'not eating': 2, 'off feed': 2, 'no appetite': 2,
    'fever': 2, 'shivering': 2,
    'swelling': 2, 'discharge': 2,
    'diarrhea': 2, 'loose motion': 2,
    'limping': 1, 'lame': 1,
    'cough': 1, 'coughing': 1,
  };

  for (const [kw, pts] of Object.entries(keywords)) {
    if (sLower.includes(kw)) {
      score += pts;
      reasons.push(`Reported symptom: ${kw}`);
    }
  }

  // 3. Preliminary Clinical Diagnosis Mapping
  let preliminaryDiagnosis = 'General observation needed';
  if (sLower.includes('bloat') || sLower.includes('bloated')) {
    preliminaryDiagnosis = 'Acute Ruminal Tympany (Bloat)';
  } else if (sLower.includes('mastitis') || sLower.includes('udder')) {
    preliminaryDiagnosis = 'Bovine Clinical Mastitis';
  } else if (score >= 4 && (sLower.includes('fever') || (sensorData?.temperature && sensorData.temperature > 39.5))) {
    preliminaryDiagnosis = 'Bovine Ephemeral Fever / Systemic Infection';
  } else if (sLower.includes('limp') || sLower.includes('lame')) {
    preliminaryDiagnosis = 'Foot Rot / Locomotor Lameness';
  } else if (sLower.includes('down') || sLower.includes('collapsed')) {
    preliminaryDiagnosis = 'Downer Cow Syndrome / Hypocalcemia (Milk Fever)';
  }

  // 4. Severity Level & Recommended Action
  const severity = Math.min(10, Math.max(1, score));
  let severityLevel: 'low' | 'medium' | 'high' | 'emergency';
  let recommendedAction: 'self_care' | 'schedule_visit' | 'video_consult' | 'emergency';

  if (severity >= 7) {
    severityLevel = 'emergency';
    recommendedAction = 'emergency';
  } else if (severity >= 5) {
    severityLevel = 'high';
    recommendedAction = 'video_consult';
  } else if (severity >= 3) {
    severityLevel = 'medium';
    recommendedAction = 'schedule_visit';
  } else {
    severityLevel = 'low';
    recommendedAction = 'self_care';
  }

  return {
    severity,
    severity_level: severityLevel,
    preliminary_diagnosis: preliminaryDiagnosis,
    confidence: score > 3 ? 0.85 : 0.70,
    recommended_action: recommendedAction,
    reasoning: reasons.length > 0 ? reasons.join('; ') : 'Routine physical checkup recommended',
  };
}

// ---------------------------------------------------------------------------
// 1. Symptom Triage Endpoint
// ---------------------------------------------------------------------------

aiChatRouter.post('/triage', async (c) => {
  const user = await requireAuth(c);
  const db = c.env.DB;

  const farmer = await getFarmerByUserId(db, user.id);
  if (!farmer) {
    throw new HTTPException(404, { message: 'Farmer profile not found' });
  }

  const body = await c.req.json().catch(() => null);
  const parsed = TriageRequestSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid triage request details' });
  }

  const cattle = (await db.prepare('SELECT id, name, breed FROM cattle WHERE id = ? AND farmer_id = ?').bind(parsed.data.cattle_id, farmer.id).first()) as any;
  if (!cattle) {
    throw new HTTPException(404, { message: 'Cattle not found' });
  }

  // Fetch latest sensor reading if available
  const latestSensor = (await db.prepare(
    'SELECT temperature, heart_rate, activity_level FROM sensor_readings WHERE cattle_id = ? ORDER BY created_at DESC, rowid DESC LIMIT 1'
  ).bind(parsed.data.cattle_id).first()) as any;

  const result = evaluateTriage(parsed.data.symptoms, latestSensor);

  // Auto-record as an observation health record
  const recordId = crypto.randomUUID();
  const todayStr = new Date().toISOString().slice(0, 10);
  await db.prepare(
    `INSERT INTO health_records (id, cattle_id, date, record_type, symptoms, diagnosis, severity, notes)
     VALUES (?, ?, ?, 'observation', ?, ?, ?, ?)`
  ).bind(
    recordId,
    parsed.data.cattle_id,
    todayStr,
    parsed.data.symptoms.trim(),
    result.preliminary_diagnosis,
    result.severity,
    `AI Triage: ${result.reasoning}`
  ).run();

  return c.json({
    success: true,
    data: {
      health_record_id: recordId,
      cattle_name: cattle.name,
      severity: result.severity,
      severity_level: result.severity_level,
      preliminary_diagnosis: result.preliminary_diagnosis,
      confidence: result.confidence,
      recommended_action: result.recommended_action,
      reasoning: result.reasoning,
    },
    message: 'Triage complete',
  });
});

// ---------------------------------------------------------------------------
// 2. Kisan Sahayata Schemes Directory (Govt Subsidies & Schemes)
// ---------------------------------------------------------------------------

export const GOVT_SCHEMES = [
  {
    id: 'kcc_pashupalan',
    title: 'KCC Pashupalan (किसान क्रेडिट कार्ड - पशुपालन)',
    category: 'credit',
    max_amount: '₹2,00,000 (Collateral-Free)',
    interest_rate: '4% Effective p.a. (7% base minus 3% timely repayment incentive)',
    subsidy_rate: 'Interest subvention of 3%',
    badge: '4% Subsidized Loan',
    overview_hi: 'पशुपालकों को चारा, दाना व दैनिक खर्चों हेतु ₹2 लाख तक का बिना किसी बंधक (Security-free) ऋण 4% वार्षिक ब्याज पर मिलता है।',
    overview_en: 'Working capital credit up to ₹2 Lakh without collateral at 4% effective interest rate for feed, fodder, and maintenance.',
    eligibility_hi: [
      'दुधारू गाय या भैंस रखने वाले व्यक्तिगत किसान या पशुपालक',
      'स्वयं सहायता समूह (SHG) व दुग्ध उत्पादक सहकारी समिति सदस्य',
      'किराएदार या बटाईदार पशुपालक भी पात्र'
    ],
    eligibility_en: [
      'Individual farmers or cattle keepers with active dairy animals',
      'Members of Dairy Cooperative Societies & Women SHGs',
      'Tenant or sharecropper farmers'
    ],
    documents_hi: [
      'आधार कार्ड व पैन कार्ड',
      'बैंक पासबुक व 2 पासपोर्ट साइज फोटो',
      'दुग्ध सहकारी समिति का दुग्ध आपूर्ति प्रमाण पत्र या पशु संख्या प्रमाण'
    ],
    documents_en: [
      'Aadhaar card & PAN card',
      'Bank passbook & 2 passport photos',
      'Milk cooperative society supply certificate or livestock proof'
    ],
    application_guide: 'नजदीकी बैंक शाखा या दुग्ध समिति सचिव से KCC पशुपालन फॉर्म भरकर जमा करें।'
  },
  {
    id: 'rashtriya_gokul_mission',
    title: 'Rashtriya Gokul Mission (राष्ट्रीय गोकुल मिशन - नस्ल सुधार)',
    category: 'breeding',
    max_amount: '₹100/Sexed Semen Straw & ₹5,000 IVF Grant',
    interest_rate: 'N/A (Direct Subsidy)',
    subsidy_rate: 'Up to 90% Subsidy on High-Pedigree Semen',
    badge: '90%+ Female Calf Guarantee',
    overview_hi: 'देशी गोवंश (साहीवाल, गीर, थारपारकर) व मुर्रा भैंस के नस्ल सुधार हेतु मात्र ₹100 में बछिया पैदा करने वाला सॉर्टेड सीमेन।',
    overview_en: 'Breed improvement program providing sex-sorted semen at ~₹100/straw guaranteeing 90%+ female heifer calf births.',
    eligibility_hi: [
      'सभी देशी गाय व भैंस पालक किसान',
      'सक्रिय प्रजनन आयु की स्वस्थ गाय या भैंस'
    ],
    eligibility_en: [
      'All indigenous cow and buffalo rearers',
      'Healthy breedable females free of reproductive tract infections'
    ],
    documents_hi: [
      'पशु का ईयर टैग (INAPH 12-अंक)',
      'पशु स्वास्थ्य प्रमाण पत्र'
    ],
    documents_en: [
      '12-digit Pashu Aadhaar ear tag',
      'Basic reproductive health clearance'
    ],
    application_guide: 'निकटतम राजकीय पशु चिकित्सालय या एआई तकनीशियन से संपर्क कर सेक्स्ड सीमेन की मांग करें।'
  },
  {
    id: 'pashu_bima_yojana',
    title: 'Pashu Bima Yojana (पशुधन बीमा योजना - 70% सरकारी अंशदान)',
    category: 'insurance',
    max_amount: 'Market Value Coverage (Up to ₹80,000/Animal)',
    interest_rate: 'N/A',
    subsidy_rate: '70% for SC/ST/BPL & 50% for General Farmers',
    badge: 'Up to 70% Premium Subsidy',
    overview_hi: 'दूधारू गाय-भैंस की बीमारी, प्रसव जटिलता या आकस्मिक मृत्यु होने पर आर्थिक सुरक्षा। प्रीमियम पर सरकार 70% तक अनुदान देती है।',
    overview_en: 'Comprehensive livestock mortality insurance covering death due to diseases, accidents, and calving complications.',
    eligibility_hi: [
      'देशी, संकर गाय व दुधारू भैंसें',
      'प्रति परिवार अधिकतम 5 पशुओं का बीमा अनुमन्य'
    ],
    eligibility_en: [
      'Indigenous, crossbred cattle and milch buffaloes',
      'Maximum 5 animals per farmer household'
    ],
    documents_hi: [
      'पशु का 12 अंकों का कान का टैग',
      'सरकारी पशु चिकित्सा अधिकारी द्वारा जारी स्वास्थ्य व मूल्य प्रमाण पत्र',
      'बीपीएल / जाति प्रमाण पत्र (सब्सिडी हेतु)'
    ],
    documents_en: [
      '12-digit ear tag photo and number',
      'Health and valuation certificate from Govt Veterinary Officer',
      'BPL/Category certificate for enhanced 70% subsidy'
    ],
    application_guide: 'राजकीय पशु चिकित्सालय के डॉक्टर से संपर्क कर पशु का टैगिंग व बीमा फॉर्म भरवाएं।'
  },
  {
    id: 'national_livestock_mission',
    title: 'National Livestock Mission (राष्ट्रीय पशुधन मिशन - NLM)',
    category: 'subsidy',
    max_amount: 'Up to ₹50,00,000 Capital Subsidy',
    interest_rate: 'Bank-linked',
    subsidy_rate: '50% Capital Subsidy for Dairy & Fodder Units',
    badge: '50% Capital Grant',
    overview_hi: 'चारा साइलेज बैंक, टीएमआर पैलेट प्लांट व पशु नस्ल संवर्धन इकाई लगाने हेतु सरकार द्वारा 50% तक पूंजीगत अनुदान।',
    overview_en: '50% capital subsidy up to ₹50 Lakh for establishing silage making units, fodder banks, and breeding infrastructure.',
    eligibility_hi: [
      'व्यक्तिगत किसान, एफपीओ (FPO) व दुग्ध उद्यमी',
      'परियोजना हेतु पर्याप्त भूमि व जल स्रोत उपलब्ध हो'
    ],
    eligibility_en: [
      'Individual dairy farmers, FPOs, and livestock entrepreneurs',
      'Clear title land or long-term lease for fodder facility'
    ],
    documents_hi: [
      'विस्तृत परियोजना रिपोर्ट (DPR)',
      'जमीन का स्वामित्व दस्तावेज / लीज एग्रीमेंट',
      'बैंक ऋण स्वीकृति पत्र (In-principle sanction)'
    ],
    documents_en: [
      'Detailed Project Report (DPR)',
      'Land title or long-term registered lease deed',
      'In-principle bank loan sanction letter'
    ],
    application_guide: 'nlm.udyamimitra.in पोर्टल पर ऑनलाइन प्रोजेक्ट रिपोर्ट के साथ आवेदन करें।'
  }
];

aiChatRouter.get('/schemes', async (c) => {
  return c.json({
    success: true,
    data: GOVT_SCHEMES,
    message: 'Government schemes catalog retrieved'
  });
});

// ---------------------------------------------------------------------------
// 3. Pashu Mitra AI Farmer Chat Assistant (Bilingual Domain Intelligence)
// ---------------------------------------------------------------------------

aiChatRouter.post('/chat/message', async (c) => {
  let user: { id: string; role: string; phone: string; full_name: string } | null = null;
  try {
    user = await requireAuth(c);
  } catch {
    // Guest farmers permitted to chat with Pashu Mitra
  }
  const db = c.env.DB;

  const body = await c.req.json().catch(() => null);
  const parsed = ChatMessageSchema.safeParse(body);
  if (!parsed.success) {
    throw new HTTPException(422, { message: 'Invalid chat request structure' });
  }

  const queryText = (parsed.data.message || parsed.data.content || '').trim();
  if (!queryText) {
    throw new HTTPException(422, { message: 'Message cannot be empty' });
  }

  let cattleContext = '';
  if (parsed.data.cattle_id) {
    const cattle = (await db.prepare('SELECT name, breed, status, weight_kg FROM cattle WHERE id = ?').bind(parsed.data.cattle_id).first()) as any;
    if (cattle) {
      cattleContext = `Cattle: ${cattle.name || 'Unnamed'} (${cattle.breed}, Status: ${cattle.status}, Weight: ${cattle.weight_kg}kg). `;
    }
  }

  const msgLower = queryText.toLowerCase();
  const isHindi = parsed.data.language === 'hi' || /[\u0900-\u097F]/.test(queryText) || msgLower.includes('kcc') || msgLower.includes('yojana');

  let reply = '';

  // 1. Government Schemes & Subsidies
  if (msgLower.includes('kcc') || msgLower.includes('credit card') || msgLower.includes('क्रेडिट') || msgLower.includes('ऋण') || msgLower.includes('लोन')) {
    if (isHindi) {
      reply = `${cattleContext}🏛️ **पशुपालन किसान क्रेडिट कार्ड (KCC Pashupalan):**\n\n1. **लोन राशि:** ₹2,00,000 तक बिना किसी गारंटी/बंधक (Collateral-free)।\n2. **ब्याज दर:** केवल 4% प्रभावी वार्षिक (7% सामान्य ब्याज में 3% समय पर अदायगी छूट)।\n3. **उपयोग:** चारा, दाना, दवा, टीकाकरण व दैनिक डेयरी खर्चों हेतु।\n4. **पात्रता:** कोई भी किसान जो गाय या भैंस पालता हो (भूमिहीन पशुपालक भी पात्र)।\n5. **जरूरी दस्तावेज:** आधार कार्ड, पैन कार्ड, बैंक पासबुक और दुग्ध समिति/सरपंच द्वारा पशु सत्यापन प्रमाण।\n\n📌 **आवेदन कैसे करें:** अपने नजदीकी बैंक या स्थानीय दुग्ध सहकारी समिति सचिव से KCC पशुपालन आवेदन पत्र प्राप्त कर जमा करें।`;
    } else {
      reply = `${cattleContext}🏛️ **Kisan Credit Card (KCC) for Animal Husbandry:**\n\n1. **Credit Limit:** Up to ₹2,00,000 without collateral security.\n2. **Subsidized Interest:** Effective 4% per annum (7% regular minus 3% prompt repayment subvention).\n3. **Purpose:** Working capital for feed, green fodder, medicines, and breeding maintenance.\n4. **Eligibility:** All farmers owning milch cattle, buffaloes, or small ruminants (including landless farmers).\n5. **Documents:** Aadhaar, PAN, bank passbook, and certificate from village dairy cooperative.\n\n📌 **How to Apply:** Submit the simple 1-page KCC Animal Husbandry form at your local bank branch or dairy cooperative society.`;
    }
  } else if (msgLower.includes('gokul') || msgLower.includes('semen') || msgLower.includes('गोकुल') || msgLower.includes('बछिया') || msgLower.includes('सीमेन')) {
    if (isHindi) {
      reply = `${cattleContext}🧬 **राष्ट्रीय गोकुल मिशन (Rashtriya Gokul Mission):**\n\n1. **सेक्स्ड सीमेन सब्सिडी:** मात्र ₹100 में उच्च अनुवांशिक गुणवत्ता वाला सीमेन उपलब्ध है, जिससे 90%+ बछिया जन्म सुनिश्चित होता है।\n2. **देशी नस्ल संवर्धन:** साहीवाल, गीर, थारपारकर, राठी व मुर्रा भैंसों हेतु निःशुल्क कृत्रिम गर्भाधान (AI)।\n3. **IVF अनुदान:** उच्च दुग्ध उत्पादन क्षमता वाली बछिया तैयार करने पर ₹5,000 प्रति बछिया सरकारी प्रोत्साहन।\n\n📌 **लाभ लेने हेतु:** अपने ब्लॉक के राजकीय पशु चिकित्सालय या प्रशिक्षित मैत्री (MAITRI) कृत्रिम गर्भाधान तकनीशियन से संपर्क करें।`;
    } else {
      reply = `${cattleContext}🧬 **Rashtriya Gokul Mission (Breed Improvement & Sexed Semen):**\n\n1. **Sexed Sorted Semen:** Available at a subsidized price of ₹100/straw guaranteeing 90%+ female calf births.\n2. **Indigenous Germplasm:** Promotes purebred Sahiwal, Gir, Tharparkar, and Murrah lines.\n3. **IVF Grant:** Up to ₹5,000 government grant per heifer born through In-Vitro Fertilization (IVF) technology.\n\n📌 **How to Avail:** Request sexed sorted straws from your block veterinary dispensary or certified MAITRI AI technician.`;
    }
  } else if (msgLower.includes('bima') || msgLower.includes('insurance') || msgLower.includes('बीमा')) {
    if (isHindi) {
      reply = `${cattleContext}🛡️ **पशुधन बीमा योजना (Livestock Insurance Scheme):**\n\n1. **सरकारी सब्सिडी:** बीपीएल, एससी/एसटी वर्ग हेतु 70% सब्सिडी; सामान्य वर्ग हेतु 50% सब्सिडी। किसान को मात्र 30% या 50% प्रीमियम देना होता है।\n2. **कवरेज:** बीमारी, प्रसव जटिलता, करंट, आकाशीय बिजली या दुर्घटना से पशु की मृत्यु।\n3. **अवधि:** 1 वर्ष से 3 वर्ष तक की पॉलिसी।\n4. **क्लेम नियम:** पशु की मृत्यु होने पर 24 घंटे के अंदर टोल-फ्री नंबर पर सूचित करें और 12-अंकीय कान का टैग संभाल कर रखें। सरकारी डॉक्टर द्वारा पोस्टमार्टम रिपोर्ट अनिवार्य है।\n\n📌 **बीमा कैसे कराएं:** नजदीकी पशु अस्पताल के डॉक्टर से मिलकर पशु का ईयर-टैगिंग व स्वास्थ्य प्रमाण पत्र बनवाएं।`;
    } else {
      reply = `${cattleContext}🛡️ **Pashu Bima Yojana (Livestock Insurance Scheme):**\n\n1. **Premium Subsidy:** 70% subsidy for SC/ST/BPL farmers; 50% for general dairy farmers.\n2. **Risk Coverage:** Accidental death, epidemic diseases, surgical/calving shock, lightning, and electrocution.\n3. **Policy Term:** 1-year or 3-year term (covers current market valuation up to ₹80,000).\n4. **Claim Protocol:** Retain the 12-digit ear tag, notify within 24 hours, and obtain a mandatory post-mortem certificate from a government veterinary officer.\n\n📌 **Enrollment:** Contact your nearest government veterinary dispensary for ear tagging and valuation.`;
    }
  } else if (msgLower.includes('mastitis') || msgLower.includes('udder') || msgLower.includes('थनैला') || msgLower.includes('सूजन') || msgLower.includes('थन')) {
    if (isHindi) {
      reply = `${cattleContext}🚨 **थनैला (Mastitis) आपातकालीन प्राथमिक उपचार:**\n\n1. **तुरंत थन खाली करें:** प्रभावित थन का सारा मवाद या फटा दूध 2-2 घंटे के अंतराल पर पूरी तरह निकालें (इसे जमीन पर न फेंकें, बर्तन में लेकर नष्ट करें)।\n2. **सफाई व लेप:** थन को लाल दवा (पोटैशियम परमैंगनेट 1:1000) या गुनगुने फिटकरी पानी से धोएं। एलोवेरा + हल्दी का ताजा लेप लगाएं।\n3. **ठंडी सिकाई:** यदि अयन/थन बहुत गर्म व सूजा हुआ है, तो बर्फ या ठंडे पानी से सिकाई करें।\n4. **सावधानी:** इस दूध को कभी भी सामान्य दूध में न मिलाएं।\n\n⚠️ **महत्वपूर्ण:** थनैला जीवाणु संक्रमण है। तुरंत डॉक्टर से इंट्रा-मेमरी एंटीबायोटिक ट्यूब व सूजन रोधी इंजेक्शन लगवाएं। आप ऊपर 'Tele-Vet' से 1-क्लिक वीडियो परामर्श ले सकते हैं।`;
    } else {
      reply = `${cattleContext}🚨 **Bovine Mastitis Emergency Protocol:**\n\n1. **Frequent Stripping:** Completely strip out infected milk/clots from the affected quarter every 2 hours into a disposable container.\n2. **Teat Wash & Antisepsis:** Wash udder with potassium permanganate (1:1000) or povidone-iodine. Apply fresh turmeric + aloe vera paste.\n3. **Cold Compresses:** If udder is hot, swollen, or engorged, apply cold water or ice compresses.\n4. **Precaution:** Strictly DO NOT pool this milk into the bulk tank.\n\n⚠️ **Critical:** Mastitis requires immediate intramammary antibiotic infusion and anti-inflammatory therapy. Tap 'Tele-Vet' in the menu for instant video consultation with a certified bovine doctor.`;
    }
  } else if (msgLower.includes('bloat') || msgLower.includes('afara') || msgLower.includes('अफारा') || msgLower.includes('गैस') || msgLower.includes('पेट फूलना')) {
    if (isHindi) {
      reply = `${cattleContext}💨 **अफारा (Bloat / Acute Tympany) देसी घरेलू उपचार:**\n\n1. **देसी नुस्खा:** 200 मिली सरसों का तेल + 30 मिली तारपीन का तेल + 10 ग्राम हींग (गुनगुने पानी में घोलकर) नाल से तुरंत पिलाएं।\n2. **पशु को चलाएं:** पशु को ढलान पर आगे का हिस्सा ऊपर रखकर खड़ा करें ताकि गैस डकार के रास्ते निकल सके।\n3. **जीभ व मुंह:** पशु के मुंह में लकड़ी या रस्सी दबाकर रखें जिससे लार बने और झाग टूटे।\n\n⚠️ **आपातकाल:** यदि पशु को सांस लेने में भारी तकलीफ हो रही हो, तो बाईं कोख (Left paralumbar fossa) में ट्रोकार कैन्युला या मोटी सुई से गैस रिलीज करने हेतु तुरंत पशु चिकित्सक को 1962 पर बुलाएं।`;
    } else {
      reply = `${cattleContext}💨 **Acute Ruminal Bloat / Tympany Emergency Care:**\n\n1. **Emergency Drench:** 200 ml mustard oil + 30 ml turpentine oil + 10 g asafoetida (hing) mixed in warm water given orally via drenching bottle.\n2. **Positioning:** Stand the cow on an incline with front quarters elevated to encourage belching (eructation).\n3. **Keep Mouth Open:** Tie a smooth wooden stick across the mouth to stimulate saliva flow (saliva breaks froth).\n\n⚠️ **Emergency:** If the cow is suffocating, immediate left flank puncture using a trocar and cannula is required. Call toll-free 1962 immediately.`;
    }
  } else if (msgLower.includes('feed') || msgLower.includes('diet') || msgLower.includes('fodder') || msgLower.includes('आहार') || msgLower.includes('चारा') || msgLower.includes('दाना') || msgLower.includes('दूध बढ़ा')) {
    if (isHindi) {
      reply = `${cattleContext}🌾 **संतुलित पशु आहार व दूध बढ़ाने का फार्मूला:**\n\n1. **हरा चारा:** 20-25 किग्रा प्रतिदिन (नेपियर, बरसीम या मक्का)।\n2. **सूखा चारा:** 4-5 किग्रा गेहूं का भूसा या धान का पुआल (फैट बढ़ाने के लिए जरूरी)।\n3. **संतुलित दाना (20% प्रोटीन):**\n   - शरीर रख-रखाव: 1.5 से 2 किग्रा\n   - दूध उत्पादन: प्रति 2.5 लीटर दूध पर 1 किग्रा अतिरिक्त दाना।\n4. **खनिज मिश्रण (Mineral Mixture):** 50-100 ग्राम चिलेटेड मिनरल मिक्स + 30 ग्राम सादा नमक रोज।\n5. **स्वच्छ पानी:** 60-80 लीटर ताजा पानी दिन में 3-4 बार।`;
    } else {
      reply = `${cattleContext}🌾 **High-Yield Balanced Ration Formula:**\n\n1. **Green Fodder:** 20-25 kg/day (Napier, Lucerne, or Berseem) for vitamins and succulence.\n2. **Dry Roughage:** 4-5 kg wheat straw or hay (essential for rumen acetate & milk fat synthesis).\n3. **Concentrate Mix (20% CP):**\n   - Maintenance allowance: 1.5 - 2.0 kg\n   - Production allowance: 1 kg concentrate for every 2.5 litres of milk yield.\n4. **Minerals & Salt:** 50-100 g chelated mineral mixture + 30 g common salt daily.\n5. **Water:** 60-80 litres fresh clean water available round the clock.`;
    }
  } else if (msgLower.includes('fat') || msgLower.includes('snf') || msgLower.includes('फैट') || msgLower.includes('एसएनएफ')) {
    if (isHindi) {
      reply = `${cattleContext}🥛 **दूध में फैट व SNF बढ़ाने के वैज्ञानिक तरीके:**\n\n1. **फैट (Fat) बढ़ाने के उपाय:**\n   - सूखा चारा (भूसा) कभी बंद न करें (कम से कम 4-5 किग्रा भूसा जरूरी है, जिससे रूमेन में एसिटिक एसिड बनता है जो फैट बनाता है)।\n   - आहार में बिनौला खल (Cottonseed cake) या 100 ग्राम बाईपास फैट (Bypass Fat) शामिल करें।\n   - दाना दलिया के रूप में दें, बारीक पीसकर पाउडर न बनाएं।\n2. **SNF (Solid-Not-Fat) बढ़ाने के उपाय:**\n   - प्रोटीन युक्त खली (सरसों या सोयाबीन खली) 25-30% मात्रा में मिलाएं।\n   - खनिज मिश्रण (50 ग्राम) नियमित दें और साफ ताजा पानी भरपूर पिलाएं।\n   - थनैला की सब-क्लिनिकल जांच (CMT) कराएं, थनैला होने पर SNF गिर जाता है।`;
    } else {
      reply = `${cattleContext}🥛 **Scientific Methods to Boost Milk Fat & SNF:**\n\n1. **To Increase Milk Fat:**\n   - Always provide adequate dry straw (4-5 kg daily). Fiber digestion generates acetate, the direct precursor for milk butterfat.\n   - Feed cottonseed cake or bypass fat (100g/day) during peak lactation.\n   - Feed coarse cracked grains rather than fine powdered flour to prevent subacute ruminal acidosis (SARA).\n2. **To Increase SNF (Solid-Not-Fat):**\n   - Include high-quality protein cakes (mustard cake, soybean meal, or guar korma) in the concentrate ration.\n   - Add 50g chelated mineral mixture daily.\n   - Screen for subclinical mastitis (mastitis degrades milk protein and lowers SNF).`;
    }
  } else if (msgLower.includes('heat') || msgLower.includes('ai') || msgLower.includes('breeding') || msgLower.includes('गर्भाधान') || msgLower.includes('हीट') || msgLower.includes('गाभिन')) {
    if (isHindi) {
      reply = `${cattleContext}🐮 **प्रजनन, हीट पहचान व एआई का AM-PM नियम:**\n\n1. **हीट के लक्षण:** बेचैन होना, बार-बार रंभाना, अन्य पशुओं पर चढ़ना, पारदर्शी कांच जैसा गाढ़ा स्राव आना और दूध में अचानक कमी।\n2. **AM-PM नियम (कृत्रिम गर्भाधान का सही समय):**\n   - यदि पशु सुबह हीट में आया है -> तो शाम को AI करवाएं।\n   - यदि पशु शाम को हीट में आया है -> तो अगली सुबह AI करवाएं।\n3. **गर्भकाल (Gestation):** गाय में 280-285 दिन (लगभग 9 माह 9 दिन) तथा भैंस में 310 दिन (लगभग 10 माह 10 दिन)।\n4. **गाभिन पशु आहार:** ब्याने से 60 दिन पहले सूखा दाना (स्टीमिंग-अप) 2-3 किग्रा दें ताकि बछड़ा तंदुरुस्त हो और भरपूर दूध मिले।`;
    } else {
      reply = `${cattleContext}🐮 **Bovine Estrus (Heat) Detection & AM-PM Insemination Rule:**\n\n1. **Primary Signs of Estrus:** Standing to be mounted, clear glassy vaginal discharge, frequent bellowing, decreased milk let-down.\n2. **The Golden AM-PM Rule:**\n   - Estrus detected in morning (AM) -> Perform Artificial Insemination in the evening (PM).\n   - Estrus detected in evening (PM) -> Perform Artificial Insemination the next morning (AM).\n3. **Bovine Gestation:** ~283 days for cows and ~310 days for buffaloes.\n4. **Dry Period Steaming-Up:** Provide 2-3 kg extra concentrate during the last 60 days before calving for maternal reserve and calf vigor.`;
    }
  } else if (msgLower.includes('helpline') || msgLower.includes('call') || msgLower.includes('फोन') || msgLower.includes('नंबर') || msgLower.includes('मदद')) {
    if (isHindi) {
      reply = `${cattleContext}📞 **24/7 किसान व पशु चिकित्सा हेल्पलाइन डायरेक्टरी:**\n\n1. 🚑 **1962** - मोबाइल पशु चिकित्सा एम्बुलेंस (Toll-Free Government Ambulance)\n2. 🌾 **1800-180-1551** - किसान कॉल सेंटर (भारत सरकार कृषि मंत्रालय - निःशुल्क कृषि व डेयरी सलाह)\n3. 🥛 **1800-233-1962** - राष्ट्रीय डेयरी विकास बोर्ड (NDDB) हेल्पलाइन\n4. 🩺 **मिल्टेरा टेली-क्लिनिक:** होम स्क्रीन पर 'Tele-Vet' से किसी भी समय पशु डॉक्टर से वीडियो कॉल पर जुड़ें।`;
    } else {
      reply = `${cattleContext}📞 **24/7 Farmer & Veterinary Helplines:**\n\n1. 🚑 **1962** - Mobile Veterinary Ambulance (Toll-Free Government Emergency Service)\n2. 🌾 **1800-180-1551** - Kisan Call Centre (Ministry of Agriculture, GoI)\n3. 🥛 **1800-233-1962** - NDDB Dairy Farmer Support\n4. 🩺 **Milterra Tele-Vet:** Connect with verified bovine specialists via video consultation right inside the app.`;
    }
  } else {
    if (isHindi) {
      reply = `${cattleContext}नमस्ते! मैं आपका **पशु मित्र (Pashu Mitra AI)** डेयरी सहायक हूँ।\n\nमैं आपकी निम्नलिखित विषयों पर तुरंत 24/7 सहायता कर सकता हूँ:\n- 🏛️ **सरकारी योजनाएं:** KCC पशुपालन लोन, राष्ट्रीय गोकुल मिशन, पशु बीमा\n- 🩺 **रोग पहचान व देसी नुस्खे:** थनैला, अफारा, बुखार, खुरपका\n- 🌾 **संतुलित आहार व पोषण:** दूध व फैट/SNF बढ़ाने का फार्मूला\n- 🐮 **प्रजनन व गाभिन देखभाल:** सही समय पर AI व ब्यांत गणना\n- 📞 **हेल्पलाइन नंबर:** 1962 पशु एम्बुलेंस व 1800-180-1551 किसान कॉल सेंटर\n\nआप अपना सवाल नीचे टाइप कर सकते हैं अथवा ऊपर दिए गए त्वरित विषयों पर टैप करें।`;
    } else {
      reply = `${cattleContext}Namaste! I am **Pashu Mitra AI**, your dedicated Dairy & Herd Advisory Assistant.\n\nI can assist you 24/7 with:\n- 🏛️ **Government Subsidies & Schemes:** KCC Animal Husbandry, Rashtriya Gokul Mission, Livestock Insurance\n- 🩺 **Disease Triage & First Aid:** Mastitis, Bloat/Afara, Ephemeral Fever, Foot Rot\n- 🌾 **Nutrition & Ration:** High-yield feeding, Fat & SNF boost\n- 🐮 **Breeding & Gestation:** Heat detection, AM-PM AI rule, dry period care\n- 📞 **Emergency Helplines:** 1962 Ambulance & 1800-180-1551 Kisan Call Centre\n\nType your question below or tap on any quick topic chip to begin.`;
    }
  }

  return c.json({
    success: true,
    data: {
      response: reply,
      language: isHindi ? 'hi' : 'en',
    },
    message: 'Chat response',
  });
});