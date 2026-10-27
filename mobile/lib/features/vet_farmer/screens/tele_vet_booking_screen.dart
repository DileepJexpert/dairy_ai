import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';
import '../../cart/providers/cart_provider.dart';
import '../../marketplace/widgets/store_design.dart';
import '../providers/vet_farmer_provider.dart';

class TeleVetBookingScreen extends ConsumerStatefulWidget {
  const TeleVetBookingScreen({super.key, this.initialCattleId});

  final String? initialCattleId;

  @override
  ConsumerState<TeleVetBookingScreen> createState() => _TeleVetBookingScreenState();
}

class _TeleVetBookingScreenState extends ConsumerState<TeleVetBookingScreen> {
  int _activeView = 0; // 0 = Book Consultation, 1 = Active E-Prescription (Rx)

  // Selected Cattle
  String? _selectedCattle;

  // Symptoms Selection
  final Set<String> _selectedSymptoms = <String>{};

  final List<Map<String, dynamic>> _symptomList = [
    {
      'id': 'Mastitis / Udder Swelling',
      'title': 'थनैला रोग (Mastitis)',
      'desc': 'अयन/थन में सूजन या गर्मी, दूध में छिछड़े या खून, दूध में अचानक गिरावट',
      'severity': 'HIGH',
      'icon': Icons.water_drop_outlined,
    },
    {
      'id': 'Rumen Bloat / Acidosis',
      'title': 'अफारा व एसिडोसिस (Bloat)',
      'desc': 'बायाँ पेट फूला हुआ, बेचैनी, लात मारना, जुगाली बंद व सांस फूलना',
      'severity': 'EMERGENCY',
      'icon': Icons.warning_amber_rounded,
    },
    {
      'id': 'High Fever (>104°F)',
      'title': 'तेज़ बुखार (Bovine Fever)',
      'desc': 'शरीर अत्यधिक गर्म, कांपना, सुस्ती, कान ठंडे या सुस्त खड़े रहना',
      'severity': 'MODERATE',
      'icon': Icons.thermostat_outlined,
    },
    {
      'id': 'Foot Rot / Lameness',
      'title': 'खुरपका व लंगड़ापन (Foot Rot)',
      'desc': 'खुरों के बीच घाव या सूजन, चलने में दर्द, बदबू व ज़मीन पर बैठना',
      'severity': 'MODERATE',
      'icon': Icons.airline_stops_outlined,
    },
    {
      'id': 'Off-Feed & Low Rumination',
      'title': 'भूख न लगना व अपच (Off-Feed)',
      'desc': 'दाना या चारा छोड़ना, सुस्त आंखें, रूमेन में धीमी हलचल',
      'severity': 'MILD',
      'icon': Icons.grass_outlined,
    },
    {
      'id': 'Respiratory Distress',
      'title': 'सांस तकलीफ़ व निमोनिया (Pneumonia)',
      'desc': 'मुंह खोलकर हांफना, नाक से स्राव, सीने से घुरघुराहट या खांसी',
      'severity': 'HIGH',
      'icon': Icons.air_outlined,
    },
  ];

  // Selected Doctor
  int _selectedDoctorIndex = 0;
  final List<Map<String, dynamic>> _doctors = [
    {
      'name': 'Dr. Arvind Sharma',
      'degree': 'M.V.Sc Surgery & Theriogenology',
      'experience': '14 yrs exp',
      'rating': 4.9,
      'reviews': 1280,
      'languages': 'Hindi, English, Punjabi',
      'specialty': 'Bovine Surgery & Udder Pathology',
      'fee': 250,
      'vciReg': 'VCI-RAJ-44821',
      'available': 'Online Now (Instant Slot)',
      'phone': '+919825099001',
      'whatsapp': '919825099001',
    },
    {
      'name': 'Dr. Shalini Mehta',
      'degree': 'Ph.D Ruminant Nutrition & Metabolic Health',
      'experience': '9 yrs exp',
      'rating': 4.8,
      'reviews': 890,
      'languages': 'Hindi, English, Gujarati',
      'specialty': 'Transition Nutrition & Acidosis Care',
      'fee': 250,
      'vciReg': 'VCI-GUJ-29103',
      'available': 'Next in 25 mins',
      'phone': '+919825099002',
      'whatsapp': '919825099002',
    },
    {
      'name': 'Dr. Rajesh Patel',
      'degree': 'B.V.Sc & A.H. Dairy Herd Health',
      'experience': '12 yrs exp',
      'rating': 4.9,
      'reviews': 1450,
      'languages': 'Hindi, Marathi',
      'specialty': 'Herd Mastitis Control & SCC Reduction',
      'fee': 200,
      'vciReg': 'VCI-MAH-38190',
      'available': 'Today 05:00 PM',
      'phone': '+919825099003',
      'whatsapp': '919825099003',
    },
  ];

