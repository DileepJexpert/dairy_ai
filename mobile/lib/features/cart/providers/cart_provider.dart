import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/features/marketplace/providers/product_provider.dart';
import 'package:dairy_ai/core/analytics_service.dart';
import '../models/cart_models.dart';
import '../services/local_basket_storage.dart';

export '../services/local_basket_storage.dart';

final cartProvider =
    StateNotifierProvider<CartNotifier, AsyncValue<Cart>>((ref) {
  final dio = ref.watch(dioProvider);
  final storage = ref.watch(localBasketStorageProvider);
  final analytics = ref.read(analyticsServiceProvider);
  final user = ref.watch(currentUserProvider);
  return CartNotifier(
    dio: dio,
    storage: storage,
    ref: ref,
    analytics: analytics,
    isLoggedIn: user != null,
  );
});

final cartItemCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider).valueOrNull?.itemCount ?? 0);

final savedItemsErrorProvider = StateProvider<String?>((ref) => null);
final savedForLaterProvider =
    StateNotifierProvider<SavedForLaterNotifier, List<CartItem>>((ref) {
  final user = ref.watch(currentUserProvider);
  return SavedForLaterNotifier(ref, enabled: user != null);
});

class SavedForLaterNotifier extends StateNotifier<List<CartItem>> {
  SavedForLaterNotifier(this.ref, {bool enabled = true}) : super([]) {
    if (enabled) Future.microtask(refresh);
  }
  final Ref ref;
  Dio get dio => ref.read(dioProvider);

  Future<void> refresh() async {
    if (!mounted) return;
    try {
      final res = await dio.get('/marketplace/saved-items');
      if (!mounted) return;
      state = (res.data['data'] as List)
          .map((j) => CartItem.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      ref.read(savedItemsErrorProvider.notifier).state = null;
    } catch (_) {
      if (mounted) {
        ref.read(savedItemsErrorProvider.notifier).state =
            'Saved items could not be loaded.';
      }
    }
  }

  Future<void> save(CartItem item) async {
    await dio.post('/marketplace/cart/items/${item.id}/save');
    await refresh();
    if (mounted) await ref.read(cartProvider.notifier).refresh();
  }

  Future<void> restore(CartItem item) async {
    await dio.post('/marketplace/saved-items/${item.productId}/restore');
    await refresh();
    if (mounted) await ref.read(cartProvider.notifier).refresh();
  }

  Future<void> remove(String id) async {
    await dio.delete('/marketplace/saved-items/$id');
    if (mounted) state = state.where((p) => p.productId != id).toList();
  }
}

class CartNotifier extends StateNotifier<AsyncValue<Cart>> {
  CartNotifier({
    required Dio dio,
    required LocalBasketStorage storage,
    required this.ref,
    AnalyticsService? analytics,
    bool isLoggedIn = false,
  })  : _dio = dio,
        _storage = storage,
        _analytics = analytics,
        _isLoggedIn = isLoggedIn,
        super(AsyncValue.data(_createEmptyCart())) {
    _initFuture = _init();
  }

  final Dio _dio;
  final LocalBasketStorage _storage;
  final Ref ref;
  final AnalyticsService? _analytics;
  final bool _isLoggedIn;
  Future<void>? _initFuture;

  Future<void> _waitForInit() async {
    if (_initFuture != null) {
      try {
        await _initFuture;
      } catch (_) {}
    }
  }

  static Cart _createEmptyCart() {
    return const Cart(
      id: '',
      itemCount: 0,
      subtotal: 0.0,
      items: [],
    );
  }

  Future<void> _init() async {
    final localItems = await _storage.load();
    if (mounted) {
      state = AsyncValue.data(_buildLocalCart(localItems));
    }
    if (_isLoggedIn) {
      await _refreshInternal(throwOnError: false);
    }
  }

  Cart _buildLocalCart(List<LocalBasketItem> localItems) {
    if (localItems.isEmpty) return _createEmptyCart();

    final snapshot = ref.read(staticCatalogueProvider).valueOrNull;
    final cartItems = <CartItem>[];
    double subtotal = 0.0;
    int totalCount = 0;

    for (final item in localItems) {
      final product = snapshot?.byId(item.productId);
      final price = product?.price ?? item.priceWhenAdded ?? 0.0;
      final lineTotal = price * item.quantity;
      subtotal += lineTotal;
      totalCount += item.quantity;

      cartItems.add(CartItem(
        id: item.productId,
        productId: item.productId,
        title: product?.title ?? item.title ?? 'Product',
        quantity: item.quantity,
        priceWhenAdded: item.priceWhenAdded ?? price,
        currentPrice: price,
        inStock: product != null ? (!product.stockKnown || product.inStock) : true,
        lineTotal: lineTotal,
        vendorName:
            product?.vendor?['business_name']?.toString() ?? 'Milterra Dairy',
        primaryImage: product?.primaryImage ?? item.primaryImage,
        unit: product?.unit ?? item.unit ?? 'item',
        priceChanged: item.priceWhenAdded != null &&
            product != null &&
            (item.priceWhenAdded! - product.price).abs() > 0.01,
        availableQuantity: product?.availableQuantity ?? 99,
      ));
    }

    return Cart(
      id: 'local-basket',
      itemCount: totalCount,
      subtotal: subtotal,
      items: cartItems,
    );
  }

