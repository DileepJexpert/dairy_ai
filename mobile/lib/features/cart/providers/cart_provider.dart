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

  Future<void> refresh({bool throwOnError = false}) async {
    try {
      final res = await _dio.get('/marketplace/cart');
      final body = res.data as Map<String, dynamic>;
      if (body['data'] is! Map) {
        throw const FormatException('Cart response did not contain data');
      }
      state = AsyncValue.data(
        Cart.fromJson(Map<String, dynamic>.from(body['data'] as Map)),
      );
    } catch (error, stackTrace) {
      if (state.valueOrNull == null) {
        state = AsyncValue.error(error, stackTrace);
      }
      if (throwOnError) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  Future<void> add(String productId, int quantity, [Product? product]) async {
    if (product?.isConcept == true) {
      throw StateError('Concept products are not for sale');
    }
    await _dio.post('/marketplace/cart/items', data: {
      'product_id': productId,
      'quantity': quantity,
    });
    await refresh(throwOnError: true);
  }

  Future<void> update(String itemId, int quantity) async {
    if (quantity <= 0) {
      await remove(itemId);
      return;
    }
    await _dio.put(
      '/marketplace/cart/items/$itemId',
      data: {'quantity': quantity},
    );
    await refresh(throwOnError: true);
  }

  Future<void> remove(String itemId) async {
    await _dio.delete('/marketplace/cart/items/$itemId');
    await refresh(throwOnError: true);
  }

  Future<void> clear() async {
    await _dio.delete('/marketplace/cart');
    state = AsyncValue.data(_createEmptyCart());
  }

  Future<Map<String, dynamic>> validate() async {
    try {
      final body = (await _dio.post('/marketplace/cart/validate')).data
          as Map<String, dynamic>;
      return Map<String, dynamic>.from(body['data'] as Map);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
