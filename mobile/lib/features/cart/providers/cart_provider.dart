import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import 'package:dairy_ai/features/marketplace/models/product_models.dart';
import 'package:dairy_ai/core/analytics_service.dart';
import '../models/cart_models.dart';

final cartProvider =
    StateNotifierProvider<CartNotifier, AsyncValue<Cart>>((ref) {
  final user = ref.watch(currentUserProvider);
  return CartNotifier(
      ref.read(dioProvider), ref.read(analyticsServiceProvider), user != null);
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
      if (mounted)
        ref.read(savedItemsErrorProvider.notifier).state =
            'Saved items could not be loaded.';
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
  CartNotifier(this._dio, [this._analytics, bool enabled = true])
      : super(AsyncValue.data(_createEmptyCart())) {
    if (enabled) refresh();
  }

  final Dio _dio;
  final AnalyticsService? _analytics;

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
      if (!mounted) return;
      state = AsyncValue.data(
        Cart.fromJson(Map<String, dynamic>.from(body['data'] as Map)),
      );
    } catch (error, stackTrace) {
      if (mounted) {
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
    _analytics?.trackAddToCart(
      productId,
      product?.title ?? 'Product',
      quantity,
      product?.price ?? 0.0,
    );
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
    _analytics?.trackRemoveFromCart(itemId, 'Cart Item');
    await _dio.delete('/marketplace/cart/items/$itemId');
    await refresh(throwOnError: true);
  }

  Future<void> clear() async {
    await _dio.delete('/marketplace/cart');
    if (mounted) state = AsyncValue.data(_createEmptyCart());
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
