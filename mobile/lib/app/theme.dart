import 'store_theme.dart';

/// Compatibility aliases for brand theme references.
/// Defines Milterra's modern luxury palette (Onyx Black, Heritage Gold, and Warm Cream).
class DairyTheme {
  DairyTheme._();
  static const primaryDark = storePrimary;
  static const primaryGreen = storePrimary; // Modern luxury onyx (replaces legacy green)
  static const accentGold = storeGold;
  static const accentOrange = storeGold;
  static const lightGreen = storeSage;      // Soft luxury cream/stone accent
  static const creamWhite = storeCream;
  static const darkText = storeText;
  static const subtleGrey = storeMuted;
  static const errorRed = storeError;
  static const backgroundWhite = storeCream;
  static final lightTheme = StoreTheme.light;
}
