import 'product_models.dart';

String _previewTitle(Product p) {
  // Keep established trade names; do not advertise unverified composition or outcomes.
  final line = RegExp(
          r'^MILTERRA (CALCI-PRO|MINERA-360|LACTA-PRO|RUMEN-PRO|HEAT-GUARD)',
          caseSensitive: false)
      .firstMatch(p.title);
  if (line != null) return line.group(0)!;
  if (p.title.contains('Bovine Gold'))
    return 'MILTERRA Bovine Gold Cattle Feed';
  if (p.title.contains('Cal-Gold')) return 'MILTERRA Cal-Gold';
  if (p.title.contains('Lacto-Energy')) return 'MILTERRA Lacto-Energy';
  return p.title;
}

/// Editorial previews are deliberately separate from the API's sellable stock.
/// Legacy preview URLs stay valid. No commercial fallback is injected on errors.
final conceptCatalogue = defaultMilterraProducts
    .where((p) => p.isConcept || p.title.toLowerCase().contains('white butter'))
    .map((p) => p.copyWith(
          title: _previewTitle(p),
          description: Product.conceptExplanation,
          inStock: false,
          availableQuantity: 0,
          taxonomy: {
            ...?p.taxonomy,
            'concept': true,
            'status': 'Concept Preview'
          },
          specifications: const {
            'listing_status': 'concept',
            'imagery': 'Concept packaging'
          },
          media: p.title.toLowerCase().contains('white butter')
              ? const ['assets/store/white-butter-concept.png']
              : p.media,
        ))
    .toList(growable: false);
