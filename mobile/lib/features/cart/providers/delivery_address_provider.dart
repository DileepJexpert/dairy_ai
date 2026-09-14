import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/delivery_address.dart';

final deliveryAddressesProvider = StateNotifierProvider<DeliveryAddressNotifier,
        AsyncValue<List<DeliveryAddress>>>(
    (ref) => DeliveryAddressNotifier(ref.read(dioProvider),
        enabled: ref.watch(currentUserProvider) != null));

class DeliveryAddressNotifier
    extends StateNotifier<AsyncValue<List<DeliveryAddress>>> {
  DeliveryAddressNotifier(this._dio, {bool enabled = true})
      : super(const AsyncValue.data([])) {
    if (enabled) refresh();
  }

  final Dio _dio;

  Future<void> refresh() async {
    try {
      final body = (await _dio.get('/marketplace/addresses')).data
          as Map<String, dynamic>;
      final data = body['data'] as List? ?? [];
      final list = data
          .map((item) =>
              DeliveryAddress.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      if (mounted) state = AsyncValue.data(list);
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> create(Map<String, dynamic> address) async {
    try {
      await _dio.post('/marketplace/addresses', data: address);
      await refresh();
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> makeDefault(String addressId) async {
    try {
      await _dio
          .put('/marketplace/addresses/$addressId', data: {'is_default': true});
      await refresh();
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> delete(String addressId) async {
    try {
      await _dio.delete('/marketplace/addresses/$addressId');
      await refresh();
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> update(String addressId, Map<String, dynamic> address) async {
    try {
      await _dio.put('/marketplace/addresses/$addressId', data: address);
      await refresh();
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}
