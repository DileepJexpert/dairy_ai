import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoreCoupon {
  const StoreCoupon({
    required this.code,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.discountAmount,
    this.minOrderAmount = 0,
  });

  final String code;
  final String title;
  final String description;
  final double discountPercent; // e.g. 10.0 for 10%
  final double discountAmount; // e.g. 100.0 for ₹100
  final double minOrderAmount;

  double calculateDiscount(double subtotal) {
    if (subtotal < minOrderAmount) return 0.0;
    if (discountPercent > 0) {
      return (subtotal * discountPercent) / 100.0;
    }
    return discountAmount.clamp(0.0, subtotal);
  }
}

const availableStoreCoupons = <StoreCoupon>[
  StoreCoupon(
    code: 'MILTERRA10',
    title: '10% OFF PURE DAIRY & ANIMAL CARE',
    description: 'Save 10% on pure A2 Desi Cow Ghee, Makhan, cattle feed, and supplements.',
    discountPercent: 10.0,
    discountAmount: 0,
    minOrderAmount: 0,
  ),
  StoreCoupon(
    code: 'FARM50',
    title: '₹50 OFF FARM ESSENTIALS',
    description: 'Flat ₹50 discount on cattle feed, mineral supplements, and equipment.',
    discountPercent: 0,
    discountAmount: 50.0,
    minOrderAmount: 0,
  ),
  StoreCoupon(
    code: 'BILONA15',
    title: '15% OFF BILONA GHEE',
    description: 'Save 15% on authentic wooden churned Vedic A2 Bilona Ghee 1L & 5L packs.',
    discountPercent: 15.0,
    discountAmount: 0,
    minOrderAmount: 0,
  ),
];

class AppliedCouponNotifier extends StateNotifier<StoreCoupon?> {
  AppliedCouponNotifier() : super(null);

  bool applyCoupon(String code, [double subtotal = double.infinity]) {
    final clean = code.trim().toUpperCase();
    final match = availableStoreCoupons.firstWhere(
      (c) => c.code == clean,
      orElse: () => const StoreCoupon(code: '', title: '', description: '', discountPercent: 0, discountAmount: 0),
    );

    if (match.code.isEmpty) return false;
    if (subtotal != double.infinity && subtotal < match.minOrderAmount) return false;

    state = match;
    return true;
  }

  void removeCoupon() {
    state = null;
  }
}

final appliedCouponProvider = StateNotifierProvider<AppliedCouponNotifier, StoreCoupon?>((ref) {
  return AppliedCouponNotifier();
});

final couponDiscountProvider = Provider.family<double, double>((ref, subtotal) {
  final coupon = ref.watch(appliedCouponProvider);
  if (coupon == null) return 0.0;
  return coupon.calculateDiscount(subtotal);
});
