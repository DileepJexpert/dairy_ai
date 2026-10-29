import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:dairy_ai/core/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/vet_farmer/models/vet_farmer_models.dart';
import 'package:dairy_ai/features/vet_farmer/providers/vet_farmer_provider.dart';
import 'package:dairy_ai/shared/widgets/stat_card.dart';
import 'package:dairy_ai/features/home/widgets/voice_entry_dialog.dart';
import 'package:dairy_ai/features/milk/widgets/milk_slip_selector_modal.dart';
import '../models/dashboard_model.dart';
import '../providers/home_provider.dart';
import 'package:dairy_ai/features/health/providers/active_crises_provider.dart';
import 'package:dairy_ai/shared/widgets/farmer_auth_action.dart';

/// The main Milterra Home Screen.
///
/// Features a unified ecosystem architecture:
/// 1. When Unauthenticated:
///    - Open Veterinary Portal: browse certified bovine vets, ratings, specialties.
///    - Open Cattle Commerce: browse balanced feed, silage, minerals, and A2 dairy.
///    - Community Bulletin & Daily BMC milk rates.
///    - Generic Platform Vitals (no fake private farm data).
///    - 1-Click Multi-tenant Demo Accounts (Ramesh, Suresh, Priya, Admin).
/// 2. When Authenticated:
///    - Private Dairy ERP Dashboard with real herd counts, milk yield, health alerts.
///    - Top-right Sign Out button in the exact same spot as Sign In.
///    - Quick actions (Add Milk, Health Check, Call Vet, AI Chat, Milk Purity).
///    - Farmer recent activity feed.
class FarmerHomeScreen extends ConsumerWidget {
  const FarmerHomeScreen({super.key});

