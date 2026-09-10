import 'package:flutter/material.dart';
import '../models/product_models.dart';
import 'store_design.dart';

// Presentation grouping only: every selected pack retains its real product ID.
// This matches the existing detail-page variant rule until family IDs exist.
List<List<Product>> storeProductGroups(List<Product> products) {
  final groups = <String, List<Product>>{};
  for (final product in products) {
    final key = product.packSize == null
        ? product.id
        : '${product.vendorId}|${product.title}|${storeCategory(product)}';
    groups.putIfAbsent(key, () => []).add(product);
  }
  return groups.values.toList();
}

class StoreProductCard extends StatefulWidget {
  const StoreProductCard(
      {super.key,
      required this.packs,
      required this.onOpen,
      required this.onAdd,
      this.busyIds = const {},
      this.compact = false});
  final List<Product> packs;
  final ValueChanged<Product> onOpen, onAdd;
  final Set<String> busyIds;
  final bool compact;
  @override
  State<StoreProductCard> createState() => _StoreProductCardState();
}

class _StoreProductCardState extends State<StoreProductCard> {
  String? _selected;
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final product = widget.packs
        .firstWhere((p) => p.id == _selected, orElse: () => widget.packs.first);
    final busy = widget.busyIds.contains(product.id);
    return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : StoreLayout.motion,
            decoration: BoxDecoration(
                color: storeCream,
                borderRadius: StoreLayout.corners,
                boxShadow: _hover
                    ? [
                        BoxShadow(
                            color: storeGreen.withValues(alpha: .06),
                            blurRadius: 18,
                            offset: const Offset(0, 6))
                      ]
                    : []),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Material(
                  color: storeWarm,
                  borderRadius: StoreLayout.corners,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap: () => widget.onOpen(product),
                      child: AspectRatio(
                          aspectRatio: 1.06,
                          child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: ProductArtwork(product: product))))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeCategory(product).toUpperCase(),
                            style: StoreType.eyebrow,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        InkWell(
                            onTap: () => widget.onOpen(product),
                            child: SizedBox(
                                height: 43,
                                child: Text(
                                    product.title.replaceFirst('Milterra ', ''),
                                    style: StoreType.productCardHeading(
                                        widget.compact),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis))),
                        SizedBox(
                            height: 44,
                            child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: widget.packs
                                    .map((pack) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 6),
                                          child: ChoiceChip(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              showCheckmark:
                                                  widget.packs.length > 1,
                                              label: Text(
                                                  pack.packSize ?? pack.unit),
                                              selected: pack.id == product.id,
                                              onSelected: (_) => setState(
                                                  () => _selected = pack.id)),
                                        ))
                                    .toList())),
                        const SizedBox(height: 6),
                        Text(storeMoney(product.price),
                            style: StoreType.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                            product.inStock
                                ? 'In stock'
                                : 'Currently unavailable',
                            style: product.inStock
                                ? StoreType.stock
                                : StoreType.muted),
                        const SizedBox(height: 10),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                onPressed: product.inStock &&
                                        product.availableQuantity >=
                                            product.minOrderQuantity &&
                                        !busy
                                    ? () => widget.onAdd(product)
                                    : null,
                                child: Text(busy ? 'Adding…' : 'Add to cart'))),
                      ])),
            ])));
  }
}
