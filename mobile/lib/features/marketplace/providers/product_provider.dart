import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/product_models.dart';
import '../models/static_catalogue.dart';

/// Pages serves a small same-origin pointer and a versioned immutable JSON
/// snapshot. Native builds may bundle the same export as an asset. If neither
/// has been published yet, the live API remains the migration fallback.
final staticCatalogueReaderProvider =
    Provider<Future<StaticCatalogue?> Function()>((ref) {
  if (!kIsWeb) {
    return () async {
      try {
        return StaticCatalogue.parse(
            await rootBundle.loadString(StaticCatalogue.assetPath));
      } on FlutterError {
        return null;
      }
    };
  }
  return () async {
    final client = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ));
    final pointerUrl = Uri.base.resolve(StaticCatalogue.pointerUrl);
    if (pointerUrl.origin != Uri.base.origin) {
      throw const FormatException('Catalogue pointer must be same-origin');
    }
    Response<String> response;
    try {
      response = await client.get<String>(pointerUrl.toString(),
          options: Options(responseType: ResponseType.plain));
    } on DioException {
      return null;
    }
    final pointer = StaticCataloguePointer.parse(response.data ?? '');
    final snapshotUrl = Uri.base.resolve(pointer.snapshotPath);
    final snapshotResponse = await client.get<String>(snapshotUrl.toString(),
        options: Options(responseType: ResponseType.plain));
    final snapshot = StaticCatalogue.parse(snapshotResponse.data ?? '');
    if (snapshot.contentSha256 != pointer.contentSha256) {
      throw const FormatException('Catalogue pointer and snapshot differ');
    }
    return snapshot;
  };
});

final staticCatalogueProvider = FutureProvider<StaticCatalogue?>((ref) async {
  return ref.read(staticCatalogueReaderProvider)();
});

const _legacyStorefrontSkuAliases = <String, String>{
  'mil-ghee-500': 'MIL-GHEE-500',
  'mil-ghee-1000': 'MIL-GHEE-1000',
  'mil-buff-500': 'MIL-BUFF-500',
  'mil-paneer-200': 'MIL-PANEER-200',
};

// URL aliases only; content still comes from persisted product families.
const _legacyConceptSlugs = <String, String>{
  'feed-janam-42': 'janam-42-transition-nutrition-concept',
  'mil-mineral-supp': 'milterra-minera-360-concept',
  'feed-minera-360-1kg': 'milterra-minera-360-concept',
  'feed-rumen-pro-500g': 'milterra-rumen-pro-concept',
};

Product conceptFamilyProduct(ProductFamily family) => Product(
      id: 'family-${family.id}',
      vendorId: family.vendorId ?? '',
      familyId: family.id,
      title: family.title,
      brand: family.brand,
      category: family.department.toLowerCase().contains('equipment')
          ? ProductCategory.equipment
          : ProductCategory.feedNutrition,
      price: 0,
      unit: 'proposed pack',
      description: family.description,
      publicationStatus: family.isPublished ? 'published' : 'draft',
      media: family.media.isNotEmpty
          ? family.media
          : [if (family.primaryImage != null) family.primaryImage!],
      taxonomy: {
        'concept': true,
        'status': 'Concept Preview',
        'department': family.department,
        'collection': family.collection
      },
      specifications: {
        'concept': true,
        'listing_status': 'concept',
        'family_id': family.id,
        'department': family.department,
        'collection': family.collection
      },
    );

final productsProvider = FutureProvider.family<List<Product>, ProductCategory?>(
    (ref, category) async {
  final snapshot = await ref.watch(staticCatalogueProvider.future);
  if (snapshot != null) {
    final items = snapshot.products
        .where((p) => category == null || p.category == category)
        .toList();
    final existingFamilies = items.map((p) => p.familyId).toSet();
    items.addAll(snapshot.families
        .where((f) =>
            f.isConcept && f.isPublished && !existingFamilies.contains(f.id))
        .map(conceptFamilyProduct)
        .where((p) => category == null || p.category == category));
    return items;
  }

  final items = <Product>[];
  var page = 1;
  while (true) {
    final response = await ref
        .read(dioProvider)
        .get('/marketplace/products', queryParameters: {
      if (category != null)
        'category': category == ProductCategory.equipment
            ? 'EQUIPMENT'
            : 'FEED_NUTRITION',
      'sort_by': 'featured',
      'page': page,
      'per_page': 100,
    });
    final body = response.data as Map;
    final raw = body['data'] as List;
    items.addAll(raw
        .map((j) => Product.fromJson(Map<String, dynamic>.from(j as Map)))
        .where((p) => !p.isDraft));
    if (raw.isEmpty || page * 100 >= (body['total'] as int)) break;
    page++;
  }
  final families = await ref.watch(familiesProvider.future);
  final existingFamilies = items.map((p) => p.familyId).toSet();
  items.addAll(families
      .where((f) =>
          f.isConcept && f.isPublished && !existingFamilies.contains(f.id))
      .map(conceptFamilyProduct)
      .where((p) => category == null || p.category == category));
  return items;
});

final productDetailProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  final snapshot = await ref.watch(staticCatalogueProvider.future);
  if (snapshot != null) {
    final conceptSlug = _legacyConceptSlugs[id];
    final family = conceptSlug != null
        ? snapshot.familyBySlug(conceptSlug)
        : id.startsWith('family-')
            ? snapshot.familyById(id.substring(7))
            : null;
    if (family != null && family.isConcept) {
      return conceptFamilyProduct(family);
    }
    final sku = _legacyStorefrontSkuAliases[id];
    final product = sku == null ? snapshot.byId(id) : snapshot.bySku(sku);
    if (product == null) {
      throw StateError('Product is no longer available.');
    }
    return product;
  }

  if (_legacyConceptSlugs.containsKey(id)) {
    final response = await ref
        .read(dioProvider)
        .get('/marketplace/families/${_legacyConceptSlugs[id]}');
    return conceptFamilyProduct(ProductFamily.fromJson(
        Map<String, dynamic>.from(response.data['data'])));
  }
  if (id.startsWith('family-')) {
    final response = await ref
        .read(dioProvider)
        .get('/marketplace/families/${id.substring(7)}');
    final family = ProductFamily.fromJson(
        Map<String, dynamic>.from(response.data['data']));
    return conceptFamilyProduct(family);
  }
  final sku = _legacyStorefrontSkuAliases[id];
  if (sku != null) {
    final response = await ref.read(dioProvider).get('/marketplace/products',
        queryParameters: {'sku': sku, 'page': 1, 'per_page': 1});
    final data = response.data['data'] as List;
    if (data.isEmpty) throw StateError('Product is no longer available.');
    return Product.fromJson(Map<String, dynamic>.from(data.first));
  }
  final response = await ref.read(dioProvider).get('/marketplace/products/$id');
  return Product.fromJson(Map<String, dynamic>.from(response.data['data']));
});

final familiesProvider = FutureProvider<List<ProductFamily>>((ref) async {
  final snapshot = await ref.watch(staticCatalogueProvider.future);
  if (snapshot != null) return snapshot.families;
  final response = await ref.watch(dioProvider).get('/marketplace/families');
  return (response.data['data'] as List)
      .map((j) => ProductFamily.fromJson(Map<String, dynamic>.from(j)))
      .toList();
});
final vendorFamiliesProvider = FutureProvider<List<ProductFamily>>((ref) async {
  ref.watch(currentUserProvider);
  final response = await ref.watch(dioProvider).get('/vendor/families');
  return (response.data['data'] as List)
      .map((j) => ProductFamily.fromJson(Map<String, dynamic>.from(j)))
      .toList();
});

final recentRFQsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final response = await ref.read(dioProvider).get('/rfq/recent');
    return (response.data['data'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  } catch (_) {
    return [];
  }
});

class VendorStorefrontData {
  final Map<String, dynamic> vendor;
  final List<Product> products;
  const VendorStorefrontData({
    required this.vendor,
    required this.products,
  });
}

final vendorStorefrontProvider =
    FutureProvider.family<VendorStorefrontData, String>((ref, vendorId) async {
  final dio = ref.read(dioProvider);
  final vendorRes = await dio.get('/marketplace/vendors/$vendorId');
  final vendorMap = Map<String, dynamic>.from(vendorRes.data['data'] as Map);

  final prodRes = await dio.get('/marketplace/products', queryParameters: {
    'vendor_id': vendorId,
    'per_page': 100,
  });
  final rawProducts = (prodRes.data['data'] as List? ?? []);
  final products = rawProducts
      .map((j) => Product.fromJson(Map<String, dynamic>.from(j as Map)))
      .where((p) => p.isPublished && !p.isDraft)
      .toList();

  return VendorStorefrontData(vendor: vendorMap, products: products);
});
