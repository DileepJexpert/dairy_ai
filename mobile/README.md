# dairy_ai

## Storefront product hero

`assets/catalogue/home_hero.json` controls the featured products and their hero images in display order. Use a published product ID from `assets/catalogue/products.json` and an image bundled under `assets/store/`; the image should show the complete package with space around its edges. Product name, size, price and product-page route are read from the catalogue, so do not duplicate them in the hero file. `image_note` is an optional disclosure for illustrative artwork.

`lib/features/marketplace/widgets/storefront_hero.dart` is the landing page's replaceable hero slot. It resolves the merchandising file and currently renders `HeroSplitShowcase`. A future design can replace that renderer without changing the rest of `product_list_screen.dart` or the catalogue. The right-hand farm stories remain configured in `models/hero_showcase_config.dart`.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
