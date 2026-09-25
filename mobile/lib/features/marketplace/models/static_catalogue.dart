import 'dart:convert';

import 'product_models.dart';

/// A published browsing snapshot. Live stock and checkout prices come from the API.
class StaticCatalogue {
  StaticCatalogue._({
    required this.contentSha256,
    required this.products,
    required this.families,
    required Map<String, Product> productsById,
    required Map<String, Product> productsBySku,
  })  : _productsById = productsById,
        _productsBySku = productsBySku;

  static const schemaVersion = 1;
  static const assetPath = 'assets/catalogue/products.json';
  static const pointerUrl = String.fromEnvironment(
    'CATALOGUE_POINTER_URL',
    defaultValue: '/catalogue/current.json',
  );

  final String contentSha256;
  final List<Product> products;
  final List<ProductFamily> families;
  final Map<String, Product> _productsById;
  final Map<String, Product> _productsBySku;

  Product? byId(String id) => _productsById[id];
  Product? bySku(String sku) => _productsBySku[sku];

  ProductFamily? familyById(String id) {
    for (final family in families) {
      if (family.id == id) return family;
    }
    return null;
  }

  ProductFamily? familyBySlug(String slug) {
    for (final family in families) {
      if (family.slug == slug) return family;
    }
    return null;
  }

  factory StaticCatalogue.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Catalogue root must be an object');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['schema_version'] != schemaVersion) {
      throw const FormatException('Unsupported catalogue schema version');
    }
    final hash = json['content_sha256'];
    if (hash is! String || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException('Catalogue content hash is missing');
    }
    if (json['products'] is! List || json['families'] is! List) {
      throw const FormatException('Catalogue records are missing');
    }

    final products = <Product>[];
    final productsById = <String, Product>{};
    final productsBySku = <String, Product>{};
    for (final raw in json['products'] as List) {
      if (raw is! Map) {
        throw const FormatException('Invalid catalogue product');
      }
      final record = Map<String, dynamic>.from(raw);
      if (record.containsKey('in_stock') ||
          record.containsKey('available_quantity') ||
          record['id'] is! String ||
          (record['id'] as String).isEmpty ||
          record['vendor_id'] is! String ||
          (record['vendor_id'] as String).isEmpty ||
          record['publication_status'] != 'published' ||
          record['is_active'] != true) {
        throw const FormatException(
            'Catalogue contains non-public product data');
      }
      final sku = record['sku'];
      if (sku is! String || sku.isEmpty) {
        throw const FormatException('Catalogue product SKU is missing');
      }
      final product = Product.fromJson(record, snapshot: true);
      if (!product.price.isFinite ||
          product.price < 0 ||
          productsById.containsKey(product.id) ||
          productsBySku.containsKey(sku)) {
        throw const FormatException(
            'Catalogue contains duplicate product IDs or SKUs');
      }
      products.add(product);
      productsById[product.id] = product;
      productsBySku[sku] = product;
    }

    final families = <ProductFamily>[];
    final familyIds = <String>{};
    for (final raw in json['families'] as List) {
      if (raw is! Map) {
        throw const FormatException('Invalid catalogue family');
      }
      final record = Map<String, dynamic>.from(raw);
      final family = ProductFamily.fromJson(record);
      if (family.id.isEmpty ||
          !family.isPublished ||
          !familyIds.add(family.id)) {
        throw const FormatException('Catalogue contains an invalid family');
      }
      families.add(family);
    }
    return StaticCatalogue._(
      contentSha256: hash,
      products: List.unmodifiable(products),
      families: List.unmodifiable(families),
      productsById: Map.unmodifiable(productsById),
      productsBySku: Map.unmodifiable(productsBySku),
    );
  }
}

class StaticCataloguePointer {
  const StaticCataloguePointer({
    required this.snapshotPath,
    required this.contentSha256,
  });

  final String snapshotPath;
  final String contentSha256;

  factory StaticCataloguePointer.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('Catalogue pointer must be an object');
    }
    final json = Map<String, dynamic>.from(decoded);
    final hash = json['content_sha256'];
    if (json['schema_version'] != StaticCatalogue.schemaVersion ||
        hash is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException(
          'Catalogue pointer version or hash is invalid');
    }
    final snapshot = json['snapshot'];
    if (snapshot != '/catalogue/products-$hash.json') {
      throw const FormatException('Catalogue pointer path does not match hash');
    }
    return StaticCataloguePointer(
      snapshotPath: snapshot as String,
      contentSha256: hash,
    );
  }
}
