import 'store_theme.dart';

/// Compatibility aliases for older DairyAI screens.
/// Change brand values in store_theme.dart, not here.
class DairyTheme {
  DairyTheme._();
  static const primaryGreen = storeGreen;
  static const accentOrange = storeGold;
  static const lightGreen = storeSage;
  static const creamWhite = storeCream;
  static const darkText = storeGreen;
  static const subtleGrey = storeMuted;
  static const errorRed = storeError;
  static const backgroundWhite = storeCream;
  static final lightTheme = StoreTheme.light;
}
