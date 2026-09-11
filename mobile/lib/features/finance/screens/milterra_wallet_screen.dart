import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../marketplace/widgets/store_design.dart';

import '../providers/wallet_provider.dart';

class MilterraWalletScreen extends ConsumerStatefulWidget {
  const MilterraWalletScreen({super.key});

  @override
  ConsumerState<MilterraWalletScreen> createState() =>
      _MilterraWalletScreenState();
}

class _MilterraWalletScreenState extends ConsumerState<MilterraWalletScreen> {
  String _selectedFilter = 'all'; // 'all', 'payouts', 'orders', 'cashback'

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
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Wallet & Balance'),

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
                                      onTap: () => context.go('/shop'),
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
                                  'Milterra Balance & Farmer Wallet',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: storeGreen,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Combine cooperative milk supply earnings with store cashback credits for frictionless 1-click purchases and bank payouts.',
                                  style: TextStyle(fontSize: 13, color: storeMuted),
                                ),
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
                      const StoreFooter(),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '100% FDIC / RBI Protected',
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
            storeMoney(_walletBalance),
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
                      desc: 'Verified by Anand Cooperative Dairy',
                    ),
                    const SizedBox(height: 12),
                    _subBalanceTile(
                      icon: Icons.card_giftcard_outlined,
                      label: 'Store Cashback & Credits',
                      amount: _storeCreditBalance,
                      desc: 'Ready for instant marketplace checkout',
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
                        desc: 'Verified by Anand Cooperative Dairy',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _subBalanceTile(
                        icon: Icons.card_giftcard_outlined,
                        label: 'Store Cashback & Credits',
                        amount: _storeCreditBalance,
                        desc: 'Ready for instant marketplace checkout',
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
          title: 'Shop with Balance',
          subtitle: 'Use your milk earnings directly for fresh A2 Ghee & cattle feed.',
          icon: Icons.shopping_bag_outlined,
          buttonText: 'Shop the Marketplace →',
          onTap: () => context.go('/shop'),
          isPrimary: true,
          width: isMobile ? double.infinity : 320,
        ),
        _actionCard(
          title: 'Instant Bank Payout',
          subtitle: 'Withdraw earnings to your linked cooperative or national bank.',
          icon: Icons.account_balance_outlined,
          buttonText: 'Withdraw to Bank',
          onTap: _openWithdrawDialog,
          isPrimary: false,
          width: isMobile ? double.infinity : 320,
        ),
        _actionCard(
          title: 'Add Store Credit',
          subtitle: 'Top-up wallet balance via UPI, RuPay, or Net Banking.',
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
            style: const TextStyle(fontSize: 12, color: storeMuted, height: 1.4),
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
            'No transactions found for this filter.',
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
          final amountColor =
              isCredit ? const Color(0xff2e7d32) : storeOrange;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isCredit
                  ? const Color(0xffe8f5e9)
                  : const Color(0xfffff3e0),
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
      child: const Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 20,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_outlined, size: 20, color: storeGreen),
              SizedBox(width: 8),
              Text(
                'Direct Cooperative Settlement',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: storeGreen,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 20, color: storeGreen),
              SizedBox(width: 8),
              Text(
                '256-Bit SSL Encrypted Banking',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: storeGreen,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.price_check_outlined, size: 20, color: storeGreen),
              SizedBox(width: 8),
              Text(
                'Zero Processing Fee on Payouts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: storeGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Dialog: Withdraw to Bank
  // --------------------------------------------------------------------------
  void _openWithdrawDialog() {
    final amountCtrl = TextEditingController(text: '3600');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Milk Earnings to Bank'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your verified bank account: State Bank of India (***4812)\nIFSC: SBIN0004921',
              style: TextStyle(fontSize: 13, color: storeMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Withdrawal Amount (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: storeAmber,
              foregroundColor: storeGreen,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amt > 0 && amt <= _walletBalance) {
                ref.read(milterraWalletProvider.notifier).withdraw(amt);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: storeGreen,
                    content: Text(
                      'Withdrawal of ${storeMoney(amt)} initiated to SBI account. Will reflect within 2 hours.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Confirm Withdrawal'),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Dialog: Add Money to Wallet
  // --------------------------------------------------------------------------
  void _openAddMoneyDialog() {
    final amountCtrl = TextEditingController(text: '1000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Money to Milterra Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add pre-paid funds for faster 1-click checkout on cattle feed, minerals, and dairy products.',
              style: TextStyle(fontSize: 13, color: storeMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount to Add (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: storeAmber,
              foregroundColor: storeGreen,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amt > 0) {
                ref.read(milterraWalletProvider.notifier).creditMilkIntake(
                      amount: amt,
                      litres: 0,
                      fatPct: 0,
                      snfPct: 0,
                      farmerName: 'Self UPI Deposit',
                      centerName: 'Online Top-up',
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: storeGreen,
                    content: Text(
                      'Successfully added ${storeMoney(amt)} to your Milterra Wallet via UPI.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Pay with UPI'),
          ),
        ],
      ),
    );
  }
}
