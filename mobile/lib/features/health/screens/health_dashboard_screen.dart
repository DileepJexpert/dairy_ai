import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dairy_ai/core/extensions.dart';
import 'package:dairy_ai/features/health/models/health_models.dart';
import 'package:dairy_ai/features/health/providers/health_provider.dart'
    hide cattleListProvider;
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/herd/providers/cattle_provider.dart';
import 'package:dairy_ai/features/herd/models/cattle_model.dart';
import 'package:dairy_ai/features/health/providers/active_crises_provider.dart';
import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';
import 'package:dairy_ai/shared/widgets/farmer_responsive.dart';

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
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );
    final farmerUser = authState.maybeWhen(
      authenticated: (user) => user,
      orElse: () => null,
    );

    final cattleAsync = ref.watch(cattleListProvider(farmerUser?.id ?? ''));
    final crisesAsync = ref.watch(activeCrisesProvider);
    final allCattle = cattleAsync.asData?.value ?? const <Cattle>[];
    final activeCrises = crisesAsync.asData?.value ?? const ActiveCrises();

    final criticalCattle = allCattle
        .where((c) => activeCrises.crises.any((cr) => cr.cattleId == c.id && cr.isCritical))
        .toList();
    final watchlistCattle = allCattle
        .where((c) =>
            activeCrises.crises.any((cr) => cr.cattleId == c.id && !cr.isCritical) ||
            activeCrises.breedingAlerts.any((b) => b.cattleId == c.id))
        .toList();
    final healthyCattle = allCattle
        .where((c) => !criticalCattle.contains(c) && !watchlistCattle.contains(c))
        .toList();
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
          title: Text(
            FarmerBreakpoints.isMobile(context)
                ? 'Herd Health'
                : 'Herd Health & Crisis Monitor',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(activeHealthIssuesProvider);
                ref.invalidate(upcomingVaccinationsProvider);
                ref.invalidate(sensorAlertsProvider);
              },
            ),
            const FarmerAuthAction(nextRoute: '/health'),
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
                  if (!isAuthenticated) ...[
                    _buildUnauthenticatedHealthCard(context),
                    const SizedBox(height: 16),
                  ] else if (allCattle.isEmpty) ...[
                    _buildEmptyHerdHealthCard(context),
                    const SizedBox(height: 16),
                  ] else ...[
                    // --- Unified Dynamic Herd Triage Control Center ---
                    _buildHerdTriageHeader(
                      context,
                      total: allCattle.length,
                      critical: criticalCattle.length,
                      watchlist: watchlistCattle.length,
                      healthy: healthyCattle.length,
                    ),
                    const SizedBox(height: 12),

                    // --- Collapsible Architecture & Telemetry Timing Card ---
                    _buildArchitectureCard(context),
                    const SizedBox(height: 16),

                    // --- Filter Chips & Tag Search Bar ---
                    _buildFilterAndSearchBar(
                      context,
                      total: allCattle.length,
                      critical: criticalCattle.length,
                      watchlist: watchlistCattle.length,
                      healthy: healthyCattle.length,
                    ),
                    const SizedBox(height: 14),

                    // --- Dynamic Triage Cattle Cards (Farmer's Own Cattle Only) ---
                    ..._buildTriageCattleCards(
                      context: context,
                      allCattle: allCattle,
                      crises: activeCrises.crises,
                      breedingAlerts: activeCrises.breedingAlerts,
                    ),
                    const SizedBox(height: 20),
                  ],

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

  Widget _buildUnauthenticatedHealthCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffcbd5e1), width: 1.2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.health_and_safety_outlined, color: Color(0xff2563eb), size: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            'पशु झुंड स्वास्थ्य और क्राइसिस मॉनिटर',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff0f172a),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'अपने पशुओं के वास्तविक समय के आईओटी कॉलर अलर्ट, तापमान, जुगाली व आपातकालीन स्वास्थ्य स्थिति देखने के लिए लॉगिन करें।',
            style: TextStyle(fontSize: 12.5, color: Color(0xff64748b), height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2563eb),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('लॉगिन करें या नया खाता बनाएं', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHerdHealthCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe2e8f0), width: 1.2),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xff059669).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets_outlined, color: Color(0xff059669), size: 40),
          ),
          const SizedBox(height: 14),
          const Text(
            'आपके झुंड में अभी कोई पशु दर्ज नहीं है',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff0f172a),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'आईओटी कॉलर टेलीमेट्री, क्राइसिस मॉनिटर और क्लिनिकल अलर्ट केवल आपके पंजीकृत पशुओं के लिए दिखाए जाते हैं।',
            style: TextStyle(fontSize: 12.5, color: Color(0xff64748b), height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/herd/add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+ अपना पहला पशु जोड़ें (Register Cattle)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Herd Triage Summary Banner
  // ---------------------------------------------------------------------------
  Widget _buildHerdTriageHeader(
    BuildContext context, {
    required int total,
    required int critical,
    required int watchlist,
    required int healthy,
  }) {
    final safePercent = total > 0 ? ((healthy / total) * 100).round() : 100;
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub, color: Colors.blueAccent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '$total पशु झुंड ट्रायज ($total-Cow Herd Triage)',
                      style: const TextStyle(
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
                child: Text(
                  '$safePercent% Herd Safe',
                  style: const TextStyle(
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
            total > 0
                ? 'कुल $total पशुओं में से ${critical + watchlist} को ध्यान की आवश्यकता है। $healthy पशु सुरक्षित व सामान्य हैं।'
                : 'वर्तमान में झुंड सुरक्षित है।',
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
                  count: '$critical',
                  subtext: critical > 0 ? '$critical पशु तत्काल' : 'कोई केस नहीं',
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
                  count: '$watchlist',
                  subtext: watchlist > 0 ? '$watchlist पशु निगरानी' : 'कोई अलर्ट नहीं',
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
                  count: '$healthy',
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
  Widget _buildFilterAndSearchBar(
    BuildContext context, {
    required int total,
    required int critical,
    required int watchlist,
    required int healthy,
  }) {
    return Column(
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('सभी ($total)', HerdFilter.all, Colors.blueGrey),
              const SizedBox(width: 8),
              _buildFilterChip('🚨 आपातकाल ICU ($critical)', HerdFilter.critical, Colors.red),
              const SizedBox(width: 8),
              _buildFilterChip('🟡 हीट व वॉचलिस्ट ($watchlist)', HerdFilter.watchlist, Colors.amber.shade800),
              const SizedBox(width: 8),
              _buildFilterChip('🟢 स्वस्थ पशु ($healthy)', HerdFilter.healthy, Colors.green),
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
  List<Widget> _buildTriageCattleCards({
    required BuildContext context,
    required List<Cattle> allCattle,
    required List<CattleCrisis> crises,
    required List<BreedingAlert> breedingAlerts,
  }) {
    final cards = <Widget>[];

    bool matchesSearch(String name, String tag, String note) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return name.toLowerCase().contains(q) ||
          tag.toLowerCase().contains(q) ||
          note.toLowerCase().contains(q);
    }

    // 1. Critical Cattle (Scoped to farmer's own cattle)
    if (_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.critical) {
      for (final cattle in allCattle) {
        final cattleCrises = crises.where((cr) => cr.cattleId == cattle.id && cr.isCritical).toList();
        if (cattleCrises.isEmpty) continue;
        final crisis = cattleCrises.first;
        final vitalsBadges = crisis.alerts.map((a) {
          final valStr = a.currentValue != null ? ' (${a.currentValue})' : '';
          return '${a.alertType}$valStr: ${a.message}';
        }).toList();

        if (!matchesSearch(cattle.name, cattle.tagId, crisis.alerts.map((a) => a.message).join(' '))) {
          continue;
        }

        cards.add(
          _buildCriticalCattleCard(
            context: context,
            name: '${cattle.name} (${cattle.breed})',
            tagId: cattle.tagId,
            urgencyBadge: '🔴 CRITICAL ICU (${crisis.alerts.length} संकट अलर्ट)',
            vitalsBadges: vitalsBadges.isNotEmpty ? vitalsBadges : ['🚨 आपातकालीन क्लिनिकल अलर्ट'],
            aiDiagnosis: crisis.alerts.isNotEmpty
                ? 'AI क्लिनिकल सिंथेसिस: ${crisis.alerts.map((a) => a.message).join(' • ')}'
                : 'AI क्लिनिकल सिंथेसिस: पशु के वाइटल्स असामान्य हैं, तत्काल पशुचिकित्सक जांच की आवश्यकता है।',
            onTapIcu: () => context.push('/health/emergency-crisis?cattleId=${cattle.id}'),
            onTapSosVet: () async {
              final uri = Uri.parse('tel:+919876543210');
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
        );
        cards.add(const SizedBox(height: 12));
      }
    }

    // 2. Watchlist Cattle (Non-critical crises or breeding alerts)
    if (_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.watchlist) {
      for (final cattle in allCattle) {
        final nonCritical = crises.where((cr) => cr.cattleId == cattle.id && !cr.isCritical).toList();
        final bAlerts = breedingAlerts.where((b) => b.cattleId == cattle.id).toList();

        if (nonCritical.isEmpty && bAlerts.isEmpty) continue;

        if (bAlerts.isNotEmpty) {
          final b = bAlerts.first;
          if (matchesSearch(cattle.name, cattle.tagId, 'हीट गर्भाधान breeding heat')) {
            cards.add(
              _buildWatchlistCattleCard(
                context: context,
                name: '${cattle.name} (${cattle.breed})',
                tagId: cattle.tagId,
                statusBadge: '🔥 गर्भाधान निगरानी (Day ${b.daysSinceAi})',
                badgeColor: Colors.amber.shade900,
                vitalsBadges: [
                  'AI गर्भाधान दिनांक: ${b.inseminatedOn}',
                  'दिन पूर्ण: ${b.daysSinceAi} दिन',
                  'हीट / रिपीट जांच आवश्यक',
                ],
                actionText: 'प्रजनन रिकॉर्ड देखें',
                onTapAction: () => context.push('/breeding'),
              ),
            );
            cards.add(const SizedBox(height: 12));
          }
        }

        if (nonCritical.isNotEmpty) {
          final nc = nonCritical.first;
          if (matchesSearch(cattle.name, cattle.tagId, nc.alerts.map((a) => a.message).join(' '))) {
            cards.add(
              _buildWatchlistCattleCard(
                context: context,
                name: '${cattle.name} (${cattle.breed})',
                tagId: cattle.tagId,
                statusBadge: '🟡 स्वास्थ्य वॉचलिस्ट पूर्व चेतावनी',
                badgeColor: Colors.orange.shade800,
                vitalsBadges: nc.alerts.map((a) => '${a.alertType}: ${a.message}').toList(),
                actionText: 'हेल्थ रिकॉर्ड व उपचार देखें',
                onTapAction: () => context.push('/health/add-record'),
              ),
            );
            cards.add(const SizedBox(height: 12));
          }
        }
      }
    }

    // 3. Healthy Herd Block
    if (_selectedFilter == HerdFilter.all || _selectedFilter == HerdFilter.healthy) {
      final healthyCattle = allCattle.where((c) =>
          !crises.any((cr) => cr.cattleId == c.id) &&
          !breedingAlerts.any((b) => b.cattleId == c.id)).toList();

      if (healthyCattle.isNotEmpty) {
        final matchingHealthy = healthyCattle.where((c) =>
            matchesSearch(c.name, c.tagId, 'healthy स्वस्थ herd झुंड')).toList();
        if (matchingHealthy.isNotEmpty) {
          cards.add(_buildHealthyHerdBlock(context, matchingHealthy));
        }
      }
    }

    if (cards.isEmpty) {
      cards.add(
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Text(
              'इस फ़िल्टर में कोई पशु नहीं है (No matching cattle in this view)',
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

  Widget _buildHealthyHerdBlock(BuildContext context, List<Cattle> healthyCattle) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${healthyCattle.length} पशु पूरी तरह स्वस्थ और सामान्य हैं',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff14532d),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
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
            'स्वस्थ पशु (${healthyCattle.length}):',
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
            children: healthyCattle
                .take(12)
                .map(
                  (c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffdcfce7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${c.tagId} (${c.name})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff15803d),
                      ),
                    ),
                  ),
                )
                .toList()
              ..addAll(
                healthyCattle.length > 12
                    ? [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '... +${healthyCattle.length - 12} और स्वस्थ पशु',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff15803d),
                            ),
                          ),
                        ),
                      ]
                    : [],
              ),
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
