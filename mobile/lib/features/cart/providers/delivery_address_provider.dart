import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dairy_ai/core/api_client.dart';
import 'package:dairy_ai/features/auth/providers/auth_provider.dart';
import '../models/delivery_address.dart';

final deliveryAddressesProvider = StateNotifierProvider<DeliveryAddressNotifier,
        AsyncValue<List<DeliveryAddress>>>(
    (ref) => DeliveryAddressNotifier(ref.read(dioProvider)));

class DeliveryAddressNotifier
    extends StateNotifier<AsyncValue<List<DeliveryAddress>>> {
  DeliveryAddressNotifier(this._dio) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Dio _dio;

  Future<void> refresh() async {
    try {
      final body = (await _dio.get('/marketplace/addresses')).data
          as Map<String, dynamic>;
      final data = body['data'] as List? ?? [];
      state = AsyncValue.data(data
          .map((item) =>
              DeliveryAddress.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList());
    } on DioException catch (error, stackTrace) {
      state = AsyncValue.error(dioErrorMessage(error), stackTrace);
    }
  }

  Future<void> create(Map<String, dynamic> address) async {
    await _dio.post('/marketplace/addresses', data: address);
    await refresh();
  }

  Future<void> makeDefault(String addressId) async {
    await _dio
        .put('/marketplace/addresses/$addressId', data: {'is_default': true});
    await refresh();
  }

  Future<void> delete(String addressId) async {
    await _dio.delete('/marketplace/addresses/$addressId');
    await refresh();
  }
}
