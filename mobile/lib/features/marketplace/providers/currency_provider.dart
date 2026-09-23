import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';

/// Supported display currencies for Milterra international shoppers
enum StoreCurrency {
  inr('INR', '₹', 'Indian Rupee'),
  usd('USD', r'$', 'US Dollar'),
  eur('EUR', '€', 'Euro'),
  gbp('GBP', '£', 'British Pound'),
  aed('AED', 'AED ', 'UAE Dirham');

  final String code;
  final String symbol;
  final String label;

  const StoreCurrency(this.code, this.symbol, this.label);

  static StoreCurrency fromCode(String code) {
    return StoreCurrency.values.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => StoreCurrency.inr,
    );
  }
}

/// Currently selected currency code across the storefront
final selectedCurrencyProvider = StateProvider<StoreCurrency>((ref) => StoreCurrency.inr);

/// Fetches real-time European Central Bank rates from Frankfurter via our backend
final currencyRatesProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  try {
    final dio = ref.watch(dioProvider);
    final response = await dio.get('/marketplace/currency/rates');
    if (response.data is Map && response.data['rates'] is Map) {
      final raw = response.data['rates'] as Map;
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    }
  } catch (_) {}
  return {
    'USD': 0.0104,
    'EUR': 0.0091,
    'GBP': 0.0079,
    'AED': 0.0382,
    'CAD': 0.0147,
  };
});

/// Helper to convert and format any base INR price to the selected currency
String formatCurrencyAmount({
  required double inrAmount,
  required StoreCurrency currency,
  Map<String, double>? rates,
}) {
  if (currency == StoreCurrency.inr) {
    return '₹${inrAmount.toStringAsFixed(0)}';
  }

  final rate = rates?[currency.code] ?? 1.0;
  final converted = inrAmount * rate;

  if (currency == StoreCurrency.aed) {
    return 'AED ${converted.toStringAsFixed(1)}';
  }
  return '${currency.symbol}${converted.toStringAsFixed(2)}';
}