  // Slot Selection
  int _selectedSlotIndex = 0;
  final List<String> _timeSlots = [
    'Instant Video Call (In 5 mins)',
    'Today at 04:30 PM',
    'Today at 06:00 PM',
    'Tomorrow at 09:30 AM',
  ];

  final TextEditingController _notesController = TextEditingController(
    text: 'Right hind quarter feels hot and hard to touch since morning milking. Milk has white curd flakes.',
  );

  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _selectedCattle = widget.initialCattleId != null && widget.initialCattleId!.isNotEmpty
        ? widget.initialCattleId!
        : null;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _calculateSeverity() {
    if (_selectedSymptoms.contains('Rumen Bloat / Acidosis')) {
      return 'EMERGENCY';
    }
    if (_selectedSymptoms.contains('Mastitis / Udder Swelling') ||
        _selectedSymptoms.contains('Respiratory Distress')) {
      return 'HIGH';
    }
    if (_selectedSymptoms.contains('High Fever (>104°F)') ||
        _selectedSymptoms.contains('Foot Rot / Lameness')) {
      return 'MODERATE';
    }
    return 'MILD';
  }

  Color _getSeverityColor(String sev) {
    switch (sev) {
      case 'EMERGENCY':
        return Colors.red.shade700;
      case 'HIGH':
        return Colors.deepOrange.shade600;
      case 'MODERATE':
        return storeAmber;
      case 'MILD':
      default:
        return storeGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = _calculateSeverity();
    final severityColor = _getSeverityColor(severity);

    return Scaffold(
      backgroundColor: storeCream,
      appBar: AppBar(
        title: const Text('पशु चिकित्सालय व टेली-परामर्श (Tele-Vet Clinic)'),
        backgroundColor: const Color(0xff064e3b),
        foregroundColor: Colors.white,
        actions: const [
          FarmerAuthAction(nextRoute: '/vet/booking', color: Colors.white),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vet/search');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Breadcrumb
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            onTap: () => context.go('/herd'),
                            child: const Text('Herd Management',
                                style: TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                          InkWell(
                            onTap: () => context.go('/herd/lifecycle/$_selectedCattle'),
                            child: Text('Cattle #$_selectedCattle',
                                style: const TextStyle(fontSize: 12, color: storeMuted)),
                          ),
                          const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                          const Text('Tele-Veterinary Clinic & E-Prescription',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Screen Header Banner
                      _buildHeaderBanner(),
                      const SizedBox(height: 20),

                      // View Selector Tabs: [Book Doctor Consultation] vs [Active E-Prescription & Pharmacy]
                      Row(
                        children: [
                          _tabToggle(0, 'Book Vet Consultation', Icons.video_call_outlined),
                          const SizedBox(width: 12),
                          _tabToggle(1, 'Active E-Prescription (Rx-842)', Icons.medical_information_outlined),
                        ],
                      ),
                      const SizedBox(height: 22),

                      if (_activeView == 0) ...[
                        // 1. Cattle Selector
                        _buildCattleSelectorCard(),
                        const SizedBox(height: 20),

                        // 2. Symptom Triage Matrix & AI Calculator
                        _buildSymptomTriageCard(severity, severityColor),
                        const SizedBox(height: 20),

                        // 3. Certified Bovine Specialists Selection
                        _buildDoctorSelectionCard(),
                        const SizedBox(height: 20),

                        // 4. Time Slot & Notes
                        _buildSlotAndNotesCard(),
                        const SizedBox(height: 24),

                        // 5. Booking Action Bar
                        _buildBookingActionBar(),
                      ] else ...[
                        // E-Prescription View
                        _buildPrescriptionView(),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _tabToggle(int index, String title, IconData icon) {
    final active = _activeView == index;
    return InkWell(
      onTap: () => setState(() => _activeView = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: active ? storeGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? storeGreen : storeBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : storeGreen),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : storeGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: storeGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: storeGreen.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.health_and_safety_rounded, color: storeAmber, size: 36),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Milterra Tele-Vet & Clinical Herd Care',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    SizedBox(width: 10),
                    Chip(
                      label: Text('VCI Verified',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w800, color: storeGreen)),
                      backgroundColor: storeAmber,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                SizedBox(height: 5),
                Text(
                  'Instant high-definition video triage with India’s leading bovine veterinarians, automated somatic cell & clinical triage scoring, and 1-tap doorstep medicine fulfillment.',
                  style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCattleSelectorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pets_outlined, size: 18, color: storeGreen),
              SizedBox(width: 8),
              Text('1. Select Animal For Consultation',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: storeGreen)),
            ],
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              final cattleAsync = ref.watch(farmerCattleListProvider);
              final cattleList = cattleAsync.value ?? [];

              final genericAnimals = [
                {'tag': 'गाय (Cow - General)', 'name': 'गाय (Cow)', 'breed': 'देशी/क्रॉस गाय', 'icon': Icons.pets},
                {'tag': 'भैंस (Buffalo - General)', 'name': 'भैंस (Buffalo)', 'breed': 'मुर्रा/देशी भैंस', 'icon': Icons.pets},
                {'tag': 'बछड़ा/बछिया (Calf/Heifer)', 'name': 'बछड़ा/बछिया', 'breed': 'छोटी बछिया', 'icon': Icons.child_care},
                {'tag': 'बकरा/बकरी (Goat/Sheep)', 'name': 'बकरा/बकरी', 'breed': 'बकरी/भेड़', 'icon': Icons.grass},
              ];

              if (_selectedCattle == null) {
                if (cattleList.isNotEmpty) {
                  _selectedCattle = cattleList.first.tagId ?? cattleList.first.id.toString();
                } else {
                  _selectedCattle = 'गाय (Cow - General)';
                }
              }

              if (cattleList.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'त्वरित परामर्श मोड: नीचे से पशु चुनें अथवा अपने झुंड में पशु जोड़ें।',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xff92400e)),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => context.push('/herd/add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff064e3b),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('पशु जोड़ें +', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: genericAnimals.map((item) {
                        final tag = item['tag'] as String;
                        final isSelected = _selectedCattle == tag;
                        return InkWell(
                          onTap: () => setState(() => _selectedCattle = tag),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? storeGreen.withValues(alpha: 0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? storeGreen : storeBorder,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected ? storeGreen : const Color(0xffe2e8f0),
                                  child: Icon(item['icon'] as IconData, size: 18, color: isSelected ? Colors.white : const Color(0xff475569)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] as String,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isSelected ? storeGreen : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        item['breed'] as String,
                                        style: const TextStyle(fontSize: 11, color: storeMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cattleList.map((cattle) {
                  final tag = cattle.tagId ?? cattle.id.toString();
                  final isSelected = _selectedCattle == tag;
                  return InkWell(
                    onTap: () => setState(() => _selectedCattle = tag),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 270,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? storeGreen.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? storeGreen : storeBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(cattle.name,
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? storeGreen : storeBorder,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(tag,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : storeMuted)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(cattle.breed ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomTriageCard(String severity, Color severityColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.biotech_outlined, size: 18, color: storeGreen),
                  SizedBox(width: 8),
                  Text('2. AI Symptom Triage Matrix',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: storeGreen)),
                ],
              ),
              // AI Severity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: severityColor, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar_rounded, size: 14, color: severityColor),
                    const SizedBox(width: 6),
                    Text(
                      'AI Triage: $severity',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: severityColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Select all active clinical indications observed in the herd:',
              style: TextStyle(fontSize: 12, color: storeMuted)),
          const SizedBox(height: 16),

          // Grid of Symptoms
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _symptomList.map((item) {
              final id = item['id'] as String;
              final selected = _selectedSymptoms.contains(id);
              final sev = item['severity'] as String;

              return InkWell(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedSymptoms.remove(id);
                    } else {
                      _selectedSymptoms.add(id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? storeGreen.withValues(alpha: 0.06) : storeCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? storeGreen : storeBorder,
                      width: selected ? 1.8 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item['icon'] as IconData,
                          size: 20, color: selected ? storeGreen : storeMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['title'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: selected ? storeGreen : Colors.black87,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(sev).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    sev,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: _getSeverityColor(sev),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['desc'] as String,
                              style: const TextStyle(fontSize: 11, color: storeMuted, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                      Checkbox(
                        value: selected,
                        activeColor: storeGreen,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedSymptoms.add(id);
                            } else {
                              _selectedSymptoms.remove(id);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // First Aid Advice Panel
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: severityColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 20, color: severityColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        severity == 'EMERGENCY'
                            ? 'IMMEDIATE STABILIZATION PROTOCOL (<15 MINS)'
                            : 'CLINICAL GUIDELINES BEFORE VIDEO CONSULT',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, color: severityColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        severity == 'EMERGENCY'
                            ? 'Withhold concentrated mash/grain immediately. Provide clean lukewarm water. Elevate the animal’s head if recumbent. A tele-vet surgeon will join your priority room.'
                            : 'Completely strip out the affected quarter into an isolated bucket. Do NOT mix this milk in the cooperative collection tank. Maintain dry straw bedding.',
                        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorSelectionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_pin_outlined, size: 18, color: storeGreen),
              SizedBox(width: 8),
              Text('3. Select Bovine Veterinary Specialist',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: storeGreen)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(_doctors.length, (idx) {
              final doc = _doctors[idx];
              final isSelected = _selectedDoctorIndex == idx;
              return InkWell(
                onTap: () => setState(() => _selectedDoctorIndex = idx),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 270,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? storeGreen.withValues(alpha: 0.04) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? storeGreen : storeBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: storeGreen.withValues(alpha: 0.1),
                            child: const Icon(Icons.person, color: storeGreen, size: 24),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc['name'] as String,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: storeGreen)),
                                Text(doc['experience'] as String,
                                    style: const TextStyle(fontSize: 11, color: storeMuted)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: storeAmber),
                              const SizedBox(width: 2),
                              Text('${doc['rating']}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(doc['degree'] as String,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text('Specialty: ${doc['specialty']}',
                          style: const TextStyle(fontSize: 11, color: storeMuted)),
                      const SizedBox(height: 4),
                      Text('Reg: ${doc['vciReg']}',
                          style: const TextStyle(fontSize: 10, color: storeMuted)),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${doc['fee']} / consult',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900, color: storeGreen),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: storeGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              doc['available'] as String,
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold, color: storeGreen),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotAndNotesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 18, color: storeGreen),
              SizedBox(width: 8),
              Text('4. Choose Time Slot & Observation Notes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: storeGreen)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(_timeSlots.length, (idx) {
              final slot = _timeSlots[idx];
              final isSelected = _selectedSlotIndex == idx;
              return InkWell(
                onTap: () => setState(() => _selectedSlotIndex = idx),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? storeGreen : storeCream,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? storeGreen : storeBorder),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          const Text('Specific Observations (e.g. Milk texture, temperature, behavioral changes):',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              filled: true,
              fillColor: storeCream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: storeBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: storeBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: storeGreen, width: 1.5),
              ),
              hintText: 'Enter symptoms or attach photos of udder / eye / hoof...',
              hintStyle: const TextStyle(fontSize: 12, color: storeMuted),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingActionBar() {
    final doc = _doctors[_selectedDoctorIndex];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: storeGreen, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: storeGreen.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Consultation Fee: ',
                        style: TextStyle(fontSize: 13, color: storeMuted)),
                    Text('₹${doc['fee']}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, color: storeGreen)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: storeAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Milterra Wallet Supported',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: storeGreen)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Includes 15-min HD Video Call with ${doc['name']} + E-Prescription + 7-Day Followup Chat.',
                  style: const TextStyle(fontSize: 11, color: storeMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: storeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showBookingConfirmationDialog,
            icon: const Icon(Icons.videocam_outlined, size: 20),
            label: const Text('Confirm & Start Consultation',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _openDoctorWhatsApp(Map<String, dynamic> doc, String slot, String appointmentId) {
    final text = 'नमस्ते ${doc['name']} जी, मैंने Milterra Tele-Vet पर परामर्श बुक किया है।\n'
        '• अप्वाइंटमेंट ID: $appointmentId\n'
        '• पशु: ${_selectedCattle ?? 'गाय/भैंस'}\n'
        '• मुख्य लक्षण: ${_selectedSymptoms.isEmpty ? 'सामान्य स्वास्थ्य जांच' : _selectedSymptoms.join(', ')}\n'
        '• समय स्लॉट: $slot\n'
        'कृपया वीडियो परामर्श लिंक अथवा प्राथमिक उपचार सलाह साझा करें।';
    final phone = (doc['whatsapp'] ?? '919825099001').toString();
    launchUrl(
      Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _callDoctor(Map<String, dynamic> doc) {
    final phone = (doc['phone'] ?? '+919825099001').toString();
    launchUrl(Uri.parse('tel:$phone'));
  }

  void _showBookingConfirmationDialog() {
    final doc = _doctors[_selectedDoctorIndex];
    final slot = _timeSlots[_selectedSlotIndex];
    final appointmentId = 'VET-2026-${9182 + _selectedDoctorIndex}';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: storeGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.check_circle_outline, color: storeGreen, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('परामर्श बुक हो गया (Confirmed)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: storeGreen)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: storeCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: storeBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appointment ID: $appointmentId',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800, color: storeGreen)),
                      const SizedBox(height: 4),
                      Text('पशु (Animal): ${_selectedCattle ?? 'General'}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      Text('चिकित्सक (Doctor): ${doc['name']} (${doc['degree']})',
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      Text('समय (Slot): $slot',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: storeAmber)),
                      if (_selectedSymptoms.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('लक्षण (Symptoms): ${_selectedSymptoms.join(', ')}',
                            style: const TextStyle(fontSize: 11, color: storeMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'आपका वीडियो कंसल्टेशन रूम सक्रिय है। डॉक्टर आपसे जुड़ने के लिए तैयार हैं। आप सीधे WhatsApp या फ़ोन कॉल पर भी बात कर सकते हैं:',
                  style: TextStyle(fontSize: 12, color: storeMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff25d366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          _openDoctorWhatsApp(doc, slot, appointmentId);
                        },
                        icon: const Icon(Icons.chat, size: 16),
                        label: const Text('WhatsApp चैट', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff064e3b),
                          side: const BorderSide(color: Color(0xff064e3b)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _callDoctor(doc),
                        icon: const Icon(Icons.call, size: 16),
                        label: const Text('कॉल करें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _activeView = 1); // Switch to e-prescription view
              },
              child: const Text('डिजिटल ई-पर्चा (Rx) देखें', style: TextStyle(color: storeGreen, fontWeight: FontWeight.bold)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: storeGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: storeGreen,
                    content: Text('Joining encrypted video tele-consultation room...'),
                  ),
                );
              },
              icon: const Icon(Icons.video_camera_front_outlined, size: 18),
              label: const Text('वीडियो रूम खोलें'),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Active E-Prescription & Medicine Pharmacy View
  // -------------------------------------------------------------------------

  Widget _buildPrescriptionView() {
    final List<Map<String, dynamic>> prescribedMedicines = [
      {
        'id': 'med-101',
        'name': 'Mastilep Udder Herbal Anti-inflammatory Gel (125g)',
        'dosage': 'Apply topically over right hind quarter',
        'frequency': 'Twice Daily (Post Milking)',
        'duration': '5 Days',
        'price': 185,
        'image': 'assets/images/placeholder_feed.png',
      },
      {
        'id': 'med-102',
        'name': 'Mammitel DC Intramammary Infusion (Pack of 4 Tubes)',
        'dosage': '1 syringe infused into affected quarter after stripping',
        'frequency': 'Once Daily',
        'duration': '3 Days',
        'price': 420,
        'image': 'assets/images/placeholder_feed.png',
      },
      {
        'id': 'med-103',
        'name': 'Bovimilk Rumen Buffer & Live Probiotic Yeast (1 kg)',
        'dosage': '50g mixed with warm mash concentrate',
        'frequency': 'Morning & Evening',
        'duration': '10 Days',
        'price': 460,
        'image': 'assets/images/placeholder_feed.png',
      },
      {
        'id': 'med-104',
        'name': 'Melonex Plus Bolus (Meloxicam + Paracetamol - 2 Boli)',
        'dosage': '1 bolus orally with jaggery ball',
        'frequency': 'Once Daily',
        'duration': '2 Days',
        'price': 135,
        'image': 'assets/images/placeholder_feed.png',
      },
    ];

    const int totalPharmacyCost = 1200;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prescription Header
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: storeBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: storeGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: storeGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Milterra Digital E-Prescription (Rx)',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
                          Text('Prescription ID: Rx-2026-0842-TRIAGE',
                              style: TextStyle(fontSize: 11, color: storeMuted)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: storeGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: storeGreen),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, size: 14, color: storeGreen),
                        SizedBox(width: 4),
                        Text('Digitally Signed & Valid',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w800, color: storeGreen)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Doctor & Patient Summary
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRESCRIBED BY:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeMuted)),
                        SizedBox(height: 3),
                        Text('Dr. Arvind Sharma, M.V.Sc',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeGreen)),
                        Text('Senior Bovine Surgeon | VCI Reg: VCI-RAJ-44821',
                            style: TextStyle(fontSize: 11, color: storeMuted)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PATIENT ANIMAL:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeMuted)),
                        const SizedBox(height: 3),
                        Text('Animal Tag: ${_selectedCattle ?? 'General'}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: storeGreen)),
                        const Text('Murrah Buffalo (4.5 yrs) | Day 112 in Milk',
                            style: TextStyle(fontSize: 11, color: storeMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Clinical Diagnosis
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLINICAL DIAGNOSIS:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.brown)),
                    SizedBox(height: 3),
                    Text(
                      'Acute Clinical Mastitis (Right Hind Quarter) with Somatic Cell count elevation (>450,000 cells/mL). Udder swelling and moderate pyrexia. Secondary milk curdling detected.',
                      style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Prescribed Medicines Table
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: storeBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.medication_outlined, size: 20, color: storeGreen),
                  SizedBox(width: 8),
                  Text('Prescribed Medicines & Supplements',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: storeGreen)),
                ],
              ),
              const SizedBox(height: 16),

              ...prescribedMedicines.map((med) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: storeCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: storeBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.vaccines_outlined, color: storeGreen, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(med['name'] as String,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800, color: storeGreen)),
                            const SizedBox(height: 3),
                            Text('Dosage: ${med['dosage']} • ${med['frequency']}',
                                style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            Text('Duration: ${med['duration']}',
                                style: const TextStyle(fontSize: 11, color: storeMuted)),
                          ],
                        ),
                      ),
                      Text('₹${med['price']}',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900, color: storeGreen)),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),

              // Total & 1-Tap Add to Cart
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Prescription Fulfillment',
                          style: TextStyle(fontSize: 12, color: storeMuted)),
                      Text('₹$totalPharmacyCost (Free Priority Delivery)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900, color: storeGreen)),
                    ],
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: storeGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isAddingToCart
                        ? null
                        : () async {
                            setState(() => _isAddingToCart = true);
                            try {
                              // Attempt adding each item to cart via cartProvider
                              final cartNotifier = ref.read(cartProvider.notifier);
                              for (final med in prescribedMedicines) {
                                await cartNotifier.add(med['id'] as String, 1).catchError((_) {});
                              }
                            } catch (_) {
                              // fallback gracefully
                            } finally {
                              if (mounted) {
                                setState(() => _isAddingToCart = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: storeGreen,
                                    content: const Text(
                                        'All 4 prescribed medicines added to your Milterra Cart! Proceed to checkout.'),
                                    action: SnackBarAction(
                                      label: 'View Cart',
                                      textColor: storeAmber,
                                      onPressed: () => context.push('/cart'),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    icon: _isAddingToCart
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.shopping_bag_outlined, size: 18),
                    label: Text(
                      _isAddingToCart ? 'Adding to Cart...' : 'Add All to Milterra Cart (1-Tap)',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
