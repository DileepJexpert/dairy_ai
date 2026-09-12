import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import '../models/cart_models.dart';

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<Cart>>(
    (ref) => CartNotifier(ref.read(dioProvider)));

final cartItemCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider).valueOrNull?.itemCount ?? 0);

/// Dedicated provider for persistent "Saved for Later" items.
final savedForLaterProvider =
    StateNotifierProvider<SavedForLaterNotifier, List<CartItem>>(
        (ref) => SavedForLaterNotifier());

class SavedForLaterNotifier extends StateNotifier<List<CartItem>> {
  SavedForLaterNotifier() : super([]);

  void save(CartItem item) {
    if (!state.any((s) => s.productId == item.productId)) {
      state = [...state, item];
    }
  }

  void remove(String productId) {
    state = state.where((s) => s.productId != productId).toList();
  }

  void clear() {
    state = [];
  }
}

class CartNotifier extends StateNotifier<AsyncValue<Cart>> {
  CartNotifier(this._dio) : super(AsyncValue.data(_createEmptyCart())) {
    refresh();
  }

  final Dio _dio;

  static Cart _createEmptyCart() {
    return const Cart(
      id: '',
      itemCount: 0,
      subtotal: 0.0,
      items: [],
    );
  }

  Future<void> refresh() async {
    try {
      final res = await _dio
          .get('/marketplace/cart')
          .timeout(const Duration(milliseconds: 1500));
      final body = res.data as Map<String, dynamic>;
      if (body['data'] != null) {
        state = AsyncValue.data(
            Cart.fromJson(Map<String, dynamic>.from(body['data'] as Map)));
        return;
      }
    } catch (_) {
      // Fallback: keep existing cart or empty cart
      if (state.valueOrNull == null) {
        state = AsyncValue.data(_createEmptyCart());
      }
    }
  }

  Future<void> add(String productId, int quantity, [Product? product]) async {
    // 1. Instant optimistic local cart update (0ms UI latency)
    final current = state.valueOrNull ?? _createEmptyCart();
    final p = product ??
        defaultMilterraProducts.firstWhere(
          (item) => item.id == productId,
          orElse: () => Product(
            id: productId,
            vendorId: 'milterra-direct',
            title: 'Fresh Dairy Item',
            category: ProductCategory.feedNutrition,
            price: 450.0,
            unit: 'item',
            media: const [],
            description: '',
            inStock: true,
            availableQuantity: 99,
          ),
        );

    final existingIndex =
        current.items.indexWhere((it) => it.productId == productId);
    List<CartItem> newItems;
    if (existingIndex >= 0) {
      final existing = current.items[existingIndex];
      final newQty = existing.quantity + quantity;
      final updated = CartItem(
        id: existing.id,
        productId: existing.productId,
        title: existing.title,
        quantity: newQty,
        priceWhenAdded: existing.priceWhenAdded,
        currentPrice: existing.currentPrice,
        inStock: existing.inStock,
        lineTotal: existing.currentPrice * newQty,
        vendorName: existing.vendorName,
        primaryImage: existing.primaryImage,
        unit: existing.unit,
        availableQuantity: existing.availableQuantity,
      );
      newItems = List<CartItem>.from(current.items);
      newItems[existingIndex] = updated;
    } else {
      final newItem = CartItem(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}',
        productId: p.id,
        title: p.title,
        quantity: quantity,
        priceWhenAdded: p.price,
        currentPrice: p.price,
        inStock: p.inStock,
        lineTotal: p.price * quantity,
        vendorName: p.vendorId,
        primaryImage: p.media.isNotEmpty ? p.media.first : null,
        unit: p.unit,
        availableQuantity: p.availableQuantity,
      );
      newItems = [...current.items, newItem];
    }

    final subtotal =
        newItems.fold<double>(0.0, (sum, it) => sum + it.lineTotal);
    final totalCount =
        newItems.fold<int>(0, (sum, it) => sum + it.quantity);
    state = AsyncValue.data(Cart(
      id: current.id,
      itemCount: totalCount,
      subtotal: subtotal,
      items: newItems,
    ));

    // 2. Non-blocking background network sync with 1s timeout
    _dio
        .post('/marketplace/cart/items',
            data: {'product_id': productId, 'quantity': quantity})
        .timeout(const Duration(milliseconds: 1000))
        .catchError((_) => Response(requestOptions: RequestOptions()));
  }

  Future<void> update(String itemId, int quantity) async {
    final current = state.valueOrNull ?? _createEmptyCart();
    if (quantity <= 0) {
      await remove(itemId);
      return;
    }
    final newItems = current.items.map((it) {
      if (it.id == itemId) {
        return CartItem(
          id: it.id,
          productId: it.productId,
          title: it.title,
          quantity: quantity,
          priceWhenAdded: it.priceWhenAdded,
          currentPrice: it.currentPrice,
          inStock: it.inStock,
          lineTotal: it.currentPrice * quantity,
          vendorName: it.vendorName,
          primaryImage: it.primaryImage,
          unit: it.unit,
          availableQuantity: it.availableQuantity,
        );
      }
      return it;
    }).toList();

    final subtotal =
        newItems.fold<double>(0.0, (sum, it) => sum + it.lineTotal);
    final totalCount =
        newItems.fold<int>(0, (sum, it) => sum + it.quantity);
    state = AsyncValue.data(Cart(
      id: current.id,
      itemCount: totalCount,
      subtotal: subtotal,
      items: newItems,
    ));

    _dio
        .put('/marketplace/cart/items/$itemId', data: {'quantity': quantity})
        .timeout(const Duration(milliseconds: 1000))
        .catchError((_) => Response(requestOptions: RequestOptions()));
  }

  Future<void> remove(String itemId) async {
    final current = state.valueOrNull ?? _createEmptyCart();
    final newItems = current.items.where((it) => it.id != itemId).toList();
    final subtotal =
        newItems.fold<double>(0.0, (sum, it) => sum + it.lineTotal);
    final totalCount =
        newItems.fold<int>(0, (sum, it) => sum + it.quantity);
    state = AsyncValue.data(Cart(
      id: current.id,
      itemCount: totalCount,
      subtotal: subtotal,
      items: newItems,
    ));

    _dio
        .delete('/marketplace/cart/items/$itemId')
        .timeout(const Duration(milliseconds: 1000))
        .catchError((_) => Response(requestOptions: RequestOptions()));
  }

  Future<void> clear() async {
    state = const AsyncValue.data(Cart(
      id: 'cart-session-1',
      itemCount: 0,
      subtotal: 0.0,
      items: [],
    ));

    _dio
        .delete('/marketplace/cart')
        .timeout(const Duration(milliseconds: 1000))
        .catchError((_) => Response(requestOptions: RequestOptions()));
  }

  Future<Map<String, dynamic>> validate() async {
    try {
      final body = (await _dio.post('/marketplace/cart/validate')).data
          as Map<String, dynamic>;
      return Map<String, dynamic>.from(body['data'] as Map);
    } catch (_) {
      final current = state.valueOrNull ?? _createEmptyCart();
      return {
        'valid': true,
        'subtotal': current.subtotal,
        'delivery_fee': current.subtotal >= 499 ? 0.0 : 49.0,
        'total': current.subtotal + (current.subtotal >= 499 ? 0.0 : 49.0),
      };
    }
  }
}
