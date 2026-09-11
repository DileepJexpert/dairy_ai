import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/store_design.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterQuery = '';

  final List<Map<String, String>> _faqs = [
    {
      'category': 'Shipping & Cold Chain',
      'question': 'How is Milterra dairy shipped to maintain fresh farm quality?',
      'answer':
          'All gourmet dairy products are packed in thermal-insulated, eco-friendly cartons with gel chill packs. Ghee is bottled in heavy food-grade amber glass jars to protect against light oxidation. Perishables like fresh paneer and makhan are shipped via express cold-chain vehicles.',
    },
    {
      'category': 'Shipping & Cold Chain',
      'question': 'What are the delivery timelines and charges?',
      'answer':
          'Metro deliveries are dispatched same-day and delivered within 24–48 hours. Standard delivery is FREE on all orders above ₹499. For smaller orders, a flat delivery fee of ₹40 applies.',
    },
    {
      'category': 'Purity & Certification',
      'question': 'How can I verify the purity of my specific Ghee jar?',
      'answer':
          'Every Milterra product package features a unique Batch QR code. Scanning it in the app takes you directly to the NABL-accredited ISO/IEC 17025 laboratory certificate displaying exact Fat %, FFA, RM value, and 100% A2 allele genetic confirmation.',
    },
    {
      'category': 'Storage & Shelf Life',
      'question': 'How should I store Milterra A2 Desi Cow Bilona Ghee?',
      'answer':
          'Keep your ghee jar in a cool, dry place away from direct sunlight. Do not refrigerate, as cold temperatures disrupt its natural granular crystal structure. Always use a dry, clean spoon. Shelf life is 12 months from packing.',
    },
    {
      'category': 'Returns & Refunds',
      'question': 'What is Milterra’s 100% Quality Replacement Guarantee?',
      'answer':
          'If your package arrives damaged, with a broken jar seal, or if you are not completely satisfied with the aroma and taste, we will replace the item or issue a 100% instant refund to your Milterra Wallet or original payment method without hassle.',
    },
    {
      'category': 'Farmer Earnings & Wallet',
      'question': 'How does the Milterra Wallet work for farmers and customers?',
      'answer':
          'Dairy farmers receive instant automated credits for milk poured at cooperative collection kiosks based on digital Fat and SNF testing. Customers receive cashbacks and refund credits. Wallet balances can be withdrawn directly to bank accounts or used at checkout to buy cattle feed, minerals, and farm equipment.',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _filterQuery.isEmpty
        ? _faqs
        : _faqs.where((f) {
            final q = _filterQuery.toLowerCase();
            return f['question']!.toLowerCase().contains(q) ||
                f['answer']!.toLowerCase().contains(q) ||
                f['category']!.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Breadcrumb
                            Wrap(
                              children: [
                                InkWell(
                                  onTap: () => context.go('/shop'),
                                  child: const Text('Home',
                                      style: TextStyle(fontSize: 12, color: storeMuted)),
                                ),
                                const Text(' › ',
                                    style: TextStyle(fontSize: 12, color: storeMuted)),
                                const Text('Customer Care & Help',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen)),
                              ],
                            ),
                            const SizedBox(height: 18),

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
              hintText: 'Search help topics (e.g. delivery time, returns, ghee storage, purity)...',
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    child: Icon(a['icon'] as IconData, color: storeGreen, size: 22),
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
                    style: const TextStyle(fontSize: 11, color: storeMuted, height: 1.3),
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
                child: Text('No matching questions found. Try a different search term.',
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
                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildContactChannelsCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: storeSage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need Direct Assistance? Our Team is Here.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reach our dedicated customer care and rural cooperative support team anytime.',
            style: TextStyle(fontSize: 12, color: storeMuted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _contactTile(
                  Icons.phone_in_talk_outlined,
                  'Toll-Free Helpline',
                  '1800-MIL-TERRA (1800-645-8377)',
                  'Mon – Sat, 8:00 AM – 8:00 PM IST',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _contactTile(
                  Icons.email_outlined,
                  'Email Support',
                  'care@milterra.in',
                  'Response within 2 business hours',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _contactTile(
                  Icons.chat_bubble_outline,
                  'WhatsApp Helpline',
                  '+91 98765 43210',
                  'Instant receipt slips & order help',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _contactTile(IconData icon, String title, String value, String note) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: storeGreen, size: 24),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: storeMuted)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: storeGreen)),
          const SizedBox(height: 2),
          Text(note,
              style: const TextStyle(fontSize: 10, color: storeMuted)),
        ],
      ),
    );
  }
}
