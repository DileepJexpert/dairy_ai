import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cart/providers/cart_provider.dart';
import '../../cart/widgets/store_cart_drawer.dart';
import '../models/product_models.dart';
import '../providers/product_provider.dart';
import '../widgets/store_design.dart';
import '../widgets/store_product_card.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;
  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  int _quantity = 1, _image = 0;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId) {
      _quantity = 1;
      _image = 0;
    }
  }

  bool _available(Product p) =>
      p.inStock && p.availableQuantity >= p.minOrderQuantity;
  Future<void> _purchase(Product p,
      {bool checkout = false, int? quantity}) async {
    if (ref.read(currentUserProvider) == null) {
      context.go('/login?next=/marketplace/product/${p.id}');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(cartProvider.notifier).add(p.id, quantity ?? _quantity);
      if (!mounted) return;
      if (checkout) {
        context.push('/marketplace/checkout');
      } else {
        await showStoreCart(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not add this item. Check stock and try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(productDetailProvider(widget.productId));
    final product = result.valueOrNull;
    final mobile = MediaQuery.sizeOf(context).width < StoreLayout.tablet;
    if (product != null && _quantity < product.minOrderQuantity) {
      _quantity = product.minOrderQuantity;
    }
    return Scaffold(
        bottomNavigationBar: mobile &&
                product != null &&
                MediaQuery.viewInsetsOf(context).bottom == 0
            ? _mobilePurchase(product)
            : null,
        body: Column(children: [
          const StoreHeader(),
          StoreCategoryNavigation(
              selected: product?.taxonomy?['category_id']?.toString() ??
                  (product == null ? 'All products' : storeCategory(product))),
          Expanded(
              child: result.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('This product could not be loaded.',
                  style: StoreType.title),
              StoreLayout.panelGap,
              OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(productDetailProvider(widget.productId)),
                  child: const Text('Try again')),
              TextButton(
                  onPressed: () => storeBackToShop(context),
                  child: const Text('Back to shop')),
            ])),
            data: (p) {
              final others =
                  ref.watch(productsProvider(p.category)).valueOrNull ??
                      <Product>[];
              final packs = others
                  .where((x) => x.vendorId == p.vendorId && x.title == p.title)
                  .toList();
              if (!packs.any((x) => x.id == p.id)) packs.add(p);
              packs.sort((a, b) => a.price.compareTo(b.price));
              final related = storeProductGroups(others
                      .where(
                          (x) => x.vendorId != p.vendorId || x.title != p.title)
                      .toList())
                  .take(3)
                  .toList();
              return SingleChildScrollView(
                  key: ValueKey(p.id),
                  child: Column(children: [
                    Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: StoreLayout.maxWidth),
                            child: Padding(
                                padding: EdgeInsets.all(mobile ? 16 : 32),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            TextButton.icon(
                                                onPressed: () =>
                                                    storeBackToShop(context),
                                                icon: const Icon(
                                                    Icons.arrow_back,
                                                    size: 16),
                                                label:
                                                    const Text('Back to shop')),
                                            const Text(' / ',
                                                style: StoreType.muted),
                                            Text(storeCategory(p),
                                                style: StoreType.muted),
                                          ]),
                                      const SizedBox(height: 20),
                                      if (mobile) ...[
                                        _gallery(p, mobile),
                                        const SizedBox(height: 28),
                                        _purchaseSection(p, packs, mobile),
                                      ] else
                                        Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                  flex: 6,
                                                  child: _gallery(p, mobile)),
                                              const SizedBox(width: 48),
                                              Expanded(
                                                  flex: 5,
                                                  child: _purchaseSection(
                                                      p, packs, mobile)),
                                            ]),
                                      if (related.isNotEmpty) ...[
                                        const SizedBox(
                                            height: StoreLayout.sectionSpace),
                                        const Text(
                                            'Explore more from the collection',
                                            style: StoreType.heading),
                                        const SizedBox(height: 24),
                                        LayoutBuilder(
                                            builder: (context, space) {
                                          final columns = mobile
                                              ? (space.maxWidth < 340 ? 1 : 2)
                                              : 3;
                                          return Wrap(
                                              spacing: 24,
                                              runSpacing: 28,
                                              children: related
                                                  .map((group) => SizedBox(
                                                      width: (space.maxWidth -
                                                              24 *
                                                                  (columns -
                                                                      1)) /
                                                          columns,
                                                      child: StoreProductCard(
                                                          packs: group,
                                                          compact: mobile,
                                                          busyIds: _busy
                                                              ? group
                                                                  .map((p) =>
                                                                      p.id)
                                                                  .toSet()
                                                              : {},
                                                          onOpen: (item) =>
                                                              context.replace(
                                                                  '/marketplace/product/${item.id}'),
                                                          onAdd: (item) =>
                                                              _purchase(item,
                                                                  quantity: item.minOrderQuantity))))
                                                  .toList());
                                        }),
                                      ],
                                      const SizedBox(
                                          height: StoreLayout.sectionSpace),
                                    ])))),
                    const StoreFooter(),
                  ]));
            },
          )),
        ]));
  }

  Widget _gallery(Product p, bool mobile) => Column(children: [
        Material(
            color: storeWarm,
            borderRadius: StoreLayout.corners,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        child: SizedBox(
                            width: 760,
                            height: 740,
                            child: Column(children: [
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                      tooltip: 'Close image',
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.close))),
                              Expanded(
                                  child: InteractiveViewer(
                                      minScale: 1,
                                      maxScale: 3,
                                      child: Padding(
                                          padding: StoreLayout.panelPadding,
                                          child: ProductArtwork(
                                              product: p,
                                              imageIndex: _image)))),
                            ])))),
                child: AspectRatio(
                    aspectRatio: mobile ? 1.08 : 1,
                    child: Padding(
                        padding: EdgeInsets.all(mobile ? 16 : 28),
                        child:
                            ProductArtwork(product: p, imageIndex: _image))))),
        const SizedBox(height: 12),
        const Text('Select the image to enlarge', style: StoreType.caption),
        if (p.media.length > 1) ...[
          const SizedBox(height: 16),
          SizedBox(
              height: 72,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Semantics(
                      selected: _image == i,
                      label: 'Product image ${i + 1}',
                      child: InkWell(
                          onTap: () => setState(() => _image = i),
                          child: Container(
                              width: 72,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  borderRadius: StoreLayout.corners,
                                  border: Border.all(
                                      color: _image == i
                                          ? storeGreen
                                          : storeBorder,
                                      width: _image == i ? 2 : 1)),
                              child: Image.network(p.media[i],
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined))))))),
        ],
      ]);

  Widget _purchaseSection(Product p, List<Product> packs, bool mobile) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((p.brand ?? 'Milterra').toUpperCase(), style: StoreType.eyebrow),
        const SizedBox(height: 10),
        Text(p.title.replaceFirst('Milterra ', ''),
            style: StoreType.productTitle),
        const SizedBox(height: 16),
        Text(storeMoney(p.price), style: StoreType.price),
        Text('Price per ${p.unit}', style: StoreType.muted),
        const SizedBox(height: 24),
        const Text('Choose a pack', style: StoreType.label),
        const SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: packs
                .map((pack) => ChoiceChip(
                    label: Text(pack.packSize ?? pack.unit),
                    selected: pack.id == p.id,
                    onSelected: _busy
                        ? null
                        : (_) {
                            if (pack.id != p.id) {
                              context
                                  .replace('/marketplace/product/${pack.id}');
                            }
                          }))
                .toList()),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(child: Text('Quantity', style: StoreType.label)),
          Text(_available(p) ? 'In stock' : 'Currently unavailable',
              style: _available(p) ? StoreType.stock : StoreType.muted),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          DecoratedBox(
              decoration: BoxDecoration(
                  border: Border.all(color: storeBorder),
                  borderRadius:
                      BorderRadius.circular(StoreLayout.controlRadius)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    tooltip: 'Decrease quantity',
                    onPressed: _quantity > p.minOrderQuantity && !_busy
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove, size: 18)),
                Semantics(
                    liveRegion: true,
                    label: 'Quantity $_quantity',
                    child: SizedBox(
                        width: 34,
                        child: Text('$_quantity',
                            textAlign: TextAlign.center,
                            style: StoreType.label))),
                IconButton(
                    tooltip: 'Increase quantity',
                    onPressed: _available(p) &&
                            _quantity < p.availableQuantity &&
                            !_busy
                        ? () => setState(() => _quantity++)
                        : null,
                    icon: const Icon(Icons.add, size: 18)),
              ])),
          const SizedBox(width: 16),
          if (_quantity > 1)
            Expanded(
                child: Text('Item total: ${storeMoney(p.price * _quantity)}',
                    style: StoreType.label)),
        ]),
        if (p.minOrderQuantity > 1)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Minimum order: ${p.minOrderQuantity} packs',
                  style: StoreType.muted)),
        const SizedBox(height: 20),
        if (!mobile) ...[
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed:
                      _available(p) && !_busy ? () => _purchase(p) : null,
                  child: Text(_busy ? 'Adding…' : 'Add to cart'))),
          const SizedBox(height: 10),
        ],
        SizedBox(
            width: double.infinity,
            child: OutlinedButton(
                onPressed: _available(p) && !_busy
                    ? () => _purchase(p, checkout: true)
                    : null,
                child: const Text('Proceed to checkout'))),
        const SizedBox(height: 14),
        Text('Sold by ${p.vendor?['business_name']?.toString() ?? 'seller'}',
            style: StoreType.muted),
        const SizedBox(height: 28),
        _section(
            'About this item',
            Text(
                p.description ??
                    'The seller has not provided a description for this product.',
                style: StoreType.body),
            expanded: true),
        _section(
            'Product information',
            Column(children: [
              _detailRow('Brand', p.brand ?? 'Not provided'),
              _detailRow('Product', p.title),
              _detailRow('Category', storeCategory(p)),
              _detailRow('Pack size', p.packSize ?? p.unit),
              _detailRow('Sold by',
                  p.vendor?['business_name']?.toString() ?? 'Not provided'),
              for (final entry in p.specifications.entries)
                _detailRow(_label(entry.key), entry.value.toString()),
            ])),
        _section(
            'Ingredients & nutrition',
            Text(
                p.specifications['ingredients']?.toString() ??
                    'Ingredient, allergen and nutrition details have not been supplied by the seller. Check the product label before use.',
                style: StoreType.muted)),
        _section(
            'Delivery & returns',
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select your address at checkout.',
                      style: StoreType.body),
                  SizedBox(height: 8),
                  Text(
                      'Delivery estimates and return terms have not been provided yet.',
                      style: StoreType.muted),
                ])),
        _section(
            'About the seller',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.vendor?['business_name']?.toString() ?? 'Seller',
                  style: StoreType.cardTitle),
              Text(
                  [p.vendor?['district'], p.vendor?['state']]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(', '),
                  style: StoreType.muted),
            ])),
        _section(
            'Customer reviews',
            const Text('Customer reviews are not available yet.',
                style: StoreType.muted)),
      ]);

  Widget _section(String title, Widget child, {bool expanded = false}) =>
      ExpansionTile(
          key: PageStorageKey(widget.productId + title),
          initiallyExpanded: expanded,
          title: Text(title, style: StoreType.cardTitle),
          children: [
            Align(alignment: Alignment.centerLeft, child: child),
          ]);

  Widget _mobilePurchase(Product p) => Container(
      decoration: const BoxDecoration(
          color: storeCream,
          border: Border(top: BorderSide(color: storeBorder))),
      child: SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Expanded(
                    child: Text('${p.packSize ?? p.unit} · Qty $_quantity',
                        style: StoreType.label)),
                const SizedBox(width: 12),
                FilledButton(
                    onPressed:
                        _available(p) && !_busy ? () => _purchase(p) : null,
                    child: Text(_busy ? 'Adding…' : 'Add to cart')),
              ]))));

  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  Widget _detailRow(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: StoreType.muted)),
        const SizedBox(width: 16),
        Expanded(flex: 3, child: Text(value, style: StoreType.body)),
      ]));
}
