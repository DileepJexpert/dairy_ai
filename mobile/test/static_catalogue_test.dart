import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/marketplace/models/static_catalogue.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';

final _hash = List.filled(64, 'a').join();

Map<String, dynamic> _fixture() => {
      'schema_version': 1,
      'content_sha256': _hash,
      'products': [
        {
          'id': 'product-1',
          'sku': 'MIL-GHEE-500',
          'vendor_id': 'seller-1',
          'title': 'Milterra Ghee',
          'category': 'FEED_NUTRITION',
          'base_price': '799.00',
          'unit': 'jar',
          'pack_size': '500 ml',
          'publication_status': 'published',
          'is_active': true,
          'specifications': {'is_featured': true},
          'media': [],
        },
        {
          'id': 'product-2',
          'sku': 'MIL-MILKER-1',
          'vendor_id': 'seller-1',
          'title': 'Milking machine',
          'category': 'EQUIPMENT',
          'base_price': '1000.00',
          'unit': 'piece',
          'publication_status': 'published',
          'is_active': true,
          'media': [],
        },
      ],
      'families': [
        {
          'id': 'family-1',
          'slug': 'concept-slug',
          'vendor_id': 'seller-1',
          'title': 'Future nutrition',
          'brand': 'Milterra',
          'department': 'Animal Nutrition',
          'description': 'In development',
          'is_published': true,
          'is_concept': true,
          'media': [],
          'variants': [],
        },
      ],
    };

void main() {
  test('versioned snapshot supports browsing with no commerce API request',
      () async {
    var apiRequests = 0;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      apiRequests++;
      handler.reject(DioException(requestOptions: request));
    }));
    final catalogue = StaticCatalogue.parse(jsonEncode(_fixture()));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      staticCatalogueReaderProvider.overrideWithValue(() async => catalogue),
    ]);
    addTearDown(container.dispose);

    final all = await container.read(productsProvider(null).future);
    final equipment = await container
        .read(productsProvider(ProductCategory.equipment).future);
    final detail =
        await container.read(productDetailProvider('product-1').future);
    final legacy =
        await container.read(productDetailProvider('mil-ghee-500').future);
    final families = await container.read(familiesProvider.future);

    expect(all.map((p) => p.id), containsAll(['product-1', 'product-2']));
    expect(equipment.map((p) => p.id), ['product-2']);
    expect(detail.price, 799);
    expect(detail.stockKnown, isFalse);
    expect(detail.isStaticSnapshot, isTrue);
    expect(legacy.id, 'product-1');
    expect(families.single.id, 'family-1');
    expect(apiRequests, 0);
  });

  test('snapshot refuses publication status and stock fields', () {
    final draft = _fixture();
    (draft['products'] as List).first['publication_status'] = 'draft';
    expect(
        () => StaticCatalogue.parse(jsonEncode(draft)), throwsFormatException);

    final stocked = _fixture();
    (stocked['products'] as List).first['available_quantity'] = 10;
    expect(() => StaticCatalogue.parse(jsonEncode(stocked)),
        throwsFormatException);
  });

  test('missing published snapshot preserves the live catalogue path',
      () async {
    final paths = <String>[];
    final liveProduct = Map<String, dynamic>.from(
        (_fixture()['products'] as List).first as Map);
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      paths.add(request.path);
      handler.resolve(Response(
        requestOptions: request,
        statusCode: 200,
        data: request.path == '/marketplace/products'
            ? {
                'data': [
                  {
                    ...liveProduct,
                    'in_stock': true,
                    'available_quantity': 3,
                  }
                ],
                'total': 1,
              }
            : {'data': []},
      ));
    }));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWithValue(dio),
      staticCatalogueReaderProvider.overrideWithValue(() async => null),
    ]);
    addTearDown(container.dispose);

    final products = await container.read(productsProvider(null).future);
    expect(products.single.stockKnown, isTrue);
    expect(products.single.isStaticSnapshot, isFalse);
    expect(paths, ['/marketplace/products', '/marketplace/families']);
  });

  test('pointer only accepts a matching versioned catalogue path', () {
    final pointer = StaticCataloguePointer.parse(jsonEncode({
      'schema_version': 1,
      'content_sha256': _hash,
      'snapshot': '/catalogue/products-$_hash.json',
    }));
    expect(pointer.snapshotPath, '/catalogue/products-$_hash.json');
    expect(
      () => StaticCataloguePointer.parse(jsonEncode({
        'schema_version': 1,
        'content_sha256': _hash,
        'snapshot': 'https://example.com/other.json',
      })),
      throwsFormatException,
    );
  });
}
