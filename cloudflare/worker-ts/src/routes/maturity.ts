import { Hono } from 'hono';
import type { Env } from '../types/env.js';

export const maturityRouter = new Hono<{ Bindings: Env }>();

// ---------------------------------------------------------------------------
// 1. ESC/POS Thermal Bluetooth Printing & WhatsApp Slip Generator
// ---------------------------------------------------------------------------
maturityRouter.post('/slips/thermal/format', async (c) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const farmerName = body.farmer_name || 'Ramesh Patel';
    const tagId = body.tag_id || 'MIL-0842 (Ganga)';
    const shift = (body.shift || 'MORNING').toUpperCase();
    const date = body.date || new Date().toISOString().split('T')[0];
    const quantity = parseFloat(body.quantity_litres || 8.5);
    const fat = parseFloat(body.fat_pct || 6.8);
    const snf = parseFloat(body.snf_pct || 9.1);
    const rate = parseFloat(body.rate_per_litre || 58.5);
    const totalAmount = parseFloat(body.total_amount || (quantity * rate).toFixed(2));
    const buyer = body.buyer_type || 'Dairy Cooperative (दुग्ध समिति)';
    const slipId = `SLIP-${Date.now().toString().slice(-6)}`;

    // Build human-readable formatted 58mm slip text
    const divider = '--------------------------------';
    const doubleDivider = '================================';
    const formattedText = [
      '        MILTERRA DAIRY        ',
      '     दुग्ध संकलन पर्ची (SLIP)    ',
      doubleDivider,
      `पर्ची क्र.: ${slipId}`,
      `दिनांक: ${date} | समय: ${shift === 'MORNING' ? 'सुबह' : 'शाम'}`,
      `किसान: ${farmerName}`,
      `पशु टैग: ${tagId}`,
      `क्रेता: ${buyer}`,
      divider,
      `मात्रा (Qty):       ${quantity.toFixed(1)} Litres`,
      `फैट (Fat %):        ${fat.toFixed(1)} %`,
      `एस.एन.एफ (SNF %):  ${snf.toFixed(1)} %`,
      `दर (Rate/L):        ₹ ${rate.toFixed(2)} / L`,
      divider,
      `कुल भुगतान (NET):   ₹ ${totalAmount.toFixed(2)}`,
      doubleDivider,
      '  * डिजिटल सत्यापित पर्ची *   ',
      '  दूध शुद्धता = किसान समृद्धि  ',
      'UPI: paytmqr@milterra | ESC/POS',
    ].join('\n');

    // Generate ESC/POS raw command hex string for 58mm Bluetooth printers
    // 1B 40 (init), 1B 61 01 (center), text, 1B 61 00 (left), text, 1D 56 41 03 (cut)
    const escposHex = '1B401B6101' + Buffer.from(formattedText, 'utf-8').toString('hex') + '1D564103';

    return c.json({
      success: true,
      data: {
        slip_id: slipId,
        date,
        shift,
        farmer_name: farmerName,
        quantity_litres: quantity,
        fat_pct: fat,
        snf_pct: snf,
        rate_per_litre: rate,
        total_amount: totalAmount,
        formatted_text: formattedText,
        escpos_hex: escposHex,
        printer_standard: 'ESC/POS 58mm/80mm Bluetooth',
        barcode_code128: `MIL${slipId.replace(/[^0-9]/g, '')}`,
      },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message || 'Thermal slip generation failed' }, 500);
  }
});

