import 'package:flutter/material.dart';

// Single source of truth for the application brand and storefront design system.
// Screens define their content and layout; reusable visual rules live here.
const storeGreen = Color(0xff163c30);
const storeGold = Color(0xffb39358);
const storeCream = Color(0xfffaf8f3);
const storeMuted = Color(0xff65736b);
const storeBorder = Color(0xffe8e4da);
const storeWhite = Colors.white;
const storeHero = Color(0xffeee4cd);
const storeHeroCircle = Color(0xffe0c692);
const storeSage = Color(0xffe8eee2);
const storeFresh = Color(0xfff0f4ea);
const storeWarm = Color(0xfff5f1e8);
const storeSuccess = Color(0xff367448);
const storeError = Color(0xffb3261e);

abstract final class StorePalette {
  static const categoryAll = Color(0xffece5d5),
      categoryCow = Color(0xfff4e5bd),
      categoryBuffalo = Color(0xffdde6eb),
      categoryPaneer = Color(0xffe1ebdb);
  static const onDark = Color(0xffd2ded6),
      buffaloLabel = Color(0xff344b64),
      labelGold = Color(0xfff0dcad);
  static const paneerGradient = [
    Color(0xffedf2e6),
    storeWhite,
    Color(0xffd7e3cb)
  ];
  static const gheeGradient = [
    Color(0xffcb8d25),
    Color(0xfff5d176),
    Color(0xffe8b342),
    Color(0xffad7420)
  ];
  static const lidGradient = [
    Color(0xff243e32),
    Color(0xff4b6451),
    Color(0xff1e342a)
  ];
  static const shadow = Colors.black;
}

abstract final class StoreLayout {
  static const double maxWidth = 1320,
      mobile = 600,
      tablet = 760,
      desktop = 1000;
  static const double xxs = 4, xs = 8, sm = 12, md = 16, lg = 24, xl = 32;
  static const double radius = 8, controlRadius = 5;
  static const double heroDesktop = 1120;
  static const double sectionSpace = 56,
      heroHeight = 470,
      headerSearchWidth = 320;
  static const motion = Duration(milliseconds: 180);
  static const pagePadding = EdgeInsets.symmetric(horizontal: xl);
  static const panelPadding = EdgeInsets.all(lg);
  static const panelGap = SizedBox(height: lg);
  static BorderRadius get corners => BorderRadius.circular(radius);
  static BoxDecoration get panel =>
      BoxDecoration(color: storeWhite, borderRadius: corners);
}

abstract final class StoreType {
  static TextStyle collectionHeading(bool small) => small ? title : heading;
  static TextStyle heroHeading(bool small) =>
      small ? hero.copyWith(fontSize: 39) : hero;
  static TextStyle productCardHeading(bool small) =>
      small ? cardTitle.copyWith(fontSize: 14) : cardTitle;
  static TextStyle navigation(bool selected) => label.copyWith(
      fontSize: 13,
      color: selected ? storeGreen : storeMuted,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w400);
  static const heroBody =
      TextStyle(color: storeMuted, fontSize: 14, height: 1.65);
  static const seal = TextStyle(
      color: storeGold, fontSize: 10, height: 1.5, letterSpacing: 1.2);
  static const logo = TextStyle(
      color: storeGreen,
      fontFamily: 'CormorantGaramond',
      fontSize: 37,
      fontWeight: FontWeight.w600,
      letterSpacing: -.7);
  static const logoSuffix = TextStyle(color: storeGold, fontSize: 14);
  static const onDark =
      TextStyle(color: StorePalette.onDark, fontSize: 13, height: 1.7);
  static const footerLabel =
      TextStyle(color: storeGold, fontSize: 11, letterSpacing: 2);
  static const inverseLabel =
      TextStyle(color: storeWhite, fontSize: 12, fontWeight: FontWeight.w700);
  static const packagingBrand = TextStyle(
      color: storeWhite,
      fontWeight: FontWeight.w800,
      fontSize: 17,
      letterSpacing: -.5);
  static const packagingCategory =
      TextStyle(color: StorePalette.labelGold, fontSize: 8, letterSpacing: 1.4);
  static const packagingSize =
      TextStyle(color: StorePalette.onDark, fontSize: 9);
  static const eyebrow = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: storeMuted);
  static const heading = TextStyle(
      fontFamily: 'CormorantGaramond',
      fontSize: 36,
      fontWeight: FontWeight.w500,
      letterSpacing: -.5,
      color: storeGreen);
  static const title = TextStyle(
      fontFamily: 'CormorantGaramond',
      fontSize: 27,
      fontWeight: FontWeight.w600,
      color: storeGreen);
  static const productTitle = TextStyle(
      fontFamily: 'CormorantGaramond',
      fontSize: 42,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: storeGreen);
  static const cardTitle = TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w700,
      color: storeGreen);
  static const body = TextStyle(fontSize: 14, height: 1.65, color: storeGreen);
  static const muted = TextStyle(fontSize: 12, height: 1.5, color: storeMuted);
  static const price = TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w500,
      letterSpacing: -.6,
      color: storeGreen);
  static const label =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: storeGreen);
  static const caption = TextStyle(fontSize: 10, color: storeMuted);
  static const stock = TextStyle(fontSize: 12, color: storeSuccess);
  static const hero = TextStyle(
      fontSize: 57,
      fontFamily: 'CormorantGaramond',
      height: 1.05,
      fontWeight: FontWeight.w500,
      letterSpacing: -1,
      color: storeGreen);
}

