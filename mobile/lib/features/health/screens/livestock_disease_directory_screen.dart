import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/livestock_disease_model.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';

class LivestockDiseaseDirectoryScreen extends ConsumerStatefulWidget {
  const LivestockDiseaseDirectoryScreen({super.key});

  @override
  ConsumerState<LivestockDiseaseDirectoryScreen> createState() =>
      _LivestockDiseaseDirectoryScreenState();
}

class _LivestockDiseaseDirectoryScreenState
    extends ConsumerState<LivestockDiseaseDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedAnimal = 'all'; // 'all', 'cow', 'buffalo', 'calf'
  String _selectedCategory = 'all'; // 'all', 'bacterial', 'viral', etc.
  String _selectedSeverity = 'all'; // 'all', 'emergency', 'urgent', 'moderate'
  String? _selectedSymptomFilter;
  String _searchQuery = '';

  // Track expanded cards
  final Set<String> _expandedDiseaseIds = {};

  final List<Map<String, String>> _animalFilters = [
    {'id': 'all', 'label': 'सभी पशु (All)'},
    {'id': 'cow', 'label': '🐄 गाय (Cow)'},
    {'id': 'buffalo', 'label': '🐃 भैंस (Buffalo)'},
    {'id': 'calf', 'label': '🐮 बछड़ा (Calf)'},
  ];

  final List<Map<String, String>> _categoryFilters = [
    {'id': 'all', 'label': 'सभी श्रेणियां (All)'},
    {'id': 'bacterial', 'label': '🦠 जीवाणु (Bacterial)'},
    {'id': 'viral', 'label': '🔬 विषाणु (Viral)'},
    {'id': 'protozoal', 'label': '🪲 चिचड़ी/प्रोटोजोआ'},
    {'id': 'metabolic', 'label': '⚡ उपापचयी (Metabolic)'},
    {'id': 'reproductive', 'label': '🤰 प्रजनन व ब्यांत'},
    {'id': 'parasitic', 'label': '🪱 परजीवी (Parasites)'},
  ];

  final List<Map<String, String>> _quickSymptomChips = [
    {'id': 'fever', 'query': 'बुखार', 'label': '🌡️ तेज बुखार'},
    {'id': 'mastitis', 'query': 'थन', 'label': '🥛 थन सूजन / छीछड़े'},
    {'id': 'bloat', 'query': 'अफारा', 'label': '🎈 पेट फूलना / गैस'},
    {'id': 'red_urine', 'query': 'लाल पेशाब', 'label': '🩸 लाल पेशाब'},
    {'id': 'lameness', 'query': 'लंगड़ा', 'label': '🦵 लंगड़ापन'},
    {'id': 'nodules', 'query': 'गांठ', 'label': '⚪ गांठें व फफोले'},
    {'id': 'scours', 'query': 'दस्त', 'label': '💧 सफेद/पतला दस्त'},
    {'id': 'placenta', 'query': 'जेर', 'label': '⏳ जेर रुकना / पांछा'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  List<LivestockDisease> _filterDiseases(List<LivestockDisease> diseases) {
    return diseases.where((d) {
      // Animal filter
      if (_selectedAnimal != 'all') {
        if (!d.animalTypes.contains(_selectedAnimal)) return false;
      }

      // Category filter
      if (_selectedCategory != 'all') {
        if (d.category.toLowerCase() != _selectedCategory) return false;
      }

      // Severity filter
      if (_selectedSeverity != 'all') {
        if (d.severity.toLowerCase() != _selectedSeverity) return false;
      }

      // Quick symptom pill filter
      if (_selectedSymptomFilter != null) {
        final query = _selectedSymptomFilter!.toLowerCase();
        final blob = [
          ...d.primarySymptoms,
          ...d.secondarySymptoms,
          d.name,
          d.hindiName,
        ].join(' ').toLowerCase();
        if (!blob.contains(query)) return false;
      }

      // Search Query (English & Hindi)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final searchCorpus = [
          d.name,
          d.hindiName,
          d.scientificName,
          d.category,
          d.categoryHindi,
          ...d.primarySymptoms,
          ...d.secondarySymptoms,
          ...d.firstAidIngredients,
          d.firstAidPreparation,
          d.firstAidApplication,
          ...d.suggestedMedicines.map((m) => '${m.molecule} ${m.tradeNames.join(" ")}'),
        ].join(' ').toLowerCase();

        if (!searchCorpus.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  void _resetAllFilters() {
    setState(() {
      _selectedAnimal = 'all';
      _selectedCategory = 'all';
      _selectedSeverity = 'all';
      _selectedSymptomFilter = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final diseasesAsync = ref.watch(livestockDiseasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('पशु रोग ज्ञानकोश (Veterinary Encyclopedia)'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'हेल्पलाइन 1962',
            icon: const Icon(Icons.emergency_outlined, color: Colors.red),
            onPressed: () => _makePhoneCall('1962'),
          ),
          IconButton(
            tooltip: 'रिफ्रेश',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(livestockDiseasesProvider),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            children: [
              // Top Emergency helpline banner
              _buildHelplineBanner(context),

              // Search Bar & Filter Section
              _buildSearchAndFilters(context),

              // Disease Cards List
              Expanded(
                child: diseasesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, stack) => _buildErrorState(context, err),
                  data: (diseases) {
                    final filtered = _filterDiseases(diseases);
                    if (filtered.isEmpty) {
                      return _buildEmptyState(context);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final disease = filtered[index];
                        final isExpanded =
                            _expandedDiseaseIds.contains(disease.id);
                        return _buildDiseaseCard(context, disease, isExpanded);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomEmergencyBar(context),
    );
  }

  Widget _buildHelplineBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.red.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'आपातकालीन पशु चिकित्सा हेल्पलाइन: 1962 (टोल फ्री 24x7)',
              style: context.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _makePhoneCall('1962'),
            child: const Text('कॉल करें 1962', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'रोग, लक्षण, दवा या देसी लेप खोजें (खुरपका, थनैला, fever...)',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
          const SizedBox(height: 8),

          // Animal Type Horizontal Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._animalFilters.map((f) {
                  final isSelected = _selectedAnimal == f['id'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(f['label']!, style: const TextStyle(fontSize: 12)),
                      selectedColor: context.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? context.colorScheme.onPrimaryContainer
                            : Colors.black87,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedAnimal = f['id']!;
                        });
                      },
                    ),
                  );
                }),
                const SizedBox(width: 8),
                // Reset Button
                if (_hasActiveFilters)
                  ActionChip(
                    avatar: const Icon(Icons.restart_alt, size: 16),
                    label: const Text('सभी हटाएं', style: TextStyle(fontSize: 12)),
                    onPressed: _resetAllFilters,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Quick Symptoms Scrollable Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'त्वरित लक्षण:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                ..._quickSymptomChips.map((chip) {
                  final isSelected = _selectedSymptomFilter == chip['query'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: isSelected,
                      label: Text(chip['label']!, style: const TextStyle(fontSize: 11)),
                      selectedColor: Colors.amber.shade200,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.brown.shade900 : Colors.black87,
                      ),
                      onSelected: (val) {
                        setState(() {
                          _selectedSymptomFilter = val ? chip['query'] : null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Category & Urgency Row
          Row(
            children: [
              // Category Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCategory,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: _categoryFilters.map((cat) {
                        return DropdownMenuItem<String>(
                          value: cat['id'],
                          child: Text(cat['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Severity Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSeverity,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('सभी गंभीरता (All Severity)'),
                        ),
                        DropdownMenuItem(
                          value: 'emergency',
                          child: Text('🚨 आपातकालीन (Emergency)'),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('⚠️ तत्काल (Urgent)'),
                        ),
                        DropdownMenuItem(
                          value: 'moderate',
                          child: Text('🟢 मध्यम (Moderate)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedSeverity = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFilters =>
      _selectedAnimal != 'all' ||
      _selectedCategory != 'all' ||
      _selectedSeverity != 'all' ||
      _selectedSymptomFilter != null ||
      _searchQuery.isNotEmpty;

  Widget _buildDiseaseCard(
    BuildContext context,
    LivestockDisease d,
    bool isExpanded,
  ) {
    final severityColor = _getSeverityColor(d.severity);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isExpanded ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpanded ? severityColor.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: isExpanded ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedDiseaseIds.remove(d.id);
            } else {
              _expandedDiseaseIds.add(d.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Hindi Title & Severity Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(d.category),
                      color: severityColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.hindiName,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${d.name} (${d.scientificName})',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Severity Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      d.severity == 'emergency'
                          ? '🚨 आपातकाल'
                          : d.severity == 'urgent'
                              ? '⚠️ तत्काल'
                              : '🟢 मध्यम',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Badges row: Category, Animals, Golden Hour
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildTagPill(
                    label: d.categoryHindi,
                    color: Colors.blueGrey,
                  ),
                  ...d.animalTypes.map(
                    (a) => _buildTagPill(
                      label: a == 'cow'
                          ? 'गाय'
                          : a == 'buffalo'
                              ? 'भैंस'
                              : 'बछड़ा',
                      color: Colors.teal,
                    ),
                  ),
                  _buildTagPill(
                    label: '⏱️ ${d.criticalWindow.split("!")[0]}',
                    color: Colors.deepOrange,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Key Primary Symptoms Preview (Always visible)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          'प्रमुख लक्षण (Key Signs):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.primarySymptoms.take(2).map((s) => '• $s').join('\n'),
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),

              // Expand / Collapse Indicator
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isExpanded ? 'संक्षिप्त करें' : 'विस्तृत जांच, देसी लेप व दवाएं देखें',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.primary,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: context.colorScheme.primary,
                  ),
                ],
              ),

              // EXPANDED PROTOCOL SECTIONS
              if (isExpanded) ...[
                const Divider(height: 24),
                _buildExpandedSections(context, d),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagPill({required String label, required MaterialColor color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color.shade900,
        ),
      ),
    );
  }

  Widget _buildExpandedSections(BuildContext context, LivestockDisease d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Symptoms & Vitals Section
        _buildSectionHeader(
          icon: Icons.monitor_heart,
          title: '1. लक्षण व तापमान (Symptoms & Vitals)',
          color: Colors.indigo,
        ),
        const SizedBox(height: 6),
        ...d.primarySymptoms.map((s) => _buildBulletText(s)),
        if (d.secondarySymptoms.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'गंभीर/उन्नत लक्षण:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          ...d.secondarySymptoms.map((s) => _buildBulletText(s, isSecondary: true)),
        ],
        const SizedBox(height: 8),
        _buildVitalsCard(d.vitals),
        const SizedBox(height: 16),

        // 2. On-Farm Testing & Diagnostics
        _buildSectionHeader(
          icon: Icons.biotech,
          title: '2. जांच का तरीका (How to Test On-Farm)',
          color: Colors.teal,
        ),
        const SizedBox(height: 6),
        _buildInfoBox(
          title: 'खेत पर तुरंत जांच (Field Test):',
          content: d.onFarmTest,
          color: Colors.teal.shade50,
          borderColor: Colors.teal.shade200,
        ),
        if (d.clinicalLabTest.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildInfoBox(
            title: 'लैब व सूक्ष्मदर्शी जांच (Lab Test):',
            content: d.clinicalLabTest,
            color: Colors.blueGrey.shade50,
            borderColor: Colors.blueGrey.shade200,
          ),
        ],
        const SizedBox(height: 16),

        // 3. Golden Hour & Seasonal Timing
        _buildSectionHeader(
          icon: Icons.timer,
          title: '3. स्वर्णिम समय (Golden Hour & Seasonal Peak)',
          color: Colors.deepOrange,
        ),
        const SizedBox(height: 6),
        _buildInfoBox(
          title: '⏱️ स्वर्णिम खिड़की (Golden Window):',
          content: d.criticalWindow,
          color: Colors.orange.shade50,
          borderColor: Colors.orange.shade300,
        ),
        const SizedBox(height: 6),
        _buildInfoBox(
          title: '📅 प्रकोप का मौसम:',
          content: d.seasonalPeak,
          color: Colors.amber.shade50,
          borderColor: Colors.amber.shade200,
        ),
        const SizedBox(height: 6),
        _buildInfoBox(
          title: '⚠️ देरी का दुष्परिणाम:',
          content: d.consequenceOfDelay,
          color: Colors.red.shade50,
          borderColor: Colors.red.shade200,
        ),
        const SizedBox(height: 16),

        // 4. First Aid (Immediate On-Farm Herbal / EVP)
        _buildSectionHeader(
          icon: Icons.eco,
          title: '4. प्रथम देसी उपचार (Immediate Farm First Aid)',
          color: Colors.green,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'आवश्यक सामग्री (Ingredients):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              ...d.firstAidIngredients.map((ing) => Text('• $ing', style: const TextStyle(fontSize: 12))),
              const Divider(height: 16),
              const Text(
                'बनाने की विधि (Preparation):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(d.firstAidPreparation, style: const TextStyle(fontSize: 12)),
              const Divider(height: 16),
              const Text(
                'प्रयोग का तरीका (Application):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(d.firstAidApplication, style: const TextStyle(fontSize: 12)),
              if (d.firstAidPrecautions.isNotEmpty) ...[
                const Divider(height: 16),
                const Text(
                  'सावधानियां (Precautions):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red),
                ),
                ...d.firstAidPrecautions.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('⚠️ $p', style: const TextStyle(fontSize: 11.5, color: Colors.red)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 5. Clinical Veterinary Aid & Suggested Medicines
        _buildSectionHeader(
          icon: Icons.medical_services,
          title: '5. द्वितीय उपचार व दवाएं (Clinical Vet Aid & Medicines)',
          color: Colors.purple,
        ),
        const SizedBox(height: 6),
        _buildInfoBox(
          title: 'डॉक्टर द्वारा नैदानिक प्रोटोकॉल:',
          content: d.clinicalProtocol,
          color: Colors.purple.shade50,
          borderColor: Colors.purple.shade200,
        ),
        if (d.ivFluids.isNotEmpty) ...[
          const SizedBox(height: 6),
          _buildInfoBox(
            title: 'नस में चढ़ाने वाले तरल (IV Fluids):',
            content: d.ivFluids,
            color: Colors.purple.shade50,
            borderColor: Colors.purple.shade200,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'सुझाई गई दवाएं (Suggested Medicines & Dosage):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 6),
        ...d.suggestedMedicines.map((m) => _buildMedicineCard(context, m)),
        const SizedBox(height: 16),

        // 6. Prevention & Vaccines
        _buildSectionHeader(
          icon: Icons.shield,
          title: '6. रोकथाम व टीकाकरण (Vaccination & Biosecurity)',
          color: Colors.blue,
        ),
        const SizedBox(height: 6),
        if (d.vaccineName != null) ...[
          _buildInfoBox(
            title: '💉 टीका (Vaccine): ${d.vaccineName}',
            content: d.vaccineSchedule ?? '',
            color: Colors.blue.shade50,
            borderColor: Colors.blue.shade200,
          ),
          const SizedBox(height: 6),
        ],
        ...d.biosecurity.map((bio) => _buildBulletText('🛡️ $bio')),
        const SizedBox(height: 16),

        // Card Bottom Action Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('स्वास्थ्य रिकॉर्ड में जोड़ें', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  context.push('/health/add-record');
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.call, size: 16),
              label: const Text('हेल्पलाइन 1962', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _makePhoneCall('1962'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMedicineCard(BuildContext context, MedicineItem m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.molecule,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  m.route,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'ब्रांड नाम: ${m.tradeNames.join(", ")}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            'खुराक (Dosage): ${m.dosage}',
            style: const TextStyle(fontSize: 11.5),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.water_drop, size: 14, color: Colors.blue),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'दूध निकासी (Milk Withdrawal): ${m.milkWithdrawal}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: m.milkWithdrawal.startsWith('0')
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
          if (m.notes != null) ...[
            const SizedBox(height: 2),
            Text(
              'नोट: ${m.notes}',
              style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsCard(DiseaseVitals vitals) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildVitalCol('तापमान (°F)', vitals.temperatureF, Icons.thermostat),
          _buildVitalCol('धड़कन (HR)', vitals.heartRateBpm, Icons.favorite),
          _buildVitalCol('सांस (RR)', vitals.respirationRateBpm, Icons.air),
          _buildVitalCol('रूमेन गति', vitals.rumenMotility, Icons.replay),
        ],
      ),
    );
  }

  Widget _buildVitalCol(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.indigo.shade700),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required MaterialColor color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.shade700),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletText(String text, {bool isSecondary = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSecondary ? Colors.red : Colors.grey.shade800,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isSecondary ? Colors.red.shade900 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required String title,
    required String content,
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(content, style: const TextStyle(fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }

  Widget _buildBottomEmergencyBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.smart_toy_outlined, size: 18),
              label: const Text('AI निदान (AI Triage)'),
              onPressed: () => context.push('/health/triage'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.local_hospital, size: 18),
              label: const Text('पशु चिकित्सक खोजें'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.push('/more/vet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'कोई बीमारी नहीं मिली',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'दिए गए फ़िल्टर या खोज शब्द से मेल खाती कोई बीमारी नहीं मिली।',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetAllFilters,
              child: const Text('सभी फ़िल्टर हटाएं (Reset)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 12),
            Text('डेटा लोड करने में त्रुटि: $err'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(livestockDiseasesProvider),
              child: const Text('पुनः प्रयास करें'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'emergency':
        return Colors.red.shade700;
      case 'urgent':
        return Colors.orange.shade800;
      case 'moderate':
      default:
        return Colors.green.shade700;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'bacterial':
        return Icons.coronavirus;
      case 'viral':
        return Icons.scatter_plot;
      case 'protozoal':
        return Icons.pest_control;
      case 'metabolic':
        return Icons.bolt;
      case 'reproductive':
        return Icons.pregnant_woman;
      case 'parasitic':
        return Icons.bug_report;
      default:
        return Icons.medical_services;
    }
  }
}