  Future<void> refresh({bool throwOnError = false}) async {
    await _waitForInit();
    await _refreshInternal(throwOnError: throwOnError);
  }

  Future<void> _refreshInternal({bool throwOnError = false}) async {
    final localItems = await _storage.load();

    if (!_isLoggedIn) {
      if (mounted) {
        state = AsyncValue.data(_buildLocalCart(localItems));
      }
      return;
    }

    try {
      final res = await _dio.get('/marketplace/cart');
      final body = res.data as Map<String, dynamic>;
      if (body['data'] is! Map) {
        throw const FormatException('Cart response did not contain data');
      }
      var serverCart =
          Cart.fromJson(Map<String, dynamic>.from(body['data'] as Map));

      if (localItems.isEmpty) {
        await _syncLocalStorageWithServer(serverCart.items);
        if (mounted) {
          state = AsyncValue.data(serverCart);
        }
        return;
      }

      // Merge local basket with server cart:
      // - Delete items removed locally while offline
      // - Sync missing items to server
      // - Sync offline quantity updates to server
      final localItemMap = {for (final item in localItems) item.productId: item};
      final serverItemMap =
          {for (final item in serverCart.items) item.productId: item};
      bool syncedPending = false;

      // 1. Delete server items not present in localItems (offline deletions)
      for (final serverItem in serverCart.items) {
        if (!localItemMap.containsKey(serverItem.productId)) {
          try {
            await _dio.delete('/marketplace/cart/items/${serverItem.id}');
            syncedPending = true;
          } catch (_) {}
        }
      }

      // 2. Add new local items and update quantities
      for (final localItem in localItems) {
        final serverItem = serverItemMap[localItem.productId];
        if (serverItem == null) {
          try {
            await _dio.post('/marketplace/cart/items', data: {
              'product_id': localItem.productId,
              'quantity': localItem.quantity,
            });
            syncedPending = true;
          } catch (_) {}
        } else if (serverItem.quantity != localItem.quantity) {
          try {
            await _dio.put('/marketplace/cart/items/${serverItem.id}', data: {
              'quantity': localItem.quantity,
            });
            syncedPending = true;
          } catch (_) {}
        }
      }

      if (syncedPending) {
        final reRes = await _dio.get('/marketplace/cart');
        final reBody = reRes.data as Map<String, dynamic>;
        serverCart =
            Cart.fromJson(Map<String, dynamic>.from(reBody['data'] as Map));
      }

      await _syncLocalStorageWithServer(serverCart.items);
      if (mounted) {
        state = AsyncValue.data(serverCart);
      }
    } catch (error, stackTrace) {
      // Backend is unavailable: fall back to latest local basket without crashing
      final latestLocal = await _storage.load();
      if (mounted) {
        state = AsyncValue.data(_buildLocalCart(latestLocal));
      }
      if (throwOnError) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  Future<void> _syncLocalStorageWithServer(List<CartItem> serverItems) async {
    final newLocalItems = serverItems
        .map((item) => LocalBasketItem(
              productId: item.productId,
              quantity: item.quantity,
              priceWhenAdded: item.priceWhenAdded,
              title: item.title,
              primaryImage: item.primaryImage,
              unit: item.unit,
              addedAt: DateTime.now(),
            ))
        .toList();
    await _storage.save(newLocalItems);
  }

  Future<void> add(String productId, int quantity, [Product? product]) async {
    await _waitForInit();
    if (product?.isConcept == true) {
      throw StateError('Concept products are not for sale');
    }

    // 1. Update local basket first
    final localItems = await _storage.addItem(
      productId: productId,
      quantity: quantity,
      price: product?.price,
      title: product?.title,
      primaryImage: product?.primaryImage,
      unit: product?.unit,
      packSize: product?.packSize,
    );

    // 2. Optimistically update state
    if (mounted) {
      state = AsyncValue.data(_buildLocalCart(localItems));
    }

    _analytics?.trackAddToCart(
      productId,
      product?.title ?? 'Product',
      quantity,
      product?.price ?? 0.0,
    );

    // 3. If logged in, sync with backend (swallowing API failure so local basket works offline)
    if (_isLoggedIn) {
      try {
        await _dio.post('/marketplace/cart/items', data: {
          'product_id': productId,
          'quantity': quantity,
        });
        await _refreshInternal(throwOnError: false);
      } catch (_) {
        // API outage: local basket retains selection safely
      }
    }
  }

  Future<void> update(String itemId, int quantity) async {
    await _waitForInit();
    String productId = itemId;
    final currentCart = state.valueOrNull;
    if (currentCart != null) {
      final matching = currentCart.items
          .where((i) => i.id == itemId || i.productId == itemId)
          .firstOrNull;
      if (matching != null) {
        productId = matching.productId;
      }
    }

    final localItems = await _storage.updateQuantity(productId, quantity);
    if (mounted) {
      state = AsyncValue.data(_buildLocalCart(localItems));
    }

    if (_isLoggedIn) {
      try {
        if (quantity <= 0) {
          await _dio.delete('/marketplace/cart/items/$itemId');
        } else {
          await _dio.put(
            '/marketplace/cart/items/$itemId',
            data: {'quantity': quantity},
          );
        }
      } catch (_) {}
    }
  }

  Future<void> remove(String itemId) async {
    await _waitForInit();
    _analytics?.trackRemoveFromCart(itemId, 'Cart Item');
    String productId = itemId;
    final currentCart = state.valueOrNull;
    if (currentCart != null) {
      final matching = currentCart.items
          .where((i) => i.id == itemId || i.productId == itemId)
          .firstOrNull;
      if (matching != null) {
        productId = matching.productId;
      }
    }

    final localItems = await _storage.removeItem(productId);
    if (mounted) {
      state = AsyncValue.data(_buildLocalCart(localItems));
    }

    if (_isLoggedIn) {
      try {
        await _dio.delete('/marketplace/cart/items/$itemId');
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    await _waitForInit();
    await _storage.clear();
    if (mounted) {
      state = AsyncValue.data(_createEmptyCart());
    }
    if (_isLoggedIn) {
      try {
        await _dio.delete('/marketplace/cart');
      } catch (_) {}
    }
  }

  /// Reconciles local basket items with the server before checkout.
  /// Throws if the backend cannot be reached, so checkout can show the retry state.
  Future<Cart> reconcileWithBackend() async {
    await _waitForInit();
    final localItems = await _storage.load();
    if (localItems.isEmpty) {
      try {
        await _dio.delete('/marketplace/cart');
      } catch (_) {}
      final empty = _createEmptyCart();
      if (mounted) state = AsyncValue.data(empty);
      return empty;
    }

    final res = await _dio.get('/marketplace/cart');
    final body = res.data as Map<String, dynamic>;
    var serverCart =
        Cart.fromJson(Map<String, dynamic>.from(body['data'] as Map));

    final localItemMap = {for (final item in localItems) item.productId: item};
    final serverItemMap =
        {for (final item in serverCart.items) item.productId: item};

    bool needsReload = false;

    // 1. If an item exists on server but was deleted locally while offline, delete it from server
    for (final serverItem in serverCart.items) {
      if (!localItemMap.containsKey(serverItem.productId)) {
        try {
          await _dio.delete('/marketplace/cart/items/${serverItem.id}');
          needsReload = true;
        } catch (_) {}
      }
    }

    // 2. If an item was added locally while offline, add to server
    // 3. If an item exists in both but quantity was updated locally while offline, update on server
    for (final localItem in localItems) {
      final serverItem = serverItemMap[localItem.productId];
      if (serverItem == null) {
        await _dio.post('/marketplace/cart/items', data: {
          'product_id': localItem.productId,
          'quantity': localItem.quantity,
        });
        needsReload = true;
      } else if (serverItem.quantity != localItem.quantity) {
        try {
          await _dio.put('/marketplace/cart/items/${serverItem.id}', data: {
            'quantity': localItem.quantity,
          });
          needsReload = true;
        } catch (_) {}
      }
    }

    if (needsReload) {
      final reRes = await _dio.get('/marketplace/cart');
      final reBody = reRes.data as Map<String, dynamic>;
      serverCart =
          Cart.fromJson(Map<String, dynamic>.from(reBody['data'] as Map));
    }

    await _syncLocalStorageWithServer(serverCart.items);
    if (mounted) state = AsyncValue.data(serverCart);
    return serverCart;
  }

  Future<Map<String, dynamic>> validate() async {
    try {
      final body = (await _dio.post('/marketplace/cart/validate')).data
          as Map<String, dynamic>;
      return Map<String, dynamic>.from(body['data'] as Map);
    } catch (error, stackTrace) {
      if (mounted) {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