abstract final class StoreTheme {
  static final inverseButton =
      TextButton.styleFrom(foregroundColor: storeWhite);
  static final purchaseButton = FilledButton.styleFrom(
      backgroundColor: storeGreen, foregroundColor: storeWhite);
  static final light = ThemeData(
    useMaterial3: true,
    expansionTileTheme: const ExpansionTileThemeData(
      textColor: storeGreen,
      iconColor: storeGreen,
      collapsedTextColor: storeGreen,
      collapsedIconColor: storeMuted,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(bottom: 20),
      shape: Border(bottom: BorderSide(color: storeBorder)),
      collapsedShape: Border(bottom: BorderSide(color: storeBorder)),
    ),
    chipTheme: ChipThemeData(
      selectedColor: storeSage,
      backgroundColor: storeCream,
      side: const BorderSide(color: storeBorder),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StoreLayout.controlRadius)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      labelStyle: StoreType.label,
    ),
    scaffoldBackgroundColor: storeCream,
    colorScheme: ColorScheme.fromSeed(
        seedColor: storeGreen,
        primary: storeGreen,
        secondary: storeGold,
        surface: storeWhite),
    textTheme: const TextTheme(
        headlineLarge: StoreType.productTitle,
        headlineMedium: StoreType.heading,
        titleLarge: StoreType.title,
        titleMedium: StoreType.cardTitle,
        bodyLarge: StoreType.body,
        bodyMedium: StoreType.body,
        bodySmall: StoreType.muted,
        labelLarge: StoreType.label),
    appBarTheme: const AppBarTheme(
        backgroundColor: storeGreen,
        foregroundColor: storeWhite,
        centerTitle: false,
        elevation: 0),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: storeGreen,
            foregroundColor: storeWhite,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(StoreLayout.controlRadius)),
            textStyle: StoreType.label)),
    elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: storeGreen,
            foregroundColor: storeWhite,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(StoreLayout.controlRadius)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: storeGreen,
            side: const BorderSide(color: storeBorder),
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(StoreLayout.controlRadius)))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            foregroundColor: storeGreen, textStyle: StoreType.label)),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: storeWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(StoreLayout.controlRadius),
            borderSide: const BorderSide(color: storeBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(StoreLayout.controlRadius),
            borderSide: const BorderSide(color: storeBorder))),
    cardTheme: CardThemeData(
        color: storeWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: StoreLayout.corners,
            side: const BorderSide(color: storeBorder))),
    dividerTheme:
        const DividerThemeData(color: storeBorder, thickness: 1, space: 24),
  );
}
