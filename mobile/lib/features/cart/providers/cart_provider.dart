import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/cart_models.dart';

final cartProvider = StateNotifierProvider<CartNotifier, AsyncValue<Cart>>(
    (ref) => CartNotifier(ref.read(dioProvider)));
final cartItemCountProvider =
    Provider<int>((ref) => ref.watch(cartProvider).valueOrNull?.itemCount ?? 0);

class CartNotifier extends StateNotifier<AsyncValue<Cart>> {
  CartNotifier(this._dio) : super(const AsyncValue.loading()) {
    refresh();
  }
  final Dio _dio;
  Future<void> refresh() async {
    try {
      final body =
          (await _dio.get('/marketplace/cart')).data as Map<String, dynamic>;
      state = AsyncValue.data(
          Cart.fromJson(Map<String, dynamic>.from(body['data'] as Map)));
    } on DioException catch (e, st) {
      state = AsyncValue.error(dioErrorMessage(e), st);
    }
  }

  Future<void> add(String productId, int quantity) async {
    await _dio.post('/marketplace/cart/items',
        data: {'product_id': productId, 'quantity': quantity});
    await refresh();
  }

  Future<void> update(String itemId, int quantity) async {
    await _dio
        .put('/marketplace/cart/items/$itemId', data: {'quantity': quantity});
    await refresh();
  }

  Future<void> remove(String itemId) async {
    await _dio.delete('/marketplace/cart/items/$itemId');
    await refresh();
  }

  Future<void> clear() async {
    await _dio.delete('/marketplace/cart');
    await refresh();
  }

  Future<Map<String, dynamic>> validate() async {
    final body = (await _dio.post('/marketplace/cart/validate')).data
        as Map<String, dynamic>;
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
