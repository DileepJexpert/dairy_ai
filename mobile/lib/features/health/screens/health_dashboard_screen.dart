import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart';

/// Herd health filter categories for traffic-light triage.
enum HerdFilter { all, critical, watchlist, healthy }

/// Health overview dashboard showing 100-cow herd triage, active issues,
/// upcoming vaccinations, sensor alerts, and a quick-access button for AI triage.
class HealthDashboardScreen extends ConsumerStatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  ConsumerState<HealthDashboardScreen> createState() =>
      _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends ConsumerState<HealthDashboardScreen> {
  HerdFilter _selectedFilter = HerdFilter.all;
  bool _showArchitectureInfo = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: context.canPop()
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                )
              : IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () => context.go('/home'),
                ),
          title: const Text('Herd Health & Crisis Monitor'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(activeHealthIssuesProvider);
                ref.invalidate(upcomingVaccinationsProvider);
                ref.invalidate(sensorAlertsProvider);
              },
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(activeHealthIssuesProvider);
                ref.invalidate(upcomingVaccinationsProvider);
                ref.invalidate(sensorAlertsProvider);
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- 100-Cow Unified Herd Triage Control Center ---
                  _buildHerdTriageHeader(context),
                  const SizedBox(height: 12),

                  // --- Collapsible Architecture & Telemetry Timing Card ---
                  _buildArchitectureCard(context),
                  const SizedBox(height: 16),

                  // --- Filter Chips & Tag Search Bar ---
                  _buildFilterAndSearchBar(context),
                  const SizedBox(height: 14),

                  // --- Triage Cattle Cards (Ganga, Radha, Murrah, Healthy herd) ---
                  ..._buildTriageCattleCards(context),
                  const SizedBox(height: 20),

                  // --- AI Triage Quick Access ---
                  _TriageQuickAccessCard(),
                  const SizedBox(height: 12),
                  _DiseaseEncyclopediaCard(),
                  const SizedBox(height: 12),
                  const _PashuCreditHealthCard(),
                  const SizedBox(height: 20),

                  // --- Sensor Alerts ---
                  const _SectionHeader(
                    title: 'Live Sensor Alerts ( Collar & Tag Stream )',
                    icon: Icons.sensors,
                    iconColor: Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _SensorAlertsSection(),
                  const SizedBox(height: 20),

                  // --- Active Health Issues ---
                  const _SectionHeader(
                    title: 'Active Clinical Cases',
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  _ActiveIssuesSection(),
                  const SizedBox(height: 16),

                  // --- Agri-Hub Herd Care Supplies ---
                  const _AgriHubHerdCareBanner(),
                  const SizedBox(height: 20),

                  // --- Upcoming Vaccinations ---
                  const _SectionHeader(
                    title: 'Upcoming Vaccinations',
                    icon: Icons.vaccines,
                    iconColor: Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  _UpcomingVaccinationsSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            context.push('/health/add-record');
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Record'),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top 100-Cow Herd Triage Summary Banner
  // ---------------------------------------------------------------------------
  Widget _buildHerdTriageHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff0f172a), Color(0xff1e293b)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade400, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub, color: Colors.blueAccent, size: 14),
                    SizedBox(width: 6),
                    Text(
                      '100 पशु झुंड ट्रायज (100-Cow Herd Triage)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xff22c55e).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '94% Herd Safe',
                  style: TextStyle(
                    color: Color(0xff4ade80),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'अपवाद-आधारित क्लिनिकल कमान केंद्र (Exception-Based Command)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '100 पशुओं में से केवल 6 को तत्काल ध्यान की आवश्यकता है। 94 पशु सामान्य हैं।',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          // Traffic-Light Counter Row
          Row(
            children: [
              Expanded(
                child: _buildTriageCounterPill(
                  label: '🔴 ICU क्रिटिकल',
                  count: '2',
                  subtext: 'गंगा व राधा (तत्काल)',
                  bgColor: Colors.red.shade900.withValues(alpha: 0.4),
                  borderColor: Colors.redAccent,
                  textColor: Colors.redAccent.shade100,
                  onTap: () {
                    setState(() => _selectedFilter = HerdFilter.critical);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTriageCounterPill(
                  label: '🟡 वॉचलिस्ट/हीट',
                  count: '4',
                  subtext: 'मुर्रा + 3 पशु',
                  bgColor: Colors.amber.shade900.withValues(alpha: 0.4),
                  borderColor: Colors.amber,
                  textColor: Colors.amber.shade200,
                  onTap: () {
                    setState(() => _selectedFilter = HerdFilter.watchlist);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTriageCounterPill(
                  label: '🟢 स्वस्थ झुंड',
                  count: '94',
                  subtext: 'सामान्य चराई',
                  bgColor: Colors.green.shade900.withValues(alpha: 0.4),
                  borderColor: Colors.greenAccent,
                  textColor: Colors.greenAccent.shade100,
                  onTap: () {
                    setState(() => _selectedFilter = HerdFilter.healthy);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTriageCounterPill({
    required String label,
    required String count,
    required String subtext,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor.withValues(alpha: 0.6), width: 1.2),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtext,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 9.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Expandable Architecture & Timing Explanation Card
  // ---------------------------------------------------------------------------
  Widget _buildArchitectureCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffcbd5e1)),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.settings_input_antenna, color: Color(0xff2563eb)),
            title: const Text(
              '📡 डिवाइस इवेंट कब भेजता है व AI अलर्ट कैसे तय होता है?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xff0f172a),
              ),
            ),
            subtitle: Text(
              _showArchitectureInfo
                  ? 'हार्डवेयर ड्यूल-कैडेंस टाइमिंग व क्लाउड डिसीजन इंजन'
                  : 'टैप करके हार्डवेयर टाइमिंग व क्लिनिकल निर्णय आर्किटेक्चर समझें',
              style: const TextStyle(fontSize: 11, color: Color(0xff64748b)),
            ),
            trailing: Icon(
              _showArchitectureInfo ? Icons.expand_less : Icons.expand_more,
              color: const Color(0xff2563eb),
            ),
            onTap: () {
              setState(() => _showArchitectureInfo = !_showArchitectureInfo);
            },
          ),
          if (_showArchitectureInfo) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildArchDetailTile(
                    icon: Icons.timer,
                    iconColor: Colors.blue,
                    title: '1. ट्रांसमिशन टाइमिंग (Dual-Cadence Hardware Timing):',
                    desc:
                        '• ⏱️ 15-मिनट हार्टबीट (सामान्य): कॉलर हर 15 मिनट में जागकर 15-मिनट का औसत डेटा (तापमान, जुगाली, कदम) भेजता है ताकि बैटरी 3-5 वर्ष चले।\n• ⚡ 3-5 सेकंड आपातकालीन इंटरप्ट: यदि गाय 60 मिनट से अचेत/गिरा हुआ है (Downer) या बुखार >40.2°C है, तो एक्सेलेरोमीटर चिप 3 से 5 सेकंड में तुरंत SOS पैकेट भेजती है।',
                  ),
                  const SizedBox(height: 10),
                  _buildArchDetailTile(
                    icon: Icons.cloud_done,
                    iconColor: Colors.purple,
                    title: '2. निर्णय कहाँ होता है? (Device vs Cloud Server):',
                    desc:
                        '• डिवाइस केवल "कच्चा डेटा (Raw Sensor)" भेजता है।\n• अलर्ट का अंतिम निर्णय Cloudflare Workers AI में 7-दिवसीय रोलिंग बेसलाइन से होता है। जब 5 लक्षण एक साथ बिगड़ते हैं (बुखार 40.8°C + 0 कदम + जुगाली बंद), तभी ICU रेड अलर्ट घोषित होता है। क्षणिक धूप का स्पाइक स्वतः डी-बाउंस हो जाता है।',
                  ),
                  const SizedBox(height: 10),
                  _buildArchDetailTile(
                    icon: Icons.dashboard_customize,
                    iconColor: Colors.green,
                    title: '3. 100 पशुओं का स्केलेबल प्रबंधन (Master-Detail System):',
                    desc:
                        '• किसान को 100 स्क्रीन नहीं देखने पड़ते।\n• एक ही स्क्रीन पर ऊपर केवल 2 रेड कार्ड और 4 येलो कार्ड दिखते हैं, जबकि 94 स्वस्थ पशु एक ही हरे ग्रुप में संकलित रहते हैं।\n• गंगा (#MIL-0842) पर क्लिक करते ही सीधे उसका 5-संकट ICU टेलीमेट्री कक्ष खुलता है।',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArchDetailTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1e293b),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: Color(0xff475569),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Interactive Filter Chips & Search Bar
  // ---------------------------------------------------------------------------
  Widget _buildFilterAndSearchBar(BuildContext context) {
    return Column(
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('सभी (100)', HerdFilter.all, Colors.blueGrey),
              const SizedBox(width: 8),
              _buildFilterChip('🚨 आपातकाल ICU (2)', HerdFilter.critical, Colors.red),
              const SizedBox(width: 8),
              _buildFilterChip('🟡 हीट व वॉचलिस्ट (4)', HerdFilter.watchlist, Colors.amber.shade800),
              const SizedBox(width: 8),
              _buildFilterChip('🟢 स्वस्थ पशु (94)', HerdFilter.healthy, Colors.green),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Search Input
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'टैग ID या नाम खोजें (e.g. 0842, Ganga, Radha, 1024)...',
            hintStyle: const TextStyle(fontSize: 12.5),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (val) {
            setState(() => _searchQuery = val.trim().toLowerCase());
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, HerdFilter filter, Color color) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : color,
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: isSelected ? 1 : 0.4)),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = filter);
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dynamic Cattle Cards Based on Triage Filter & Search
  // ---------------------------------------------------------------------------
  List<Widget> _buildTriageCattleCards(BuildContext context) {
    final cards = <Widget>[];

    bool matchesSearch(String name, String tag, String note) {
      if (_searchQuery.isEmpty) return true;
      return name.toLowerCase().contains(_searchQuery) ||
          tag.toLowerCase().contains(_searchQuery) ||
          note.toLowerCase().contains(_searchQuery);
    }

    // 1. Critical Cattle: Ganga
    if ((_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.critical) &&
        matchesSearch('Ganga (गाय)', 'MIL-0842', 'Hyperpyrexia Mastitis Downer')) {
      cards.add(
        _buildCriticalCattleCard(
          context: context,
          name: 'गंगा (Ganga) - गाय',
          tagId: 'MIL-0842',
          urgencyBadge: '🔴 CRITICAL ICU (5 संकट एक साथ)',
          vitalsBadges: [
            '🌡️ बुखार 40.8°C (अति-तीव्र)',
            '🥛 एक्यूट थनैला (SCC 1.8M)',
            '🦽 डाउनर (0 कदम 2h)',
            '⏳ जुगाली बंद (5h स्टैसिस)',
            '🛑 गर्भाधान स्थगित (21 दिन)',
          ],
          aiDiagnosis:
              'AI क्लिनिकल सिंथेसिस: एंडोटॉक्सिक कोलॉर्म मैस्टाइटिस व हाइपरपाइरेक्सिया। तुरंत वेन में एंटीबायोटिक, फ्लुइड व एनएसएआईडी आवश्यक।',
          onTapIcu: () => context.push('/health/emergency-crisis'),
          onTapSosVet: () async {
            final uri = Uri.parse('tel:+919876543210');
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
        ),
      );
      cards.add(const SizedBox(height: 12));
    }

    // 2. Critical Cattle: Radha
    if ((_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.critical) &&
        matchesSearch('Radha (गाय)', 'MIL-0914', 'Ketosis Downer Stasis')) {
      cards.add(
        _buildCriticalCattleCard(
          context: context,
          name: 'राधा (Radha) - गाय',
          tagId: 'MIL-0914',
          urgencyBadge: '🔴 CRITICAL ICU (गंभीर कीटोसिस व डाउनर)',
          vitalsBadges: [
            '🦽 0 हलचल 75 मिनट',
            '📉 जुगाली -82% गिरावट',
            '🌡️ शारीरिक तापमान 39.9°C',
            '🥛 दूध उत्पादन -60%',
          ],
          aiDiagnosis:
              'AI क्लिनिकल सिंथेसिस: टाइप-1 क्लिनिकल कीटोसिस व ऊर्जा संकट। ओरल प्रोपलीन ग्लाइकोल व 40% डेक्सट्रोज़ ड्रिप की आवश्यकता।',
          onTapIcu: () => context.push('/health/emergency-crisis'),
          onTapSosVet: () async {
            final uri = Uri.parse('tel:+919876543210');
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
        ),
      );
      cards.add(const SizedBox(height: 12));
    }

    // 3. Watchlist Cattle: Murrah Buffalo
    if ((_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.watchlist) &&
        matchesSearch('Murrah (भैंस)', 'MIL-1024', 'Heat Detection Breeding')) {
      cards.add(
        _buildWatchlistCattleCard(
          context: context,
          name: 'मुर्रा (Murrah) - भैंस',
          tagId: 'MIL-1024',
          statusBadge: '🔥 चरम गर्भाधान स्वर्णिम समय (Peak Heat)',
          badgeColor: Colors.amber.shade900,
          vitalsBadges: [
            '⏰ अगले 4 घंटे में सीमेन गर्भाधान अनिवार्य',
            '📈 सक्रियता +180% (890 कदम)',
            '🥛 हल्का दूध ड्रॉप (-1.2L)',
            '❤️ हीट स्कोर 94/100',
          ],
          actionText: 'AI गर्भाधान टाइमर खोलें',
          onTapAction: () => context.push('/breeding/heat-detection'),
        ),
      );
      cards.add(const SizedBox(height: 12));
    }

    // 4. Watchlist Cattle: Lakshmi
    if ((_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.watchlist) &&
        matchesSearch('Lakshmi (गाय)', 'MIL-0721', 'Subclinical Mastitis')) {
      cards.add(
        _buildWatchlistCattleCard(
          context: context,
          name: 'लक्ष्मी (Lakshmi) - गाय',
          tagId: 'MIL-0721',
          statusBadge: '🟡 सब-क्लिनिकल थनैला पूर्व चेतावनी',
          badgeColor: Colors.orange.shade800,
          vitalsBadges: [
            '⚠️ दूध सोमैटिक सेल काउंट (SCC) प्रारंभिक वृद्धि',
            '🥛 बायाँ पिछला थन हल्का कठोर',
            '🌡️ तापमान 38.9°C (हल्का बढ़ा)',
          ],
          actionText: 'देसी हर्बल लेप व उपचार देखें',
          onTapAction: () => context.push('/health/diseases'),
        ),
      );
      cards.add(const SizedBox(height: 12));
    }

    // 5. Watchlist Cattle: Shama
    if ((_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.watchlist) &&
        matchesSearch('Shama (गाय)', 'MIL-0512', 'Acidosis SARA Feed')) {
      cards.add(
        _buildWatchlistCattleCard(
          context: context,
          name: 'श्यामा (Shama) - गाय',
          tagId: 'MIL-0512',
          statusBadge: '🟡 चारा सेवन ड्रॉप (SARA एसिडोसिस निगरानी)',
          badgeColor: Colors.orange.shade800,
          vitalsBadges: [
            '📉 चारा सेवन 25% कम',
            '⏳ दैनिक जुगाली 280 मिनट (नॉर्मल 480m)',
            '🧪 रूमेन बफरिंग पाउडर आवश्यक',
          ],
          actionText: 'हेल्थ रिकॉर्ड विवरण देखें',
          onTapAction: () => context.push('/health/add-record'),
        ),
      );
      cards.add(const SizedBox(height: 12));
    }

    // 6. Healthy Herd Block (94 Cattle)
    if ((_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.healthy) &&
        (_searchQuery.isEmpty || 'healthy स्वस्थ herd झुंड 94'.contains(_searchQuery))) {
      cards.add(_buildHealthyHerdBlock(context));
    }

    if (cards.isEmpty) {
      cards.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'कोई पशु मेल नहीं खाया (No matching cattle found)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return cards;
  }

  Widget _buildCriticalCattleCard({
    required BuildContext context,
    required String name,
    required String tagId,
    required String urgencyBadge,
    required List<String> vitalsBadges,
    required String aiDiagnosis,
    required VoidCallback onTapIcu,
    required VoidCallback onTapSosVet,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfffef2f2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade400, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emergency, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      urgencyBadge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'टैग: #$tagId',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xff991b1b),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xff7f1d1d),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: vitalsBadges
                .map(
                  (b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      b,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff991b1b),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    aiDiagnosis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: Color(0xff7f1d1d),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: onTapIcu,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text(
                    '🚨 आपातकालीन ICU कक्ष खोलें',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onTapSosVet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade900,
                    side: BorderSide(color: Colors.red.shade700, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text(
                    'SOS डॉक्टर',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistCattleCard({
    required BuildContext context,
    required String name,
    required String tagId,
    required String statusBadge,
    required Color badgeColor,
    required List<String> vitalsBadges,
    required String actionText,
    required VoidCallback onTapAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfffffbeb),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade400, width: 1.2),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusBadge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'टैग: #$tagId',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff78350f),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: vitalsBadges
                .map(
                  (b) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTapAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: badgeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                actionText,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyHerdBlock(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff86efac), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff16a34a).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Color(0xff16a34a), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '94 पशु पूरी तरह स्वस्थ और सामान्य हैं',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff14532d),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'सामान्य चारा, जुगाली व दुग्ध उत्पादन • शून्य क्राइसिस अलर्ट',
                      style: TextStyle(fontSize: 11, color: Color(0xff166534)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffbbf7d0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _HerdStat(label: 'औसत तापमान', val: '38.5°C', status: 'सामान्य'),
                _HerdStat(label: 'औसत जुगाली', val: '492 min/दिन', status: 'उत्तम'),
                _HerdStat(label: 'औसत कदम', val: '3,240 कदम', status: 'सक्रिय'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'स्वस्थ पशु टैग सूचकांक (Tags 0001 to 0094):',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              '#MIL-0001',
              '#MIL-0002',
              '#MIL-0003',
              '#MIL-0004',
              '#MIL-0005',
              '#MIL-0006',
              '#MIL-0007',
              '... +87 और स्वस्थ पशु',
            ]
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffdcfce7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff15803d),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _HerdStat extends StatelessWidget {
  final String label;
  final String val;
  final String status;
  const _HerdStat({required this.label, required this.val, required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xff14532d))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xffdcfce7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xff15803d)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// AI Triage quick-access card
// ---------------------------------------------------------------------------
class _TriageQuickAccessCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/health/triage');
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.medical_services,
                  color: context.colorScheme.onPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Health Triage',
                      style: context.textTheme.titleMedium?.copyWith(
                        color: context.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Report symptoms and get instant AI diagnosis',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: context.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Livestock Disease Directory card
// ---------------------------------------------------------------------------
class _DiseaseEncyclopediaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/health/diseases');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.teal.shade700,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'पशु रोग ज्ञानकोश',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'देसी लेप व दवाएं',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '15+ प्रमुख रोग: लक्षण, जांच विधि, स्वर्णिम समय, प्राथमिक देसी उपचार व दूध निकासी सुरक्षा',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.teal.shade900.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.teal.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pashu CIBIL Credit & Loan Banner in Health Screen
// ---------------------------------------------------------------------------
class _PashuCreditHealthCard extends StatelessWidget {
  const _PashuCreditHealthCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff0fdf4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff86efac)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/finance/pashu-credit'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff16a34a).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: Color(0xff16a34a),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'हेल्थ समर्थित KCC लोन @ 4%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: Color(0xff14532d),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xffdcfce7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Pashu CIBIL',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff15803d),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'टीकाकरण व कम रोग जोखिम से पाएं पूर्व-स्वीकृत ₹1.6-3 लाख व 50% बीमा छूट',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: const Color(0xff166534).withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color(0xff16a34a),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sensor alerts section
// ---------------------------------------------------------------------------
class _SensorAlertsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(sensorAlertsProvider);

    return alertsAsync.when(
      loading: () => const _ShimmerPlaceholder(height: 80),
      error: (_, __) => const _EmptyTile(
        icon: Icons.check_circle_outline,
        message: 'No sensor alerts. All cattle vitals are normal.',
      ),
      data: (alerts) {
        if (alerts.isEmpty) {
          return const _EmptyTile(
            icon: Icons.check_circle_outline,
            message: 'No sensor alerts. All cattle vitals are normal.',
          );
        }
        return Column(
          children: alerts.map((alert) => _SensorAlertTile(alert: alert)).toList(),
        );
      },
    );
  }
}

class _SensorAlertTile extends StatelessWidget {
  final SensorAlert alert;
  const _SensorAlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final isTemp = alert.alertType == 'high_temp';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isTemp ? Colors.red : Colors.orange).withValues(alpha: 0.15),
          child: Icon(
            isTemp ? Icons.thermostat : Icons.monitor_heart,
            color: isTemp ? Colors.red : Colors.orange,
          ),
        ),
        title: Text(
          alert.cattleName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${alert.alertLabel}: ${alert.value.toStringAsFixed(1)} ${alert.unit}',
        ),
        trailing: Text(
          _timeAgo(alert.timestamp),
          style: context.textTheme.bodySmall,
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Active health issues section
// ---------------------------------------------------------------------------
class _ActiveIssuesSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issuesAsync = ref.watch(activeHealthIssuesProvider);

    return issuesAsync.when(
      loading: () => const _ShimmerPlaceholder(height: 80),
      error: (_, __) => const _EmptyTile(
        icon: Icons.favorite,
        message: 'No active health issues. Great job!',
      ),
      data: (issues) {
        if (issues.isEmpty) {
          return const _EmptyTile(
            icon: Icons.favorite,
            message: 'No active health issues. Great job!',
          );
        }
        return Column(
          children: issues.map((record) => _HealthIssueTile(record: record)).toList(),
        );
      },
    );
  }
}

class _HealthIssueTile extends StatelessWidget {
  final HealthRecord record;
  const _HealthIssueTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.withValues(alpha: 0.15),
          child: const Icon(Icons.sick, color: Colors.red),
        ),
        title: Text(
          record.cattleName ?? 'Cattle #${record.cattleId}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          record.symptoms.isNotEmpty
              ? record.symptoms.join(', ')
              : record.type.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _TypeChip(type: record.type),
        onTap: () {
          // Navigate to health record detail if needed.
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final HealthRecordType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (type) {
      case HealthRecordType.illness:
        bg = Colors.red;
        break;
      case HealthRecordType.surgery:
        bg = Colors.purple;
        break;
      case HealthRecordType.treatment:
        bg = Colors.orange;
        break;
      case HealthRecordType.checkup:
        bg = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.name[0].toUpperCase() + type.name.substring(1),
        style: TextStyle(fontSize: 11, color: bg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming vaccinations section
// ---------------------------------------------------------------------------
class _UpcomingVaccinationsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vacAsync = ref.watch(upcomingVaccinationsProvider);

    return vacAsync.when(
      loading: () => const _ShimmerPlaceholder(height: 80),
      error: (_, __) => const _EmptyTile(
        icon: Icons.vaccines,
        message: 'No upcoming vaccinations.',
      ),
      data: (vaccinations) {
        if (vaccinations.isEmpty) {
          return const _EmptyTile(
            icon: Icons.vaccines,
            message: 'No upcoming vaccinations.',
          );
        }
        return Column(
          children: vaccinations
              .map((v) => _VaccinationTile(vaccination: v))
              .toList(),
        );
      },
    );
  }
}

class _VaccinationTile extends StatelessWidget {
  final Vaccination vaccination;
  const _VaccinationTile({required this.vaccination});

  @override
  Widget build(BuildContext context) {
    final isOverdue = vaccination.isOverdue;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.15),
          child: Icon(
            Icons.vaccines,
            color: isOverdue ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          vaccination.cattleName ?? 'Cattle #${vaccination.cattleId}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(vaccination.vaccineName),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (isOverdue ? Colors.red : Colors.blue).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isOverdue ? 'OVERDUE' : 'Upcoming',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOverdue ? Colors.red : Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------
class _EmptyTile extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTile({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: context.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerPlaceholder extends StatelessWidget {
  final double height;
  const _ShimmerPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator.adaptive()),
      ),
    );
  }
}

class _AgriHubHerdCareBanner extends StatelessWidget {
  const _AgriHubHerdCareBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff5f8f5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xff1b4332).withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xff1b4332).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services_outlined,
                  color: Color(0xff1b4332),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Milterra Agri-Hub Veterinary & Care Supplies',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff1b4332),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Emergency drench, mineral nutrition & hygiene supplies',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep your herd protected. Rapid delivery of high-potency oral calcium, chelated trace minerals with live yeast, and herbal udder hygiene solutions.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xff333333),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(
                  Icons.local_pharmacy,
                  size: 16,
                  color: Color(0xff1b4332),
                ),
                label: const Text('Cal-Gold Drench (₹1,150)'),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b4332),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: const Color(0xff1b4332).withValues(alpha: 0.3),
                  ),
                ),
                onPressed: () => context.push('/shop/product/feed-calcium-5l'),
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Color(0xff1b4332),
                ),
                label: const Text('Chelated Minerals (₹890)'),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b4332),
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: const Color(0xff1b4332).withValues(alpha: 0.3),
                  ),
                ),
                onPressed: () => context.push('/shop/product/feed-mineral-5'),
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.storefront,
                  size: 16,
                  color: Color(0xff1b4332),
                ),
                label: const Text('All Farm Essentials →'),
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1b4332),
                ),
                backgroundColor: const Color(0xff1b4332).withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: const Color(0xff1b4332).withValues(alpha: 0.4),
                  ),
                ),
                onPressed: () => context.push('/shop?category=Animal nutrition'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
