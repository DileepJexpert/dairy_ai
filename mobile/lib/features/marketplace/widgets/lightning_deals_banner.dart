import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'store_design.dart';

class LightningDealItem {
  const LightningDealItem({
    required this.product,
    required this.discountPercent,
    required this.claimedPercent,
    required this.dealPrice,
    required this.originalPrice,
    required this.badge,
  });

  final Product product;
  final int discountPercent;
  final int claimedPercent; // e.g. 74
  final double dealPrice;
  final double originalPrice;
  final String badge;
}

class LightningDealsRail extends ConsumerStatefulWidget {
  const LightningDealsRail({super.key, this.title = "Today's Deals & Lightning Offers"});

  final String title;

  @override
  ConsumerState<LightningDealsRail> createState() => _LightningDealsRailState();
}

class _LightningDealsRailState extends ConsumerState<LightningDealsRail> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Default 5 hours 42 minutes 19 seconds remaining
    _remaining = const Duration(hours: 5, minutes: 42, seconds: 19);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining = _remaining - const Duration(seconds: 1);
        } else {
          _remaining = const Duration(hours: 12, minutes: 0, seconds: 0);
        }
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
    // Generate deal items from default catalogue
    final dealProducts = [
      LightningDealItem(
        product: defaultMilterraProducts[0], // A2 Gir Cow Ghee 500ml
        discountPercent: 20,
        claimedPercent: 84,
        dealPrice: 639,
        originalPrice: 799,
        badge: 'Deal of the Day',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[1], // A2 Gir Cow Ghee 1000ml
        discountPercent: 18,
        claimedPercent: 91,
        dealPrice: 1229,
        originalPrice: 1499,
        badge: 'Lightning Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[3], // Vedic White Makhan
        discountPercent: 15,
        claimedPercent: 62,
        dealPrice: 380,
        originalPrice: 450,
        badge: 'Limited time deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[5], // Dairy Feed Pellets 50kg
        discountPercent: 14,
        claimedPercent: 77,
        dealPrice: 1375,
        originalPrice: 1600,
        badge: 'Farmer Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[6], // Chelated Mineral Mixture
        discountPercent: 22,
        claimedPercent: 69,
        dealPrice: 975,
        originalPrice: 1250,
        badge: 'Best Seller Deal',
      ),
      LightningDealItem(
        product: defaultMilterraProducts[8], // Ultrasonic Milk Fat Analyzer
        discountPercent: 15,
        claimedPercent: 45,
        dealPrice: 39950,
        originalPrice: 47000,
        badge: 'Machinery Deal',
      ),
    ];

    return Container(
      color: storeWhite,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Countdown Timer
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: storeGreen,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffcc0c39),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Ends in ${_formatTimer(_remaining)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => context.go('/shop/deals'),
                child: const Text(
                  'See all deals',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff007185),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal scrollable deals rail
          SizedBox(
            height: 340,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dealProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildDealCard(context, dealProducts[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDealCard(BuildContext context, LightningDealItem item) {
    final p = item.product;

    return Container(
      width: 220,
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
                      child: Center(
                        child: p.media.isNotEmpty
                            ? Image.network(
                                p.media.first,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.inventory_2_outlined, size: 48, color: storeGreen),
                              )
                            : const Icon(Icons.inventory_2_outlined, size: 48, color: storeGreen),
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
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Discount Pill & Limited Deal Tag
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Limited time deal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffcc0c39),
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
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff0f1111),
                    ),
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
              const SizedBox(height: 8),

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
                      minHeight: 6,
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
                    ref.read(cartProvider.notifier).add(p.id, 1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added ${p.title} to Cart at Deal Price!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Add to Cart',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
