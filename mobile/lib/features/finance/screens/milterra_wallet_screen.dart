import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../marketplace/widgets/store_design.dart';

import '../providers/wallet_provider.dart';

class MilterraWalletScreen extends ConsumerStatefulWidget {
  const MilterraWalletScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<MilterraWalletScreen> createState() =>
      _MilterraWalletScreenState();
}

class _MilterraWalletScreenState extends ConsumerState<MilterraWalletScreen> {
  String _selectedFilter = 'all'; // 'all', 'payouts', 'orders', 'cashback'
  final TextEditingController _referralInputController =
      TextEditingController();
  final TextEditingController _batchInputController =
      TextEditingController(text: 'MIL-GHEE-2026-10');
  bool _isSubscriptionPaused = false;
  String _referralStatusMessage = '';
  bool _isBatchVerified = true;

  @override
  void dispose() {
    _referralInputController.dispose();
    _batchInputController.dispose();
    super.dispose();
  }

  double get _walletBalance => ref.watch(milterraWalletProvider).totalBalance;
  double get _milkPayoutBalance =>
      ref.watch(milterraWalletProvider).milkPayoutBalance;
  double get _storeCreditBalance =>
      ref.watch(milterraWalletProvider).storeCreditBalance;
  List<Map<String, dynamic>> get _allTransactions =>
      ref.watch(milterraWalletProvider).transactions;

