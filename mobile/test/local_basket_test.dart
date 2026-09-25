import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/auth/models/user_model.dart';
import 'package:dairy_ai/features/cart/providers/cart_provider.dart';
import 'package:dairy_ai/features/marketplace/models/static_catalogue.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';

class _FakeFailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'Backend API is down',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeCartBackendAdapter implements HttpClientAdapter {
  final Map<String, int> serverCart = {};

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final path = options.path;

    if (options.method == 'GET' && path == '/marketplace/cart') {
      final items = serverCart.entries.map((e) {
        final price = e.key == 'cow500' ? 899.0 : 1200.0;
        return {
          'id': 'server-${e.key}',
          'product_id': e.key,
          'title': e.key == 'cow500' ? 'Milterra A2 Desi Cow Ghee' : 'Other Ghee',
          'quantity': e.value,
          'price_when_added': price,
          'current_price': price,
          'in_stock': true,
          'line_total': price * e.value,
          'unit': 'jar',
        };
      }).toList();

      final subtotal = items.fold<double>(0.0, (acc, item) => acc + (item['line_total'] as double));
      final count = items.fold<int>(0, (acc, item) => acc + (item['quantity'] as int));

      return ResponseBody.fromString(
        '''
        {
          "success": true,
          "data": {
            "id": "server-cart-123",
            "item_count": $count,
            "subtotal": $subtotal,
            "items": ${items.map((i) => '''
              {
                "id": "${i['id']}",
                "product_id": "${i['product_id']}",
                "title": "${i['title']}",
                "quantity": ${i['quantity']},
                "price_when_added": ${i['price_when_added']},
                "current_price": ${i['current_price']},
                "in_stock": ${i['in_stock']},
                "line_total": ${i['line_total']},
                "unit": "${i['unit']}"
              }
            ''').toList()}
          }
        }
        ''',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'POST' && path == '/marketplace/cart/items') {
      final data = options.data as Map;
      final productId = data['product_id'].toString();
      final qty = (data['quantity'] as num).toInt();
      serverCart[productId] = (serverCart[productId] ?? 0) + qty;
      return ResponseBody.fromString(
        '{"success": true, "data": {"id": "item-$productId", "quantity": ${serverCart[productId]}}}',
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'PUT' && path.startsWith('/marketplace/cart/items/')) {
      final itemId = path.split('/').last;
      final productId = itemId.replaceFirst('server-', '').replaceFirst('item-', '');
      final data = options.data as Map;
      final qty = (data['quantity'] as num).toInt();
      serverCart[productId] = qty;
      return ResponseBody.fromString(
        '{"success": true, "data": {"id": "$itemId", "quantity": $qty}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'DELETE' && path.startsWith('/marketplace/cart/items/')) {
      final itemId = path.split('/').last;
      final productId = itemId.replaceFirst('server-', '').replaceFirst('item-', '');
      serverCart.remove(productId);
      return ResponseBody.fromString(
        '{"success": true, "data": {}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    if (options.method == 'DELETE' && path == '/marketplace/cart') {
      serverCart.clear();
      return ResponseBody.fromString(
        '{"success": true, "data": {}}',
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    throw DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: 404),
    );
  }

  @override
  void close({bool force = false}) {}
}

final _hash = List.filled(64, 'b').join();

final _sampleCatalogue = StaticCatalogue.parse('''
{
  "schema_version": 1,
  "content_sha256": "$_hash",
  "products": [
    {
      "id": "cow500",
      "sku": "MIL-GHEE-500",
      "vendor_id": "seller-milterra",
      "title": "Milterra A2 Desi Cow Ghee (500ml)",
      "category": "FEED_NUTRITION",
      "base_price": "799.00",
      "unit": "jar",
      "pack_size": "500 ml",
      "publication_status": "published",
      "is_active": true,
      "specifications": {},
      "media": []
    },
    {
      "id": "paneer200",
      "sku": "MIL-PANEER-200",
      "vendor_id": "seller-milterra",
      "title": "Milterra Fresh Paneer (200g)",
      "category": "FEED_NUTRITION",
      "base_price": "160.00",
      "unit": "pack",
      "pack_size": "200 g",
      "publication_status": "published",
      "is_active": true,
      "specifications": {},
      "media": []
    }
  ],
  "families": []
}
''');

void main() {
  test('Anonymous customer adds, updates, and removes items locally without network', () async {
    final mockStorage = LocalBasketStorage();
    final dio = Dio()..httpClientAdapter = _FakeFailingAdapter();

    final container = ProviderContainer(
      overrides: [
        localBasketStorageProvider.overrideWithValue(mockStorage),
        dioProvider.overrideWithValue(dio),
        currentUserProvider.overrideWith((ref) => null),
        staticCatalogueProvider.overrideWith((ref) => Future.value(_sampleCatalogue)),
      ],
    );
    addTearDown(container.dispose);

    // Initial state: empty basket
    var cart = container.read(cartProvider).valueOrNull;
    expect(cart, isNotNull);
    expect(cart!.itemCount, 0);

    // 1. Add cow500 to cart anonymously
    await container.read(cartProvider.notifier).add(
          'cow500',
          2,
          _sampleCatalogue.byId('cow500'),
        );

    cart = container.read(cartProvider).valueOrNull;
    expect(cart, isNotNull);
    expect(cart!.itemCount, 2);
    expect(cart.subtotal, 1598.0); // 799 * 2
    expect(cart.items.first.title, 'Milterra A2 Desi Cow Ghee (500ml)');

    // Verify persisted in LocalBasketStorage
    final savedItems = await mockStorage.load();
    expect(savedItems.length, 1);
    expect(savedItems.first.productId, 'cow500');
    expect(savedItems.first.quantity, 2);

    // 2. Add paneer200
    await container.read(cartProvider.notifier).add(
          'paneer200',
          1,
          _sampleCatalogue.byId('paneer200'),
        );
    cart = container.read(cartProvider).valueOrNull;
    expect(cart!.itemCount, 3);
    expect(cart.subtotal, 1758.0); // 1598 + 160

    // 3. Update quantity of cow500 to 3
    await container.read(cartProvider.notifier).update('cow500', 3);
    cart = container.read(cartProvider).valueOrNull;
    expect(cart!.itemCount, 4);
    expect(cart.subtotal, 2557.0); // 799 * 3 + 160

    // 4. Remove paneer200
    await container.read(cartProvider.notifier).remove('paneer200');
    cart = container.read(cartProvider).valueOrNull;
    expect(cart!.itemCount, 3);
    expect(cart.subtotal, 2397.0); // 799 * 3

    // 5. Clear cart
    await container.read(cartProvider.notifier).clear();
    cart = container.read(cartProvider).valueOrNull;
    expect(cart!.itemCount, 0);
    expect((await mockStorage.load()).isEmpty, isTrue);
  });

  test('Outage resilience: browsing and basket editing remain functional when API is down', () async {
    final mockStorage = LocalBasketStorage();
    // Pre-populate storage with an item
    await mockStorage.addItem(
      productId: 'cow500',
      quantity: 1,
      price: 799.0,
      title: 'Milterra A2 Desi Cow Ghee (500ml)',
    );

    final dio = Dio()..httpClientAdapter = _FakeFailingAdapter();

    // Authenticated user with failing backend API
    final container = ProviderContainer(
      overrides: [
        localBasketStorageProvider.overrideWithValue(mockStorage),
        dioProvider.overrideWithValue(dio),
        currentUserProvider.overrideWith((ref) => const UserModel(
              id: 'user-1',
              phone: '+919999900000',
              role: 'farmer',
            )),
        staticCatalogueProvider.overrideWith((ref) => Future.value(_sampleCatalogue)),
      ],
    );
    addTearDown(container.dispose);

    // Refresh against failing backend falls back to local storage gracefully without throwing
    await container.read(cartProvider.notifier).refresh(throwOnError: false);

    final cart = container.read(cartProvider).valueOrNull;
    expect(cart, isNotNull);
    expect(cart!.itemCount, 1);
    expect(cart.subtotal, 799.0);
    expect(cart.items.first.productId, 'cow500');

    // Customer can continue editing basket locally during outage
    await container.read(cartProvider.notifier).update('cow500', 4);
    final updatedCart = container.read(cartProvider).valueOrNull;
    expect(updatedCart!.itemCount, 4);
    expect(updatedCart.subtotal, 3196.0);
  });

  test('Reconciliation: local items sync to backend and retrieve authoritative server cart', () async {
    final mockStorage = LocalBasketStorage();
    final fakeBackend = _FakeCartBackendAdapter();
    final dio = Dio()..httpClientAdapter = fakeBackend;

    // Anonymous user selected cow500 in local basket
    await mockStorage.addItem(
      productId: 'cow500',
      quantity: 2,
      price: 799.0,
    );

    // User logs in and visits checkout
    final container = ProviderContainer(
      overrides: [
        localBasketStorageProvider.overrideWithValue(mockStorage),
        dioProvider.overrideWithValue(dio),
        currentUserProvider.overrideWith((ref) => const UserModel(
              id: 'user-1',
              phone: '+919999900000',
              role: 'farmer',
            )),
        staticCatalogueProvider.overrideWith((ref) => Future.value(_sampleCatalogue)),
      ],
    );
    addTearDown(container.dispose);

    // Reconcile pushes local selection to backend
    final reconciledCart = await container.read(cartProvider.notifier).reconcileWithBackend();

    expect(reconciledCart.itemCount, 2);
    // Server price is 899.0, so line total reflects authoritative server value
    expect(reconciledCart.subtotal, 1798.0);
    expect(reconciledCart.items.first.currentPrice, 899.0);

    // Verify server has received the item
    expect(fakeBackend.serverCart['cow500'], 2);
  });

  test('Bidirectional reconciliation: offline quantity updates and item deletions sync to backend', () async {
    final mockStorage = LocalBasketStorage();
    final fakeBackend = _FakeCartBackendAdapter();
    final dio = Dio()..httpClientAdapter = fakeBackend;

    // Server already has cow500 (qty 2) and paneer200 (qty 1)
    fakeBackend.serverCart['cow500'] = 2;
    fakeBackend.serverCart['paneer200'] = 1;

    // Offline user updated cow500 to qty 5 and removed paneer200 from local basket
    await mockStorage.addItem(
      productId: 'cow500',
      quantity: 5,
      price: 799.0,
    );

    final container = ProviderContainer(
      overrides: [
        localBasketStorageProvider.overrideWithValue(mockStorage),
        dioProvider.overrideWithValue(dio),
        currentUserProvider.overrideWith((ref) => const UserModel(
              id: 'user-1',
              phone: '+919999900000',
              role: 'farmer',
            )),
        staticCatalogueProvider.overrideWith((ref) => Future.value(_sampleCatalogue)),
      ],
    );
    addTearDown(container.dispose);

    // Reconcile pushes offline quantity modification (5) and deletion of paneer200 to backend
    final reconciledCart = await container.read(cartProvider.notifier).reconcileWithBackend();

    expect(reconciledCart.itemCount, 5);
    expect(reconciledCart.items.length, 1);
    expect(reconciledCart.items.first.productId, 'cow500');
    expect(reconciledCart.items.first.quantity, 5);

    // Verify backend state reflects user's offline edits
    expect(fakeBackend.serverCart['cow500'], 5);
    expect(fakeBackend.serverCart.containsKey('paneer200'), isFalse);
  });

  test('Storage transparency: isPersisted reflects secure storage success or fallback', () async {
    final storage = LocalBasketStorage();
    expect(storage.isPersisted, isTrue);

    storage.setPersistedForTesting(false);
    expect(storage.isPersisted, isFalse);

    storage.setPersistedForTesting(true);
    expect(storage.isPersisted, isTrue);
  });
}

