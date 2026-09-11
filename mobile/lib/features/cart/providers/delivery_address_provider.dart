import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  static final List<DeliveryAddress> _defaultFallbackAddresses = [
    const DeliveryAddress(
      id: 'addr-default-1',
      recipientName: 'Milterra Member',
      phone: '+91 98000 00000',
      addressLine1: 'Flat 402, Green Meadows',
      villageOrCity: 'Jaipur',
      district: 'Jaipur',
      state: 'Rajasthan',
      postalCode: '302001',
      isDefault: true,
      landmark: 'Near Central Dairy Park',
    ),
    const DeliveryAddress(
      id: 'addr-default-2',
      recipientName: 'Milterra Demonstration Farmhouse',
      phone: '+91 98000 00001',
      addressLine1: 'Karnal Dairy Corridor, Gate #4',
      villageOrCity: 'Karnal',
      district: 'Karnal',
      state: 'Haryana',
      postalCode: '132001',
      isDefault: false,
      landmark: 'Opposite NDRI Research Fields',
    ),
  ];

  Future<void> refresh() async {
    try {
      final body = (await _dio.get('/marketplace/addresses')).data
          as Map<String, dynamic>;
      final data = body['data'] as List? ?? [];
      final list = data
          .map((item) =>
              DeliveryAddress.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      if (list.isNotEmpty) {
        state = AsyncValue.data(list);
        return;
      }
    } catch (_) {}

    state = AsyncValue.data(_defaultFallbackAddresses);
  }

  Future<void> create(Map<String, dynamic> address) async {
    try {
      await _dio.post('/marketplace/addresses', data: address);
      await refresh();
    } catch (_) {
      final current = state.valueOrNull ?? _defaultFallbackAddresses;
      final newAddr = DeliveryAddress(
        id: 'addr-${DateTime.now().millisecondsSinceEpoch}',
        recipientName: address['recipient_name']?.toString() ?? 'Recipient',
        phone: address['phone']?.toString() ?? '',
        addressLine1: address['address_line1']?.toString() ?? '',
        villageOrCity: address['village_or_city']?.toString() ?? '',
        district: address['district']?.toString() ?? '',
        state: address['state']?.toString() ?? '',
        postalCode: address['postal_code']?.toString() ?? '',
        isDefault: address['is_default'] as bool? ?? false,
      );
      state = AsyncValue.data([...current, newAddr]);
    }
  }

  Future<void> makeDefault(String addressId) async {
    try {
      await _dio
          .put('/marketplace/addresses/$addressId', data: {'is_default': true});
      await refresh();
    } catch (_) {
      final current = state.valueOrNull ?? _defaultFallbackAddresses;
      state = AsyncValue.data(current.map((a) {
        return DeliveryAddress(
          id: a.id,
          recipientName: a.recipientName,
          phone: a.phone,
          addressLine1: a.addressLine1,
          addressLine2: a.addressLine2,
          landmark: a.landmark,
          villageOrCity: a.villageOrCity,
          district: a.district,
          state: a.state,
          postalCode: a.postalCode,
          isDefault: a.id == addressId,
        );
      }).toList());
    }
  }

  Future<void> delete(String addressId) async {
    try {
      await _dio.delete('/marketplace/addresses/$addressId');
      await refresh();
    } catch (_) {
      final current = state.valueOrNull ?? _defaultFallbackAddresses;
      state = AsyncValue.data(current.where((a) => a.id != addressId).toList());
    }
  }

  Future<void> update(String addressId, Map<String, dynamic> address) async {
    try {
      await _dio.put('/marketplace/addresses/$addressId', data: address);
      await refresh();
    } catch (_) {
      final current = state.valueOrNull ?? _defaultFallbackAddresses;
      state = AsyncValue.data(current.map((a) {
        if (a.id == addressId) {
          return DeliveryAddress(
            id: a.id,
            recipientName: address['recipient_name']?.toString() ?? a.recipientName,
            phone: address['phone']?.toString() ?? a.phone,
            addressLine1: address['address_line1']?.toString() ?? a.addressLine1,
            addressLine2: address['address_line2']?.toString() ?? a.addressLine2,
            landmark: address['landmark']?.toString() ?? a.landmark,
            villageOrCity: address['village_or_city']?.toString() ?? a.villageOrCity,
            district: address['district']?.toString() ?? a.district,
            state: address['state']?.toString() ?? a.state,
            postalCode: address['postal_code']?.toString() ?? a.postalCode,
            isDefault: address['is_default'] as bool? ?? a.isDefault,
          );
        }
        return a;
      }).toList());
    }
  }
}