  Widget _wrapDesktopWidth(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: child,
      ),
    );
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardStatsProvider);
    final authState = ref.watch(authProvider);
    final isAuthenticated = authState.maybeWhen(
      authenticated: (_) => true,
      orElse: () => false,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/chat'),
        backgroundColor: const Color(0xff047857),
        icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
        label: const Text(
          'पशु मित्र AI',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(dashboardStatsProvider.notifier).refresh(),
        ),
        data: (stats) => RefreshIndicator(
          onRefresh: () => ref.read(dashboardStatsProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context, ref, stats, isAuthenticated: isAuthenticated),
              if (!isAuthenticated) ...[
                // Open Ecosystem Portal View
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildHeroWelcome(context, ref))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildNetworkVitals(context))),
                SliverToBoxAdapter(
                  child: _wrapDesktopWidth(
                    _buildVeterinaryPortalSection(
                      context,
                      ref,
                      isAuthenticated: isAuthenticated,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildKisanSahayataSection(context))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildCommerceSection(context))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildCommunitySocialSection(context, ref, isAuthenticated: isAuthenticated))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildCommunityBulletin(context))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildErpGatewayBanner(context, ref))),
              ] else ...[
                // Authenticated Dairy Farmer ERP View
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildStatsGrid(context, stats))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildEmergencyCrisisAlertCard(context, ref))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildBreedingAlertCard(context, ref))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildQuickActions(context, farmerName: stats.farmerName))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildFarmerShortcuts(context))),
                SliverToBoxAdapter(
                  child: _wrapDesktopWidth(
                    _buildVeterinaryPortalSection(
                      context,
                      ref,
                      isAuthenticated: isAuthenticated,
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildKisanSahayataSection(context))),
                SliverToBoxAdapter(child: _wrapDesktopWidth(_buildCommunitySocialSection(context, ref, isAuthenticated: isAuthenticated))),
                SliverToBoxAdapter(
                  child: _wrapDesktopWidth(
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Activity',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/more/milk-summary'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildActivityList(context, stats.recentActivities),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top App Bar
  // ---------------------------------------------------------------------------

  SliverAppBar _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    DashboardStats stats, {
    required bool isAuthenticated,
  }) {
    final greeting = _greeting();

    return SliverAppBar(
      expandedHeight: isAuthenticated ? 120 : 100,
      pinned: true,
      backgroundColor: const Color(0xff064e3b),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAuthenticated) ...[
              Text(
                '$greeting,',
                style: const TextStyle(
                  color: Color(0xffa7f3d0),
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Text(
                stats.farmerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ] else ...[
              const Text(
                'Milterra Dairy Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Text(
                'Open Vet, Commerce & Dairy ERP',
                style: TextStyle(
                  color: Color(0xffa7f3d0),
                  fontSize: 10,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (isAuthenticated)
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/home/notifications'),
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
            ),
          ),
        const FarmerAuthAction(nextRoute: '/home', color: Colors.white),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Open Portal: Hero Welcome & 1-Click Multi-tenant Test Accounts
  // ---------------------------------------------------------------------------

  Widget _buildHeroWelcome(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff064e3b), Color(0xff047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff064e3b).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff34d399).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xff34d399)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hub_outlined, color: Color(0xff6ee7b7), size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Open Cattle & Dairy Ecosystem',
                      style: TextStyle(
                        color: Color(0xffa7f3d0),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/login?next=/home'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                child: const Text('Farmer Sign In >', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Connect, Consult & Manage Dairy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Open access to certified bovine veterinarians, high-yield cattle feed, and purity verification. Sign in required only for appointment booking and private Dairy ERP.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.88),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (kDebugMode || AppConstants.flowSimulation) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xff065f46), height: 1),
            const SizedBox(height: 12),
            const Text(
              '⚡ 1-Click Demo Accounts (Explore Private ERP):',
              style: TextStyle(
                color: Color(0xffa7f3d0),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDemoLoginChip(
                  context,
                  ref,
                  label: '🌾 Ramesh (Gir Dairy)',
                  phone: '9876510001',
                  password: 'Password@123',
                ),
                _buildDemoLoginChip(
                  context,
                  ref,
                  label: '🐃 Suresh (Murrah Buffalo)',
                  phone: '9876510002',
                  password: 'Password@123',
                ),
                _buildDemoLoginChip(
                  context,
                  ref,
                  label: '🥛 Priya (Dairy Co-op)',
                  phone: '9876510003',
                  password: 'Password@123',
                ),
                _buildDemoLoginChip(
                  context,
                  ref,
                  label: '👨‍⚕️ Dr. Deshmukh (Vet Portal)',
                  phone: '9825099001',
                  password: 'Password@123',
                ),
                _buildDemoLoginChip(
                  context,
                  ref,
                  label: '⚙️ Admin Portal',
                  phone: 'admin@milterra.in',
                  password: 'Admin@12345',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDemoLoginChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String phone,
    required String password,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _executeQuickLogin(
          context,
          ref,
          phone: phone,
          password: password,
          label: label,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xffa7f3d0)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeQuickLogin(
    BuildContext context,
    WidgetRef ref, {
    required String phone,
    required String password,
    required String label,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('Logging in as $label...'),
        duration: const Duration(milliseconds: 900),
      ),
    );

    try {
      await ref.read(authProvider.notifier).loginWithPassword(phone, password);
      ref.invalidate(dashboardStatsProvider);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Open Portal: Generic Platform Vitals (No fake counts!)
  // ---------------------------------------------------------------------------

  Widget _buildNetworkVitals(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 18, color: Color(0xff047857)),
              const SizedBox(width: 6),
              Text(
                'Milterra Network Vitals',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff047857),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: isWide ? 1.75 : 1.45,
                children: [
                  StatCard(
                    icon: Icons.medical_services_outlined,
                    label: 'Certified Vets',
                    value: '18+ Doctors',
                    color: Colors.teal,
                    onTap: () => context.push('/more/vet'),
                  ),
                  StatCard(
                    icon: Icons.pets,
                    label: 'Tracked Cattle',
                    value: '8,500+ Herd',
                    color: Colors.indigo,
                    onTap: () => context.push('/login?next=/herd'),
                  ),
                  StatCard(
                    icon: Icons.water_drop_outlined,
                    label: 'Daily Milk Flow',
                    value: '45,000+ L',
                    color: Colors.blue,
                    onTap: () => context.push('/purity'),
                  ),
                  StatCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Feed & Supplies',
                    value: '60+ Products',
                    color: Colors.amber.shade800,
                    onTap: () => launchUrl(Uri.parse('https://milterrafoods.com'), mode: LaunchMode.externalApplication),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Open Portal: Veterinary Doctors Section
  // ---------------------------------------------------------------------------

  Widget _buildVeterinaryPortalSection(
    BuildContext context,
    WidgetRef ref, {
    required bool isAuthenticated,
  }) {
    final vetsAsync = ref.watch(vetSearchProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.health_and_safety, color: Color(0xff047857), size: 20),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'पशु चिकित्सालय व टेली-क्लिनिक (Tele-Vet)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      'सत्यापित पशु चिकित्सकों से वीडियो कॉल, इमरजेंसी परामर्श व डिजिटल पर्चा',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/vet/booking'),
                    icon: const Icon(Icons.video_call, size: 16),
                    label: const Text('वीडियो कॉल'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff047857),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => context.push('/more/vet'),
                    child: const Text('सभी देखें'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          vetsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => _buildVetsList(
              context,
              ref,
              _fallbackVets,
              isAuthenticated: isAuthenticated,
            ),
            data: (vets) {
              final list = vets.isNotEmpty ? vets : _fallbackVets;
              return _buildVetsList(
                context,
                ref,
                list,
                isAuthenticated: isAuthenticated,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVetsList(
    BuildContext context,
    WidgetRef ref,
    List<VetProfile> vets, {
    required bool isAuthenticated,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        if (!isWide) {
          return Column(
            children: vets
                .map((vet) => _buildVetCard(
                      context,
                      ref,
                      vet,
                      isAuthenticated: isAuthenticated,
                    ))
                .toList(),
          );
        }

        final cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 0,
          children: vets
              .map((vet) => SizedBox(
                    width: cardWidth,
                    child: _buildVetCard(
                      context,
                      ref,
                      vet,
                      isAuthenticated: isAuthenticated,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildVetCard(
    BuildContext context,
    WidgetRef ref,
    VetProfile vet, {
    required bool isAuthenticated,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xffecfdf5),
                  child: Text(
                    vet.name.isNotEmpty ? vet.name.replaceAll('Dr. ', '')[0] : 'V',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xff047857),
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vet.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffecfdf5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xffa7f3d0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, size: 12, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  '${vet.rating.toStringAsFixed(1)} (${vet.totalConsultations}+)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xff065f46),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vet.qualification,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                          const SizedBox(width: 2),
                          Text(
                            vet.locationLabel ?? (vet.city ?? 'India'),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.payments_outlined, size: 13, color: Color(0xff047857)),
                          const SizedBox(width: 2),
                          Text(
                            '₹${vet.fee.toInt()} / consult',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff047857),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (vet.specializations.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: vet.specializations.take(3).map((spec) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xfff1f5f9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      spec,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xff334155),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/more/vet'),
                    icon: const Icon(Icons.info_outline, size: 14),
                    label: const Text('View Profile', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _handleVetBooking(
                      context,
                      ref,
                      vet,
                      isAuthenticated: isAuthenticated,
                    ),
                    icon: const Icon(Icons.calendar_month, size: 14),
                    label: const Text('Book Consult', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xff047857),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleVetBooking(
    BuildContext context,
    WidgetRef ref,
    VetProfile vet, {
    required bool isAuthenticated,
  }) {
    context.push('/vet/booking');
  }

  // ---------------------------------------------------------------------------
  // Kisan Sahayata Kendra & Pashu Mitra AI Section
  // ---------------------------------------------------------------------------

  Widget _buildKisanSahayataSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffa7f3d0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffecfdf5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.support_agent,
                    color: Color(0xff047857),
                    size: 26,
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
                            'किसान सहायता केंद्र',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xff0f172a),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xff047857),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '24/7 LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Pashu Mitra AI, KCC 4% लोन, गोकुल मिशन व 1962 एम्बुलेंस',
                        style: TextStyle(fontSize: 12, color: Color(0xff64748b)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/more/chat'),
                  child: const Text('सभी देखें'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _SahayataPill(
                    icon: Icons.hub_outlined,
                    label: '🏢 समिति ERP',
                    color: const Color(0xff065f46),
                    onTap: () => context.push('/collection/operator'),
                  ),
                  const SizedBox(width: 8),
                  _SahayataPill(
                    icon: Icons.grain_outlined,
                    label: '🌾 मिनरल मिक्स व दाना',
                    color: const Color(0xffb45309),
                    onTap: () => context.push('/feed/store'),
                  ),
                  const SizedBox(width: 8),
                  _SahayataPill(
                    icon: Icons.chat_bubble_outline,
                    label: '💬 AI से पूछें',
                    color: const Color(0xff047857),
                    onTap: () => context.push('/more/chat'),
                  ),
                  const SizedBox(width: 8),
                  _SahayataPill(
                    icon: Icons.account_balance_outlined,
                    label: '🏛️ KCC लोन (4%)',
                    color: Colors.blue.shade700,
                    onTap: () => context.push('/more/chat'),
                  ),
                  const SizedBox(width: 8),
                  _SahayataPill(
                    icon: Icons.verified_outlined,
                    label: '🧬 गोकुल मिशन',
                    color: Colors.purple.shade700,
                    onTap: () => context.push('/more/chat'),
                  ),
                  const SizedBox(width: 8),
                  _SahayataPill(
                    icon: Icons.emergency_outlined,
                    label: '🚑 1962 एम्बुलेंस',
                    color: Colors.red.shade700,
                    onTap: () => launchUrl(Uri.parse('tel:1962')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Open Portal: Cattle Commerce & Feeds Section
  // ---------------------------------------------------------------------------

  Widget _buildCommerceSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Color(0xff047857), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Cattle Feed & Farm Commerce',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Direct delivery of high-yield cattle feeds & supplements',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => launchUrl(Uri.parse('https://milterrafoods.com'), mode: LaunchMode.externalApplication),
                child: const Text('Milterra Store ↗'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildProductCard(
                  context,
                  title: 'Milterra Superfeed Bypass Fat (50kg)',
                  category: 'High-Yield Rations',
                  price: '₹1,450',
                  badge: '22% Protein',
                  icon: Icons.grass,
                  color: Colors.green,
                ),
                _buildProductCard(
                  context,
                  title: 'Chelated Mineral Mixture (5kg)',
                  category: 'Fertility & Conception',
                  price: '₹620',
                  badge: 'With Chromium',
                  icon: Icons.science,
                  color: Colors.teal,
                ),
                _buildProductCard(
                  context,
                  title: 'Super Napier Hybrid Slips (500)',
                  category: 'Green Fodder',
                  price: '₹850',
                  badge: '18% Protein Fodder',
                  icon: Icons.eco,
                  color: Colors.lightGreen,
                ),
                _buildProductCard(
                  context,
                  title: 'Milterra Pure A2 Gir Cow Ghee (1L)',
                  category: 'Dairy Products',
                  price: '₹1,650',
                  badge: 'Vedic Bilona',
                  icon: Icons.verified,
                  color: Colors.amber.shade800,
                ),
                _buildProductCard(
                  context,
                  title: 'Smart IoT Rumination Collar Tag',
                  category: 'Smart Hardware',
                  price: '₹2,499',
                  badge: 'Heat & Mastitis Alert',
                  icon: Icons.sensors,
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context, {
    required String title,
    required String category,
    required String price,
    required String badge,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
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
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            category,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xff047857),
                ),
              ),
              InkWell(
                onTap: () => launchUrl(Uri.parse('https://milterrafoods.com'), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xff047857),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Open Portal & ERP: Community Social Cases & Doctor Advisory
  // ---------------------------------------------------------------------------

  Widget _buildCommunitySocialSection(
    BuildContext context,
    WidgetRef ref, {
    required bool isAuthenticated,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.forum_outlined, color: Color(0xff047857), size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Cattle Cases & Doctor Advice',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Farmers post cattle photos • Verified vets give clinical advice',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.push('/community'),
                child: const Text('View All >'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final case1 = _buildFeaturedCaseCard(
                context,
                authorName: 'Ramesh Patel',
                authorRole: '🌾 Dairy Farmer (Anand)',
                cattleTag: 'Gir #GIR-0104',
                title: 'Swelling and heat in rear right teat after milking, yield dropped by 3L',
                tag: 'Mastitis & Udder Care',
                imageUrl: 'https://images.unsplash.com/photo-1570042225831-d98fa7577f1e?w=800',
                vetName: 'Dr. Hasmukh Deshmukh',
                vetDegree: 'MVSc Animal Reproduction & Surgery',
                vetAdvice: 'Do not massage harshly. Strip out affected quarter completely every 2 hours. Apply fresh Aloe vera (250g) + Turmeric (50g) + Chuna (15g) paste externally. Book consult if temp exceeds 103°F.',
              );
              final case2 = _buildFeaturedCaseCard(
                context,
                authorName: 'Suresh Yadav',
                authorRole: '🐃 Dairy Farmer (Karnal)',
                cattleTag: 'Murrah #MUR-0208',
                title: 'Buffalo not showing clear estrus heat after 90 days postpartum',
                tag: 'Breeding & Infertility',
                imageUrl: 'https://images.unsplash.com/photo-1546445317-29f4545e9d53?w=800',
                vetName: 'Dr. Rakesh Verma',
                vetDegree: 'PhD Animal Genetics & Breeding (NDRI)',
                vetAdvice: 'Silent estrus is frequent. Check at 5 AM & 9 PM for subtle vulvar swelling and stringy mucus. Feed 50g chelated mineral mixture with organic chromium daily for 21 days.',
              );

              if (!isWide) {
                return Column(
                  children: [
                    case1,
                    const SizedBox(height: 12),
                    case2,
                  ],
                );
              }

              final cardWidth = (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  SizedBox(width: cardWidth, child: case1),
                  SizedBox(width: cardWidth, child: case2),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Action button to post or open community
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/community'),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                  label: const Text('Ask / Post Cattle Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xff047857),
                    side: const BorderSide(color: Color(0xff047857), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCaseCard(
    BuildContext context, {
    required String authorName,
    required String authorRole,
    required String cattleTag,
    required String title,
    required String tag,
    required String imageUrl,
    required String vetName,
    required String vetDegree,
    required String vetAdvice,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () => context.push('/community'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xffecfdf5),
                    child: Text(
                      authorName.isNotEmpty ? authorName[0] : 'F',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff047857)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(authorRole, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffecfdf5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xffa7f3d0)),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xff065f46)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 10),

              // Verified Doctor Advice Callout
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xfff0fdf4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xff86efac)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, size: 14, color: Color(0xff047857)),
                        const SizedBox(width: 4),
                        Text(
                          '$vetName • Verified Doctor',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Color(0xff065f46),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vetDegree,
                      style: const TextStyle(fontSize: 10, color: Color(0xff047857)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vetAdvice,
                      style: const TextStyle(fontSize: 11, color: Color(0xff064e3b), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Open Portal: Community Bulletin
  // ---------------------------------------------------------------------------

  Widget _buildCommunityBulletin(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.campaign_outlined, color: Color(0xff047857), size: 20),
              SizedBox(width: 6),
              Text(
                'Community & Advisory Bulletin',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfff8fafc),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xffe2e8f0)),
            ),
            child: Column(
              children: [
                _buildBulletinRow(
                  icon: Icons.hub_outlined,
                  color: const Color(0xff065f46),
                  title: 'डेयरी सहकारी समिति व बीएमसी ऑपरेटर ERP',
                  subtitle: 'ग्राम वीएलसीसी दूध संकलन, डिजिटल वजन, 10-दिवसीय पखवाड़ा बिलिंग व डायरेक्ट बैंक भुगतान।',
                  actionLabel: 'ऑपरेटर कंसोल >',
                  onTap: () => context.push('/collection/operator'),
                ),
                const Divider(height: 18),
                _buildBulletinRow(
                  icon: Icons.vaccines_outlined,
                  color: Colors.orange,
                  title: 'NADCP FMD Vaccination Camp',
                  subtitle: 'Free Foot & Mouth Disease booster active across district veterinary dispensaries this week.',
                ),
                const Divider(height: 18),
                _buildBulletinRow(
                  icon: Icons.currency_rupee,
                  color: Colors.green,
                  title: 'Daily BMC Milk Procurement Rate',
                  subtitle: 'Base ₹38.50/L (Fat 4.2% / SNF 8.5%). Automated direct bank credit within 24 hours.',
                  actionLabel: 'Check Passbook >',
                  onTap: () => context.push('/passbook'),
                ),
                const Divider(height: 18),
                _buildBulletinRow(
                  icon: Icons.favorite_border,
                  color: Colors.pink,
                  title: 'AI Garbhadhan & Heat Alerts ("गर्भधान कैलेंडर")',
                  subtitle: '283-day bovine gestation cycles & repeat heat alerts. Prevent ₹10k/cycle lost milk yield.',
                  actionLabel: 'Check Calendar >',
                  onTap: () => context.push('/breeding'),
                ),
                const Divider(height: 18),
                _buildBulletinRow(
                  icon: Icons.healing_outlined,
                  color: Colors.red,
                  title: 'AI पशु रोग पहचान व देसी प्राथमिक उपचार',
                  subtitle: 'थनैला, अफारा, लम्पी स्किन के लक्षण पहचानें व ICAR प्रमाणित देसी नुस्खे देखें।',
                  actionLabel: 'उपचार देखें >',
                  onTap: () => context.push('/health/triage'),
                ),
                const Divider(height: 18),
                _buildBulletinRow(
                  icon: Icons.grain_outlined,
                  color: const Color(0xffb45309),
                  title: 'खनिज मिश्रण व पशुआहार बाज़ार (13x ROI)',
                  subtitle: '50g चिलेटेड मिनरल मिक्स से पाएँ +1.3L अतिरिक्त दूध। FPO व डीलर से सीधे आर्डर या दूध बिल से भुगतान।',
                  actionLabel: 'दाना बाज़ार >',
                  onTap: () => context.push('/feed/store'),
                ),
                const Divider(height: 18),
                _buildBulletinRow(
                  icon: Icons.grass,
                  color: const Color(0xffb45309),
                  title: 'संतुलित पशुआहार व चारा कैलकुलेटर',
                  subtitle: 'दूध व वजन अनुसार सूखा-हरा चारा और दाना नापें। मासिक ₹1,800+ बचाएं।',
                  actionLabel: 'कैलकुलेटर खोलें >',
                  onTap: () => context.push('/feed/calculator'),
                ),
                const Divider(height: 18),
                _buildBulletinRow(
                  icon: Icons.verified_outlined,
                  color: Colors.teal,
                  title: 'NABL Milk Purity Scanner',
                  subtitle: 'Test any brand or home milk sample for adulterants and get verified lab certification.',
                  actionLabel: 'Check Purity >',
                  onTap: () => context.push('/purity'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletinRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.3),
              ),
              if (actionLabel != null && onTap != null) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xff047857),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Open Portal: Dairy ERP Gateway Banner
  // ---------------------------------------------------------------------------

  Widget _buildErpGatewayBanner(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffbfdbfe)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Color(0xff1d4ed8), size: 22),
              SizedBox(width: 8),
              Text(
                'Commercial Dairy Farmer ERP',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xff1e3a8a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Run your entire dairy farm: cattle pedigrees, morning & evening milk collection logs, breeding heat cycles, health alerts, and instant UPI payout ledger.',
            style: TextStyle(fontSize: 12, color: Color(0xff1e40af), height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push('/login?next=/home'),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Access Private Dairy ERP'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff1d4ed8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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

  // ---------------------------------------------------------------------------
  // Authenticated ERP: 2x2 Stats Grid
  // ---------------------------------------------------------------------------

  Widget _buildStatsGrid(BuildContext context, DashboardStats stats) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          return GridView.count(
            crossAxisCount: isWide ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: isWide ? 1.75 : 1.45,
            children: [
              StatCard(
                icon: Icons.pets,
                label: 'Total Cattle',
                value: '${stats.totalCattle}',
                color: Colors.teal,
                onTap: () => context.push('/herd'),
              ),
              StatCard(
                icon: Icons.receipt_long,
                label: 'Dugdha Passbook',
                value: '${stats.todayMilkLitres.toStringAsFixed(1)} L',
                color: Colors.blue,
                onTap: () => context.push('/passbook'),
              ),
              StatCard(
                icon: Icons.warning_amber_rounded,
                label: 'Health Alerts',
                value: '${stats.pendingHealthAlerts}',
                color: stats.pendingHealthAlerts > 0 ? Colors.red : Colors.green,
                onTap: () => context.push('/health'),
              ),
              StatCard(
                icon: Icons.vaccines,
                label: 'Vaccinations Due',
                value: '${stats.upcomingVaccinations}',
                color: Colors.orange,
                onTap: () => context.push('/health/vaccinations'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Authenticated ERP: Multi-Crisis Emergency ICU Alert Card
  // ---------------------------------------------------------------------------
  Widget _buildEmergencyCrisisAlertCard(BuildContext context, WidgetRef ref) {
    final crises = ref.watch(activeCrisesProvider).maybeWhen(
          data: (d) => d.crises,
          orElse: () => const <CattleCrisis>[],
        );
    if (crises.isEmpty) return const SizedBox.shrink();
    final hasCritical = crises.any((c) => c.isCritical);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InkWell(
        onTap: () => context.push('/health/emergency-crisis'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xfffef2f2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xfff87171), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xffdc2626),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasCritical
                          ? '🚨 गंभीर स्वास्थ्य आपातकाल (Critical Health Alert)'
                          : '⚠️ स्वास्थ्य चेतावनी (Health Warning)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xff991b1b),
                      ),
                    ),
                  ),
                  const Text(
                    'देखें >',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffdc2626),
                    ),
                  ),
                ],
              ),
              for (final cr in crises.take(3)) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xfffecaca)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '${cr.cattleName} (#${cr.tagId}) - ${cr.alerts.length} alert(s)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xff7f1d1d),
                              ),
                            ),
                          ),
                          Text(
                            cr.isCritical ? '🚨 कोड रेड' : '⚠️ चेतावनी',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xffdc2626),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final a in cr.alerts)
                            _crisisMiniBadge(_crisisBadgeText(a), const Color(0xffdc2626)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              if (crises.length > 3) ...[
                const SizedBox(height: 8),
                Text(
                  '+${crises.length - 3} more animals need attention',
                  style: const TextStyle(fontSize: 11, color: Color(0xff7f1d1d)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _crisisBadgeText(CrisisAlert a) {
    final v = a.currentValue?.toStringAsFixed(1) ?? '--';
    switch (a.alertType) {
      case 'high_temperature':
        return '🌡️ $v°C बुखार (Fever)';
      case 'high_heart_rate':
        return '❤️ $v bpm (High heart rate)';
      case 'activity_drop':
        return '🛑 Activity drop ($v)';
      default:
        return a.message;
    }
  }

  Widget _crisisMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _buildBreedingAlertCard(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(activeCrisesProvider).maybeWhen(
          data: (d) => d.breedingAlerts,
          orElse: () => const <BreedingAlert>[],
        );
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xfffdf2f8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xfffbcfe8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite, color: Color(0xffbe185d), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'पशु गर्भधान व हीट अलर्ट (Breeding Alerts)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xff831843),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => context.push('/breeding'),
                  child: const Text(
                    'Full Calendar >',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xffbe185d),
                    ),
                  ),
                ),
              ],
            ),
            for (final a in alerts) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xfffce7f3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notification_important,
                        color: Color(0xffbe185d), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.cattleName} (Tag #${a.tagId}) - Day ${a.daysSinceAi} (Repeat Heat Window ⚠️)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff831843),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Inseminated on ${a.inseminatedOn}. Watch for clear mucus discharge & bellowing.',
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Authenticated ERP: Quick Actions
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(BuildContext context, {required String farmerName}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _QuickActionButton(
                        icon: Icons.mic,
                        label: 'Voice Entry',
                        color: Colors.indigo,
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => VoiceEntryDialog(farmerName: farmerName),
                        ),
                      ),
                      _QuickActionButton(
                        icon: Icons.print_outlined,
                        label: 'Print Slip',
                        color: Colors.blueGrey,
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => MilkSlipSelectorModal(
                            farmerName: farmerName,
                          ),
                        ),
                      ),
                      _QuickActionButton(
                        icon: Icons.whatshot,
                        label: 'Heat Alert',
                        color: Colors.deepOrange,
                        onTap: () => context.push('/breeding/heat-detection'),
                      ),
                      _QuickActionButton(
                        icon: Icons.emergency,
                        label: 'ICU Alert',
                        color: const Color(0xffdc2626),
                        onTap: () => context.push('/health/emergency-crisis'),
                      ),
                      _QuickActionButton(
                        icon: Icons.receipt_long_outlined,
                        label: 'Passbook',
                        color: const Color(0xff064e3b),
                        onTap: () => context.push('/passbook'),
                      ),
                      _QuickActionButton(
                        icon: Icons.favorite_border,
                        label: 'Breeding',
                        color: Colors.pink,
                        onTap: () => context.push('/breeding'),
                      ),
                      _QuickActionButton(
                        icon: Icons.healing_outlined,
                        label: 'Rog Pehchan',
                        color: Colors.red,
                        onTap: () => context.push('/health/triage'),
                      ),
                      _QuickActionButton(
                        icon: Icons.grass_outlined,
                        label: 'Feed Calc',
                        color: const Color(0xffb45309),
                        onTap: () => context.push('/feed/calculator'),
                      ),
                      _QuickActionButton(
                        icon: Icons.grain_outlined,
                        label: 'Feed Store',
                        color: const Color(0xffb45309),
                        onTap: () => context.push('/feed/store'),
                      ),
                      _QuickActionButton(
                        icon: Icons.hub_outlined,
                        label: 'Society ERP',
                        color: const Color(0xff065f46),
                        onTap: () => context.push('/collection/operator'),
                      ),
                      _QuickActionButton(
                        icon: Icons.smart_toy_outlined,
                        label: 'Pashu Mitra',
                        color: const Color(0xff047857),
                        onTap: () => context.push('/more/chat'),
                      ),
                      _QuickActionButton(
                        icon: Icons.video_call_outlined,
                        label: 'Tele-Vet',
                        color: Colors.green,
                        onTap: () => context.push('/vet/booking'),
                      ),
                      _QuickActionButton(
                        icon: Icons.verified_outlined,
                        label: 'Milk Purity',
                        color: Colors.teal,
                        onTap: () => context.push('/purity'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Authenticated ERP: Farmer Ecosystem Shortcuts
  // ---------------------------------------------------------------------------

  Widget _buildFarmerShortcuts(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/more/vet'),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xffecfdf5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xffa7f3d0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.video_camera_front_outlined, color: Color(0xff047857), size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Book Vet Call',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xff065f46),
                            ),
                          ),
                          Text(
                            'Verified bovine doctors',
                            style: TextStyle(fontSize: 10, color: Color(0xff047857)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => launchUrl(Uri.parse('https://milterrafoods.com'), mode: LaunchMode.externalApplication),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffffbeb),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xfffde68a)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined, color: Color(0xffb45309), size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Feed',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xff78350f),
                            ),
                          ),
                          Text(
                            'High-yield bypass fat',
                            style: TextStyle(fontSize: 10, color: Color(0xffb45309)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Authenticated ERP: Recent Activity List
  // ---------------------------------------------------------------------------

  SliverList _buildActivityList(
    BuildContext context,
    List<RecentActivity> activities,
  ) {
    if (activities.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No recent activity recorded yet.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ]),
      );
    }

    return SliverList.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _wrapDesktopWidth(_ActivityTile(activity: activity));
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers & Fallbacks
  // ---------------------------------------------------------------------------

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const List<VetProfile> _fallbackVets = [
    VetProfile(
      id: 1,
      userId: 1,
      name: 'Dr. Hasmukh Deshmukh',
      qualification: 'MVSc Animal Reproduction & Surgery',
      licenseNo: 'VET-GJ-2014-88',
      specializations: ['Bovine Infertility', 'Ultrasound', 'Mastitis Control'],
      languages: ['Hindi', 'Gujarati', 'English'],
      fee: 250.0,
      rating: 4.9,
      totalConsultations: 184,
      city: 'Anand',
      district: 'Anand',
      isAvailable: true,
    ),
    VetProfile(
      id: 2,
      userId: 2,
      name: 'Dr. Rakesh Verma',
      qualification: 'PhD Animal Genetics & Breeding (NDRI)',
      licenseNo: 'VET-HR-2011-42',
      specializations: ['Pedigree Insemination', 'Murrah Lineage', 'TMR Ration'],
      languages: ['Hindi', 'Punjabi', 'English'],
      fee: 300.0,
      rating: 4.9,
      totalConsultations: 240,
      city: 'Karnal',
      district: 'Karnal',
      isAvailable: true,
    ),
    VetProfile(
      id: 3,
      userId: 3,
      name: 'Dr. Ananya Patwardhan',
      qualification: 'BVSc & AH Preventive Veterinary Medicine',
      licenseNo: 'VET-MH-2018-91',
      specializations: ['Organic Herd Health', 'Herbal Udder Care', 'Calfhood Vaccines'],
      languages: ['Marathi', 'Hindi', 'English'],
      fee: 200.0,
      rating: 4.8,
      totalConsultations: 112,
      city: 'Baramati',
      district: 'Pune',
      isAvailable: true,
    ),
  ];
}

// =============================================================================
// Helper Widgets
// =============================================================================

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity});

  final RecentActivity activity;

  IconData _iconForType(String type) {
    switch (type) {
      case 'milk':
        return Icons.water_drop;
      case 'health':
        return Icons.medical_services;
      case 'vaccination':
        return Icons.vaccines;
      case 'breeding':
        return Icons.favorite;
      case 'feed':
        return Icons.grass;
      case 'finance':
        return Icons.currency_rupee;
      default:
        return Icons.info_outline;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'milk':
        return Colors.blue;
      case 'health':
        return Colors.red;
      case 'vaccination':
        return Colors.orange;
      case 'breeding':
        return Colors.pink;
      case 'feed':
        return Colors.green;
      case 'finance':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorForType(activity.type);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(_iconForType(activity.type), color: color, size: 20),
      ),
      title: Text(
        activity.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        activity.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: activity.cattleTag != null
          ? Text(
              activity.cattleTag!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              (message.contains('401') || message.toLowerCase().contains('unauthorized') || message.toLowerCase().contains('dioexception'))
                  ? 'Welcome to Milterra Dairy! Exploring in preview mode.'
                  : message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}


class _SahayataPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SahayataPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