maturityRouter.post('/slips/whatsapp/format', async (c) => {
  try {
    const body = await c.req.json().catch(() => ({}));
    const farmerName = body.farmer_name || 'Ramesh Patel';
    const date = body.date || new Date().toISOString().split('T')[0];
    const shift = (body.shift || 'MORNING') === 'MORNING' ? 'सुबह (Morning)' : 'शाम (Evening)';
    const quantity = parseFloat(body.quantity_litres || 8.5);
    const fat = parseFloat(body.fat_pct || 6.8);
    const snf = parseFloat(body.snf_pct || 9.1);
    const rate = parseFloat(body.rate_per_litre || 58.5);
    const totalAmount = parseFloat(body.total_amount || (quantity * rate).toFixed(2));
    const slipId = body.slip_id || `SLIP-${Date.now().toString().slice(-6)}`;

    const whatsappMessage = 
`🥛 *MILTERRA दुग्ध संकलन रसीद* 🥛
━━━━━━━━━━━━━━━━━━━
📋 *पर्ची संख्या:* ${slipId}
👤 *किसान:* ${farmerName}
📅 *दिनांक:* ${date} (${shift})
━━━━━━━━━━━━━━━━━━━
🍶 *दूध मात्रा:* ${quantity.toFixed(1)} लीटर
🧪 *फैट (Fat):* ${fat.toFixed(1)}% | *SNF:* ${snf.toFixed(1)}%
💰 *दर:* ₹${rate.toFixed(2)}/लीटर
━━━━━━━━━━━━━━━━━━━
💵 *कुल राशि:* *₹${totalAmount.toFixed(2)}*
━━━━━━━━━━━━━━━━━━━
📲 डिजिटल पासबुक व खाता देखने के लिए:
https://farmers.milterrafoods.com/#/passbook

धन्यवाद! शुद्ध दूध, सही दाम।`;

    const encodedText = encodeURIComponent(whatsappMessage);
    const whatsappDeepLink = `https://api.whatsapp.com/send?text=${encodedText}`;

    return c.json({
      success: true,
      data: {
        slip_id: slipId,
        message_text: whatsappMessage,
        whatsapp_deep_link: whatsappDeepLink,
        upi_payment_link: `upi://pay?pa=farmers@milterra&pn=${encodeURIComponent(farmerName)}&am=${totalAmount}&tn=${slipId}`,
      },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ---------------------------------------------------------------------------
// 2. Smart IoT Heat (Estrus) Detection & Insemination Window Countdown
// ---------------------------------------------------------------------------
maturityRouter.get('/breeding/heat-alerts', async (c) => {
  const alerts = [
    {
      cattle_id: 'MIL-0842',
      cattle_name: 'Ganga (गंगा)',
      breed: 'Gir Cow (गीर गाय)',
      lactation_stage: 'Lactation 2 (Day 68 post-calving)',
      heat_status: 'HEAT_DETECTED',
      confidence_pct: 96.5,
      onset_time: new Date(Date.now() - 4 * 3600 * 1000).toISOString(),
      activity_spike_pct: 320,
      rumination_drop_pct: 28,
      golden_window_start: new Date(Date.now() + 4 * 3600 * 1000).toISOString(),
      golden_window_end: new Date(Date.now() + 14 * 3600 * 1000).toISOString(),
      hours_remaining: 10.5,
      rule_applied: 'AM-PM Rule: Heat observed early morning -> Inseminate this evening between 5:00 PM and 9:00 PM',
      sire_recommendations: [
        {
          sire_id: 'BAIF-GIR-SHAMBHU',
          name: 'Shambhu (शंभू)',
          organization: 'BAIF / NDDB Certified',
          semen_type: 'Sexed Semen (90% Female Calf Guarantee)',
          fat_potential_pct: 5.4,
          straw_price_inr: 450,
          in_stock: true,
        },
        {
          sire_id: 'NDDB-GIR-VEER',
          name: 'Veer (वीर)',
          organization: 'NDDB Progeny Tested',
          semen_type: 'Conventional High-Yield (+850L)',
          fat_potential_pct: 4.9,
          straw_price_inr: 200,
          in_stock: true,
        },
      ],
      ai_vet_contact: {
        recommended_action: 'कृत्रिम गर्भाधान (AI) तकनीशियन को अभी बुक करें',
        phone: '+919876543210',
      },
    },
    {
      cattle_id: 'MIL-1024',
      cattle_name: 'Murrah-1 (लक्ष्मी)',
      breed: 'Murrah Buffalo (मुर्रा भैंस)',
      lactation_stage: 'Lactation 2 (Dry Period)',
      heat_status: 'PROESTRUS_APPROACHING',
      confidence_pct: 78.0,
      onset_time: null,
      activity_spike_pct: 140,
      rumination_drop_pct: 12,
      golden_window_start: new Date(Date.now() + 28 * 3600 * 1000).toISOString(),
      golden_window_end: new Date(Date.now() + 44 * 3600 * 1000).toISOString(),
      hours_remaining: 28.0,
      rule_applied: 'प्रारंभिक लक्षण दिखे हैं - अगले 24-36 घंटों में पूर्ण हीट संभावित',
      sire_recommendations: [
        {
          sire_id: 'CIRB-MURRAH-SULTAN',
          name: 'Sultan Lineage (सुलतान वंशज)',
          organization: 'CIRB Hisar Certified',
          semen_type: 'Sexed Semen',
          fat_potential_pct: 7.8,
          straw_price_inr: 500,
          in_stock: true,
        },
      ],
      ai_vet_contact: {
        recommended_action: 'निगरानी रखें - गर्भाधान का समय कल दोपहर',
        phone: '+919876543210',
      },
    },
  ];

  return c.json({
    success: true,
    total_active_alerts: alerts.length,
    alerts,
  });
});

// ---------------------------------------------------------------------------
// 3. Bulk Milk Cooler (BMC) Chilling Center & Cold-Chain IoT Telemetry
// ---------------------------------------------------------------------------
maturityRouter.get('/cold-chain/bmc-status', async (c) => {
  const bmcData = {
    center_id: 'BMC-ANAND-04',
    center_name: 'Mogar Primary Milk Chilling Center (मोगर बीएमसी)',
    manager_name: 'Vikrambhai Solanki',
    capacity_litres: 5000,
    current_volume_litres: 3840,
    fill_pct: 76.8,
    current_temperature_c: 3.7,
    target_temperature_c: 4.0,
    status: 'OPTIMAL_CHILLED',
    agitator_rpm: 28,
    agitator_status: 'ACTIVE_NORMAL',
    compressor_cycles_1hr: 3,
    compressor_status: 'AUTO_CYCLING_STANDBY',
    power_source: 'GRID_PRIMARY',
    backup_genset_fuel_pct: 92,
    spoilage_risk: 'ZERO_RISK',
    mbrt_hours: 4.8,
    last_cleaned_cip: new Date(Date.now() - 14 * 3600 * 1000).toISOString(),
    hourly_telemetry: [
      { time: '06:00', temp_c: 8.4, volume_l: 1200, note: 'Morning intake started' },
      { time: '07:00', temp_c: 6.8, volume_l: 2500, note: 'Rapid chilling active' },
      { time: '08:00', temp_c: 4.2, volume_l: 3600, note: 'Intake complete' },
      { time: '09:00', temp_c: 3.8, volume_l: 3840, note: 'Chilled < 4°C maintained' },
      { time: '10:00', temp_c: 3.7, volume_l: 3840, note: 'Optimal storage' },
    ],
  };

  return c.json({
    success: true,
    data: bmcData,
  });
});

// ---------------------------------------------------------------------------
// 4. GOBARdhan Biogas & Carbon Credit Ledger (New Farmer Income)
// ---------------------------------------------------------------------------
maturityRouter.get('/sustainability/gobardhan-credits', async (c) => {
  const sustainabilityData = {
    farmer_id: 'farmer-dileep-1',
    farmer_name: 'Ramesh Patel',
    village: 'Mogar',
    total_cattle: 4,
    daily_dung_output_kg: 72.0,
    biogas_digester_status: 'OPERATIONAL (2 m³ Deenbandhu Model)',
    biogas_monthly_m3: 108.0,
    lpg_cylinder_equivalent: 2.8,
    monthly_lpg_savings_inr: 2520,
    bio_slurry_monthly_litres: 2160,
    bio_slurry_fertilizer_value_inr: 3240,
    carbon_mitigation: {
      standard: 'Gold Standard & Verra Verified VM0042',
      methane_avoidance_mt_co2e: 4.2,
      total_carbon_credits_earned: 4.2,
      price_per_credit_inr: 900.0,
      total_carbon_revenue_inr: 3780.0,
      withdrawable_balance_inr: 3780.0,
    },
    total_monthly_circular_income_inr: 9540, // 2520 (LPG) + 3240 (Slurry) + 3780 (Carbon)
  };

  return c.json({
    success: true,
    data: sustainabilityData,
  });
});

maturityRouter.post('/sustainability/carbon/withdraw', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const amount = parseFloat(body.amount || 3780.0);
  const upiId = body.upi_id || 'ramesh@upi';

  return c.json({
    success: true,
    message: `₹${amount} कार्बन क्रेडिट राशि सफलतापूर्वक आपके बैंक खाते में भेजी गई।`,
    transaction_id: `CRB-TXN-${Date.now().toString().slice(-6)}`,
    amount,
    upi_id: upiId,
    timestamp: new Date().toISOString(),
  });
});

// ---------------------------------------------------------------------------
// 5. AI Muzzle-Print Biometrics for Cattle Insurance
// ---------------------------------------------------------------------------
maturityRouter.post('/insurance/claims/muzzle-verify', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const cattleId = body.cattle_id || 'MIL-0842';
  const claimType = body.claim_type || 'MORTALITY_INSURANCE';

  return c.json({
    success: true,
    data: {
      claim_docket_id: `CLAIM-2026-${Date.now().toString().slice(-6)}`,
      cattle_id: cattleId,
      cattle_name: 'Ganga (गीर गाय)',
      policy_number: 'NIC-PASHU-2025-88392',
      sum_insured: 75000,
      biometric_verification: {
        method: 'Bovine Muzzle Print Ridge Biometrics (थूथन प्रिंट मिलान)',
        match_confidence_pct: 99.4,
        status: 'VERIFIED_GENUINE',
        geotag_verified: true,
        gps_location: '22.5645° N, 72.9289° E (Mogar Village)',
      },
      iot_telemetry_audit: {
        smart_collar_tag: 'COL-9021',
        history_summary: '24-hour telemetry recorded fever spike (40.8°C) followed by cessation of heartbeat. Verified by IoT ledger.',
      },
      approval_speed: '48-Hour Fast-Track Settlement Promise',
      claim_status: 'PRE_APPROVED_FOR_DISBURSAL',
      disbursal_amount: 75000,
    },
  });
});

// ---------------------------------------------------------------------------
// 6. Group Feed & Silage Buying Pool (सामूहिक खरीद)
// ---------------------------------------------------------------------------
maturityRouter.get('/feed/group-pools', async (c) => {
  const pools = [
    {
      pool_id: 'POOL-SILAGE-ANAND-01',
      title: 'मक्का साइलेज बेल सामूहिक खरीद (Corn Silage Bales 500kg)',
      category: 'Silage',
      cluster_location: 'आनंद व मोगर ब्लॉक (Anand Cluster)',
      delivery_hub: 'मोगर प्राथमिक दुग्ध सहकारी समिति',
      target_metric_tons: 50.0,
      booked_metric_tons: 38.5,
      min_order_kg: 500,
      retail_price_per_kg: 5.60,
      group_pool_price_per_kg: 4.30,
      savings_pct: 23.2,
      hours_remaining: 32,
      total_participating_farmers: 24,
      status: 'OPEN_FAST_FILLING',
    },
    {
      pool_id: 'POOL-PELLET-ANAND-02',
      title: 'संतुलित कैटल फीड पेलेट्स 22% प्रोटीन (Balanced Feed 50kg Bags)',
      category: 'Feed Pellets',
      cluster_location: 'आनंद व मोगर ब्लॉक (Anand Cluster)',
      delivery_hub: 'अमूल फीड डिपो, मोगर',
      target_metric_tons: 20.0,
      booked_metric_tons: 16.2,
      min_order_kg: 100,
      retail_price_per_kg: 26.0,
      group_pool_price_per_kg: 21.5,
      savings_pct: 17.3,
      hours_remaining: 48,
      total_participating_farmers: 31,
      status: 'OPEN',
    },
  ];

  return c.json({
    success: true,
    total_pools: pools.length,
    pools,
  });
});

maturityRouter.post('/feed/group-pools/join', async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const poolId = body.pool_id || 'POOL-SILAGE-ANAND-01';
  const quantityKg = parseFloat(body.quantity_kg || 1000);
  const farmerName = body.farmer_name || 'Ramesh Patel';
  const pricePerKg = poolId.includes('SILAGE') ? 4.30 : 21.50;
  const retailPricePerKg = poolId.includes('SILAGE') ? 5.60 : 26.00;
  const totalAmount = quantityKg * pricePerKg;
  const totalSaved = quantityKg * (retailPricePerKg - pricePerKg);

  return c.json({
    success: true,
    booking_id: `GRP-BOOK-${Date.now().toString().slice(-6)}`,
    message: `सामूहिक खरीद में ${quantityKg} कि.ग्रा. सफलतापूर्वक बुक किया गया!`,
    pool_id: poolId,
    farmer_name: farmerName,
    quantity_kg: quantityKg,
    price_per_kg: pricePerKg,
    total_amount: totalAmount,
    total_saved_inr: totalSaved,
    delivery_date: '3 दिन बाद (सामूहिक ट्रक आगमन पर)',
  });
});

// ---------------------------------------------------------------------------
// 7. Bovine Multi-Crisis Emergency ICU Telemetry & Health Alert
// (Heat + High Fever 40.8°C + Acute Mastitis + 2h No Movement + 5h No Jugali)
// ---------------------------------------------------------------------------
maturityRouter.get('/health/multi-crisis-alert', async (c) => {
  const crisisData = {
    cattle_id: 'MIL-0842',
    cattle_name: 'Ganga (गंगा - गीर गाय)',
    tag_id: 'MIL-0842',
    breed: 'Gir Indigenous Cow (गीर देशी गाय)',
    age_years: 4.5,
    lactation_stage: 'Lactation 2 (Day 72 post-calving)',
    weight_kg: 420.0,
    emergency_level: 'CODE_RED_CRITICAL',
    last_updated: new Date().toISOString(),
    vitals: {
      temperature_c: 40.8,
      temperature_f: 105.4,
      normal_temp_c: 38.5,
      temp_status: 'CRITICAL_FEVER',
      heart_rate_bpm: 96,
      normal_hr_bpm: 68,
      hr_status: 'TACHYCARDIA_DISTRESS',
      activity_level: 0,
      activity_normal: 75,
      no_movement_minutes: 125,
      rumination_minutes_5h: 0,
      rumination_normal_5h: 110,
      rumination_status: 'RUMEN_ATONY_STASIS',
      milk_yield_drop_pct: 45.0,
    },
    alerts: [
      {
        id: 'ALT-FEVER-01',
        title: 'अति-गंभीर बुखार (Hyperpyrexia - 40.8°C / 105.4°F)',
        category: 'FEVER',
        severity: 'CRITICAL',
        badge: '🚨 40.8°C FEVER',
        duration: 'पिछले 4 घंटे से तापमान 105.4°F पर स्थिर',
        clinical_finding: 'तीव्र जीवाणु विषाक्तता (Acute Bacteremia / Endotoxemia)',
        urgency: 'तत्काल आईवी एंटीपायरेटिक आवश्यक',
      },
      {
        id: 'ALT-MASTITIS-02',
        title: 'तीव्र क्लिनिकल थनैला (Acute Toxic Mastitis - Right Hind Quarter)',
        category: 'MASTITIS',
        severity: 'CRITICAL',
        badge: '⚠️ तीव्र थनैला (MASTITIS)',
        duration: 'दाहिना पिछला थन सूजा, गर्म व कठोर; पीला पानी व थक्के',
        clinical_finding: 'ई-कोलाई या स्ट्रेप्टोकोकस टॉक्सिन, 45% दूध उत्पादन गिरा (CMT Score 3+)',
        urgency: 'हर 30 मिनट में थन खाली करें + एंटीबायोटिक ट्यूब',
      },
      {
        id: 'ALT-RECUMBENT-03',
        title: 'अचल पशु / डाउनर सिंड्रोम (No Movement > 2 Hours - Recumbent Cow)',
        category: 'MOVEMENT',
        severity: 'CRITICAL',
        badge: '🛑 2 घंटे से 0 हलचल (0 STEPS)',
        duration: '125 मिनट से गर्दन व पैरों में कोई गतिविधि नहीं',
        clinical_finding: 'अत्यधिक दर्द, सेप्टिक शॉक व डिहाइड्रेशन के कारण खड़ी होने में असमर्थ',
        urgency: 'कोमल बिछावन + आईवी ड्रिप व दर्द निवारक',
      },
      {
        id: 'ALT-RUMEN-04',
        title: 'रूमेन गतिरोध (No Jugali / Stalled Rumination > 5 Hours)',
        category: 'RUMINATION',
        severity: 'CRITICAL',
        badge: '⏳ 5 घंटे से 0 जुगाली (RUMEN STASIS)',
        duration: 'पिछले 300 मिनट में 0 मिनट जुगाली (Normal: 90-120 min)',
        clinical_finding: 'रूमेन एटोनी (Reticulo-ruminal Atony), पेट में गैस व एसिडोसिस का भारी जोखिम',
        urgency: 'रूमेन टोनिक्स व प्रोबायोटिक बोलस',
      },
      {
        id: 'ALT-HEAT-05',
        title: 'मद चक्र सह-उत्पत्ति (Estrus Co-occurrence / False Heat Stress)',
        category: 'ESTRUS',
        severity: 'WARNING',
        badge: '🔥 21-दिवसीय हीट चक्र',
        duration: 'दिन 21 चक्र का मद संकेत',
        clinical_finding: 'मद के हार्मोनल लक्षण थनैला व बुखार के दर्द के साथ अत्यधिक तनाव उत्पन्न कर रहे हैं। कृत्रिम गर्भाधान (AI) तुरंत स्थगित रखें!',
        urgency: 'गर्भाधान वर्जित - पहले थनैला व बुखार का उपचार करें',
      },
    ],
    ai_clinical_triage: {
      diagnosis: 'तीव्र विषैला थनैला व सेप्टिक शॉक (Acute Toxic Mastitis with Secondary Hypomotility & Downer Cow Syndrome)',
      summary: 'गंगा गाय में 40.8°C बुखार, 5 घंटे से शून्य जुगाली और 2 घंटे से अचल पड़े रहना अत्यंत आपातकालीन स्थिति है। यह केवल हीट का मामला नहीं है—थनैला के विषैले बैक्टीरिया खून में फैल रहे हैं। 2 घंटे के भीतर तत्काल चिकित्सकीय उपचार न मिलने पर पशु की जान को खतरा हो सकता है।',
      immediate_actions: [
        'तुरंत पशु चिकित्सक को बुलाएं या पास के सरकारी/प्राइवेट वेटरनरी अस्पताल को आपातकालीन कॉल करें।',
        'प्रभावित दाहिने पिछले थन को हर 30 मिनट में धीरे-धीरे पूरी तरह खाली (Frequent Stripping) करें।',
        'तापमान 105.4°F से घटाने के लिए माथे व शरीर पर ठंडे पानी की पट्टी रखें।',
        'डॉक्टर की सलाह अनुसार Flunixin Meglumine व Ringer Lactate (IV Fluid) तुरंत दें।',
      ],
      first_aid_medicines: [
        { name: 'Flunixin Meglumine (Megludyne) 15-20ml IV/IM', purpose: '105.4°F बुखार व थनैला टॉक्सिन का शॉक तुरंत रोकने हेतु' },
        { name: 'Intramammary Infusion (Cobactan LC / Pendistrin-SH)', purpose: 'सूजे हुए थन में सीधे चढ़ाने हेतु एंटीबायोटिक ट्यूब' },
        { name: 'Ringer Lactate / Dextrose 5% (3-4 Litres IV)', purpose: 'शॉक, निर्जलीकरण (Dehydration) व डाउनर अवस्था से बाहर लाने हेतु' },
        { name: 'Rumen Motor / Appetizer Bolus (Rumentas / Biosacc)', purpose: 'ठप पड़ी जुगाली (Rumen Motility) पुनः शुरू करने हेतु' },
      ],
      vet_emergency_contact: {
        doctor_name: 'Dr. Ramesh Sharma (B.V.Sc & A.H.)',
        clinic_name: 'अमूल वेटरनरी पॉलीक्लिनिक, आनंद',
        phone: '+919876543210',
        distance_km: 3.2,
      },
    },
  };

  return c.json({
    success: true,
    data: crisisData,
  });
});

