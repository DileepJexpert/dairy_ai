import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import '../models/product_models.dart';
import '../widgets/store_design.dart';
import '../widgets/lightning_deals_banner.dart';

class DealsScreen extends ConsumerStatefulWidget {
  const DealsScreen({super.key});

  @override
  ConsumerState<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends ConsumerState<DealsScreen> {
  String _departmentFilter = 'All Categories';
  String _dealTypeFilter = 'All Deal Types';
  String _sortBy = 'Featured';

  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _remaining = endOfDay.difference(now);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final current = DateTime.now();
        final target = DateTime(current.year, current.month, current.day, 23, 59, 59);
        _remaining = target.difference(current);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final deals = [
      LightningDealItem(
        product: defaultMilterraProducts[0],
        discountPercent: 20,
        claimedPercent: 84,
        dealPrice: 639,
        originalPrice: 799,
        badge: 'Deal of the Day',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[1],
        discountPercent: 18,
        claimedPercent: 91,
        dealPrice: 1229,
        originalPrice: 1499,
        badge: 'Lightning Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[2],
        discountPercent: 16,
        claimedPercent: 70,
        dealPrice: 1250,
        originalPrice: 1499,
        badge: 'Lightning Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[3],
        discountPercent: 15,
        claimedPercent: 62,
        dealPrice: 380,
        originalPrice: 450,
        badge: 'Limited time deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[4],
        discountPercent: 25,
        claimedPercent: 78,
        dealPrice: 299,
        originalPrice: 399,
        badge: 'Deal of the Day',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[5],
        discountPercent: 14,
        claimedPercent: 77,
        dealPrice: 1375,
        originalPrice: 1600,
        badge: 'Farmer Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[6],
        discountPercent: 22,
        claimedPercent: 69,
        dealPrice: 975,
        originalPrice: 1250,
        badge: 'Farmer Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[7],
        discountPercent: 15,
        claimedPercent: 55,
        dealPrice: 1530,
        originalPrice: 1800,
        badge: 'Farmer Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[8],
        discountPercent: 15,
        claimedPercent: 45,
        dealPrice: 39950,
        originalPrice: 47000,
        badge: 'Machinery Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[9],
        discountPercent: 12,
        claimedPercent: 50,
        dealPrice: 28160,
        originalPrice: 32000,
        badge: 'Machinery Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[10],
        discountPercent: 10,
        claimedPercent: 65,
        dealPrice: 21600,
        originalPrice: 24000,
        badge: 'Machinery Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[11],
        discountPercent: 18,
        claimedPercent: 82,
        dealPrice: 2870,
        originalPrice: 3500,
        badge: 'Lightning Deal',
      ),
    ];

    // Filter deals
    var filtered = deals;
    if (_departmentFilter == 'Dairy Foods') {
      filtered = filtered.where((d) {
        final dept = d.product.taxonomy?['department_name']?.toString() ?? '';
        return dept.contains('Dairy') || d.product.price < 1000;
      }).toList();
    } else if (_departmentFilter == 'Cattle Feed') {
      filtered = filtered.where((d) => d.badge == 'Farmer Deal' || d.product.title.contains('Pellets') || d.product.title.contains('Mineral')).toList();
    } else if (_departmentFilter == 'Machinery') {
      filtered = filtered.where((d) => d.product.category == ProductCategory.equipment).toList();
    }

    if (_dealTypeFilter == 'Deal of the Day') {
      filtered = filtered.where((d) => d.badge == 'Deal of the Day').toList();
    } else if (_dealTypeFilter == 'Lightning Deals') {
      filtered = filtered.where((d) => d.badge == 'Lightning Deal' || d.badge == 'Limited time deal').toList();
    } else if (_dealTypeFilter == '20%+ Off') {
      filtered = filtered.where((d) => d.discountPercent >= 20).toList();
    }

    // Sort deals
    if (_sortBy == 'Discount: High to Low') {
      filtered.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    } else if (_sortBy == 'Price: Low to High') {
      filtered.sort((a, b) => a.dealPrice.compareTo(b.dealPrice));
    } else if (_sortBy == 'Price: High to Low') {
      filtered.sort((a, b) => b.dealPrice.compareTo(a.dealPrice));
    }

    return Scaffold(
      backgroundColor: storeCream,
      body: Column(
        children: [
          const StoreHeader(currentCategory: 'All'),
          const StoreCategoryNavigation(selected: 'Deals'),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < StoreLayout.tablet;
                final isDesktop = constraints.maxWidth >= 960;

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: StoreLayout.maxWidth),
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
                                      child: const Text('Home', style: TextStyle(fontSize: 12, color: storeMuted)),
                                    ),
                                    const Text(' › ', style: TextStyle(fontSize: 12, color: storeMuted)),
                                    const Text('Today\'s Deals & Lightning Offers',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Hero Deals Banner
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xff067d62), Color(0xff0d3b2e)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(StoreLayout.radius),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xffcc0c39),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('LIMITED TIME OFFERS',
                                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                                                ),
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Ends in ${_formatTimer(_remaining)}',
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Milterra Today\'s Deals & Flash Savings',
                                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                                            ),
                                            const SizedBox(height: 6),
                                            const Text(
                                              'Handpicked offers on Pure A2 Gir Cow Ghee, Bilona Butter, High-Yield Cattle Pellets & Modern Milking Equipment.',
                                              style: TextStyle(fontSize: 13, color: Color(0xffe0f2ec)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isMobile) ...[
                                        const SizedBox(width: 20),
                                        Container(
                                          width: 260,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 72,
                                                height: 72,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: const [
                                                    BoxShadow(color: Color(0x1a000000), blurRadius: 6, offset: Offset(0, 2)),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.asset(
                                                    'assets/store/buffalo-ghee.png',
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.local_offer, size: 36, color: storeGreen),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'UP TO 25% OFF',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w900,
                                                        color: storeGold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Cooperative Fresh',
                                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Lab-tested purity batch guaranteed',
                                                      style: TextStyle(fontSize: 11, color: Color(0xffd1fae5)),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
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
                                const SizedBox(height: 20),

                                // Filter Controls Bar
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: storeWhite,
                                    borderRadius: BorderRadius.circular(StoreLayout.radius),
                                    border: Border.all(color: storeBorder),
                                  ),
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 10,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    alignment: WrapAlignment.spaceBetween,
                                    children: [
                                      // Department Pills
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: ['All Categories', 'Dairy Foods', 'Cattle Feed', 'Machinery'].map((dept) {
                                          final isSel = _departmentFilter == dept;
                                          return ChoiceChip(
                                            label: Text(dept),
                                            selected: isSel,
                                            selectedColor: storeGreen,
                                            labelStyle: TextStyle(
                                              color: isSel ? storeWhite : storeGreen,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            onSelected: (_) => setState(() => _departmentFilter = dept),
                                          );
                                        }).toList(),
                                      ),

                                      // Deal Type Pills
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: ['All Deal Types', 'Deal of the Day', 'Lightning Deals', '20%+ Off'].map((t) {
                                          final isSel = _dealTypeFilter == t;
                                          return FilterChip(
                                            label: Text(t),
                                            selected: isSel,
                                            selectedColor: storeAmber,
                                            labelStyle: TextStyle(
                                              color: isSel ? storeGreen : const Color(0xff333333),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                            onSelected: (_) => setState(() => _dealTypeFilter = t),
                                          );
                                        }).toList(),
                                      ),

                                      // Sort By
                                      DropdownButton<String>(
                                        value: _sortBy,
                                        underline: const SizedBox(),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: storeGreen),
                                        items: const [
                                          DropdownMenuItem(value: 'Featured', child: Text('Featured Deals')),
                                          DropdownMenuItem(value: 'Discount: High to Low', child: Text('Discount: High to Low')),
                                          DropdownMenuItem(value: 'Price: Low to High', child: Text('Price: Low to High')),
                                          DropdownMenuItem(value: 'Price: High to Low', child: Text('Price: High to Low')),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) setState(() => _sortBy = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Deals Grid
                                LayoutBuilder(
                                  builder: (context, gridConstraints) {
                                    final columns = isMobile
                                        ? (gridConstraints.maxWidth < 400 ? 1 : 2)
                                        : (isDesktop ? 4 : 3);

                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: filtered.length,
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: isMobile ? (gridConstraints.maxWidth < 400 ? 1.0 : 0.56) : 0.60,
                                      ),
                                      itemBuilder: (context, index) {
                                        return _buildDealsGridItem(context, filtered[index]);
                                      },
                                    );
                                  },
                                ),
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

  Widget _buildDealsGridItem(BuildContext context, LightningDealItem item) {
    final p = item.product;

    return Container(
      decoration: BoxDecoration(
        color: storeWhite,
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        border: Border.all(color: storeBorder),
      ),
      child: InkWell(
        onTap: () => context.go('/shop/product/${p.id}'),
        borderRadius: BorderRadius.circular(StoreLayout.radius),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image container
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xfff8faf9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Center(
                        child: ProductArtwork(
                          product: p,
                          showCaption: false,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xffcc0c39),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          item.badge,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Discount Tag & Validity Countdown
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xffcc0c39),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      '-${item.discountPercent}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Ends in ${_formatTimer(_remaining)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xffcc0c39)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Price & Strike-through M.R.P.
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    storeMoney(item.dealPrice),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xff0f1111)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    storeMoney(item.originalPrice),
                    style: const TextStyle(
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                      color: storeMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Title
              Text(
                p.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff0f1111),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),

              // Claimed Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.claimedPercent / 100.0,
                      backgroundColor: const Color(0xffe7e7e7),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xffe67a00)),
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.claimedPercent}% claimed',
                    style: const TextStyle(fontSize: 10, color: storeMuted, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Quick Add to Cart Button
              SizedBox(
                width: double.infinity,
                height: 30,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: storeAmber,
                    foregroundColor: storeGreen,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    ref.read(cartProvider.notifier).add(p.id, 1, p);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${p.title} to Cart at Deal Price!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Add to Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
