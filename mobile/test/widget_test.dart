import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/app/theme.dart';
import 'package:dairy_ai/features/marketplace/widgets/store_design.dart';

void main() {
  test('Legacy theme shares the application design system', () {
    expect(DairyTheme.lightTheme, same(StoreTheme.light));
    expect(DairyTheme.primaryGreen, storeGreen);
    expect(StoreTheme.light.colorScheme.primary, storeGreen);
  });

  test('Storefront currency uses Indian formatting', () {
    expect(storeMoney(1499), '₹1,499');
    expect(storeMoney(149.5), '₹149.50');
    expect(storeMoney(125000), '₹1,25,000');
  });
}