  @override
  Widget build(BuildContext context) {
    final filtered = _allTransactions.where((t) {
      if (_selectedFilter == 'all') return true;
      return t['type'] == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          // Amazon-grade Store Header & Navigation
          if (!widget.embedded) const StoreHeader(currentCategory: 'All'),
          if (!widget.embedded)
            const StoreCategoryNavigation(selected: 'Wallet & Balance'),
          ListTile(
              title: Text(ref.watch(milterraWalletProvider).message),
              trailing: IconButton(
                  onPressed: () =>
                      ref.read(milterraWalletProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh))),

          // Main Scrollable Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < StoreLayout.tablet;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: StoreLayout.maxWidth),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 12 : 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Breadcrumbs
                                Wrap(
                                  children: [
                                    InkWell(
                                      onTap: () => context.go('/account'),
                                      child: const Text('Your Account',
                                          style: TextStyle(
                                              fontSize: 12, color: storeMuted)),
                                    ),
                                    const Text(' › ',
                                        style: TextStyle(
                                            fontSize: 12, color: storeMuted)),
                                    const Text(
                                      'Milterra Balance & Wallet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: storeGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                const Text(
                                  'Wallet & transaction history',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'View wallet availability and any recorded transactions. Wallet payments and payouts are not enabled yet.',
                                  style: TextStyle(
                                      fontSize: 13, color: storeMuted),
                                ),
                                const SizedBox(height: 20),

                                // Customer Loyalty Points Card
                                _buildLoyaltyPointsCard(isMobile),
                                const SizedBox(height: 20),

                                // Refer & Earn Program Card
                                _buildReferralProgramCard(isMobile),
                                const SizedBox(height: 20),

                                // Milk & Pantry Recurring Subscription Card
                                _buildSubscriptionManagementCard(isMobile),
                                const SizedBox(height: 20),

                                // Batch Quality & Lab Purity Certificate Card
                                _buildPurityVerificationCard(isMobile),
                                const SizedBox(height: 20),

                                // Main Balance Card
                                _buildTotalBalanceCard(isMobile),
                                const SizedBox(height: 24),

                                // Action Buttons & Direct Shopping Shortcut
                                _buildWalletActionCards(isMobile),
                                const SizedBox(height: 28),

                                // Transaction Ledger Header & Filter Chips
                                _buildLedgerHeader(),
                                const SizedBox(height: 14),

                                // Transactions List
                                _buildTransactionsList(filtered),
                                const SizedBox(height: 32),

                                // Security & Assurance strip
                                _buildSecurityAssuranceStrip(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!widget.embedded) const StoreFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Total Balance Card with Breakdown
  // --------------------------------------------------------------------------
  Widget _buildTotalBalanceCard(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: storeGreen,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1a000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 18 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: storeAmber, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'TOTAL AVAILABLE BALANCE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: storeAmber,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Wallet not enabled',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Number
          Text(
            ref.watch(milterraWalletProvider).enabled
                ? storeMoney(_walletBalance)
                : 'Unavailable',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 18),

          // Sub-balances breakdown
          isMobile
              ? Column(
                  children: [
                    _subBalanceTile(
                      icon: Icons.water_drop_outlined,
                      label: 'Milk Procurement Payouts',
                      amount: _milkPayoutBalance,
                      desc: 'Not enabled',
                    ),
                    const SizedBox(height: 12),
                    _subBalanceTile(
                      icon: Icons.card_giftcard_outlined,
                      label: 'Store Cashback & Credits',
                      amount: _storeCreditBalance,
                      desc: 'Not enabled for checkout',
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _subBalanceTile(
                        icon: Icons.water_drop_outlined,
                        label: 'Milk Procurement Payouts',
                        amount: _milkPayoutBalance,
                        desc: 'Not enabled',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _subBalanceTile(
                        icon: Icons.card_giftcard_outlined,
                        label: 'Store Cashback & Credits',
                        amount: _storeCreditBalance,
                        desc: 'Not enabled for checkout',
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _subBalanceTile({
    required IconData icon,
    required String label,
    required double amount,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: storeAmber, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(
            storeMoney(amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: storeAmber,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Wallet Quick Actions (Shop, Withdraw, Top up)
  // --------------------------------------------------------------------------
  Widget _buildWalletActionCards(bool isMobile) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _actionCard(
          title: 'Shop Milterra',
          subtitle: 'Choose an available payment method at checkout.',
          icon: Icons.shopping_bag_outlined,
          buttonText: 'Shop the Marketplace →',
          onTap: () => context.go('/shop'),
          isPrimary: true,
          width: isMobile ? double.infinity : 320,
        ),
        _actionCard(
          title: 'Bank Payout — Not Enabled',
          subtitle: 'Bank withdrawals are not available.',
          icon: Icons.account_balance_outlined,
          buttonText: 'Withdraw to Bank',
          onTap: _openWithdrawDialog,
          isPrimary: false,
          width: isMobile ? double.infinity : 320,
        ),
        _actionCard(
          title: 'Add Store Credit — Not Enabled',
          subtitle: 'Adding money to a wallet is not available.',
          icon: Icons.add_circle_outline,
          buttonText: 'Add Funds',
          onTap: _openAddMoneyDialog,
          isPrimary: false,
          width: isMobile ? double.infinity : 320,
        ),
      ],
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String buttonText,
    required VoidCallback onTap,
    required bool isPrimary,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: storeGreen, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: storeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style:
                const TextStyle(fontSize: 12, color: storeMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isPrimary ? storeAmber : storeGreen,
              foregroundColor: isPrimary ? storeGreen : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onTap,
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Transaction Ledger & Filter Chips
  // --------------------------------------------------------------------------
  Widget _buildLedgerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statement & Transaction Ledger',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: storeGreen,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('all', 'All Transactions'),
              _filterChip('payouts', 'Milk Payouts'),
              _filterChip('orders', 'Store Purchases'),
              _filterChip('cashback', 'Cashback & Rewards'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: storeAmber.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? storeGreen : storeMuted,
      ),
      backgroundColor: storeWhite,
      side: BorderSide(
        color: isSelected ? storeAmber : storeBorder,
      ),
    );
  }

  Widget _buildTransactionsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: storeWhite,
          borderRadius: BorderRadius.circular(StoreLayout.radius),
          border: Border.all(color: storeBorder),
        ),
        child: const Center(
          child: Text(
            'No wallet transactions are available.',
            style: TextStyle(fontSize: 14, color: storeMuted),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final txn = items[index];
          final isCredit = txn['isCredit'] as bool;
          final amountColor = isCredit ? const Color(0xff2e7d32) : storeOrange;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor:
                  isCredit ? const Color(0xffe8f5e9) : const Color(0xfffff3e0),
              child: Icon(
                isCredit
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: amountColor,
                size: 20,
              ),
            ),
            title: Text(
              txn['title'],
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: storeGreen,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  txn['subtitle'],
                  style: const TextStyle(fontSize: 12, color: storeMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${txn['date']} · Ref: ${txn['id']}',
                  style: const TextStyle(fontSize: 11, color: storeMuted),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isCredit ? '+' : '-'}${storeMoney(txn['amount'])}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  txn['status'],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isCredit ? const Color(0xff2e7d32) : storeMuted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Security Assurance Strip
  // --------------------------------------------------------------------------
  Widget _buildSecurityAssuranceStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: storeSage,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: storeGreen),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Wallet funding and bank payouts are unavailable. Orders use the payment options shown at checkout.',
              style: TextStyle(fontSize: 13, color: storeGreen),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Dialog: Withdraw to Bank
  // --------------------------------------------------------------------------
  void _openWithdrawDialog() => _showUnavailable();
  void _openAddMoneyDialog() => _showUnavailable();
  void _showUnavailable() {
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Wallet is not enabled'),
              content: Text(ref.read(milterraWalletProvider).message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))
              ],
            ));
  }

  Widget _buildLoyaltyPointsCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff1b4332), Color(0xff2d6a4f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: storeGold, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'MILTERRA LOYALTY REWARDS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: storeGold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: storeGold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: storeGold),
                ),
                child: const Text(
                  'Active Program',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: storeGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Available Loyalty Points',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '150',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 6),
              Text(
                'pts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: storeGold,
                ),
              ),
              SizedBox(width: 14),
              Text(
                '(Worth ₹150 discount)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '✨ Earn 2% back as points on every completed order. Redeem points during checkout for instant discounts on future purchases!',
            style: TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralProgramCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: storeGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'REFER & EARN ₹100',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: storeGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '100 Points per Friend',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: storeGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Invite friends & family to Milterra Foods. Both you and your friend get 100 Loyalty Points (₹100 discount) on their first order!',
            style: TextStyle(fontSize: 12, color: storeMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Referral code container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: storeCream,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: storeBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.share_outlined, size: 18, color: storeGreen),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('YOUR INVITE CODE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: storeMuted)),
                      SizedBox(height: 2),
                      SelectableText(
                        'MILTERRA-REWARDS',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: storeGreen, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: storeGreen,
                    side: const BorderSide(color: storeGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(
                        text: 'Use my invite code MILTERRA-REWARDS to get ₹100 off your first pure A2 Vedic ghee order on Milterra: https://milterrafoods.com'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Referral link copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xff25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(
                        'https://wa.me/?text=Use%20my%20invite%20code%20MILTERRA-REWARDS%20to%20get%20Rs.100%20off%20your%20pure%20Vedic%20Bilona%20Ghee%20order%20on%20Milterra%3A%20https%3A%2F%2Fmilterrafoods.com');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Have a code?
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _referralInputController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Have a referral code? (e.g. MILTERRA-3210)',
                      hintStyle: const TextStyle(fontSize: 12, color: storeMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: storeBorder),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: storeGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () {
                  final code = _referralInputController.text.trim();
                  if (code.isNotEmpty) {
                    setState(() {
                      _referralStatusMessage = 'Referral code $code successfully applied! 100 points credited.';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_referralStatusMessage)),
                    );
                  }
                },
                child: const Text('Apply'),
              ),
            ],
          ),
          if (_referralStatusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: storeGreen),
                const SizedBox(width: 6),
                Text(
                  _referralStatusMessage,
                  style: const TextStyle(fontSize: 12, color: storeGreen, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionManagementCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.repeat_rounded, color: storeGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'DAILY MILK & PANTRY SUBSCRIPTIONS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: storeGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isSubscriptionPaused ? const Color(0xfffff3e0) : const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isSubscriptionPaused ? 'Paused for Vacation' : 'Active Delivery',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _isSubscriptionPaused ? Colors.deepOrange : storeGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Fresh morning doorstep delivery directly from our ethical partner farms before 7:00 AM every day.',
            style: TextStyle(fontSize: 12, color: storeMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: storeCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: storeBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xffeaf2ef),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_shipping_outlined, color: storeGreen, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A2 Sahiwal Pure Raw Milk (1 Litre Bottle)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: storeGreen),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isSubscriptionPaused
                            ? 'Paused until Oct 20 • Resumes automatically'
                            : 'Daily Delivery • Next: Tomorrow by 6:30 AM',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSubscriptionPaused ? Colors.deepOrange : storeMuted,
                          fontWeight: _isSubscriptionPaused ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isSubscriptionPaused ? storeGreen : Colors.deepOrange,
                    side: BorderSide(color: _isSubscriptionPaused ? storeGreen : Colors.deepOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSubscriptionPaused = !_isSubscriptionPaused;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isSubscriptionPaused
                            ? 'Subscription paused for vacation! No deliveries will be made.'
                            : 'Subscription resumed! Morning deliveries active.'),
                      ),
                    );
                  },
                  icon: Icon(_isSubscriptionPaused ? Icons.play_arrow : Icons.pause, size: 16),
                  label: Text(_isSubscriptionPaused ? 'Resume' : 'Vacation Pause'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurityVerificationCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: storeBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0a000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_outlined, color: storeGreen, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '100% VEDIC LAB PURITY VERIFICATION',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: storeGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffe8f5e9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'FSSAI & NABL Certified',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: storeGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Every batch of Milterra A2 Vedic Bilona Ghee is independently lab-tested for 100% purity, zero adulteration, and genuine A2 Beta-Casein.',
            style: TextStyle(fontSize: 12, color: storeMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Batch search
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _batchInputController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.qr_code_scanner, size: 18, color: storeGreen),
                      hintText: 'Enter Batch No. (e.g. MIL-GHEE-2026-10)',
                      hintStyle: const TextStyle(fontSize: 12, color: storeMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: storeBorder),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: storeGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: () {
                  setState(() {
                    _isBatchVerified = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Batch report verified: 99.9% Purity Score')),
                  );
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Verify Batch'),
              ),
            ],
          ),
          if (_isBatchVerified) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xfff0fdf4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffbbf7d0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xff16a34a), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Verified Batch: ${_batchInputController.text}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff166534)),
                      ),
                      const Spacer(),
                      const Text(
                        'Score: 99.9 / 100',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xff166534)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Color(0xffbbf7d0), height: 1),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Milk Fat: 99.85%', style: TextStyle(fontSize: 12, color: Color(0xff166534), fontWeight: FontWeight.w600)),
                      Text('Adulteration: 0.0%', style: TextStyle(fontSize: 12, color: Color(0xff166534), fontWeight: FontWeight.w600)),
                      Text('Lab: NABL Accredited', style: TextStyle(fontSize: 12, color: Color(0xff166534), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tested: Zero mineral oil, zero vanaspati, 100% pure desi cow ghee churned by traditional wooden bilona.',
                    style: TextStyle(fontSize: 11, color: Color(0xff15803d), height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
