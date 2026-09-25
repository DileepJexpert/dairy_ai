import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/store_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/support_panel.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final help = ref.watch(storeHelpProvider);
    final faqs = (help.valueOrNull?['faqs'] as List? ?? [])
        .map((e) => Map<String, String>.from(e))
        .toList();
    final filteredFaqs = _filterQuery.isEmpty
        ? faqs
        : faqs.where((f) {
            final q = _filterQuery.toLowerCase();
            return f['question']!.toLowerCase().contains(q) ||
                f['answer']!.toLowerCase().contains(q) ||
                f['category']!.toLowerCase().contains(q);
          }).toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/shop');
        }
      },
      child: Scaffold(
        backgroundColor: storeCream,
        body: Column(
          children: [
            const StoreHeader(currentCategory: 'All'),
            const StoreCategoryNavigation(selected: 'Customer Care & Help'),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Navigation & Back Action Bar
                              _buildBackAndBreadcrumbs(context),
                              const SizedBox(height: 20),

                            // Hero Header & Search Bar
                            _buildHelpHeader(),
                            const SizedBox(height: 28),

                            // Quick Action Tiles
                            _buildQuickActionCards(context),
                            const SizedBox(height: 36),

                            // FAQ Section
                            _buildFaqSection(filteredFaqs),
                            const SizedBox(height: 40),

                            // Contact Channels Card
                            _buildContactChannelsCard(),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const StoreFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBackAndBreadcrumbs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: storeBorder.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/shop');
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: storeGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: storeGreen.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 16, color: storeGreen),
                  SizedBox(width: 6),
                  Text(
                    'Back to Store',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: storeGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Text('│', style: TextStyle(color: Color(0xffcbd5e1), fontSize: 14)),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: () => context.go('/shop'),
                  child: const Text(
                    'Home',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: storeMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Text(' › ', style: TextStyle(fontSize: 12.5, color: storeMuted)),
                InkWell(
                  onTap: () => context.go('/shop'),
                  child: const Text(
                    'Store',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: storeMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Text(' › ', style: TextStyle(fontSize: 12.5, color: storeMuted)),
                const Text(
                  'Customer Care & Help',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: storeGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: storeGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How can we help you today?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find answers regarding your orders, cold-chain deliveries, lab purity testing, or farmer wallet settlements.',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _filterQuery = v.trim()),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText:
                  'Search help topics (e.g. delivery time, returns, ghee storage, purity)...',
              hintStyle: const TextStyle(fontSize: 13, color: storeMuted),
              prefixIcon: const Icon(Icons.search, color: storeGreen),
              suffixIcon: _filterQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: storeMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _filterQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    final actions = [
      {
        'icon': Icons.local_shipping_outlined,
        'title': 'Track Your Order',
        'desc': 'Live courier dispatch and estimated delivery time',
        'route': '/marketplace/orders',
      },
      {
        'icon': Icons.location_on_outlined,
        'title': 'Delivery Addresses',
        'desc': 'Manage saved home, farm, and billing addresses',
        'route': '/marketplace/addresses',
      },
      {
        'icon': Icons.account_balance_wallet_outlined,
        'title': 'Milterra Wallet',
        'desc': 'Check milk earnings, store credits & bank withdrawal',
        'route': '/balance',
      },
      {
        'icon': Icons.verified_outlined,
        'title': 'Purity Lab Verification',
        'desc': 'View ISO 17025 test parameters and certificates',
        'route': '/purity',
      },
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: actions.map((a) {
        return SizedBox(
          width: 242,
          child: InkWell(
            onTap: () => context.push(a['route'] as String),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: storeBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: storeSage,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(a['icon'] as IconData,
                        color: storeGreen, size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    a['title'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: storeGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    a['desc'] as String,
                    style: const TextStyle(
                        fontSize: 11, color: storeMuted, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFaqSection(List<Map<String, String>> faqs) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.quiz_outlined, color: storeGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: storeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (faqs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                    'No matching questions found. Try a different search term.',
                    style: TextStyle(color: storeMuted)),
              ),
            )
          else
            ...faqs.map((f) {
              return ExpansionTile(
                title: Text(
                  f['question']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: storeGreen,
                  ),
                ),
                subtitle: Text(
                  f['category']!,
                  style: const TextStyle(fontSize: 11, color: storeAmberDark),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      f['answer']!,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black87, height: 1.4),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildContactChannelsCard() => Card(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ref.watch(storeHelpProvider).when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => TextButton(
                    onPressed: () => ref.invalidate(storeHelpProvider),
                    child: const Text('Help content unavailable. Retry')),
                data: (data) =>
                    Text(data['contact_message']?.toString() ?? '')),
            const SizedBox(height: 16),
            const SupportPanel(),
          ])));
}
