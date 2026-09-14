import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../auth/providers/auth_provider.dart';

class StoreCoupon {
  const StoreCoupon({
    required this.code,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.discountAmount,
    this.minOrderAmount = 0,
    this.maxDiscountCap,
  });
  final String code, title, description;
  final double discountPercent, discountAmount, minOrderAmount;
  final double? maxDiscountCap;
  factory StoreCoupon.fromJson(Map j) {
    double number(dynamic v) => double.parse(v.toString());
    return StoreCoupon(
        code: j['code'],
        title: j['code'],
        description: j['description'],
        discountPercent: j['discount_type'] == 'percentage'
            ? number(j['discount_value'])
            : 0,
        discountAmount:
            j['discount_type'] == 'flat' ? number(j['discount_value']) : 0,
        minOrderAmount: number(j['min_order_value']),
        maxDiscountCap: j['max_discount_cap'] == null
            ? null
            : number(j['max_discount_cap']));
  }
  double calculateDiscount(double subtotal) {
    if (subtotal < minOrderAmount) return 0;
    var discount =
        discountPercent > 0 ? subtotal * discountPercent / 100 : discountAmount;
    if (maxDiscountCap != null) discount = discount.clamp(0, maxDiscountCap!);
    return double.parse(discount.clamp(0, subtotal).toStringAsFixed(2));
  }
}

final availableCouponsProvider =
    FutureProvider.autoDispose<List<StoreCoupon>>((ref) async {
  final response = await ref.watch(dioProvider).get('/marketplace/coupons');
  return (response.data['data'] as List)
      .map((j) => StoreCoupon.fromJson(j as Map))
      .toList();
});

class AppliedCouponNotifier extends StateNotifier<StoreCoupon?> {
  AppliedCouponNotifier(this.dio) : super(null);
  final Dio dio;
  Future<bool> applyCoupon(String code, [double? subtotal]) async {
    try {
      final response = await dio.post('/marketplace/coupons/quote',
          data: {'code': code.trim().toUpperCase()});
      if (!mounted) return false;
      state = StoreCoupon.fromJson(response.data['data']['coupon'] as Map);
      return true;
    } on DioException {
      if (mounted) state = null;
      return false;
    }
  }

  void removeCoupon() => state = null;
}

final appliedCouponProvider =
    StateNotifierProvider<AppliedCouponNotifier, StoreCoupon?>((ref) {
  ref.watch(currentUserProvider);
  return AppliedCouponNotifier(ref.read(dioProvider));
});

final couponDiscountProvider = Provider.family<double, double>(
    (ref, subtotal) =>
        ref.watch(appliedCouponProvider)?.calculateDiscount(subtotal) ?? 0);
